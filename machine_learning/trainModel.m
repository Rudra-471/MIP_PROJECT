function [model, testMetrics] = trainModel(varargin)
%TRAINMODEL Train and evaluate the SVM Normal/Abnormal classifier.
%   [model, testMetrics] = trainModel() uses the default project layout:
%     dataset/Normal, dataset/Abnormal  -> input images
%     features.mat                       -> cached feature dataset
%     models/trainedModel.mat            -> trained model
%     results/                           -> metrics, confusion matrix, predictions
%
%   Name/value options: 'DatasetDir', 'FeaturesFile', 'ModelFile',
%   'ResultsDir', 'ForceRecompute' (true to ignore the features.mat cache).
%
%   Steps
%     1. Feature extraction for every image (buildFeatureDataset, cached)
%     2. Stratified 80/20 train/test split (fixed random seed)
%     3. Z-score standardisation using TRAINING-set statistics only
%     4. RBF-kernel SVM; BoxConstraint and KernelScale chosen by stratified
%        5-fold cross-validation on the training set (balanced accuracy)
%     5. Platt scaling fitted on out-of-fold CV scores -> calibrated
%        probability P(Abnormal); the final decision is P(Abnormal) >= 0.5
%     6. Final SVM trained on the whole training set
%     7. Evaluation on the untouched test set (evaluateModel)

projectRoot = fileparts(fileparts(mfilename('fullpath')));
parser = inputParser;
parser.addParameter('DatasetDir',   fullfile(projectRoot, 'dataset'));
parser.addParameter('FeaturesFile', fullfile(projectRoot, 'features.mat'));
parser.addParameter('ModelFile',    fullfile(projectRoot, 'models', 'trainedModel.mat'));
parser.addParameter('ResultsDir',   fullfile(projectRoot, 'results'));
parser.addParameter('ForceRecompute', false);
parser.parse(varargin{:});
opts = parser.Results;

checkToolboxes(true);
cfg = getConfig();

% 1) Features -------------------------------------------------------------
data = buildFeatureDataset(opts.DatasetDir, opts.FeaturesFile, cfg, opts.ForceRecompute);
X = data.featureMatrix;
y = data.labels(:);
for c = 1:numel(cfg.classNames)
    if nnz(strcmp(y, cfg.classNames{c})) < 10
        error('CXR:missingDataset', ...
            'Class "%s" has fewer than 10 usable images - add more images before training.', ...
            cfg.classNames{c});
    end
end

% 2) Stratified train/test split -------------------------------------------
isTest = stratifiedSplit(y, cfg.testFraction, cfg.randomSeed);
XTrain = X(~isTest, :);  yTrain = y(~isTest);
XTest  = X(isTest, :);   yTest  = y(isTest);
fprintf('Train: %d images (%d Normal / %d Abnormal) | Test: %d images (%d Normal / %d Abnormal)\n', ...
    numel(yTrain), nnz(strcmp(yTrain, 'Normal')), nnz(strcmp(yTrain, 'Abnormal')), ...
    numel(yTest),  nnz(strcmp(yTest, 'Normal')),  nnz(strcmp(yTest, 'Abnormal')));

% 3) Standardisation (training statistics only - no test-set leakage) ------
mu = mean(XTrain, 1);
sigma = std(XTrain, 0, 1);
sigma(sigma == 0) = 1;
ZTrain = (XTrain - repmat(mu, size(XTrain, 1), 1)) ./ repmat(sigma, size(XTrain, 1), 1);
ZTest  = (XTest  - repmat(mu, size(XTest, 1), 1))  ./ repmat(sigma, size(XTest, 1), 1);

% 4) Hyper-parameter search with stratified k-fold CV ----------------------
foldId = stratifiedKFold(yTrain, cfg.cvFolds, cfg.randomSeed);
scaleGrid = cfg.svmScaleGrid * sqrt(size(X, 2));
cvResults = zeros(0, 4);   % [BoxConstraint KernelScale BalancedAcc Accuracy]
bestBalAcc = -Inf;
fprintf('Cross-validating %d hyper-parameter combinations...\n', numel(cfg.svmBoxGrid) * numel(scaleGrid));
for C = cfg.svmBoxGrid
    for kernelScale = scaleGrid
        oofScores = crossValidatedScores(ZTrain, yTrain, foldId, C, kernelScale, cfg);
        oofPred = repmat({'Normal'}, numel(yTrain), 1);
        oofPred(oofScores > 0) = {'Abnormal'};
        m = evaluateModel(yTrain, oofPred, cfg.positiveClass, cfg.classNames);
        cvResults(end+1, :) = [C, kernelScale, m.balancedAccuracy, m.accuracy]; %#ok<AGROW>
        if m.balancedAccuracy > bestBalAcc + 1e-12
            bestBalAcc = m.balancedAccuracy;
            best = struct('BoxConstraint', C, 'KernelScale', kernelScale, 'oofScores', oofScores);
        end
    end
