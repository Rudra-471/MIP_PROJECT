classdef AppController < handle
    %APPCONTROLLER State and callbacks of the dashboard (the "glue" layer).
    %   The controller holds the application state (configuration, loaded
    %   model, current single-image analysis, dataset scan, evaluation) and
    %   implements every UI callback. All image processing, training and
    %   evaluation is delegated to the project modules (runAnalysisStep,
    %   runTrainingWorkflow, classifyFeatures, ...); this class only calls
    %   them and renders their results. Errors are caught, logged
    %   (logs/app.log) and shown to the user - never silently ignored.

    properties
        Figure                      % uifigure
        Theme                       % uiTheme()
        Config                      % current processing / dataset / SVM configuration
        UI = struct()               % handles returned by the build* functions
        Dependencies                % checkDependencies() report
        Model = []                  % trained model struct ([] = not trained / not loaded)
        Analysis = []               % current single-image analysis ([] = no image)
        AnalysisVersion = 0         % incremented whenever Analysis changes
        Prediction = []             % last prediction (valid only for AnalysisVersion)
        DatasetDir = ''
        MetadataFile = ''
        Meta = []                   % loaded NIH metadata (also used for dataset labels)
        DatasetSummary = []         % result of the last dataset scan
        TrainingState = 'idle'      % idle | running | done | failed | cancelled
        LastTraining = []           % runTrainingWorkflow result of this session
        CurrentPage = 'dashboard'
        InspectorView = 'histogram' % histogram | morphology
        ModelFile = ''              % '' -> models/trainedModel.mat
        ResultsRoot = ''            % '' -> results/
    end

    methods (Static)
        function pages = pageList()
            pages = {'dashboard',  'Dashboard'
                     'analysis',   'Image Analysis'
                     'training',   'Dataset & Training'
                     'evaluation', 'Model Evaluation'
                     'about',      'Project Information'
                     'settings',   'Settings'};
        end

        function steps = stepList()
            % key, dashboard name, analysis-page button text
            steps = {'load',       'Image acquisition',          'Upload X-Ray'
                     'preprocess', 'Grayscale + noise reduction', 'Preprocess'
                     'enhance',    'Enhancement + gamma',        'Enhance Image'
                     'segment',    'Lung segmentation',          'Segment Lung'
                     'morphology', 'Morphological processing',   'Apply Morphology'
                     'features',   'Feature extraction',         'Extract Features'
                     'predict',    'SVM classification',         'Predict'};
        end
    end

    methods
        % ================================================================ setup
        function obj = AppController(fig, theme, cfg)
            obj.Figure = fig;
            obj.Theme = theme;
            obj.Config = cfg;
            obj.Dependencies = checkDependencies(false);
        end

        function attachUI(obj, ui)
            obj.UI = ui;
        end

        function initialize(obj, loadSavedModel)
            % Load an existing model (unless loadSavedModel is false), then
            % show the dashboard.
            if nargin < 2
                loadSavedModel = true;
            end
            if loadSavedModel && exist(obj.modelFilePath(), 'file') == 2
                try
                    obj.setModel(loadTrainedModel(obj.modelFilePath()));
                    logMessage('INFO', 'Loaded model %s', obj.modelFilePath());
                catch err
                    obj.Model = [];
                    logMessage('WARN', 'Saved model could not be loaded: %s', err.message);
                    uialert(obj.Figure, sprintf(['The saved model could not be used:\n%s\n\n' ...
                        'Train a new model on the Dataset & Training page.'], err.message), ...
                        'Model not available', 'Icon', 'warning');
                end
            end
            if ~obj.Dependencies.ok
                uialert(obj.Figure, obj.Dependencies.message, 'Missing toolboxes', 'Icon', 'error');
                logMessage('ERROR', '%s', obj.Dependencies.message);
            end
            obj.syncSettingsUI();
            obj.refreshAll();
            obj.navigate('dashboard');
        end

        % =========================================================== navigation
        function navigate(obj, page)
            pages = AppController.pageList();
            if ~any(strcmp(pages(:, 1), page))
                return;
            end
            obj.CurrentPage = page;
            for k = 1:size(pages, 1)
                active = strcmp(pages{k, 1}, page);
                panel = obj.UI.(pages{k, 1}).panel;
                panel.Visible = onOff(active);
                btn = obj.UI.sidebar.navButtons{k};
                bar = obj.UI.sidebar.navBars{k};
                if active
                    btn.BackgroundColor = obj.Theme.cardAlt;
                    btn.FontColor = obj.Theme.text;
                    btn.FontWeight = 'bold';
                    bar.BackgroundColor = obj.Theme.accent;
                else
                    btn.BackgroundColor = obj.Theme.sidebar;
                    btn.FontColor = obj.Theme.textMuted;
                    btn.FontWeight = 'normal';
                    bar.BackgroundColor = obj.Theme.sidebar;
                end
            end
            titleLabel = obj.UI.top.title;
            titleLabel.Text = pages{strcmp(pages(:, 1), page), 2};
            switch page
                case 'dashboard',  obj.refreshDashboard();
                case 'evaluation', obj.refreshEvaluation();
                case 'training',   obj.refreshTrainingPage();
            end
            obj.refreshTopBar();
        end

        function refreshAll(obj)
            obj.renderAnalysis();
            obj.refreshTrainingPage();
            obj.refreshEvaluation();
            obj.refreshDashboard();
            obj.refreshTopBar();
        end

        % ======================================================= image analysis
        function uploadImage(obj)
            try
                [file, folder] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
                    'Chest X-ray images (*.png, *.jpg, *.jpeg, *.bmp, *.tif)'; '*.*', 'All files (*.*)'}, ...
                    'Select a chest X-ray image');
                obj.focus();
                if isequal(file, 0)
                    obj.setTopStatus('Upload cancelled - no image was selected.');
                    return;
                end
                obj.loadImageFile(fullfile(folder, file));
            catch err
                obj.reportError(err, 'Upload X-Ray');
            end
        end

        function loadImageFile(obj, filePath)
            % Load and validate an image (Upload X-Ray without the file dialog).
            try
                [~, name, ext] = fileparts(filePath);
                obj.setTopStatus(['Reading ' name ext ' ...']);
                analysis = createAnalysis(filePath, obj.Config);
                obj.setAnalysis(analysis);
                obj.InspectorView = 'histogram';
                obj.applyInspectorView();
                logMessage('INFO', 'Loaded image %s (%d x %d, %s, %s)', analysis.fileName, ...
                    analysis.imageInfo.width, analysis.imageInfo.height, analysis.imageInfo.colorType, ...
                    analysis.imageInfo.class);
                obj.navigate('analysis');
                obj.refreshAll();
            catch err
                obj.reportError(err, 'Upload X-Ray');
                obj.refreshAll();
            end
        end

        function runStep(obj, step)
            if strcmp(step, 'predict')
                obj.predict();
                return;
            end
            try
                [ok, reason] = obj.prerequisites(step);
                if ~ok
                    uialert(obj.Figure, reason, 'Step not available yet', 'Icon', 'warning');
                    return;
                end
                obj.setTopStatus(sprintf('Running: %s ...', stepName(step)));
                obj.setAnalysis(runAnalysisStep(obj.Analysis, step, obj.Config, true));
                obj.refreshAll();
                obj.reportStepOutcome(step);
            catch err
                obj.reportError(err, stepName(step));
                obj.refreshAll();
            end
        end

        function runFullAnalysis(obj)
            if isempty(obj.Analysis)
                obj.uploadImage();
                if isempty(obj.Analysis)
                    return;
                end
            end
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Run Full Analysis', 'Message', 'Starting...', 'Value', 0);
            closer = onCleanup(@() closeDialog(dlg));
            steps = {'preprocess', 'enhance', 'segment', 'morphology', 'features'};
            try
                for k = 1:numel(steps)
                    dlg.Message = sprintf('Step %d of %d: %s', k, numel(steps) + 1, stepName(steps{k}));
                    dlg.Value = (k - 1) / (numel(steps) + 1);
                    obj.setAnalysis(runAnalysisStep(obj.Analysis, steps{k}, obj.Config, false));
                    obj.renderAnalysis();
                    drawnow limitrate;
                    if strcmp(steps{k}, 'segment') && ~strcmp(obj.Analysis.seg.status, 'ok')
                        obj.refreshAll();
                        closeDialog(dlg);
                        uialert(obj.Figure, sprintf(['Lung segmentation failed:\n%s\n\nThe analysis stopped ' ...
                            'because lung-region features (and therefore a prediction) need a lung mask.'], ...
                            obj.Analysis.seg.message), 'Segmentation failed', 'Icon', 'warning');
                        return;
                    end
                end
                dlg.Value = numel(steps) / (numel(steps) + 1);
                if ~isempty(obj.Model)
                    dlg.Message = 'Step 6 of 6: SVM classification';
                    obj.classifyCurrent();
                end
                obj.refreshAll();
                closeDialog(dlg);
                if isempty(obj.Model)
                    uialert(obj.Figure, ['All processing steps finished. No trained model is loaded, ' ...
                        'so no prediction was made. Train a model on the Dataset & Training page.'], ...
                        'Analysis complete', 'Icon', 'info');
                elseif strcmp(obj.Analysis.refine.status, 'partial')
                    uialert(obj.Figure, [obj.Analysis.refine.message ' The prediction was made, but ' ...
                        'treat it with extra caution.'], 'Segmentation uncertain', 'Icon', 'warning');
                end
            catch err
                closeDialog(dlg);
                obj.reportError(err, 'Run Full Analysis');
                obj.refreshAll();
            end
        end

        function predict(obj)
            try
                [ok, reason] = obj.canPredict();
                if ~ok
                    uialert(obj.Figure, reason, 'Prediction not available', 'Icon', 'warning');
                    return;
                end
                obj.setTopStatus('Running: SVM classification ...');
                obj.classifyCurrent();
                obj.refreshAll();
            catch err
                obj.reportError(err, 'Predict');
                obj.refreshAll();
            end
        end

        function resetAnalysis(obj, askFirst)
            if askFirst && ~isempty(obj.Analysis)
                choice = uiconfirm(obj.Figure, 'Clear the current image and all analysis results?', ...
                    'Reset analysis', 'Options', {'Reset', 'Cancel'}, 'DefaultOption', 2, ...
                    'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Reset')
                    return;
                end
            end
            obj.setAnalysis([]);
            obj.refreshAll();
            obj.setTopStatus('Analysis reset - upload a chest X-ray to begin.');
        end

        function setEnhancementMethod(obj, method)
            obj.Config.enhance.method = method;
            obj.reapplyEnhancement();
        end

        function previewGamma(obj, value)
            label = obj.UI.analysis.gammaLabel;
            label.Text = sprintf('Gamma correction   %s = %.2f', char(947), value);
        end

        function setGamma(obj, value)
            value = round(value * 100) / 100;
            obj.Config.enhance.gamma = value;
            slider = obj.UI.analysis.gammaSlider;
            slider.Value = value;
            obj.reapplyEnhancement();
        end

        function showInspector(obj, view)
            obj.InspectorView = view;
            obj.applyInspectorView();
            obj.renderInspector();
        end

        function exportAnalysisReport(obj)
            try
                if isempty(obj.Analysis)
                    uialert(obj.Figure, 'Upload and analyse an image first.', 'Nothing to export', 'Icon', 'warning');
                    return;
                end
                [~, base] = fileparts(obj.Analysis.fileName);
                [file, folder] = uiputfile({'*.txt', 'Text report (*.txt)'; '*.csv', 'CSV report (*.csv)'}, ...
                    'Export analysis report', fullfile(obj.resultsRootPath(), [base '_report.txt']));
                obj.focus();
                if isequal(file, 0)
                    return;
                end
                obj.exportReportTo(fullfile(folder, file));
            catch err
                obj.reportError(err, 'Export Report');
            end
        end

        function exportReportTo(obj, filePath)
            % Write the analysis report (TXT or CSV by extension) without a dialog.
            try
                exportReport(obj.buildReport(), filePath);
                logMessage('INFO', 'Exported analysis report %s', filePath);
                uialert(obj.Figure, sprintf('Report saved to\n%s', filePath), 'Report exported', 'Icon', 'success');
            catch err
                obj.reportError(err, 'Export Report');
            end
        end

        % ===================================================== dataset & training
        function browseDataset(obj)
            try
                start = obj.DatasetDir;
                if isempty(start) || exist(start, 'dir') ~= 7
                    start = fullfile(projectRoot(), 'dataset');
                end
                folder = uigetdir(start, 'Select the NIH ChestX-ray14 dataset folder');
                obj.focus();
                if isequal(folder, 0)
                    return;
                end
                obj.setDatasetFolder(folder);
            catch err
                obj.reportError(err, 'Select dataset folder');
            end
        end

        function setDatasetFolder(obj, folder)
            % Use folder as dataset root and auto-detect the metadata CSV.
            if exist(folder, 'dir') ~= 7
                error('CXR:missingDataset', 'Dataset folder not found: %s', folder);
            end
            obj.DatasetDir = folder;
            obj.MetadataFile = '';
            for k = 1:numel(obj.Config.dataset.metadataFileNames)
                candidate = fullfile(folder, obj.Config.dataset.metadataFileNames{k});
                if exist(candidate, 'file') == 2
                    obj.MetadataFile = candidate;
                    break;
                end
            end
            obj.Meta = [];
            obj.DatasetSummary = [];
            msgs = {sprintf('Dataset folder: %s', folder)};
            if isempty(obj.MetadataFile)
                msgs{end + 1} = ['Data_Entry_2017_v2020.csv was not found in this folder. ' ...
                    'Select it with the second Browse button.'];
            else
                msgs{end + 1} = 'Metadata CSV detected. Click "Scan & Validate Dataset".';
            end
            messagesArea = obj.UI.training.messages;
            messagesArea.Value = msgs(:);
            obj.refreshAll();
        end

        function browseMetadata(obj)
            try
                start = obj.DatasetDir;
                if isempty(start)
                    start = projectRoot();
                end
                [file, folder] = uigetfile({'*.csv', 'NIH metadata (*.csv)'}, ...
                    'Select Data_Entry_2017_v2020.csv', start);
                obj.focus();
                if isequal(file, 0)
                    return;
                end
                obj.MetadataFile = fullfile(folder, file);
                if isempty(obj.DatasetDir)
                    obj.DatasetDir = folder;
                end
                obj.Meta = [];
                obj.DatasetSummary = [];
                obj.refreshAll();
            catch err
                obj.reportError(err, 'Select metadata file');
            end
        end

        function scanDataset(obj)
            if isempty(obj.DatasetDir)
                uialert(obj.Figure, 'Select the dataset folder first (Browse).', 'No dataset folder', 'Icon', 'warning');
                return;
            end
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Scan & Validate Dataset', ...
                'Message', 'Reading metadata CSV...', 'Indeterminate', 'on');
            closer = onCleanup(@() closeDialog(dlg));
            try
                cfg = obj.trainingConfig();
                if isempty(obj.MetadataFile)
                    error('CXR:missingMetadata', ['Data_Entry_2017_v2020.csv was not found in %s. ' ...
                        'Download it from https://nihcc.app.box.com/v/ChestXray-NIHCC and select it.'], obj.DatasetDir);
                end
                meta = loadDatasetMetadata(obj.MetadataFile, cfg);
                dlg.Message = 'Indexing image files (this can take a minute for the full dataset)...';
                index = indexDatasetImages(obj.DatasetDir, cfg, ...
                    @(n, folder) setDialogMessage(dlg, sprintf('Indexing image files... %d folders searched', n)));
                official = loadOfficialSplit(fileparts(obj.MetadataFile), cfg);
                if isempty(official)
                    official = loadOfficialSplit(obj.DatasetDir, cfg);
                end
                obj.Meta = meta;
                obj.DatasetSummary = obj.summarizeDataset(meta, index, official, cfg);
                obj.refreshTrainingPage();
                obj.refreshAll();
                closeDialog(dlg);
                if obj.DatasetSummary.numFound == 0
                    uialert(obj.Figure, ['None of the images listed in the metadata were found in the ' ...
                        'selected folder. Check that the image archives are extracted there.'], ...
                        'No images found', 'Icon', 'warning');
                end
            catch err
                closeDialog(dlg);
                messagesArea = obj.UI.training.messages;
                messagesArea.Value = {['Dataset validation failed: ' err.message]};
                obj.reportError(err, 'Scan dataset');
            end
        end

        function startTraining(obj)
            if strcmp(obj.TrainingState, 'running')
                return;
            end
            if ~obj.Dependencies.ok
                uialert(obj.Figure, obj.Dependencies.message, 'Missing toolboxes', 'Icon', 'error');
                return;
            end
            if isempty(obj.DatasetDir)
                uialert(obj.Figure, 'Select and scan the NIH dataset folder first.', 'No dataset', 'Icon', 'warning');
                return;
            end
            if ~isempty(obj.Model)
                choice = uiconfirm(obj.Figure, sprintf(['Training replaces the current model ' ...
                    '(%s). Continue?'], obj.modelFilePath()), 'Start training', ...
                    'Options', {'Train new model', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
                if ~strcmp(choice, 'Train new model')
                    return;
                end
            end
            cfg = obj.trainingConfig();
            ui = obj.UI.training;
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Training SVM', 'Message', 'Starting...', ...
                'Value', 0, 'Cancelable', 'on', 'CancelText', 'Cancel training');
            closer = onCleanup(@() closeDialog(dlg));
            obj.TrainingState = 'running';
            ui.trainButton.Enable = 'off';
            ui.log.Value = {sprintf('[%s] Training started.', datestr(now, 'HH:MM:SS'))};
            obj.refreshTopBar();
            obj.refreshDashboard();
            try
                result = runTrainingWorkflow(obj.DatasetDir, 'Config', cfg, ...
                    'MetadataFile', obj.MetadataFile, 'UseCache', ui.useCache.Value, ...
                    'ModelFile', obj.modelFilePath(), ...
                    'ResultsDir', fullfile(obj.resultsRootPath(), ['evaluation_' datestr(now, 'yyyymmdd_HHMMSS')]), ...
                    'ProgressFcn', @(f, msg) obj.trainingProgress(dlg, f, msg));
                ui.log.Value = [ui.log.Value(:); result.log(:)];
                if strcmp(result.status, 'cancelled')
                    obj.TrainingState = 'cancelled';
                    obj.setProgress(0, 'Training cancelled - no model was saved.');
                    closeDialog(dlg);
                    uialert(obj.Figure, 'Training was cancelled. The previous model (if any) is unchanged.', ...
                        'Training cancelled', 'Icon', 'info');
                else
                    obj.TrainingState = 'done';
                    obj.LastTraining = result;
                    obj.Config.dataset = cfg.dataset;
                    obj.Config.svm = cfg.svm;
                    obj.setModel(result.model);
                    obj.setProgress(1, sprintf('Model training status: trained (%s)', result.model.trainingInfo.trainedOn));
                    closeDialog(dlg);
                    m = result.evaluation.metrics;
                    obj.navigate('evaluation');
                    uialert(obj.Figure, sprintf(['Training finished.\n\nHeld-out test set: %d images\n' ...
                        'Accuracy %s, Sensitivity %s, Specificity %s\n\nModel: %s\nResults: %s'], ...
                        m.numSamples, pct(m.accuracy), pct(m.sensitivity), pct(m.specificity), ...
                        result.modelFile, result.resultsDir), 'Training complete', 'Icon', 'success');
                end
            catch err
                obj.TrainingState = 'failed';
                ui.log.Value = [ui.log.Value(:); {['ERROR: ' err.message]}];
                obj.setProgress(0, 'Model training status: failed (see log)');
                closeDialog(dlg);
                obj.reportError(err, 'Training failed');
            end
            ui.trainButton.Enable = 'on';
            obj.refreshAll();
        end

        function stop = trainingProgress(obj, dlg, fraction, message)
            stop = false;
            try
                dlg.Value = min(max(fraction, 0), 1);
                dlg.Message = message;
                stop = dlg.CancelRequested;
            catch
            end
            obj.setProgress(fraction, message);
            drawnow limitrate;
        end

        % ============================================================ evaluation
        function exportEvaluationResults(obj)
            try
                ev = obj.currentEvaluation();
                if isempty(ev)
                    uialert(obj.Figure, 'Evaluation pending: train a model first.', 'Nothing to export', 'Icon', 'warning');
                    return;
                end
                folder = uigetdir(obj.resultsRootPath(), 'Select a folder for the evaluation files');
                obj.focus();
                if isequal(folder, 0)
                    return;
                end
                out = fullfile(folder, ['evaluation_export_' datestr(now, 'yyyymmdd_HHMMSS')]);
                exportEvaluation(ev, out);
                uialert(obj.Figure, sprintf(['Saved metrics.csv, metrics.txt, confusion_matrix.csv and ' ...
                    'test_predictions.csv to\n%s'], out), 'Metrics exported', 'Icon', 'success');
            catch err
                obj.reportError(err, 'Export Metrics');
            end
        end

        function exportConfusionFigure(obj)
            try
                ev = obj.currentEvaluation();
                if isempty(ev)
                    uialert(obj.Figure, 'Evaluation pending: train a model first.', 'Nothing to export', 'Icon', 'warning');
                    return;
                end
                [file, folder] = uiputfile({'*.png', 'PNG image (*.png)'}, 'Export confusion matrix', ...
                    fullfile(obj.resultsRootPath(), 'confusion_matrix.png'));
                obj.focus();
                if isequal(file, 0)
                    return;
                end
                saveConfusionFigure(ev.metrics, fullfile(folder, file));
                uialert(obj.Figure, sprintf('Saved %s', fullfile(folder, file)), 'Figure exported', 'Icon', 'success');
            catch err
                obj.reportError(err, 'Export confusion matrix');
            end
        end

        function loadModelFromFile(obj)
            try
                [file, folder] = uigetfile({'*.mat', 'Trained model (*.mat)'}, 'Load a trained model', ...
                    fullfile(projectRoot(), 'models'));
                obj.focus();
                if isequal(file, 0)
                    return;
                end
                obj.setModel(loadTrainedModel(fullfile(folder, file)));
                obj.refreshAll();
                uialert(obj.Figure, sprintf('Loaded %s', fullfile(folder, file)), 'Model loaded', 'Icon', 'success');
            catch err
                obj.reportError(err, 'Load model');
            end
        end

        % ============================================================== settings
        function applySettings(obj)
            try
                s = obj.UI.settings;
                cfg = obj.Config;
                cfg.preprocess.processingSize = s.processingSize.Value;
                cfg.preprocess.noiseMethod = s.noiseMethod.Value;
                cfg.preprocess.medianWindow = [1 1] * s.medianWindow.Value;
                cfg.preprocess.gaussianSigma = s.gaussianSigma.Value;
                cfg.enhance.claheClipLimit = s.claheClip.Value;
                cfg.enhance.claheNumTiles = [1 1] * s.claheTiles.Value;
                cfg.enhance.stretchTolerance = [s.stretchTol.Value, 100 - s.stretchTol.Value] / 100;
                cfg.features.glcmNumLevels = s.glcmLevels.Value;
                cfg.morph.openRadius = s.openRadius.Value;
                cfg.morph.closeRadius = s.closeRadius.Value;
                cfg.morph.erodeRadius = s.erodeRadius.Value;
                cfg.morph.dilateRadius = s.dilateRadius.Value;
                changed = ~pipelineConfigsMatch(cfg, obj.Config);
                obj.Config = cfg;
                if changed && ~isempty(obj.Analysis)
                    obj.setAnalysis(clearAnalysisFrom(obj.Analysis, 'preprocess'));
                end
                note = sprintf('Settings applied at %s.', datestr(now, 'HH:MM:SS'));
                if ~isempty(obj.Model) && ~pipelineConfigsMatch(cfg, obj.Model.pipelineConfig)
                    note = [note ' They differ from the loaded model''s training configuration.'];
                end
                s.state.Text = note;
                obj.refreshAll();
            catch err
                obj.reportError(err, 'Apply settings');
            end
        end

        function restoreDefaultSettings(obj)
            defaults = appConfig();
            obj.Config = adoptPipelineConfig(obj.Config, defaults);
            obj.syncSettingsUI();
            obj.applySettings();
        end

        % ============================================================== rendering
        function renderAnalysis(obj)
            ui = obj.UI.analysis;
            t = obj.Theme;
            a = obj.Analysis;
            obj.previewGamma(obj.Config.enhance.gamma);
            if ~isequal(ui.method.Value, obj.Config.enhance.method)
                ui.method.Value = obj.Config.enhance.method;
            end
            if isempty(a)
                showEmptyState(ui.axes.original, t, 'Upload a chest X-ray to begin');
                showEmptyState(ui.axes.enhanced, t, 'Run Preprocess, then Enhance Image');
                showEmptyState(ui.axes.mask, t, 'Run Segment Lung');
                showEmptyState(ui.axes.final, t, 'Run Apply Morphology');
                names = fieldnames(ui.info);
                for k = 1:numel(names)
                    ui.info.(names{k}).Text = '';
                end
                ui.fileLabel.Text = 'No image loaded';
                ui.featureTable.Data = cell(0, 3);
                ui.roiLabel.Text = 'Features are extracted from the final lung mask.';
                ui.roiLabel.FontColor = t.textFaint;
                obj.renderInspector();
                obj.renderStatusAndPrediction();
                obj.refreshAnalysisControls();
                return;
            end

            info = a.imageInfo;
            ui.fileLabel.Text = sprintf('%s  (%d x %d px)', a.fileName, info.width, info.height);
            showImage(ui.axes.original, a.original, t);
            ui.info.original.Text = sprintf('%d x %d px  |  %s  |  %s  |  %s', info.width, info.height, ...
                info.format, info.colorType, info.class);

            if a.done.enhance
                showImage(ui.axes.enhanced, a.enhanced, t);
                ui.info.enhanced.Text = sprintf('%s  |  gamma %.2f  |  %s noise filter', ...
                    methodName(a.enhancementMethod), a.gamma, a.pre.noiseMethod);
            elseif a.done.preprocess
                showImage(ui.axes.enhanced, a.pre.denoised, t);
                ui.info.enhanced.Text = sprintf('Preprocessed only (grayscale, %d x %d, %s filter) - not enhanced yet', ...
                    size(a.pre.denoised, 2), size(a.pre.denoised, 1), a.pre.noiseMethod);
            else
                showEmptyState(ui.axes.enhanced, t, 'Run Preprocess, then Enhance Image');
                ui.info.enhanced.Text = '';
            end

            if a.done.morphology && ~strcmp(a.refine.status, 'failed')
                showImage(ui.axes.mask, a.finalMask, t);
                ui.info.mask.Text = sprintf('Final mask: %d region(s), %.1f %% of image (%s)', ...
                    a.refine.numRegions, 100 * a.refine.areaFraction, a.refine.status);
            elseif a.done.morphology
                showEmptyState(ui.axes.mask, t, wrapText(['Mask empty after morphology: ' a.refine.message]), t.warning);
                ui.info.mask.Text = 'Segmentation failed';
            elseif a.done.segment && strcmp(a.seg.status, 'ok')
                showImage(ui.axes.mask, a.seg.initialMask, t);
                ui.info.mask.Text = sprintf('Initial mask (before morphology): %d region(s), %.1f %% of image', ...
                    a.seg.info.numRegions, 100 * a.seg.info.areaFraction);
            elseif a.done.segment
                showEmptyState(ui.axes.mask, t, wrapText(['Segmentation failed: ' a.seg.message]), t.warning);
                ui.info.mask.Text = 'No plausible lung region found';
            else
                showEmptyState(ui.axes.mask, t, 'Run Segment Lung');
                ui.info.mask.Text = '';
            end

            if ~isempty(a.overlay)
                showImage(ui.axes.final, a.overlay, t);
                ui.info.final.Text = 'Teal outline = approximate lung region (not a lesion localisation)';
            elseif a.done.morphology && strcmp(a.refine.status, 'failed')
                showEmptyState(ui.axes.final, t, 'No lung ROI available', t.warning);
                ui.info.final.Text = '';
            elseif a.done.morphology
                showEmptyState(ui.axes.final, t, 'Run Enhance Image to create the final image');
                ui.info.final.Text = '';
            else
                showEmptyState(ui.axes.final, t, 'Run Apply Morphology');
                ui.info.final.Text = '';
            end

            if a.done.features
                names = a.cfg.features.names(:);
                groups = a.cfg.features.groups(:);
                values = arrayfun(@(v) sprintf('%.4g', v), a.features(:), 'UniformOutput', false);
                ui.featureTable.Data = [names, groups, values];
                if strcmp(a.roiType, 'lung')
                    ui.roiLabel.Text = sprintf('ROI: final lung mask (%d px, %.1f %% of image)', ...
                        a.featureDetails.numRoiPixels, 100 * a.featureDetails.roiFraction);
                    ui.roiLabel.FontColor = t.textFaint;
                else
                    ui.roiLabel.Text = 'ROI: WHOLE IMAGE (segmentation failed) - exploration only, not valid for classification';
                    ui.roiLabel.FontColor = t.warning;
                end
            else
                ui.featureTable.Data = cell(0, 3);
                ui.roiLabel.Text = 'Run Extract Features to compute the 10 features.';
                ui.roiLabel.FontColor = t.textFaint;
            end

            obj.renderInspector();
            obj.renderStatusAndPrediction();
            obj.refreshAnalysisControls();
        end

        function renderInspector(obj)
            ui = obj.UI.analysis;
            t = obj.Theme;
            a = obj.Analysis;
            if strcmp(obj.InspectorView, 'histogram')
                if isempty(a) || isempty(a.histOriginal)
                    showEmptyState(ui.histAxes, t, 'Histograms appear after preprocessing');
                else
                    label = '';
                    if ~isempty(a.histEnhanced)
                        label = sprintf('Enhanced (%s, gamma %.2f)', methodName(a.enhancementMethod), a.gamma);
                    end
                    plotHistograms(ui.histAxes, a.histOriginal, a.histEnhanced, t, label);
                end
            else
                titles = {'Initial binary mask', 'After morphological processing', 'Final candidate lung mask'};
                if isempty(a) || ~a.done.morphology
                    for k = 1:3
                        showEmptyState(ui.morphAxes{k}, t, titles{k});
                    end
                    ui.morphInfo.Text = 'Run Segment Lung and Apply Morphology to inspect each stage.';
                else
                    masks = {a.morph.input, a.morph.output, a.finalMask};
                    for k = 1:3
                        showImage(ui.morphAxes{k}, masks{k}, t, titles{k});
                    end
                    c = a.morph.counts;
                    ui.morphInfo.Text = sprintf(['Foreground pixels\ninitial    %7d\nopening    %7d\n' ...
                        'small obj. %7d\nclosing    %7d\nhole fill  %7d\nerosion    %7d\n' ...
                        'dilation   %7d\nfinal      %7d\n\nStatus: %s'], c.input, c.opened, c.cleaned, ...
                        c.closed, c.filled, c.eroded, c.dilated, nnz(a.finalMask), a.refine.status);
                end
            end
        end

        function renderStatusAndPrediction(obj)
            ui = obj.UI.analysis;
            t = obj.Theme;
            a = obj.Analysis;
            % ---- processing status
            if isempty(a)
                setLabel(ui.status.image, 'Not loaded', t.textMuted);
                setLabel(ui.status.segmentation, 'Not run', t.textMuted);
                setLabel(ui.status.roi, 'Not computed', t.textMuted);
            else
                setLabel(ui.status.image, a.fileName, t.text);
                if ~a.done.segment
                    setLabel(ui.status.segmentation, 'Not run', t.textMuted);
                elseif ~strcmp(a.seg.status, 'ok')
                    setLabel(ui.status.segmentation, 'Failed', t.warning);
                elseif ~a.done.morphology
                    setLabel(ui.status.segmentation, 'Initial mask (morphology pending)', t.text);
                elseif strcmp(a.refine.status, 'ok')
                    setLabel(ui.status.segmentation, 'OK - two lung regions', t.success);
                elseif strcmp(a.refine.status, 'partial')
                    setLabel(ui.status.segmentation, 'Uncertain (see mask info)', t.warning);
                else
                    setLabel(ui.status.segmentation, 'Failed after morphology', t.warning);
                end
                if ~a.done.features
                    setLabel(ui.status.roi, 'Not computed', t.textMuted);
                elseif strcmp(a.roiType, 'lung')
                    setLabel(ui.status.roi, 'Lung mask', t.success);
                else
                    setLabel(ui.status.roi, 'Whole image (exploration only)', t.warning);
                end
            end
            if strcmp(obj.TrainingState, 'running')
                setLabel(ui.status.model, 'Training in progress', t.accent);
            elseif isempty(obj.Model)
                setLabel(ui.status.model, 'Model not trained', t.warning);
            else
                setLabel(ui.status.model, sprintf('%s SVM (trained)', obj.Model.kernel), t.success);
            end

            % ---- prediction
            ui.datasetLabel.Text = obj.datasetLabelText();
            if isempty(obj.Model)
                setLabel(ui.predictionValue, 'Model not trained', t.textFaint);
                ui.scoreLabel.Text = '';
                ui.modelLabel.Text = 'No trained model is loaded.';
                ui.predictionNote.Text = ['Preprocessing, segmentation and features work without a model. ' ...
                    'Train one on the Dataset & Training page to enable classification.'];
            elseif isempty(obj.Prediction) || obj.Prediction.version ~= obj.AnalysisVersion
                setLabel(ui.predictionValue, 'No prediction', t.textFaint);
                ui.scoreLabel.Text = '';
                ui.modelLabel.Text = obj.modelSummary();
                [ok, reason] = obj.canPredict();
                if ok
                    ui.predictionNote.Text = 'Click Predict to classify this image.';
                else
                    ui.predictionNote.Text = reason;
                end
            else
                p = obj.Prediction;
                if strcmp(p.label, obj.Model.positiveClass)
                    color = t.warning;
                else
                    color = t.success;
                end
                setLabel(ui.predictionValue, upper(p.label), color);
                ui.scoreLabel.Text = sprintf('SVM decision value %+.3f (uncalibrated margin, not a probability)', p.score);
                ui.modelLabel.Text = obj.modelSummary();
                ui.predictionNote.Text = [p.note ' Model prediction only - not a diagnosis.'];
            end
        end

        function refreshAnalysisControls(obj)
            ui = obj.UI.analysis;
            a = obj.Analysis;
            steps = {'preprocess', 'enhance', 'segment', 'morphology', 'features'};
            for k = 1:numel(steps)
                [ok, reason] = obj.prerequisites(steps{k});
                btn = ui.stepButtons.(steps{k});
                btn.Enable = onOff(ok);
                if ok
                    btn.Tooltip = stepName(steps{k});
                else
                    btn.Tooltip = reason;
                end
                dot = ui.stepDots.(steps{k});
                dot.FontColor = obj.stepColor(steps{k});
            end
            [ok, reason] = obj.canPredict();
            ui.stepButtons.predict.Enable = onOff(ok);
            if ok
                ui.stepButtons.predict.Tooltip = 'Classify with the trained SVM';
            else
                ui.stepButtons.predict.Tooltip = reason;
            end
            ui.stepDots.predict.FontColor = obj.stepColor('predict');
            hasImage = ~isempty(a);
            ui.runAllButton.Enable = 'on';
            if hasImage
                ui.runAllButton.Tooltip = 'Run every step on the loaded image';
            else
                ui.runAllButton.Tooltip = 'Choose an image, then run every step';
            end
            ui.exportButton.Enable = onOff(hasImage);
            ui.resetButton.Enable = onOff(hasImage);
            topReset = obj.UI.top.resetButton;
            topReset.Enable = onOff(hasImage);
            if ui.gammaSlider.Value ~= obj.Config.enhance.gamma
                ui.gammaSlider.Value = obj.Config.enhance.gamma;
            end
        end

        function refreshTopBar(obj)
            t = obj.Theme;
            top = obj.UI.top;
            top.status.Text = obj.workflowStatusText();
            if ~isempty(obj.DatasetSummary)
                uiPill(top.datasetChip, t, sprintf('Dataset: %s images found', ...
                    thousands(obj.DatasetSummary.numFound)), ternary(obj.DatasetSummary.numFound > 0, 'ok', 'warn'));
            elseif ~isempty(obj.DatasetDir)
                uiPill(top.datasetChip, t, 'Dataset: selected, not scanned', 'warn');
            else
                uiPill(top.datasetChip, t, 'Dataset: not configured', 'neutral');
            end
            if strcmp(obj.TrainingState, 'running')
                uiPill(top.modelChip, t, 'Model: training...', 'info');
            elseif ~isempty(obj.Model)
                uiPill(top.modelChip, t, sprintf('Model: trained (%s SVM)', obj.Model.kernel), 'ok');
            else
                uiPill(top.modelChip, t, 'Model: not trained', 'warn');
            end
        end

        function refreshDashboard(obj)
            h = obj.UI.dashboard;
            t = obj.Theme;
            ev = obj.currentEvaluation();

            % Dataset images processed
            if ~isempty(obj.Model) && isfield(obj.Model, 'datasetInfo')
                di = obj.Model.datasetInfo;
                processed = sum(di.achieved(:)) - di.numFeatureFailures;
                setLabel(h.cards.dataset.value, thousands(processed), t.text);
                h.cards.dataset.caption.Text = sprintf(['images with extracted features in the last training ' ...
                    'run (%d skipped)'], di.numFeatureFailures);
            elseif ~isempty(obj.DatasetSummary)
                setLabel(h.cards.dataset.value, '0', t.text);
                h.cards.dataset.caption.Text = sprintf('%s labelled images found on disk; none processed yet', ...
                    thousands(obj.DatasetSummary.numFound));
            else
                setLabel(h.cards.dataset.value, 'Not available', t.textFaint);
                h.cards.dataset.caption.Text = 'No dataset has been processed yet';
            end

            % Model training status
            if strcmp(obj.TrainingState, 'running')
                setLabel(h.cards.model.value, 'Training...', t.accent);
                h.cards.model.caption.Text = 'see the Dataset & Training page';
            elseif ~isempty(obj.Model)
                setLabel(h.cards.model.value, 'Trained', t.success);
                h.cards.model.caption.Text = obj.modelSummary();
            else
                setLabel(h.cards.model.value, 'Model not trained', t.warning);
                h.cards.model.caption.Text = 'Train the SVM on the Dataset & Training page';
            end

            % Selected image
            a = obj.Analysis;
            if isempty(a)
                setLabel(h.cards.image.value, 'No image loaded', t.textFaint);
                h.cards.image.caption.Text = 'Upload an X-ray in Image Analysis';
            else
                setLabel(h.cards.image.value, shorten(a.fileName, 22), t.text);
                h.cards.image.caption.Text = sprintf('%d of 6 processing steps complete', obj.completedSteps());
            end

            % Last evaluation
            if isempty(ev)
                setLabel(h.cards.metrics.value, 'Evaluation pending', t.textFaint);
                h.cards.metrics.caption.Text = 'Metrics appear after training and test-set evaluation';
            else
                m = ev.metrics;
                setLabel(h.cards.metrics.value, ['Accuracy ' pct(m.accuracy)], t.text);
                h.cards.metrics.caption.Text = sprintf('F1 %s | Sens. %s | Spec. %s | n = %d test images', ...
                    pct(m.f1), pct(m.sensitivity), pct(m.specificity), m.numSamples);
            end

            % Workflow
            steps = AppController.stepList();
            for k = 1:size(steps, 1)
                [text, color] = obj.stepState(steps{k, 1});
                h.workflow.state{k}.Text = text;
                h.workflow.state{k}.FontColor = color;
                h.workflow.dot{k}.FontColor = color;
            end

            % Getting started
            check = char(10003);
            if ~isempty(obj.Model)
                setLabel(h.next{1}, [check '  Dataset processed and model trained'], t.success);
                if isempty(ev)
                    setLabel(h.next{2}, '2.  The loaded model has no stored test evaluation - re-train it', t.warning);
                else
                    setLabel(h.next{2}, sprintf('%s  Evaluated on %d held-out test images - see Model Evaluation', ...
                        check, ev.metrics.numSamples), t.success);
                end
            elseif ~isempty(obj.DatasetSummary)
                setLabel(h.next{1}, [check '  Dataset scanned and validated'], t.success);
                setLabel(h.next{2}, '2.  Start training (patient-wise split, validation-based model selection)', t.text);
            else
                setLabel(h.next{1}, '1.  Configure the NIH ChestX-ray14 folder (Dataset & Training)', t.text);
                setLabel(h.next{2}, '2.  Train the SVM and evaluate it on the held-out test set', t.text);
            end
            if isempty(a)
                setLabel(h.next{3}, ['3.  Analyse an X-ray in Image Analysis (processing works ' ...
                    'without a model; prediction needs one)'], t.text);
            else
                setLabel(h.next{3}, sprintf('%s  Image loaded: %s', check, a.fileName), t.success);
            end
        end

        function refreshTrainingPage(obj)
            ui = obj.UI.training;
            t = obj.Theme;
            ui.datasetField.Value = obj.DatasetDir;
            ui.metadataField.Value = obj.MetadataFile;
            c = obj.Config;
            ui.pipelineInfo.Text = sprintf(['Training pipeline: %s, gamma %.2f, %s noise filter, ' ...
                '%d px (set on Image Analysis / Settings; stored in the model).'], ...
                methodName(c.enhance.method), c.enhance.gamma, c.preprocess.noiseMethod, c.preprocess.processingSize);
            running = strcmp(obj.TrainingState, 'running');
            ui.trainButton.Enable = onOff(~running && ~isempty(obj.DatasetDir));
            if isempty(obj.DatasetDir)
                ui.trainButton.Tooltip = 'Select the dataset folder first';
            else
                ui.trainButton.Tooltip = 'Extract features, train the SVM and evaluate on the test set';
            end
            s = obj.DatasetSummary;
            keys = {'rows', 'found', 'normal', 'abnormal', 'patients'};
            if isempty(s)
                for k = 1:numel(keys)
                    setLabel(ui.stats.(keys{k}), 'Not available', t.textFaint);
                end
                ui.splitTable.Data = cell(0, 5);
                ui.splitSource.Text = 'Scan the dataset to preview the split.';
                return;
            end
            values = [s.numRows, s.numFound, s.numNormal, s.numAbnormal, s.numPatients];
            for k = 1:numel(keys)
                setLabel(ui.stats.(keys{k}), thousands(values(k)), t.text);
            end
            if isempty(s.preview)
                ui.splitTable.Data = cell(0, 5);
                ui.splitSource.Text = 'No subset could be formed with the current options (see messages).';
            else
                r = s.preview.report;
                rows = cell(3, 5);
                names = {'Train', 'Validation', 'Test'};
                for k = 1:3
                    if all(isnan(r.requested(k, :)))
                        req = 'natural';
                    else
                        req = sprintf('%d / %d', r.requested(k, 1), r.requested(k, 2));
                    end
                    rows(k, :) = {names{k}, r.achieved(k, 1), r.achieved(k, 2), r.patientsPerSplit(k), req};
                end
                ui.splitTable.Data = rows;
                ui.splitSource.Text = sprintf('Split: %s. Overlapping patients: %d.', r.splitSource, r.patientOverlap);
            end
            ui.messages.Value = s.messages(:);
        end

        function refreshEvaluation(obj)
            h = obj.UI.evaluation;
            t = obj.Theme;
            ev = obj.currentEvaluation();
            keys = {'accuracy', 'precision', 'sensitivity', 'specificity', 'f1'};
            if isempty(ev)
                for k = 1:numel(keys)
                    setLabel(h.metric.(keys{k}).value, 'Pending', t.textFaint);
                end
                setLabel(h.metric.samples.value, 'Pending', t.textFaint);
                h.metric.samples.caption.Text = 'held-out test set';
                showEmptyState(h.confusionAxes, t, 'Evaluation pending - train a model to evaluate it on the held-out test set');
                h.details.Value = {'Evaluation pending.'; ''; ['Metrics are computed only after a model has ' ...
                    'been trained and evaluated on a patient-wise held-out test set. No metric is shown ' ...
                    'before that, and none of the values on this page are examples.']};
                h.exportMetricsButton.Enable = 'off';
                h.exportFigureButton.Enable = 'off';
            else
                m = ev.metrics;
                for k = 1:numel(keys)
                    if isnan(m.(keys{k}))
                        setLabel(h.metric.(keys{k}).value, 'Undefined', t.warning);
                    else
                        setLabel(h.metric.(keys{k}).value, pct(m.(keys{k})), t.text);
                    end
                end
                setLabel(h.metric.samples.value, sprintf('%d', m.numSamples), t.text);
                h.metric.samples.caption.Text = sprintf('%d %s / %d %s', m.trueClassCounts(1), ...
                    m.classNames{1}, m.trueClassCounts(2), m.classNames{2});
                plotConfusion(h.confusionAxes, m, t);
                h.details.Value = obj.evaluationDetails(ev);
                h.exportMetricsButton.Enable = 'on';
                h.exportFigureButton.Enable = 'on';
            end
            if isempty(obj.Model) || ~isfield(obj.Model, 'selection')
                h.selectionTable.Data = cell(0, 4);
            else
                sel = obj.Model.selection;
                scores = [sel.valBalancedAccuracy];
                scores(isnan(scores)) = -Inf;
                [~, order] = sort(scores, 'descend');
                rows = cell(numel(order), 4);
                for k = 1:numel(order)
                    e = sel(order(k));
                    scale = '-';
                    if strcmp(e.kernel, 'rbf')
                        scale = sprintf('%.3g', e.kernelScale);
                    end
                    rows(k, :) = {e.kernel, e.boxConstraint, scale, pct(e.valBalancedAccuracy)};
                end
                h.selectionTable.Data = rows;
            end
        end

        function syncSettingsUI(obj)
            s = obj.UI.settings;
            c = obj.Config;
            s.processingSize.Value = c.preprocess.processingSize;
            s.noiseMethod.Value = c.preprocess.noiseMethod;
            s.medianWindow.Value = c.preprocess.medianWindow(1);
            s.gaussianSigma.Value = c.preprocess.gaussianSigma;
            s.claheClip.Value = c.enhance.claheClipLimit;
            s.claheTiles.Value = c.enhance.claheNumTiles(1);
            s.stretchTol.Value = 100 * c.enhance.stretchTolerance(1);
            s.glcmLevels.Value = c.features.glcmNumLevels;
            s.openRadius.Value = c.morph.openRadius;
            s.closeRadius.Value = c.morph.closeRadius;
            s.erodeRadius.Value = c.morph.erodeRadius;
            s.dilateRadius.Value = c.morph.dilateRadius;
        end
    end

    % ===================================================================
    methods (Access = private)
        function file = modelFilePath(obj)
            file = obj.ModelFile;
            if isempty(file)
                file = defaultModelFile();
            end
        end

        function folder = resultsRootPath(obj)
            folder = obj.ResultsRoot;
            if isempty(folder)
                folder = fullfile(projectRoot(), 'results');
            end
        end

        function setAnalysis(obj, analysis)
            obj.Analysis = analysis;
            obj.AnalysisVersion = obj.AnalysisVersion + 1;   % invalidates any prediction
        end

        function setModel(obj, model)
            % Adopt the model and its processing configuration, so that the
            % displayed features are the ones the classifier expects.
            obj.Model = model;
            obj.Prediction = [];
            if ~pipelineConfigsMatch(obj.Config, model.pipelineConfig)
                obj.Config = adoptPipelineConfig(obj.Config, model.pipelineConfig);
                if ~isempty(obj.Analysis)
                    obj.setAnalysis(clearAnalysisFrom(obj.Analysis, 'preprocess'));
                end
            end
            if isfield(model, 'datasetInfo') && isempty(obj.DatasetDir) && ...
                    exist(model.datasetInfo.datasetDir, 'dir') == 7
                obj.DatasetDir = model.datasetInfo.datasetDir;
                obj.MetadataFile = model.datasetInfo.metadataFile;
            end
            if isfield(obj.UI, 'settings')
                obj.syncSettingsUI();
            end
        end

        function classifyCurrent(obj)
            [ok, reason] = obj.canPredict();
            if ~ok
                error('CXR:predictionFailed', '%s', reason);
            end
            model = obj.Model;
            [match, differences] = pipelineConfigsMatch(obj.Config, model.pipelineConfig);
            if match
                X = obj.Analysis.features;
                note = 'Features were computed with the same configuration as the training data.';
            else
                reprocessed = runImagePipeline(obj.Analysis.original, model.pipelineConfig);
                X = reprocessed.features;
                note = sprintf(['Your current settings differ from the model''s training configuration ' ...
                    '(%s), so the image was re-processed with the training configuration (%s, gamma %.2f) ' ...
                    'for this prediction.'], strjoin(differences, ', '), ...
                    methodName(model.pipelineConfig.enhance.method), model.pipelineConfig.enhance.gamma);
            end
            [labels, scores] = classifyFeatures(X, model);
            obj.Prediction = struct('label', labels{1}, 'score', scores(1), 'note', note, ...
                'version', obj.AnalysisVersion, 'features', X, 'time', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            logMessage('INFO', 'Prediction for %s: %s (score %.3f)', obj.Analysis.fileName, labels{1}, scores(1));
        end

        function [ok, reason] = prerequisites(obj, step)
            if isempty(obj.Analysis)
                ok = false;
                reason = 'Upload an X-ray image first.';
            else
                [ok, reason] = analysisPrerequisites(obj.Analysis, step);
            end
        end

        function [ok, reason] = canPredict(obj)
            ok = false;
            a = obj.Analysis;
            if isempty(obj.Model)
                reason = 'No trained model is loaded. Train one on the Dataset & Training page.';
            elseif isempty(a)
                reason = 'Upload an X-ray image first.';
            elseif ~a.done.features
                reason = 'Extract the features first (or use Run Full Analysis).';
            elseif ~strcmp(a.roiType, 'lung')
                reason = ['Lung segmentation failed for this image, so its features were computed on the ' ...
                    'whole image. The model was trained on lung-region features, so no prediction is made.'];
            else
                ok = true;
                reason = '';
            end
        end

        function reapplyEnhancement(obj)
            % Re-run the enhancement when the method or gamma changes
            % (segmentation is kept; features and prediction are invalidated).
            try
                if ~isempty(obj.Analysis) && obj.Analysis.done.enhance
                    hadFeatures = obj.Analysis.done.features;
                    obj.setAnalysis(runAnalysisStep(obj.Analysis, 'enhance', obj.Config, true));
                    if hadFeatures
                        obj.setTopStatus(['Enhancement changed - features and prediction were cleared. ' ...
                            'Run Extract Features again.']);
                    end
                end
                obj.renderAnalysis();
                obj.refreshDashboard();
                obj.refreshTrainingPage();
            catch err
                obj.reportError(err, 'Enhancement');
            end
        end

        function reportStepOutcome(obj, step)
            a = obj.Analysis;
            switch step
                case 'segment'
                    if ~strcmp(a.seg.status, 'ok')
                        uialert(obj.Figure, sprintf(['%s\n\nYou can still extract whole-image features ' ...
                            'for exploration, but classification is disabled for this image.'], a.seg.message), ...
                            'Segmentation failed', 'Icon', 'warning');
                    end
                case 'morphology'
                    if strcmp(a.refine.status, 'failed')
                        uialert(obj.Figure, a.refine.message, 'Segmentation failed', 'Icon', 'warning');
                    elseif strcmp(a.refine.status, 'partial')
                        obj.setTopStatus(a.refine.message);
                    end
                case 'features'
                    if strcmp(a.roiType, 'wholeImage')
                        uialert(obj.Figure, ['Features were computed on the WHOLE image because no lung ' ...
                            'mask is available. They are shown for exploration only and cannot be ' ...
                            'classified.'], 'Whole-image features', 'Icon', 'warning');
                    end
            end
        end

        function applyInspectorView(obj)
            ui = obj.UI.analysis;
            t = obj.Theme;
            isHist = strcmp(obj.InspectorView, 'histogram');
            ui.histPanel.Visible = onOff(isHist);
            ui.morphPanel.Visible = onOff(~isHist);
            active = {ui.histToggle, ui.morphToggle};
            for k = 1:2
                on = (k == 1) == isHist;
                if on
                    active{k}.BackgroundColor = t.input;
                    active{k}.FontColor = t.text;
                else
                    active{k}.BackgroundColor = t.card;
                    active{k}.FontColor = t.textMuted;
                end
            end
        end

        function n = completedSteps(obj)
            n = 0;
            if isempty(obj.Analysis)
                return;
            end
            % the six steps after upload: 5 processing steps + prediction
            d = obj.Analysis.done;
            n = d.preprocess + d.enhance + d.segment + d.morphology + d.features + obj.hasCurrentPrediction();
        end

        function tf = hasCurrentPrediction(obj)
            tf = ~isempty(obj.Prediction) && obj.Prediction.version == obj.AnalysisVersion;
        end

        function [text, color] = stepState(obj, step)
            t = obj.Theme;
            a = obj.Analysis;
            text = 'Pending';
            color = t.textFaint;
            if isempty(a)
                if strcmp(step, 'load')
                    text = 'No image loaded';
                elseif strcmp(step, 'predict') && isempty(obj.Model)
                    text = 'Model not trained';
                end
                return;
            end
            switch step
                case 'load'
                    text = sprintf('%s (%d x %d)', a.fileName, a.imageInfo.width, a.imageInfo.height);
                    color = t.success;
                case {'preprocess', 'enhance', 'features'}
                    if a.done.(step)
                        text = 'Done';
                        color = t.success;
                        if strcmp(step, 'features') && strcmp(a.roiType, 'wholeImage')
                            text = 'Done (whole image - exploration only)';
                            color = t.warning;
                        end
                    end
                case 'segment'
                    if a.done.segment
                        if strcmp(a.seg.status, 'ok')
                            text = 'Done';
                            color = t.success;
                        else
                            text = 'Failed - no plausible lung region';
                            color = t.warning;
                        end
                    end
                case 'morphology'
                    if a.done.morphology
                        switch a.refine.status
                            case 'ok'
                                text = 'Done';
                                color = t.success;
                            case 'partial'
                                text = 'Done (uncertain mask)';
                                color = t.warning;
                            otherwise
                                text = 'Failed';
                                color = t.warning;
                        end
                    end
                case 'predict'
                    if obj.hasCurrentPrediction()
                        text = ['Predicted: ' obj.Prediction.label];
                        color = t.success;
                    elseif isempty(obj.Model)
                        text = 'Model not trained';
                        color = t.warning;
                    end
            end
        end

        function color = stepColor(obj, step)
            [~, color] = obj.stepState(step);
        end

        function text = workflowStatusText(obj)
            if strcmp(obj.TrainingState, 'running')
                text = 'Training in progress...';
                return;
            end
            a = obj.Analysis;
            if isempty(a)
                text = 'No image loaded - upload a chest X-ray to begin';
                return;
            end
            text = sprintf('%s  |  %d of 6 steps complete', a.fileName, obj.completedSteps());
            if a.done.segment && ~strcmp(a.seg.status, 'ok')
                text = [text '  |  segmentation failed'];
            elseif obj.hasCurrentPrediction()
                text = [text '  |  predicted ' obj.Prediction.label];
            end
        end

        function text = datasetLabelText(obj)
            text = 'Dataset label: Not available';
            a = obj.Analysis;
            if isempty(a)
                return;
            end
            if isempty(obj.Meta)
                text = 'Dataset label: Not available (NIH metadata not loaded)';
                return;
            end
            k = find(strcmp(obj.Meta.imageIndex, a.fileName), 1);
            if isempty(k)
                text = 'Dataset label: Not available (image not in metadata)';
            elseif obj.Meta.isValid(k)
                text = sprintf('Dataset label: %s (%s)', obj.Meta.binaryLabel{k}, obj.Meta.findingLabels{k});
            else
                text = sprintf('Dataset label: invalid (%s)', obj.Meta.invalidReason{k});
            end
        end

        function text = modelSummary(obj)
            m = obj.Model;
            if isempty(m)
                text = 'Model not trained';
                return;
            end
            text = sprintf('%s SVM, C = %g, trained %s', m.kernel, m.boxConstraint, m.trainingInfo.trainedOn);
        end

        function ev = currentEvaluation(obj)
            ev = [];
            if ~isempty(obj.Model) && isfield(obj.Model, 'testEvaluation') && ~isempty(obj.Model.testEvaluation)
                ev = obj.Model.testEvaluation;
            end
        end

        function lines = evaluationDetails(obj, ev)
            m = ev.metrics;
            lines = {sprintf('Evaluated on: %s', ev.evaluatedOn)};
            fields = fieldnames(ev.summary);
            for k = 1:numel(fields)
                lines{end + 1} = sprintf('%s: %s', fields{k}, ev.summary.(fields{k})); %#ok<AGROW>
            end
            lines = [lines, {'', sprintf('Positive class: %s  (TP = correctly predicted %s)', m.positiveClass, m.positiveClass), ...
                sprintf('Test set: %d images - %d %s, %d %s', m.numSamples, m.trueClassCounts(1), ...
                    m.classNames{1}, m.trueClassCounts(2), m.classNames{2}), ...
                sprintf('TP = %d, TN = %d, FP = %d, FN = %d', m.TP, m.TN, m.FP, m.FN), ...
                sprintf('Balanced accuracy: %s', pct(m.balancedAccuracy))}];
            if ~isempty(m.undefined)
                lines{end + 1} = sprintf('Undefined (zero denominator): %s', strjoin(m.undefined, ', '));
            end
            if ~isempty(obj.LastTraining) && ~isempty(obj.LastTraining.resultsDir)
                lines{end + 1} = sprintf('Saved results: %s', obj.LastTraining.resultsDir);
            end
            lines = [lines, {'', ['Reference labels are NIH ChestX-ray14 labels mined from radiology ' ...
                'reports (imperfect, not clinical ground truth).'], ...
                'A good accuracy value alone does not establish clinical usefulness.'}];
            lines = lines(:);
        end

        function s = summarizeDataset(obj, meta, index, official, cfg) %#ok<INUSL>
            onDisk = ismember(meta.imageIndex, index.fileNames) & meta.isValid;
            s = struct();
            s.numRows = meta.report.numRows;
            s.numFound = nnz(onDisk);
            s.numNormal = nnz(onDisk & strcmp(meta.binaryLabel, 'Normal'));
            s.numAbnormal = nnz(onDisk & strcmp(meta.binaryLabel, 'Abnormal'));
            s.numPatients = numel(unique(meta.patientId(onDisk)));
            s.numFilesIndexed = numel(index.fileNames);
            messages = [{sprintf('Metadata: %s', meta.csvPath)}; meta.report.messages(:)];
            messages{end + 1} = sprintf('Indexed %s image files in %d folders under %s.', ...
                thousands(numel(index.fileNames)), index.numFolders, index.rootDir);
            if ~isempty(index.duplicates)
                messages{end + 1} = sprintf('%d file name(s) occur in several folders; the first copy is used.', ...
                    numel(index.duplicates));
            end
            notListed = numel(index.fileNames) - nnz(ismember(index.fileNames, meta.imageIndex));
            if notListed > 0
                messages{end + 1} = sprintf('%d image file(s) on disk are not listed in the metadata and are ignored.', notListed);
            end
            if isempty(official)
                messages{end + 1} = ['Official split lists (train_val_list.txt / test_list.txt) not found: ' ...
                    'a reproducible random patient-wise split will be used.'];
            else
                messages{end + 1} = 'Official NIH split lists found: they define the patient-wise test set.';
            end
            s.preview = [];
            try
                s.preview = prepareDataset(meta, index, cfg, official);
                messages = [messages; {''; 'Planned subset with the current options:'}; s.preview.report.messages(:)];
            catch err
                messages = [messages; {''; ['Subset not possible: ' err.message]}];
            end
            s.messages = messages;
        end

        function cfg = trainingConfig(obj)
            ui = obj.UI.training;
            cfg = obj.Config;
            cfg.dataset.subsetSize = ui.subsetSize.Value;
            cfg.dataset.balanceClasses = ui.balance.Value;
            if strcmp(ui.views.Value, 'PA')
                cfg.dataset.viewPositions = {'PA'};
            else
                cfg.dataset.viewPositions = {'PA', 'AP'};
            end
            cfg.dataset.maxImagesPerPatient = ui.maxPerPatient.Value;
            cfg.dataset.testFraction = ui.testFraction.Value;
            cfg.dataset.validationFraction = ui.valFraction.Value;
            cfg.dataset.randomSeed = ui.seed.Value;
            switch ui.kernels.Value
                case 'linear', cfg.svm.kernels = {'linear'};
                case 'rbf',    cfg.svm.kernels = {'rbf'};
                otherwise,     cfg.svm.kernels = {'linear', 'rbf'};
            end
            % The pipeline part (incl. enhancement method and gamma) is the
            % current configuration; it is stored inside the trained model.
        end

        function setProgress(obj, fraction, message)
            ui = obj.UI.training;
            f = min(max(fraction, 0), 1);
            ui.progressTrack.ColumnWidth = {sprintf('%.4fx', max(f, 1e-4)), sprintf('%.4fx', max(1 - f, 1e-4))};
            ui.progressStatus.Text = message;
        end

        function report = buildReport(obj)
            a = obj.Analysis;
            report = struct();
            report.fileName = a.fileName;
            report.noiseMethod = obj.Config.preprocess.noiseMethod;
            report.enhancementMethod = methodName(obj.Config.enhance.method);
            report.gamma = obj.Config.enhance.gamma;
            if a.done.enhance
                report.enhancementMethod = methodName(a.enhancementMethod);
                report.gamma = a.gamma;
            end
            if ~a.done.segment
                report.segmentationStatus = 'not run';
            elseif a.done.morphology
                report.segmentationStatus = sprintf('%s - %s', a.refine.status, a.refine.message);
            else
                report.segmentationStatus = sprintf('%s - %s', a.seg.status, a.seg.message);
            end
            report.featureNames = obj.Config.features.names;
            report.featureValues = a.features;
            switch a.roiType
                case 'lung',       report.roiType = 'final lung mask';
                case 'wholeImage', report.roiType = 'whole image (segmentation failed; exploration only)';
                otherwise,         report.roiType = 'features not computed';
            end
            if isempty(obj.Model)
                report.modelStatus = 'Model not trained';
            else
                report.modelStatus = obj.modelSummary();
            end
            if obj.hasCurrentPrediction()
                report.prediction = obj.Prediction.label;
                report.predictionNote = sprintf(['Model prediction (SVM decision value %+.3f, uncalibrated). ' ...
                    '%s'], obj.Prediction.score, obj.Prediction.note);
            else
                report.prediction = 'Not available';
                [~, reason] = obj.canPredict();
                report.predictionNote = reason;
            end
            report.datasetLabel = strrep(obj.datasetLabelText(), 'Dataset label: ', '');
        end

        function setTopStatus(obj, text)
            statusLabel = obj.UI.top.status;
            statusLabel.Text = text;
            drawnow limitrate;
        end

        function focus(obj)
            try
                figure(obj.Figure);
            catch
            end
        end

        function reportError(obj, err, titleText)
            logMessage('ERROR', '%s: %s [%s]', titleText, err.message, err.identifier);
            if ~isempty(err.stack)
                logMessage('ERROR', '  at %s (line %d)', err.stack(1).name, err.stack(1).line);
            end
            if strncmp(err.identifier, 'CXR:', 4)
                message = err.message;
            else
                message = sprintf('An unexpected error occurred:\n%s\n\nDetails were written to logs/app.log.', err.message);
            end
            try
                uialert(obj.Figure, message, titleText, 'Icon', 'error');
            catch
                fprintf(2, '%s: %s\n', titleText, message);
            end
            statusLabel = obj.UI.top.status;
            statusLabel.Text = ['Error: ' strtok(message, newline)];
        end
    end
end

% =========================================================================
% Local helper functions
function s = onOff(tf)
if tf
    s = 'on';
else
    s = 'off';
end
end

function out = ternary(condition, a, b)
if condition
    out = a;
else
    out = b;
end
end

function setLabel(lbl, text, color)
lbl.Text = text;
lbl.FontColor = color;
end

function name = stepName(step)
steps = AppController.stepList();
k = find(strcmp(steps(:, 1), step), 1);
name = steps{k, 2};
end

function name = methodName(method)
switch method
    case 'stretch', name = 'Contrast stretching';
    case 'histeq',  name = 'Histogram equalization';
    case 'clahe',   name = 'CLAHE';
    otherwise,      name = method;
end
end

function t = pct(v)
if isempty(v) || isnan(v)
    t = 'undefined';
else
    t = sprintf('%.1f %%', 100 * v);
end
end

function t = thousands(n)
% 112120 -> '112,120'
t = sprintf('%d', round(n));
t = fliplr(regexprep(fliplr(t), '(\d{3})(?=\d)', '$1,'));
end

function s = shorten(s, n)
if numel(s) > n
    s = [s(1:n - 3) '...'];
end
end

function s = wrapText(s)
% Insert line breaks so long messages fit an image panel
words = strsplit(s, ' ');
lines = {''};
for k = 1:numel(words)
    if numel(lines{end}) + numel(words{k}) > 38 && ~isempty(lines{end})
        lines{end + 1} = words{k}; %#ok<AGROW>
    else
        lines{end} = strtrim([lines{end} ' ' words{k}]);
    end
end
s = strjoin(lines, newline);
end

function closeDialog(dlg)
try
    close(dlg);
catch
end
end

function setDialogMessage(dlg, message)
try
    dlg.Message = message;
    drawnow limitrate;
catch
end
end

function cfg = adoptPipelineConfig(cfg, source)
% Copy every feature-relevant section from source into cfg
sections = {'preprocess', 'enhance', 'segment', 'morph', 'features'};
for k = 1:numel(sections)
    cfg.(sections{k}) = source.(sections{k});
end
end
