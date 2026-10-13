function result = runTrainingWorkflow(datasetDir, varargin)
%RUNTRAININGWORKFLOW Complete dataset -> features -> SVM -> test evaluation workflow.
%   result = runTrainingWorkflow(datasetDir) uses appConfig() defaults.
%   result = runTrainingWorkflow(datasetDir, 'Name', value, ...) options:
%     'Config'       configuration struct (default appConfig())
%     'MetadataFile' path of Data_Entry_2017_v2020.csv (default: searched in datasetDir)
%     'ModelFile'    output model (default models/trainedModel.mat)
%     'ResultsDir'   evaluation output folder (default results/<timestamp>)
%     'ProgressFcn'  @(fraction, message) -> true to cancel (GUI progress)
%     'UseCache'     re-use cached features (default true, cache/featureCache.mat)
%
%   Steps
%     1. read + validate metadata             (loadDatasetMetadata)
%     2. index image files on disk            (indexDatasetImages)
%     3. build binary labels, patient-wise split and subset (prepareDataset;
%        official NIH lists are used when train_val_list.txt / test_list.txt exist)
%     4. extract features for train, validation and test images
%     5. train the SVM, select hyper-parameters on validation data (trainSVM)
%     6. save the model with all preprocessing metadata
%     7. evaluate ONCE on the held-out test set (evaluateModel)
%     8. save the evaluation results (exportEvaluation)
%
%   result fields: status ('completed' | 'cancelled'), model, evaluation,
%   dataset, metadataReport, failures, modelFile, resultsDir, log (cellstr).
%
%   Example
%     setupProject();
%     r = runTrainingWorkflow('D:\data\NIH-ChestXray14');

parser = inputParser();
parser.addParameter('Config', []);
parser.addParameter('MetadataFile', '');
parser.addParameter('ModelFile', defaultModelFile());
parser.addParameter('ResultsDir', '');
parser.addParameter('ProgressFcn', []);
parser.addParameter('UseCache', true);
parser.parse(varargin{:});
opts = parser.Results;
cfg = opts.Config;
if isempty(cfg)
    cfg = appConfig();
end
progress = opts.ProgressFcn;
logLines = {};

result = struct('status', 'running', 'model', [], 'evaluation', [], 'dataset', [], ...
                'metadataReport', [], 'failures', [], 'modelFile', '', 'resultsDir', '', 'log', {{}});

checkDependencies(true);
if nargin < 1 || isempty(datasetDir) || exist(char(datasetDir), 'dir') ~= 7
    error('CXR:missingDataset', 'Dataset folder not found: %s', char(datasetDir));
end
datasetDir = char(datasetDir);

% ---- 1. Metadata -------------------------------------------------------------
if report(0.01, 'Reading metadata...'), result = cancelResult(result, logLines); return; end
metadataFile = opts.MetadataFile;
if isempty(metadataFile)
    metadataFile = findMetadataFile(datasetDir, cfg);
end
meta = loadDatasetMetadata(metadataFile, cfg);
result.metadataReport = meta.report;
note(meta.report.messages);

% ---- 2. Index ------------------------------------------------------------------
if report(0.03, 'Indexing image files...'), result = cancelResult(result, logLines); return; end
index = indexDatasetImages(datasetDir, cfg);
note(sprintf('Indexed %d image files in %d folders.', numel(index.fileNames), index.numFolders));
if ~isempty(index.duplicates)
    note(sprintf('%d file name(s) occur in several folders; the first copy is used.', numel(index.duplicates)));
end

% ---- 3. Labels, split, subset ------------------------------------------------
officialSplit = loadOfficialSplit(fileparts(metadataFile), cfg);
if isempty(officialSplit)
    officialSplit = loadOfficialSplit(datasetDir, cfg);
