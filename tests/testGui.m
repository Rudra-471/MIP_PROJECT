function results = testGui()
%TESTGUI Drive the dashboard through its main workflows.
%   MATLAB : opens the real dashboard (launchApp(false), so a saved model is
%            not loaded), calls the same callbacks a user triggers, checks
%            the application state and closes the window. Dialog-based
%            actions are exercised through their dialog-free methods
%            (loadImageFile, setDatasetFolder, exportReportTo).
%   Octave : no uifigure exists, so tests/ui_mock provides headless
%            stand-ins (see the README there). The real page builders and
%            AppController logic run; drawing itself is not tested.
%   The training step uses a SYNTHETIC NIH-style folder (software test only).

results = struct('name', {}, 'status', {}, 'message', {});
testsDir = fileparts(mfilename('fullpath'));
octave = isOctaveRuntime();
global MOCK_UI MOCK_UI_REGISTRY %#ok<GVMIS>
if octave
    MOCK_UI = struct('alerts', {{}}, 'answers', {{}}, 'files', {{}});
    MOCK_UI_REGISTRY = {};
    mockDir = fullfile(testsDir, 'ui_mock');
    addpath(mockDir);
    pathCleaner = onCleanup(@() rmpath(mockDir));
end
tmp = tempname();
mkdir(tmp);
tmpCleaner = onCleanup(@() rmdirQuiet(tmp));
samples = dir(fullfile(testsDir, 'data', 'nih_samples', '*.png'));
sample = fullfile(testsDir, 'data', 'nih_samples', samples(1).name);

ctrl = [];
try
    ctrl = launchApp(false);
    ctrl.ModelFile = fullfile(tmp, 'models', 'trainedModel.mat');
    ctrl.ResultsRoot = fullfile(tmp, 'results');
catch err
    results(end+1) = runCase('dashboard starts', @() error('test:launch', '%s', err.message));
    return;
end
figCleaner = onCleanup(@() closeApp(ctrl));

if octave
    results(end+1) = runCase('layout: placements inside grids, no accidental overlap', @() checkLayout(MOCK_UI_REGISTRY));
end
results(end+1) = runCase('dashboard starts with honest empty states', @() checkStart(ctrl));
results(end+1) = runCase('sidebar navigation shows exactly one page', @() checkNavigation(ctrl));
results(end+1) = runCase('upload enables only the first step', @() checkUpload(ctrl, sample));
results(end+1) = runCase('step buttons run the pipeline in order', @() checkSteps(ctrl));
results(end+1) = runCase('predict is disabled without a model', @() checkNoModel(ctrl, octave));
results(end+1) = runCase('enhancement method / gamma changes re-enhance', @() checkEnhancementControls(ctrl));
results(end+1) = runCase('inspector switches histogram / morphology', @() checkInspector(ctrl));
results(end+1) = runCase('Run Full Analysis completes all steps', @() checkFullAnalysis(ctrl));
results(end+1) = runCase('analysis report export', @() checkReport(ctrl, tmp));
results(end+1) = runCase('corrupted image upload is reported, state kept', @() checkCorrupt(ctrl, tmp, octave));
results(end+1) = runCase('failed segmentation path', @() checkSegFailure(ctrl, tmp, octave));
results(end+1) = runCase('dataset folder scan (synthetic NIH layout)', @() checkScan(ctrl, tmp));
results(end+1) = runCase('training from the GUI updates model and evaluation', @() checkTraining(ctrl));
results(end+1) = runCase('prediction with the trained model', @() checkPrediction(ctrl, sample));
results(end+1) = runCase('settings apply and restore', @() checkSettings(ctrl));
results(end+1) = runCase('reset clears the analysis', @() checkReset(ctrl));
end

