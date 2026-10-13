function results = testTraining(runIntegration)
%TESTTRAINING Tests for SVM training, prediction, model saving, reports and
%the end-to-end training workflow.
%   All data here is SYNTHETIC (random feature vectors, phantom images) and
%   only verifies that the software works. Nothing here is a medical result.
%   runIntegration (default true) also runs the end-to-end workflow on a
%   temporary synthetic NIH-style folder (about 1 minute).

if nargin < 1
    runIntegration = true;
end
cfg = appConfig();
results = struct('name', {}, 'status', {}, 'message', {});
tmp = tempname();
mkdir(tmp);
cleaner = onCleanup(@() rmdirQuiet(tmp));

[XTr, yTr] = syntheticFeatures(60, 1);
[XVa, yVa] = syntheticFeatures(20, 2);
model = [];
try
    model = trainSVM(XTr, yTr, XVa, yVa, cfg);
catch err
    fprintf('  trainSVM failed: %s\n', err.message);
end

results(end+1) = runCase('SVM trains on valid (synthetic) data', @() checkModel(model, cfg));
results(end+1) = runCase('standardisation uses training statistics', @() checkStandardization(model, XTr, yTr, XVa));
results(end+1) = runCase('kernel/hyper-parameters chosen on validation data', @() checkSelection(model, cfg));
results(end+1) = runCase('single class is rejected', ...
    @() expectError(@() trainSVM(XTr, repmat({'Normal'}, 60, 1), XVa, yVa, cfg), 'CXR:singleClass'));
results(end+1) = runCase('too few samples are rejected', ...
    @() expectError(@() trainSVM(XTr([1:4 31:34], :), yTr([1:4 31:34]), XVa, yVa, cfg), 'CXR:insufficientData'));
results(end+1) = runCase('non-finite features are rejected', @() checkNonFinite(XTr, yTr, XVa, yVa, cfg));
results(end+1) = runCase('invalid labels are rejected', ...
    @() expectError(@() trainSVM(XTr, repmat({'Normal'; 'Sick'}, 30, 1), XVa, yVa, cfg), 'CXR:invalidLabels'));
results(end+1) = runCase('wrong number of features is rejected', ...
    @() expectError(@() classifyFeatures(rand(2, 5), model), 'CXR:featureDefinition'));
results(end+1) = runCase('missing model file', ...
    @() expectError(@() loadTrainedModel(fullfile(tmp, 'none.mat')), 'CXR:missingModel'));
results(end+1) = runCase('incomplete model is rejected', ...
    @() expectError(@() classifyFeatures(rand(1, 10), struct('kernel', 'rbf')), 'CXR:invalidModel'));
results(end+1) = runCase('model is saved with all metadata', @() checkSaveLoad(model, tmp, XVa));
results(end+1) = runCase('prediction using a saved model (load + predict)', @() checkSavedPrediction(model, tmp, XVa));
results(end+1) = runCase('single-image prediction uses the model configuration', @() checkPredictImage(model, cfg));
results(end+1) = runCase('analysis report export (TXT and CSV)', @() checkReportExport(tmp, cfg));
results(end+1) = runCase('evaluation export (metrics, confusion matrix)', @() checkEvaluationExport(tmp));

if runIntegration
    results(end+1) = runCase('end-to-end workflow on a SYNTHETIC NIH-style folder', @() checkWorkflow(tmp, cfg));
    results(end+1) = runCase('training can be cancelled without saving a model', @() checkCancel(tmp, cfg));
else
    results(end+1) = runCase('end-to-end workflow on a SYNTHETIC NIH-style folder', @() skip('disabled'));
end
end

% =========================================================================
function [X, y] = syntheticFeatures(n, seed)
% Two Gaussian clusters in 10-D (synthetic numbers, not image features)
previous = rng();
restore = onCleanup(@() rng(previous));
rng(seed, 'twister');
half = n / 2;
X = [randn(half, 10) + 1.5; randn(half, 10) - 1.5];
X(:, 3) = X(:, 3) * 100 + 50;     % different scales -> standardisation matters
y = [repmat({'Abnormal'}, half, 1); repmat({'Normal'}, half, 1)];
end

