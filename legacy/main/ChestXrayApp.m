classdef ChestXrayApp < matlab.apps.AppBase
    %CHESTXRAYAPP Chest X-Ray Abnormality Detection - interactive GUI.
    %   Start with:  ChestXrayApp   (or run startApp.m in the project root)
    %
    %   Written in the same structure App Designer generates (component
    %   properties, createComponents, callbacks, startupFcn) so it can be read
    %   and extended like any App Designer app. A binary .mlapp file can only
    %   be produced by the App Designer editor itself; see README.md.
    %
    %   Workflow: Upload X-Ray -> Preprocess -> Enhance Image -> Segment Lung
    %   -> Apply Morphology -> Extract Features -> Predict.
    %
    %   EDUCATIONAL / RESEARCH USE ONLY - NOT A MEDICAL DIAGNOSIS.

    % ---------------------------------------------------------------- UI
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        MainGrid               matlab.ui.container.GridLayout
        TitleLabel             matlab.ui.control.Label
        ControlPanel           matlab.ui.container.Panel
        ControlGrid            matlab.ui.container.GridLayout
        UploadButton           matlab.ui.control.Button
        PreprocessButton       matlab.ui.control.Button
        MethodLabel            matlab.ui.control.Label
        MethodDropDown         matlab.ui.control.DropDown
        EnhanceButton          matlab.ui.control.Button
        GammaLabel             matlab.ui.control.Label
        GammaSlider            matlab.ui.control.Slider
        GammaField             matlab.ui.control.NumericEditField
        SegmentButton          matlab.ui.control.Button
        MorphologyButton       matlab.ui.control.Button
        FeaturesButton         matlab.ui.control.Button
        PredictButton          matlab.ui.control.Button
        ResetButton            matlab.ui.control.Button
        ResultPanel            matlab.ui.container.Panel
        ResultGrid             matlab.ui.container.GridLayout
        PredictionLabel        matlab.ui.control.Label
        ConfidenceLabel        matlab.ui.control.Label
        ResultDetailLabel      matlab.ui.control.Label
        TabGroup               matlab.ui.container.TabGroup
        MainTab                matlab.ui.container.Tab
        OriginalAxes           matlab.ui.control.UIAxes
        EnhancedAxes           matlab.ui.control.UIAxes
        SegmentationAxes       matlab.ui.control.UIAxes
        FinalAxes              matlab.ui.control.UIAxes
        PreprocessTab          matlab.ui.container.Tab
        GrayAxes               matlab.ui.control.UIAxes
        DenoisedAxes           matlab.ui.control.UIAxes
        GammaAxes              matlab.ui.control.UIAxes
        HistBeforeAxes         matlab.ui.control.UIAxes
        HistAfterAxes          matlab.ui.control.UIAxes
        ComparisonTable        matlab.ui.control.Table
        MorphologyTab          matlab.ui.container.Tab
        MaskBeforeAxes         matlab.ui.control.UIAxes
        MaskAfterAxes          matlab.ui.control.UIAxes
        MorphologyInfo         matlab.ui.control.TextArea
        FeaturesTab            matlab.ui.container.Tab
        FeatureTable           matlab.ui.control.Table
        FeatureInfo            matlab.ui.control.TextArea
        EvaluationTab          matlab.ui.container.Tab
        ConfusionAxes          matlab.ui.control.UIAxes
        MetricsText            matlab.ui.control.TextArea
        StatusLabel            matlab.ui.control.Label
        DisclaimerLabel        matlab.ui.control.Label
    end

    % ------------------------------------------------------------- State
    properties (Access = private)
        Config            % processing parameters (from the model when loaded)
        Model             % trained model struct ([] until loaded)
        ToolboxesOK = false
        FileName = ''
        OriginalImage     % raw image as read from disk
        Preprocessed      % struct from preprocessImage
        EnhancedImage     % enhanced image BEFORE gamma correction
        DisplayImage      % enhanced image AFTER gamma correction
        RawMask           % lung mask before morphology
        Morphology        % struct from morphologicalProcessing
        Features          % 1 x F feature vector
        FeatureConfig     % configuration used to compute Features
    end

    properties (Constant, Access = private)
        Disclaimer = ['This system is intended for educational and research purposes only ' ...
                      'and does not provide a medical diagnosis. Results should not be used ' ...
                      'for clinical decision-making.']
        MethodItems = {'CLAHE (adapthisteq)', 'Histogram equalisation (histeq)', 'Linear stretch (imadjust)'}
        MethodKeys  = {'clahe', 'histeq', 'imadjust'}
    end

    % ========================================================= Helpers
    methods (Access = private)

        function setStatus(app, message)
            app.StatusLabel.Text = message;
            drawnow limitrate;
        end

        function showError(app, err, titleText)
            if nargin < 3
                titleText = 'Error';
            end
            message = err.message;
            if isempty(err.identifier) || ~strncmp(err.identifier, 'CXR:', 4)
                message = sprintf('An unexpected error occurred:\n%s', err.message);
            end
            uialert(app.UIFigure, message, titleText, 'Icon', 'error');
            app.setStatus(['Error: ' strtok(message, newline)]);
        end

        function ok = requireStep(app, condition, message)
            % Show a friendly message when a pipeline step is used too early.
            ok = condition;
            if ~ok
                uialert(app.UIFigure, message, 'Step missing', 'Icon', 'warning');
            end
        end

        function showImage(~, ax, img, titleText)
            cla(ax);
            imshow(img, 'Parent', ax);
            title(ax, titleText);
            axis(ax, 'image', 'off');
        end

        function plotHistogram(~, ax, img, titleText, color)
            cla(ax);
            [counts, bins] = imhist(img, 64);
            bar(ax, bins, counts, 1, 'FaceColor', color, 'EdgeColor', 'none');
            xlim(ax, [0 1]);
            title(ax, titleText);
            xlabel(ax, 'Intensity');
            ylabel(ax, 'Pixel count');
        end

        function clearResultPanel(app)
            app.PredictionLabel.Text = 'Prediction: -';
            app.PredictionLabel.FontColor = [0.15 0.15 0.15];
            app.ConfidenceLabel.Text = 'Confidence/Score: -';
            app.ResultDetailLabel.Text = 'Model prediction appears here.';
        end

        function clearDownstream(app, fromStep)
            % Invalidate results that depend on a step that was (re)run.
            steps = {'preprocess', 'enhance', 'segment', 'morphology', 'features'};
            first = find(strcmp(steps, fromStep));
            if first <= 1
                app.Preprocessed = [];
                cla(app.GrayAxes); cla(app.DenoisedAxes); cla(app.HistBeforeAxes);
            end
            if first <= 2
                app.EnhancedImage = [];
                app.DisplayImage = [];
                cla(app.EnhancedAxes); cla(app.GammaAxes); cla(app.HistAfterAxes);
                app.ComparisonTable.Data = {};
            end
            if first <= 3
                app.RawMask = [];
                cla(app.SegmentationAxes); cla(app.MaskBeforeAxes);
            end
            if first <= 4
                app.Morphology = [];
                cla(app.FinalAxes); cla(app.MaskAfterAxes);
            end
            app.Features = [];
            app.FeatureTable.Data = {};
            app.clearResultPanel();
        end

        function loaded = ensureModel(app, showAlert)
            % Load models/trainedModel.mat on demand; switch to its settings.
            if nargin < 2
                showAlert = true;
            end
            loaded = ~isempty(app.Model);
            if loaded
                return;
            end
            try
                app.Model = loadTrainedModel();
                app.Config = app.Model.cfg;
                loaded = true;
            catch err
                if showAlert
                    app.showError(err, 'Model not available');
                end
            end
        end

        function applyGamma(app)
            if isempty(app.EnhancedImage)
                return;
            end
            gammaValue = app.GammaField.Value;
            app.DisplayImage = gammaCorrection(app.EnhancedImage, gammaValue, app.Config);
            app.showImage(app.EnhancedAxes, app.DisplayImage, ...
                sprintf('Enhanced X-Ray (gamma %.2f)', gammaValue));
            app.showImage(app.GammaAxes, app.DisplayImage, sprintf('After gamma = %.2f', gammaValue));
            app.plotHistogram(app.HistAfterAxes, app.DisplayImage, ...
                'Histogram after enhancement + gamma', [0.85 0.4 0.1]);
        end

        function showEvaluation(app)
            cla(app.ConfusionAxes);
            if isempty(app.Model) || ~isfield(app.Model, 'trainingInfo')
                app.MetricsText.Value = {'No trained model loaded.', '', ...
                    'The model still needs to be trained: run trainModel (see README.md).'};
                return;
            end
            info = app.Model.trainingInfo;
            m = info.testMetrics;
            plotConfusionMatrix(app.ConfusionAxes, m.confusionMatrix, m.classNames, ...
                sprintf('Held-out test set (n = %d)', m.numSamples));
            app.MetricsText.Value = { ...
                sprintf('Model trained on %s (%s)', info.trainedOn, info.environment); ...
                sprintf('%d training / %d test images (stratified split)', info.numTrain, info.numTest); ...
                ''; ...
                sprintf('Accuracy     %6.1f %%   overall percentage of correct predictions', 100 * m.accuracy); ...
                sprintf('Sensitivity  %6.1f %%   ability to correctly identify abnormal cases', 100 * m.sensitivity); ...
                sprintf('Specificity  %6.1f %%   ability to correctly identify normal cases', 100 * m.specificity); ...
                sprintf('Precision    %6.1f %%   predicted-abnormal cases that are truly abnormal', 100 * m.precision); ...
                sprintf('F1-score     %6.1f %%   balance between precision and recall', 100 * m.f1); ...
                sprintf('ROC AUC      %6.3f', m.auc); ...
                ''; ...
                sprintf('TP = %d   TN = %d   FP = %d   FN = %d', m.TP, m.TN, m.FP, m.FN); ...
                ''; ...
                'Metrics refer to the dataset the model was trained/tested on and do not'; ...
                'measure clinical performance.'};
        end
    end

    % ======================================================= Callbacks
    methods (Access = private)

        function startupFcn(app)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(projectRoot);
            setupProject();
            app.Config = getConfig();
            app.clearResultPanel();

            [app.ToolboxesOK, toolboxMessage] = checkToolboxes();
            if ~app.ToolboxesOK
                uialert(app.UIFigure, toolboxMessage, 'Missing toolbox', 'Icon', 'error');
                app.setStatus(toolboxMessage);
                return;
            end
            try
                app.Model = loadTrainedModel();
                app.Config = app.Model.cfg;
                app.setStatus('Ready. Trained model loaded. Upload a chest X-ray to begin.');
            catch
                app.Model = [];
                app.setStatus(['Ready. No trained model found yet (run trainModel) - all ' ...
                               'processing steps work, prediction needs a model.']);
            end
            app.showEvaluation();
        end

        function UploadButtonPushed(app, ~)
            [file, folder] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.bmp;*.JPG;*.JPEG;*.PNG;*.BMP', ...
                 'Chest X-ray images (*.jpg, *.jpeg, *.png, *.bmp)'}, ...
                'Select a chest X-ray image');
            figure(app.UIFigure);   % bring the app back to the front
            if isequal(file, 0)
                uialert(app.UIFigure, 'No image selected.', 'Upload X-Ray', 'Icon', 'warning');
                return;
            end
            try
                img = readXrayImage(fullfile(folder, file), app.Config);
            catch err
                app.showError(err, 'Cannot open image');
                return;
            end
            app.clearDownstream('preprocess');
            app.OriginalImage = img;
            app.FileName = file;
            app.showImage(app.OriginalAxes, img, 'Original X-Ray');
            app.setStatus(sprintf('Loaded %s (%d x %d). Next: Preprocess.', file, size(img, 2), size(img, 1)));
        end

        function PreprocessButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.OriginalImage), 'Please upload an X-ray image first.')
                return;
            end
            try
                app.clearDownstream('preprocess');
                app.Preprocessed = preprocessImage(app.OriginalImage, app.Config);
                app.showImage(app.GrayAxes, app.Preprocessed.gray, 'Grayscale (resized)');
                app.showImage(app.DenoisedAxes, app.Preprocessed.denoised, ...
                    sprintf('Normalised + median %dx%d', app.Config.medianFilterSize));
                app.plotHistogram(app.HistBeforeAxes, app.Preprocessed.denoised, ...
                    'Histogram before enhancement', [0.2 0.4 0.7]);
                app.TabGroup.SelectedTab = app.PreprocessTab;
                app.setStatus('Preprocessing done (grayscale, resize, normalisation, median filter). Next: Enhance Image.');
            catch err
                app.showError(err);
            end
        end

        function EnhanceButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.Preprocessed), 'Please run Preprocess first.')
                return;
            end
            try
                app.clearDownstream('enhance');
                method = app.MethodKeys{strcmp(app.MethodItems, app.MethodDropDown.Value)};
                app.EnhancedImage = enhanceImage(app.Preprocessed.denoised, method, app.Config);
                app.applyGamma();

                comparison = compareEnhancement(app.Preprocessed.denoised, app.Config);
                app.ComparisonTable.Data = [{comparison.name}', ...
                    num2cell(round([comparison.stdDev]', 4)), ...
                    num2cell(round([comparison.entropy]', 3)), ...
                    num2cell(round([comparison.edgeStrength]', 5))];
                app.setStatus(sprintf(['Enhanced with %s. Adjust gamma if desired. ' ...
                    'Next: Segment Lung.'], app.MethodDropDown.Value));
            catch err
                app.showError(err);
            end
        end

        function GammaSliderValueChanging(app, event)
            app.GammaField.Value = round(event.Value, 2);
            app.applyGamma();
        end

        function GammaSliderValueChanged(app, ~)
            app.GammaField.Value = round(app.GammaSlider.Value, 2);
            app.applyGamma();
        end

        function GammaFieldValueChanged(app, ~)
            app.GammaSlider.Value = app.GammaField.Value;
            app.applyGamma();
        end

        function SegmentButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.EnhancedImage), 'Please run Enhance Image first.')
                return;
            end
            try
                app.clearDownstream('segment');
                app.setStatus('Segmenting lungs (trying several adaptive thresholds)...');
                [mask, info] = segmentLung(app.Preprocessed.denoised, app.Config);
                if info.isEmpty
                    uialert(app.UIFigure, ['No lung-like region was found. The image may not ' ...
                        'be a frontal chest X-ray or its contrast is unusual.'], ...
                        'Empty segmentation', 'Icon', 'warning');
                    app.setStatus('Segmentation failed: empty mask.');
                    return;
                end
                app.RawMask = mask;
                app.showImage(app.SegmentationAxes, ...
                    createOverlay(app.Preprocessed.gray, mask, [1 0.6 0], 0.35), ...
                    sprintf('Lung Segmentation (%d regions)', info.numRegions));
                app.showImage(app.MaskBeforeAxes, mask, 'Mask before morphology');
                app.setStatus(sprintf(['Segmentation done: %.1f%% of image, adaptive sensitivity ' ...
                    '%.2f. Next: Apply Morphology.'], 100 * info.areaFraction, info.sensitivity));
            catch err
                app.showError(err);
            end
        end

        function MorphologyButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.RawMask), 'Please run Segment Lung first.')
                return;
            end
            try
                app.clearDownstream('morphology');
                morph = morphologicalProcessing(app.RawMask, app.Config);
                if morph.isEmpty
                    uialert(app.UIFigure, 'The lung mask became empty after morphological processing.', ...
                        'Empty segmentation', 'Icon', 'warning');
                    return;
                end
                app.Morphology = morph;
                app.showImage(app.MaskAfterAxes, morph.final, 'Mask after morphology');
                app.showImage(app.FinalAxes, createOverlay(app.Preprocessed.gray, morph.final), ...
                    'Final Processed Image (lung overlay)');
                app.MorphologyInfo.Value = { ...
                    sprintf('Opening  (disk %d): %d px', app.Config.morphOpenRadius, nnz(morph.opened)); ...
                    sprintf('Remove small objects: %d px', nnz(morph.cleaned)); ...
                    sprintf('Closing  (disk %d): %d px', app.Config.morphCloseRadius, nnz(morph.closed)); ...
                    sprintf('Hole filling: %d px', nnz(morph.filled)); ...
                    sprintf('Erosion  (disk %d): %d px', app.Config.morphErodeRadius, nnz(morph.eroded)); ...
                    sprintf('Dilation (disk %d): %d px', app.Config.morphDilateRadius, nnz(morph.dilated)); ...
                    sprintf('Final (largest %d regions): %d px', app.Config.morphMaxLungs, nnz(morph.final))};
                app.setStatus('Morphological refinement done. Next: Extract Features.');
            catch err
                app.showError(err);
            end
        end

        function FeaturesButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.Morphology), 'Please run Apply Morphology first.')
                return;
            end
            try
                % Features always use the fixed training settings (enhancement
                % method from the configuration, gamma = 1) so that they are
                % comparable with the features the SVM was trained on.
                textureImage = enhanceImage(app.Preprocessed.denoised, app.Config.enhancementMethod, app.Config);
                [features, names] = extractFeatures(app.Preprocessed.denoised, textureImage, ...
                    app.Morphology.final, app.Config);
                app.Features = features;
                app.FeatureConfig = app.Config;
                app.FeatureTable.Data = [names(:), num2cell(round(features(:), 5))];
                app.TabGroup.SelectedTab = app.FeaturesTab;
                app.setStatus(sprintf('%d features extracted from the lung region. Next: Predict.', numel(features)));
            catch err
                app.showError(err, 'Feature extraction failed');
            end
        end

        function PredictButtonPushed(app, ~)
            if ~app.requireStep(~isempty(app.Features), 'Please run Extract Features first.')
                return;
            end
            if ~app.ensureModel()
                return;
            end
            try
                features = app.Features;
                if ~isequal(app.FeatureConfig, app.Model.cfg)
                    % Settings changed when the model was loaded: recompute
                    % with exactly the model's configuration.
                    result = runPipeline(app.OriginalImage, app.Model.cfg);
                    features = result.features;
                end
                prediction = classifyFeatures(features, app.Model);
                label = prediction.label{1};
                if strcmp(label, 'Abnormal')
                    app.PredictionLabel.Text = 'Prediction: ABNORMAL';
                    app.PredictionLabel.FontColor = [0.75 0.1 0.1];
                    detail = 'Model prediction: candidate abnormality.';
                else
                    app.PredictionLabel.Text = 'Prediction: NORMAL';
                    app.PredictionLabel.FontColor = [0.1 0.5 0.2];
                    detail = 'Model prediction: predicted normal.';
                end
                app.ConfidenceLabel.Text = sprintf('Confidence/Score: %.1f%%', 100 * prediction.confidence);
                app.ResultDetailLabel.Text = sprintf(['%s P(Abnormal) = %.1f%% (Platt-calibrated ' ...
                    'SVM score %.2f). Not a diagnosis.'], detail, 100 * prediction.probAbnormal, prediction.svmScore);
                app.TabGroup.SelectedTab = app.MainTab;
                app.setStatus(sprintf('Model prediction for %s: Predicted %s.', app.FileName, label));
            catch err
                app.showError(err, 'Prediction failed');
            end
        end

        function ResetButtonPushed(app, ~)
            app.clearDownstream('preprocess');
            app.OriginalImage = [];
            app.FileName = '';
            cla(app.OriginalAxes);
            app.MorphologyInfo.Value = {''};
            app.GammaSlider.Value = app.Config.defaultGamma;
            app.GammaField.Value = app.Config.defaultGamma;
            app.TabGroup.SelectedTab = app.MainTab;
            app.setStatus('Reset. Upload a chest X-ray to begin.');
        end

        function TabGroupSelectionChanged(app, ~)
            if app.TabGroup.SelectedTab == app.EvaluationTab
                app.ensureModel(false);
                app.showEvaluation();
            end
        end
    end

    % ================================================ Component creation
    methods (Access = private)

        function ax = createImageAxes(~, parent, titleText, row, column)
            ax = uiaxes(parent);
            ax.Layout.Row = row;
            ax.Layout.Column = column;
            title(ax, titleText);
            ax.XTick = [];
            ax.YTick = [];
            ax.Toolbar.Visible = 'off';
        end

        function button = createButton(app, parent, text, row, callback)
            button = uibutton(parent, 'push');
            button.Text = text;
            button.FontWeight = 'bold';
            button.Layout.Row = row;
            button.Layout.Column = [1 2];
            button.ButtonPushedFcn = createCallbackFcn(app, callback, true);
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [60 60 1400 860];
            app.UIFigure.Name = 'Chest X-Ray Abnormality Detection';

            app.MainGrid = uigridlayout(app.UIFigure, [4 2]);
            app.MainGrid.ColumnWidth = {270, '1x'};
            app.MainGrid.RowHeight = {44, '1x', 24, 46};

            app.TitleLabel = uilabel(app.MainGrid);
            app.TitleLabel.Text = 'Chest X-Ray Abnormality Detection';
            app.TitleLabel.FontSize = 22;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Layout.Column = [1 2];

            % ---------------- Controls ----------------
            app.ControlPanel = uipanel(app.MainGrid, 'Title', 'Pipeline');
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = 1;
            app.ControlGrid = uigridlayout(app.ControlPanel, [14 2]);
            app.ControlGrid.RowHeight = {32, 32, 20, 26, 32, 20, 34, 32, 32, 32, 32, 32, 32, '1x'};
            app.ControlGrid.ColumnWidth = {'1x', 70};
            app.ControlGrid.RowSpacing = 6;

            app.UploadButton     = app.createButton(app.ControlGrid, 'Upload X-Ray', 1, @UploadButtonPushed);
            app.PreprocessButton = app.createButton(app.ControlGrid, 'Preprocess', 2, @PreprocessButtonPushed);

            app.MethodLabel = uilabel(app.ControlGrid, 'Text', 'Contrast enhancement method');
            app.MethodLabel.Layout.Row = 3;
            app.MethodLabel.Layout.Column = [1 2];
            app.MethodDropDown = uidropdown(app.ControlGrid);
            app.MethodDropDown.Items = app.MethodItems;
            app.MethodDropDown.Value = app.MethodItems{1};
            app.MethodDropDown.Layout.Row = 4;
            app.MethodDropDown.Layout.Column = [1 2];

            app.EnhanceButton = app.createButton(app.ControlGrid, 'Enhance Image', 5, @EnhanceButtonPushed);

            app.GammaLabel = uilabel(app.ControlGrid, 'Text', 'Gamma correction (display)');
            app.GammaLabel.Layout.Row = 6;
            app.GammaLabel.Layout.Column = [1 2];
            app.GammaSlider = uislider(app.ControlGrid);
            app.GammaSlider.Limits = [0.2 3];
            app.GammaSlider.MajorTicks = [0.2 1 2 3];
            app.GammaSlider.Value = 1;
            app.GammaSlider.Layout.Row = 7;
            app.GammaSlider.Layout.Column = 1;
            app.GammaSlider.ValueChangedFcn = createCallbackFcn(app, @GammaSliderValueChanged, true);
            app.GammaSlider.ValueChangingFcn = createCallbackFcn(app, @GammaSliderValueChanging, true);
            app.GammaField = uieditfield(app.ControlGrid, 'numeric');
            app.GammaField.Limits = [0.2 3];
            app.GammaField.Value = 1;
            app.GammaField.ValueDisplayFormat = '%.2f';
            app.GammaField.Layout.Row = 7;
            app.GammaField.Layout.Column = 2;
            app.GammaField.ValueChangedFcn = createCallbackFcn(app, @GammaFieldValueChanged, true);

            app.SegmentButton    = app.createButton(app.ControlGrid, 'Segment Lung', 8, @SegmentButtonPushed);
            app.MorphologyButton = app.createButton(app.ControlGrid, 'Apply Morphology', 9, @MorphologyButtonPushed);
            app.FeaturesButton   = app.createButton(app.ControlGrid, 'Extract Features', 10, @FeaturesButtonPushed);
            app.PredictButton    = app.createButton(app.ControlGrid, 'Predict', 11, @PredictButtonPushed);
            app.PredictButton.BackgroundColor = [0.85 0.92 1];
            app.ResetButton      = app.createButton(app.ControlGrid, 'Reset', 12, @ResetButtonPushed);

            % ---------------- Result panel ----------------
            app.ResultPanel = uipanel(app.ControlGrid, 'Title', 'Result');
            app.ResultPanel.Layout.Row = [13 14];
            app.ResultPanel.Layout.Column = [1 2];
            app.ResultGrid = uigridlayout(app.ResultPanel, [3 1]);
            app.ResultGrid.RowHeight = {30, 24, '1x'};
            app.PredictionLabel = uilabel(app.ResultGrid);
            app.PredictionLabel.FontSize = 18;
            app.PredictionLabel.FontWeight = 'bold';
            app.ConfidenceLabel = uilabel(app.ResultGrid);
            app.ConfidenceLabel.FontSize = 14;
            app.ResultDetailLabel = uilabel(app.ResultGrid);
            app.ResultDetailLabel.WordWrap = 'on';
            app.ResultDetailLabel.VerticalAlignment = 'top';

            % ---------------- Tabs ----------------
            app.TabGroup = uitabgroup(app.MainGrid);
            app.TabGroup.Layout.Row = 2;
            app.TabGroup.Layout.Column = 2;
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            app.MainTab = uitab(app.TabGroup, 'Title', 'Main View');
            grid = uigridlayout(app.MainTab, [2 2]);
            app.OriginalAxes     = app.createImageAxes(grid, 'Original X-Ray', 1, 1);
            app.EnhancedAxes     = app.createImageAxes(grid, 'Enhanced X-Ray', 1, 2);
            app.SegmentationAxes = app.createImageAxes(grid, 'Lung Segmentation', 2, 1);
            app.FinalAxes        = app.createImageAxes(grid, 'Final Processed Image', 2, 2);

            app.PreprocessTab = uitab(app.TabGroup, 'Title', 'Preprocessing & Histograms');
            grid = uigridlayout(app.PreprocessTab, [2 3]);
            app.GrayAxes       = app.createImageAxes(grid, 'Grayscale', 1, 1);
            app.DenoisedAxes   = app.createImageAxes(grid, 'Denoised', 1, 2);
            app.GammaAxes      = app.createImageAxes(grid, 'Enhanced + gamma', 1, 3);
            app.HistBeforeAxes = uiaxes(grid);
            app.HistBeforeAxes.Layout.Row = 2;
            app.HistBeforeAxes.Layout.Column = 1;
            title(app.HistBeforeAxes, 'Histogram before enhancement');
            app.HistAfterAxes = uiaxes(grid);
            app.HistAfterAxes.Layout.Row = 2;
            app.HistAfterAxes.Layout.Column = 2;
            title(app.HistAfterAxes, 'Histogram after enhancement');
            app.ComparisonTable = uitable(grid);
            app.ComparisonTable.Layout.Row = 2;
            app.ComparisonTable.Layout.Column = 3;
            app.ComparisonTable.ColumnName = {'Method', 'Std (contrast)', 'Entropy', 'Edge strength'};
            app.ComparisonTable.RowName = {};

            app.MorphologyTab = uitab(app.TabGroup, 'Title', 'Morphology');
            grid = uigridlayout(app.MorphologyTab, [1 3]);
            grid.ColumnWidth = {'1x', '1x', 300};
            app.MaskBeforeAxes = app.createImageAxes(grid, 'Mask before morphology', 1, 1);
            app.MaskAfterAxes  = app.createImageAxes(grid, 'Mask after morphology', 1, 2);
            app.MorphologyInfo = uitextarea(grid);
            app.MorphologyInfo.Editable = 'off';
            app.MorphologyInfo.Layout.Row = 1;
            app.MorphologyInfo.Layout.Column = 3;
            app.MorphologyInfo.Value = {''};

            app.FeaturesTab = uitab(app.TabGroup, 'Title', 'Features');
            grid = uigridlayout(app.FeaturesTab, [1 2]);
            grid.ColumnWidth = {'1x', '1x'};
            app.FeatureTable = uitable(grid);
            app.FeatureTable.ColumnName = {'Feature', 'Value'};
            app.FeatureTable.RowName = {};
            app.FeatureTable.Layout.Row = 1;
            app.FeatureTable.Layout.Column = 1;
            app.FeatureInfo = uitextarea(grid);
            app.FeatureInfo.Editable = 'off';
            app.FeatureInfo.Layout.Row = 1;
            app.FeatureInfo.Layout.Column = 2;
            app.FeatureInfo.Value = { ...
                'Features are computed inside the final lung mask only.'; ''; ...
                'Intensity (normalised, denoised image):'; ...
                '  Mean, Std, Variance, Min, Max, Entropy, Skewness, Kurtosis'; ''; ...
                'Texture - GLCM of the CLAHE-enhanced image (16 levels,'; ...
                'distance 1, 0/45/90/135 degrees averaged, symmetric):'; ...
                '  Contrast, Correlation, Energy, Homogeneity'; ''; ...
                'Shape:'; '  LungAreaRatio = lung pixels / image pixels'; ''; ...
                'Features always use the training settings (gamma = 1),'; ...
                'so the gamma slider does not change the prediction.'};

            app.EvaluationTab = uitab(app.TabGroup, 'Title', 'Model Evaluation');
            grid = uigridlayout(app.EvaluationTab, [1 2]);
            app.ConfusionAxes = uiaxes(grid);
            app.ConfusionAxes.Layout.Row = 1;
            app.ConfusionAxes.Layout.Column = 1;
            app.MetricsText = uitextarea(grid);
            app.MetricsText.Editable = 'off';
            app.MetricsText.FontName = 'Courier New';
            app.MetricsText.Layout.Row = 1;
            app.MetricsText.Layout.Column = 2;

            % ---------------- Status + disclaimer ----------------
            app.StatusLabel = uilabel(app.MainGrid);
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = [1 2];
            app.StatusLabel.FontAngle = 'italic';

            app.DisclaimerLabel = uilabel(app.MainGrid);
            app.DisclaimerLabel.Text = app.Disclaimer;
            app.DisclaimerLabel.Layout.Row = 4;
            app.DisclaimerLabel.Layout.Column = [1 2];
            app.DisclaimerLabel.WordWrap = 'on';
            app.DisclaimerLabel.HorizontalAlignment = 'center';
            app.DisclaimerLabel.FontWeight = 'bold';
            app.DisclaimerLabel.FontColor = [0.7 0.1 0.1];
            app.DisclaimerLabel.BackgroundColor = [1 0.95 0.9];

            app.UIFigure.Visible = 'on';
        end
    end

    % ================================================ Construction
    methods (Access = public)

        function app = ChestXrayApp
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end