% =========================================================================
function checkLayout(registry)
% Every explicitly placed component must lie inside its parent grid, and
% only the stacked pages / inspector panels may share a grid cell.
occupied = struct('key', {}, 'type', {});
shared = 0;
for k = 1:numel(registry)
    c = registry{k};
    p = c.Parent;
    if isempty(p) || ~strcmp(p.Type, 'uigridlayout') || isempty(c.Layout.Row) || isempty(c.Layout.Column)
        continue;
    end
    nr = numel(p.RowHeight);
    if nr == 0, nr = p.GridSize(1); end
    nc = numel(p.ColumnWidth);
    if nc == 0, nc = p.GridSize(2); end
    assert(max(c.Layout.Row) <= nr && max(c.Layout.Column) <= nc, ...
        '%s placed at row %s / column %s of a %d x %d grid', c.Type, ...
        mat2str(c.Layout.Row), mat2str(c.Layout.Column), nr, nc);
    for r = c.Layout.Row(1):c.Layout.Row(end)
        for q = c.Layout.Column(1):c.Layout.Column(end)
            key = sprintf('%d|%d|%d', p.Id, r, q);
            if any(strcmp({occupied.key}, key))
                assert(strcmp(c.Type, 'uipanel'), 'two components share a cell: %s', c.Type);
                shared = shared + 1;
            else
                occupied(end + 1) = struct('key', key, 'type', c.Type); %#ok<AGROW>
            end
        end
    end
end
assert(shared == 6, 'expected 6 intentional shared cells (5 stacked pages + inspector), found %d', shared);
end

function checkStart(ctrl)
d = ctrl.UI.dashboard;
assert(strcmp(d.cards.model.value.Text, 'Model not trained'), 'model card should say "Model not trained"');
assert(strcmp(d.cards.metrics.value.Text, 'Evaluation pending'), 'metrics card should say "Evaluation pending"');
assert(strcmp(d.cards.dataset.value.Text, 'Not available'), 'dataset card should say "Not available"');
assert(strcmp(ctrl.UI.evaluation.metric.accuracy.value.Text, 'Pending'), 'evaluation must be pending');
assert(strcmp(ctrl.UI.analysis.stepButtons.preprocess.Enable, 'off'), 'Preprocess must be disabled');
assert(strcmp(ctrl.UI.analysis.stepButtons.predict.Enable, 'off'), 'Predict must be disabled');
assert(~isempty(strfind(ctrl.UI.disclaimer.Text, 'not a medical diagnosis')), 'disclaimer must be visible');
end

function checkNavigation(ctrl)
pages = AppController.pageList();
for k = 1:size(pages, 1)
    press(ctrl.UI.sidebar.navButtons{k});
    for j = 1:size(pages, 1)
        expected = 'off';
        if j == k
            expected = 'on';
        end
        assert(strcmp(ctrl.UI.(pages{j, 1}).panel.Visible, expected), 'page %s visibility wrong', pages{j, 1});
    end
    assert(strcmp(ctrl.UI.top.title.Text, pages{k, 2}), 'title should be %s', pages{k, 2});
end
press(ctrl.UI.top.homeButton);
assert(strcmp(ctrl.CurrentPage, 'dashboard'), 'Dashboard button must return to the dashboard');
end

function checkUpload(ctrl, sample)
ctrl.loadImageFile(sample);
a = ctrl.UI.analysis;
assert(~isempty(ctrl.Analysis) && strcmp(ctrl.CurrentPage, 'analysis'), 'image not loaded');
assert(strcmp(a.stepButtons.preprocess.Enable, 'on'), 'Preprocess should be enabled');
assert(strcmp(a.stepButtons.enhance.Enable, 'off') && strcmp(a.stepButtons.morphology.Enable, 'off'), ...
    'later steps must stay disabled');
assert(~isempty(strfind(ctrl.UI.top.status.Text, '0 of 6')), 'workflow status should show 0 of 6');
end

function checkSteps(ctrl)
a = ctrl.UI.analysis;
press(a.stepButtons.preprocess);
assert(ctrl.Analysis.done.preprocess, 'preprocess not done');
assert(strcmp(a.stepButtons.segment.Enable, 'on') && strcmp(a.stepButtons.morphology.Enable, 'off'), 'enable states wrong');
press(a.stepButtons.enhance);
press(a.stepButtons.segment);
press(a.stepButtons.morphology);
assert(strcmp(a.stepButtons.features.Enable, 'on'), 'features should be enabled');
press(a.stepButtons.features);
assert(ctrl.Analysis.done.features && strcmp(ctrl.Analysis.roiType, 'lung'), 'features not computed on lung ROI');
assert(size(a.featureTable.Data, 1) == 10, 'feature table should list 10 features');
assert(~isempty(strfind(a.info.final.Text, 'not a lesion')), 'final panel must state it is not a lesion map');
end