function checkModel(model, cfg)
assert(~isempty(model), 'training failed');
required = {'classifier', 'kernel', 'featureNames', 'standardization', 'classNames', ...
            'positiveClass', 'pipelineConfig', 'selection', 'trainingInfo'};
assert(all(isfield(model, required)), 'model fields missing');
assert(isequal(model.featureNames, cfg.features.names), 'feature names not stored');
assert(strcmp(model.positiveClass, 'Abnormal'), 'positive class wrong');
assert(model.trainingInfo.numFinalFit == 80, 'final model must use train + validation');
end

function checkStandardization(model, XTr, yTr, XVa)
assert(~isempty(model), 'no model');
both = [XTr; XVa];
assert(max(abs(model.standardization.mu - mean(both, 1))) < 1e-9, 'mu must come from the fitting data');
[labels, scores] = classifyFeatures(XTr, model);
assert(mean(strcmp(labels, yTr)) > 0.9, 'separable synthetic data should be learned');
assert(all(strcmp(labels(scores > 0), 'Abnormal')), 'positive score must mean Abnormal');
end

function checkSelection(model, cfg)
assert(~isempty(model), 'no model');
numCandidates = numel(cfg.svm.boxConstraints) * (1 + numel(cfg.svm.kernelScales));
assert(numel(model.selection) == numCandidates, 'expected %d candidates', numCandidates);
assert(ismember(model.kernel, {'linear', 'rbf'}), 'unknown kernel');
assert(model.bestValidationBalancedAccuracy == max([model.selection.valBalancedAccuracy]), ...
    'best candidate must have the highest validation score');
end

function checkNonFinite(XTr, yTr, XVa, yVa, cfg)
XTr(3, 4) = NaN;
expectError(@() trainSVM(XTr, yTr, XVa, yVa, cfg), 'CXR:nonFiniteFeature');
end

function checkSaveLoad(model, tmp, XVa) %#ok<INUSD>
assert(~isempty(model), 'no model');
file = fullfile(tmp, 'trainedModel.mat');
save(file, 'model', '-v7');
loaded = load(file);
m = loaded.model;
assert(isequal(m.featureNames, model.featureNames), 'feature names lost');
assert(isequal(m.standardization.mu, model.standardization.mu) && ...
       isequal(m.standardization.sigma, model.standardization.sigma), 'standardisation lost');
assert(isequal(m.classNames, model.classNames) && strcmp(m.kernel, model.kernel), 'labels/kernel lost');
assert(pipelineConfigsMatch(m.pipelineConfig, model.pipelineConfig), 'pipeline configuration lost');
end

function checkSavedPrediction(model, tmp, XVa)
assert(~isempty(model), 'no model');
if isOctaveRuntime()
    skip('Octave converts saved classifier objects to structs; verified in MATLAB only');
end
file = fullfile(tmp, 'trainedModel.mat');
save(file, 'model', '-v7');
loaded = loadTrainedModel(file);
a = classifyFeatures(XVa, model);
b = classifyFeatures(XVa, loaded);
assert(isequal(a, b), 'loaded model predicts differently');
end

function checkPredictImage(model, cfg)
assert(~isempty(model), 'no model');
r = predictImage(makeChestPhantom(512, 5), model);
assert(ismember(r.label, cfg.svm.classNames) && isfinite(r.score), 'invalid prediction');
assert(numel(r.features) == 10 && strcmp(r.analysis.roiType, 'lung'), 'lung-ROI features expected');
model.pipelineConfig.enhance.method = 'clahe';
r2 = predictImage(makeChestPhantom(512, 5), model);
assert(strcmp(r2.analysis.enhancementMethod, 'clahe'), 'the model''s enhancement method must be used');
end

function checkReportExport(tmp, cfg)
report = struct('fileName', 'test,image.png', 'enhancementMethod', 'stretch', 'gamma', 1, ...
    'noiseMethod', 'median', 'roiType', 'lung', 'segmentationStatus', 'ok', ...
    'featureNames', {cfg.features.names}, 'featureValues', 1:10, 'modelStatus', 'Trained', ...
    'prediction', 'Normal', 'predictionNote', 'n/a', 'datasetLabel', 'Not available');