end
dataset = prepareDataset(meta, index, cfg, officialSplit);
result.dataset = dataset;
note(['Split: ' dataset.report.splitSource '.']);
note(dataset.report.messages);
note(sprintf('Patients per split (train/validation/test): %d / %d / %d; overlapping patients: %d.', ...
    dataset.report.patientsPerSplit, dataset.report.patientOverlap));

% ---- 4. Features -------------------------------------------------------------------
cacheFile = '';
if opts.UseCache
    cacheFile = fullfile(projectRoot(), 'cache', 'featureCache.mat');
end
featureProgress = @(k, n, name) report(0.05 + 0.80 * k / n, ...
    sprintf('Extracting features %d / %d (%s)', k, n, name));
[X, ok, failures, cancelled] = buildFeatureMatrix(dataset.fullPath, dataset.imageName, cfg, ...
    featureProgress, cacheFile);
result.failures = failures;
if cancelled
    result = cancelResult(result, logLines);
    return;
end
note(sprintf('Features extracted for %d of %d images; %d skipped (see failures).', ...
    nnz(ok), numel(ok), numel(failures)));
if ~isempty(failures)
    [ids, ~, idx] = unique({failures.identifier});
    for k = 1:numel(ids)
        note(sprintf('  %d image(s) skipped: %s', nnz(idx == k), ids{k}));
    end
end

isTrain = strcmp(dataset.split, 'train') & ok;
isVal   = strcmp(dataset.split, 'validation') & ok;
isTest  = strcmp(dataset.split, 'test') & ok;

% ---- 5. Train ----------------------------------------------------------------------
if report(0.86, 'Training SVM (model selection on validation set)...'), result = cancelResult(result, logLines); return; end
trainProgress = @(f, msg) report(0.86 + 0.10 * f, msg);
model = trainSVM(X(isTrain, :), dataset.label(isTrain), X(isVal, :), dataset.label(isVal), ...
                 cfg, trainProgress);

% ---- 7. Evaluate once on the held-out test set -------------------------------------
if report(0.97, 'Evaluating on the held-out test set...'), result = cancelResult(result, logLines); return; end
if ~any(isTest)
    error('CXR:emptyEvaluation', 'The test set is empty; the model cannot be evaluated.');
end
[predicted, scores] = classifyFeatures(X(isTest, :), model);
metrics = evaluateModel(dataset.label(isTest), predicted, cfg.svm.positiveClass, cfg.svm.classNames);

evaluation = struct();
evaluation.metrics = metrics;
evaluation.predictions = struct('imageName', {dataset.imageName(isTest)}, ...
    'patientId', dataset.patientId(isTest), 'trueLabel', {dataset.label(isTest)}, ...
    'predictedLabel', {predicted}, 'score', scores);
evaluation.evaluatedOn = datestr(now, 'yyyy-mm-dd HH:MM:SS');
evaluation.summary = struct( ...
    'Model', sprintf('SVM, %s kernel, BoxConstraint %g%s', model.kernel, model.boxConstraint, ...
        kernelScaleText(model)), ...
    'Split', dataset.report.splitSource, ...
    'Training', sprintf('%d images (%d Normal / %d Abnormal)', model.trainingInfo.numTrain, ...
        model.trainingInfo.trainClassCounts), ...
    'Validation', sprintf('%d images (%d Normal / %d Abnormal), best balanced accuracy %.3f', ...
        model.trainingInfo.numValidation, model.trainingInfo.validationClassCounts, ...
        model.bestValidationBalancedAccuracy), ...
    'FinalFit', sprintf('%d images (training + validation)', model.trainingInfo.numFinalFit), ...
    'Enhancement', sprintf('%s, gamma %.2f', cfg.enhance.method, cfg.enhance.gamma), ...
    'Runtime', model.trainingInfo.environment);