end
fprintf('Best CV balanced accuracy %.3f (BoxConstraint = %g, KernelScale = %.3g)\n', ...
    bestBalAcc, best.BoxConstraint, best.KernelScale);

% 5) Platt scaling on out-of-fold scores -----------------------------------
[plattA, plattB] = fitPlattScaling(best.oofScores, strcmp(yTrain, cfg.positiveClass));

% 6) Final model on the full training set -----------------------------------
svm = trainSvm(ZTrain, yTrain, best.BoxConstraint, best.KernelScale, cfg);
model = struct();
model.svm            = compact(svm);
model.mu             = mu;
model.sigma          = sigma;
model.plattA         = plattA;
model.plattB         = plattB;
model.featureNames   = cfg.featureNames;
model.classNames     = cfg.classNames;
model.positiveClass  = cfg.positiveClass;
model.cfg            = cfg;
model.hyperparameters = rmfield(best, 'oofScores');

% 7) Evaluation on the held-out test set -------------------------------------
testPred = classifyFeatures(XTest, model);
testMetrics = evaluateModel(yTest, testPred.label, cfg.positiveClass, cfg.classNames, ...
                            testPred.probAbnormal);
cvPred = repmat({'Normal'}, numel(yTrain), 1);
cvProb = 1 ./ (1 + exp(plattA * best.oofScores + plattB));
cvPred(cvProb >= 0.5) = {'Abnormal'};
cvMetrics = evaluateModel(yTrain, cvPred, cfg.positiveClass, cfg.classNames, cvProb);

model.trainingInfo = struct( ...
    'trainedOn',     datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'environment',   runtimeDescription(), ...
    'numTrain',      numel(yTrain), ...
    'numTest',       numel(yTest), ...
    'numFailedImages', size(data.failedImages, 1), ...
    'cvResults',     cvResults, ...
    'cvMetrics',     cvMetrics, ...
    'testMetrics',   testMetrics);

modelDir = fileparts(opts.ModelFile);
if exist(modelDir, 'dir') ~= 7
    mkdir(modelDir);
end
save(opts.ModelFile, 'model', '-v7');
fprintf('Saved trained model to %s\n', opts.ModelFile);

saveEvaluationReport(opts.ResultsDir, model, testMetrics, cvMetrics, data, isTest, testPred);
printMetrics(testMetrics);
end

% =========================================================================
function svm = trainSvm(Z, y, boxConstraint, kernelScale, cfg)
svm = fitcsvm(Z, y, 'KernelFunction', cfg.svmKernel, ...
              'BoxConstraint', boxConstraint, 'KernelScale', kernelScale, ...
              'ClassNames', cfg.classNames);
end

function scores = crossValidatedScores(Z, y, foldId, boxConstraint, kernelScale, cfg)
% Out-of-fold SVM scores for the positive (Abnormal) class
scores = zeros(numel(y), 1);
for f = 1:max(foldId)
    inFold = foldId == f;
    svm = trainSvm(Z(~inFold, :), y(~inFold), boxConstraint, kernelScale, cfg);
    [~, s] = predict(svm, Z(inFold, :));
    scores(inFold) = s(:, strcmp(cellstr(svm.ClassNames), cfg.positiveClass));
end
end

function txt = runtimeDescription()
if isOctaveRuntime()
    txt = ['GNU Octave ' OCTAVE_VERSION];
else
    txt = ['MATLAB ' version];
end
end

function printMetrics(m)
fprintf('\n===== Held-out TEST set (%d images) =====\n', m.numSamples);
fprintf('Accuracy      : %6.2f %%\n', 100 * m.accuracy);
fprintf('Precision     : %6.2f %%\n', 100 * m.precision);
fprintf('Sensitivity   : %6.2f %%  (recall)\n', 100 * m.sensitivity);
fprintf('Specificity   : %6.2f %%\n', 100 * m.specificity);
fprintf('F1-score      : %6.2f %%\n', 100 * m.f1);
fprintf('ROC AUC       : %6.3f\n', m.auc);
fprintf('Confusion matrix (rows = true, cols = predicted; order Normal, Abnormal):\n');
disp(m.confusionMatrix);
end