function checkNoModel(ctrl, octave)
global MOCK_UI %#ok<GVMIS>
a = ctrl.UI.analysis;
assert(strcmp(a.stepButtons.predict.Enable, 'off'), 'Predict must be disabled without a model');
assert(~isempty(strfind(a.stepButtons.predict.Tooltip, 'model')), 'tooltip should explain the missing model');
assert(strcmp(a.predictionValue.Text, 'Model not trained'), 'no prediction may be shown');
if octave
    n = numel(MOCK_UI.alerts);
    ctrl.predict();
    assert(numel(MOCK_UI.alerts) == n + 1 && strcmp(MOCK_UI.alerts{end}.icon, 'warning'), 'predict should warn');
end
end

function checkEnhancementControls(ctrl)
a = ctrl.UI.analysis;
change(a.method, 'clahe');
assert(strcmp(ctrl.Analysis.enhancementMethod, 'clahe') && ctrl.Analysis.done.enhance, 'method not applied');
assert(~ctrl.Analysis.done.features && ctrl.Analysis.done.morphology, 'features cleared, mask kept');
change(a.gammaSlider, 0.8);
assert(abs(ctrl.Analysis.gamma - 0.8) < 1e-12 && abs(ctrl.Config.enhance.gamma - 0.8) < 1e-12, 'gamma not applied');
assert(~isempty(strfind(a.gammaLabel.Text, '0.80')), 'gamma label not updated');
end

function checkInspector(ctrl)
a = ctrl.UI.analysis;
press(a.morphToggle);
assert(strcmp(a.morphPanel.Visible, 'on') && strcmp(a.histPanel.Visible, 'off'), 'morphology view not shown');
press(a.histToggle);
assert(strcmp(a.histPanel.Visible, 'on') && strcmp(a.morphPanel.Visible, 'off'), 'histogram view not shown');
end

function checkFullAnalysis(ctrl)
press(ctrl.UI.analysis.runAllButton);
d = ctrl.Analysis.done;
assert(d.preprocess && d.enhance && d.segment && d.morphology && d.features, 'not every step ran');
end

function checkReport(ctrl, tmp)
file = fullfile(tmp, 'report.txt');
ctrl.exportReportTo(file);
text = fileread(file);
assert(~isempty(strfind(text, ctrl.Analysis.fileName)) && ~isempty(strfind(text, 'Model not trained')), 'report content');
assert(~isempty(strfind(text, 'not a medical diagnosis')), 'report must contain the disclaimer');
end

function checkCorrupt(ctrl, tmp, octave)
global MOCK_UI %#ok<GVMIS>
before = ctrl.Analysis.fileName;
file = fullfile(tmp, 'broken.png');
fid = fopen(file, 'w'); fwrite(fid, uint8(1:100)); fclose(fid);
ctrl.loadImageFile(file);
assert(strcmp(ctrl.Analysis.fileName, before), 'a failed upload must keep the previous image');
if octave
    assert(strcmp(MOCK_UI.alerts{end}.icon, 'error') && ~isempty(strfind(MOCK_UI.alerts{end}.message, 'decoded')), ...
        'a readable error must be shown');
end
end

function checkSegFailure(ctrl, tmp, octave)
global MOCK_UI %#ok<GVMIS>
file = fullfile(tmp, 'flat.png');
imwrite(uint8(128 + 4 * rand(256)), file);
ctrl.loadImageFile(file);
a = ctrl.UI.analysis;
press(a.stepButtons.preprocess);
press(a.stepButtons.enhance);
press(a.stepButtons.segment);
assert(~strcmp(ctrl.Analysis.seg.status, 'ok'), 'segmentation should fail on a flat image');
assert(strcmp(a.stepButtons.morphology.Enable, 'off'), 'morphology must be disabled after a failure');
if octave
    assert(strcmp(MOCK_UI.alerts{end}.title, 'Segmentation failed'), 'failure must be reported');
end
press(a.stepButtons.features);
assert(strcmp(ctrl.Analysis.roiType, 'wholeImage'), 'whole-image features expected');
assert(~isempty(strfind(a.roiLabel.Text, 'WHOLE IMAGE')), 'ROI warning missing');
end