% ---- 6. Save model (with dataset metadata and test evaluation) -----------------------
model.datasetInfo = struct('datasetDir', datasetDir, 'metadataFile', metadataFile, ...
    'splitSource', dataset.report.splitSource, 'requested', dataset.report.requested, ...
    'achieved', dataset.report.achieved, 'patientsPerSplit', dataset.report.patientsPerSplit, ...
    'numFeatureFailures', numel(failures), 'seed', cfg.dataset.randomSeed, ...
    'viewPositions', {cfg.dataset.viewPositions});
model.testEvaluation = evaluation;
modelDir = fileparts(opts.ModelFile);
if exist(modelDir, 'dir') ~= 7
    mkdir(modelDir);
end
save(opts.ModelFile, 'model', '-v7');
note(sprintf('Model saved to %s', opts.ModelFile));

% ---- 8. Save evaluation --------------------------------------------------------------
resultsDir = opts.ResultsDir;
if isempty(resultsDir)
    resultsDir = fullfile(projectRoot(), 'results', ['evaluation_' datestr(now, 'yyyymmdd_HHMMSS')]);
end
exportEvaluation(evaluation, resultsDir);
writeSplitFile(fullfile(resultsDir, 'dataset_split.csv'), dataset, ok);
writeFailures(fullfile(resultsDir, 'skipped_images.csv'), failures);
note(sprintf('Evaluation results saved to %s', resultsDir));
report(1, 'Training and evaluation finished.');

model.file = opts.ModelFile;
result.status = 'completed';
result.model = model;
result.evaluation = evaluation;
result.modelFile = opts.ModelFile;
result.resultsDir = resultsDir;
result.log = logLines(:);

    % ---------------------------------------------------------------- helpers
    function stop = report(fraction, message)
        stop = false;
        if ~isempty(progress)
            stop = progress(fraction, message);
            if isempty(stop)
                stop = false;
            end
        end
    end

    function note(messages)
        if ischar(messages)
            messages = {messages};
        end
        for i = 1:numel(messages)
            logLines{end + 1} = messages{i}; %#ok<AGROW>
            logMessage('INFO', '%s', messages{i});
        end
    end
end

% =========================================================================
function result = cancelResult(result, logLines)
result.status = 'cancelled';
result.log = [logLines(:); {'Training was cancelled by the user. No model was saved.'}];
logMessage('INFO', 'Training cancelled by the user.');
end

function file = findMetadataFile(datasetDir, cfg)
for k = 1:numel(cfg.dataset.metadataFileNames)
    candidate = fullfile(datasetDir, cfg.dataset.metadataFileNames{k});
    if exist(candidate, 'file') == 2
        file = candidate;
        return;
    end
end
error('CXR:missingMetadata', ['Metadata CSV not found in %s. Expected one of: %s. Download it ' ...
    'from https://nihcc.app.box.com/v/ChestXray-NIHCC.'], datasetDir, ...
    strjoin(cfg.dataset.metadataFileNames, ', '));
end

function t = kernelScaleText(model)
if strcmp(model.kernel, 'rbf')
    t = sprintf(', KernelScale %.3g', model.kernelScale);
else
    t = '';
end
end

function writeSplitFile(file, dataset, ok)
fid = fopen(file, 'w');
if fid < 0
    return;
end
fprintf(fid, 'image,patient_id,view,split,dataset_label,finding_labels,features_ok\n');
for k = 1:numel(dataset.imageName)
    fprintf(fid, '%s,%d,%s,%s,%s,"%s",%d\n', dataset.imageName{k}, dataset.patientId(k), ...
        dataset.viewPosition{k}, dataset.split{k}, dataset.label{k}, dataset.findingLabels{k}, ok(k));
end
fclose(fid);
end

function writeFailures(file, failures)
fid = fopen(file, 'w');
if fid < 0
    return;
end
fprintf(fid, 'image,error_id,message\n');
for k = 1:numel(failures)
    fprintf(fid, '%s,%s,"%s"\n', failures(k).name, failures(k).identifier, ...
        strrep(failures(k).message, '"', ''''));
end
fclose(fid);
end