txt = fullfile(tmp, 'report.txt');
csv = fullfile(tmp, 'report.csv');
exportReport(report, txt);
exportReport(report, csv);
t = fileread(txt);
c = fileread(csv);
assert(~isempty(strfind(t, cfg.disclaimer)) && ~isempty(strfind(t, 'Homogeneity')), 'TXT incomplete');
assert(~isempty(strfind(c, '"test,image.png"')) && ~isempty(strfind(c, 'Feature: Mean,1')), 'CSV incomplete/unescaped');
assert(~isempty(strfind(c, 'Disclaimer')), 'CSV disclaimer missing');
expectError(@() exportReport(report, fullfile(tmp, 'report.pdf')), 'CXR:exportFailed');
end

function checkEvaluationExport(tmp)
m = evaluateModel({'Normal'; 'Abnormal'; 'Abnormal'}, {'Normal'; 'Abnormal'; 'Normal'});
ev = struct('metrics', m, 'predictions', struct('imageName', {{'a'; 'b'; 'c'}}, ...
    'patientId', [1; 2; 3], 'trueLabel', {{'Normal'; 'Abnormal'; 'Abnormal'}}, ...
    'predictedLabel', {{'Normal'; 'Abnormal'; 'Normal'}}, 'score', [-1; 1; -0.5]));
out = fullfile(tmp, 'eval');
files = exportEvaluation(ev, out);
cm = fileread(files.confusionCsv);
assert(~isempty(strfind(cm, 'Normal,1,0')) && ~isempty(strfind(cm, 'Abnormal,1,1')), 'confusion CSV wrong');
assert(~isempty(strfind(fileread(files.metricsCsv), 'accuracy,0.666667')), 'metrics CSV wrong');
assert(exist(files.predictionsCsv, 'file') == 2 && exist(files.metricsTxt, 'file') == 2, 'files missing');
end

function checkWorkflow(tmp, cfg)
folder = fullfile(tmp, 'synthetic_nih');
makeSyntheticNihFolder(folder, 80);
cfg.dataset.subsetSize = 60;
modelFile = fullfile(tmp, 'wfModel.mat');
resultsDir = fullfile(tmp, 'wfResults');
r = runTrainingWorkflow(folder, 'Config', cfg, 'ModelFile', modelFile, ...
    'ResultsDir', resultsDir, 'UseCache', false);
assert(strcmp(r.status, 'completed'), 'workflow did not complete');
assert(exist(modelFile, 'file') == 2, 'model file not written');
assert(r.dataset.report.patientOverlap == 0, 'patient overlap');
testOk = strcmp(r.dataset.split, 'test') & ~ismember(r.dataset.imageName, {r.failures.name});
assert(r.evaluation.metrics.numSamples == nnz(testOk), 'test sample count mismatch');
for f = {'metrics.csv', 'metrics.txt', 'confusion_matrix.csv', 'test_predictions.csv', 'dataset_split.csv'}
    assert(exist(fullfile(resultsDir, f{1}), 'file') == 2, '%s missing', f{1});
end
assert(isfield(r.model, 'testEvaluation') && isfield(r.model, 'datasetInfo'), 'model metadata missing');
end

function checkCancel(tmp, cfg)
folder = fullfile(tmp, 'synthetic_nih_cancel');
makeSyntheticNihFolder(folder, 20);
modelFile = fullfile(tmp, 'cancelModel.mat');
r = runTrainingWorkflow(folder, 'Config', cfg, 'ModelFile', modelFile, ...
    'ProgressFcn', @(f, msg) f > 0.06, 'UseCache', false);
assert(strcmp(r.status, 'cancelled') && exist(modelFile, 'file') ~= 2, 'cancel must not save a model');
end

function skip(message)
error('CXR:testSkipped', '%s', message);
end

function rmdirQuiet(folder)
try
    rmdir(folder, 's');
catch
end
end