function checkScan(ctrl, tmp)
folder = fullfile(tmp, 'nih_synthetic');
makeSyntheticNihFolder(folder, 80);
ctrl.setDatasetFolder(folder);
assert(~isempty(ctrl.MetadataFile), 'metadata CSV should be detected');
press(ctrl.UI.training.scanButton);
s = ctrl.DatasetSummary;
assert(~isempty(s) && s.numFound == 80 && s.numNormal == 40, 'scan summary wrong');
assert(strcmp(ctrl.UI.training.stats.found.Text, '80'), 'found count not displayed');
assert(size(ctrl.UI.training.splitTable.Data, 1) == 3, 'split preview missing');
end

function checkTraining(ctrl)
t = ctrl.UI.training;
t.subsetSize.Value = 60;
t.useCache.Value = false;
press(t.trainButton);
assert(strcmp(ctrl.TrainingState, 'done'), 'training state is %s', ctrl.TrainingState);
assert(~isempty(ctrl.Model) && exist(ctrl.ModelFile, 'file') == 2, 'model not saved');
assert(strcmp(ctrl.CurrentPage, 'evaluation'), 'should show the evaluation page');
e = ctrl.UI.evaluation;
assert(~strcmp(e.metric.accuracy.value.Text, 'Pending'), 'metrics not displayed');
assert(size(e.selectionTable.Data, 1) == numel(ctrl.Model.selection), 'model selection table missing');
assert(strcmp(ctrl.UI.dashboard.cards.model.value.Text, 'Trained'), 'dashboard model card not updated');
assert(~isempty(strfind(ctrl.UI.dashboard.cards.metrics.value.Text, 'Accuracy')), 'dashboard metrics not updated');
end

function checkPrediction(ctrl, sample)
ctrl.loadImageFile(sample);
press(ctrl.UI.analysis.runAllButton);
p = ctrl.Prediction;
assert(~isempty(p) && ismember(p.label, {'Normal', 'Abnormal'}), 'no prediction');
assert(strcmp(ctrl.UI.analysis.predictionValue.Text, upper(p.label)), 'prediction not displayed');
assert(~isempty(strfind(p.note, 'same configuration')), 'configuration should match the model');
assert(isempty(strfind(lower(ctrl.UI.analysis.scoreLabel.Text), 'confidence')), 'no confidence may be shown');
change(ctrl.UI.analysis.gammaSlider, 1.3);
assert(strcmp(ctrl.UI.analysis.predictionValue.Text, 'No prediction'), 'old prediction must be invalidated');
press(ctrl.UI.analysis.stepButtons.features);
press(ctrl.UI.analysis.stepButtons.predict);
assert(~isempty(strfind(ctrl.Prediction.note, 'differ')), 'mismatched settings must be explained');
end

function checkSettings(ctrl)
s = ctrl.UI.settings;
s.openRadius.Value = 4;
press(s.applyButton);
assert(ctrl.Config.morph.openRadius == 4, 'setting not applied');
assert(~ctrl.Analysis.done.preprocess, 'analysis results must be cleared');
assert(~isempty(strfind(s.state.Text, 'differ')), 'difference to the model must be noted');
press(s.defaultsButton);
assert(ctrl.Config.morph.openRadius == 5 && s.openRadius.Value == 5, 'defaults not restored');
end

function checkReset(ctrl)
ctrl.resetAnalysis(false);
assert(isempty(ctrl.Analysis) && strcmp(ctrl.UI.analysis.exportButton.Enable, 'off'), 'reset incomplete');
assert(strcmp(ctrl.UI.dashboard.cards.image.value.Text, 'No image loaded'), 'dashboard not reset');
end

% ---- helpers ------------------------------------------------------------
function press(component)
fcn = component.ButtonPushedFcn;
fcn(component, []);
end

function change(component, value)
component.Value = value;
fcn = component.ValueChangedFcn;
fcn(component, struct('Value', value));
end

function closeApp(ctrl)
try
    if ~isOctaveRuntime()
        delete(ctrl.Figure);
    end
catch
end
end

function rmdirQuiet(folder)
try
    rmdir(folder, 's');
catch
end
end
