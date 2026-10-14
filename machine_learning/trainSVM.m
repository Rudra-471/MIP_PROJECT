function model = trainSVM(XTrain, yTrain, XVal, yVal, cfg, progressFcn)
%TRAINSVM Train the Normal/Abnormal SVM with validation-based model selection.
%   model = trainSVM(XTrain, yTrain, XVal, yVal, cfg, progressFcn)
%     XTrain, XVal - N x F feature matrices (F = numel(cfg.features.names))
%     yTrain, yVal - N x 1 cellstr labels from cfg.svm.classNames
%     progressFcn  - optional @(fraction, message)
%
%   Procedure (the test set is never used here)
%     1. Validate the data: matching sizes, finite values, known labels,
%        both classes present with at least cfg.svm.minTrainPerClass
%        training and cfg.svm.minValidationPerClass validation samples.
%     2. Z-score standardisation with the TRAINING mean and standard
%        deviation (standardizeFeatures). The same parameters are applied
%        to validation data now and to every new image later.
%     3. Class imbalance (cfg.svm.balanceWeights): 'Prior','uniform'. fitcsvm
%        normalises the observation weights of each class to sum to its
%        prior, so with uniform priors both classes carry the same total
%        weight in the SVM loss regardless of how many samples they have.
%        (Explicit inverse-frequency 'Weights' alone would NOT work: with the
%        default empirical prior fitcsvm renormalises them back.)
%     4. Model selection on the patient-wise VALIDATION set: every kernel in
%        cfg.svm.kernels ('linear', 'rbf') and every BoxConstraint (and
%        KernelScale for rbf) is trained on the training set and scored by
%        validation balanced accuracy. Ties -> simpler model (linear,
%        smaller BoxConstraint).
%     5. Final model: refit with the selected hyper-parameters on training +
%        validation data (cfg.svm.refitOnTrainVal), with standardisation
%        recomputed on that data.
%
%   The returned struct is self-contained (classifier, feature names and
%   order, standardisation, class labels, pipeline configuration). It is
%   saved as models/trainedModel.mat by runTrainingWorkflow.

if nargin < 6
    progressFcn = [];
end
classNames = cfg.svm.classNames;
positiveClass = cfg.svm.positiveClass;
numFeatures = numel(cfg.features.names);

validateTrainingData(XTrain, yTrain, 'training', cfg.svm.minTrainPerClass, numFeatures, classNames);
validateTrainingData(XVal, yVal, 'validation', cfg.svm.minValidationPerClass, numFeatures, classNames);

[ZTrain, stdTrain] = standardizeFeatures(XTrain);
ZVal = standardizeFeatures(XVal, stdTrain);

% ---- Candidate grid ----------------------------------------------------------
candidates = struct('kernel', {}, 'boxConstraint', {}, 'kernelScale', {});
for k = 1:numel(cfg.svm.kernels)
    kernel = lower(cfg.svm.kernels{k});
    for C = cfg.svm.boxConstraints
        if strcmp(kernel, 'rbf')
            for s = cfg.svm.kernelScales * sqrt(numFeatures)
                candidates(end + 1) = struct('kernel', kernel, 'boxConstraint', C, 'kernelScale', s); %#ok<AGROW>
            end
        else
            candidates(end + 1) = struct('kernel', kernel, 'boxConstraint', C, 'kernelScale', 1); %#ok<AGROW>
        end
    end
end

selection = struct('kernel', {}, 'boxConstraint', {}, 'kernelScale', {}, ...
                   'valBalancedAccuracy', {}, 'valAccuracy', {}, 'status', {});
best = 0;
bestScore = -Inf;
for k = 1:numel(candidates)
    c = candidates(k);
    entry = struct('kernel', c.kernel, 'boxConstraint', c.boxConstraint, ...
                   'kernelScale', c.kernelScale, 'valBalancedAccuracy', NaN, ...
                   'valAccuracy', NaN, 'status', 'ok');
    try
        svm = fitSvm(ZTrain, yTrain, c, cfg);
        tmp = struct('classifier', svm, 'positiveClass', positiveClass, 'classNames', {classNames});
        predicted = svmPredict(tmp, ZVal);
        m = evaluateModel(yVal, predicted, positiveClass, classNames);
        entry.valBalancedAccuracy = m.balancedAccuracy;
        entry.valAccuracy = m.accuracy;
        if m.balancedAccuracy > bestScore + 1e-12
            bestScore = m.balancedAccuracy;
            best = k;
        end
    catch fitError
        entry.status = ['failed: ' fitError.message];
        logMessage('WARN', 'SVM candidate %s C=%g scale=%.3g failed: %s', c.kernel, ...
            c.boxConstraint, c.kernelScale, fitError.message);
    end
    selection(end + 1) = entry; %#ok<AGROW>
    if ~isempty(progressFcn)
        progressFcn(k / (numel(candidates) + 1), sprintf('Model selection %d / %d (%s, C = %g)', ...
            k, numel(candidates), c.kernel, c.boxConstraint));
    end
end
if best == 0
    error('CXR:trainingFailed', 'Every SVM candidate failed to train. See logs/app.log for details.');
end
chosen = candidates(best);

% ---- Final model -------------------------------------------------------------
if cfg.svm.refitOnTrainVal
    XFinal = [XTrain; XVal];
    yFinal = [yTrain(:); yVal(:)];
else
    XFinal = XTrain;
    yFinal = yTrain(:);
end
[ZFinal, stdFinal] = standardizeFeatures(XFinal);
try
    svm = fitSvm(ZFinal, yFinal, chosen, cfg);
catch fitError
    error('CXR:trainingFailed', 'Training the final SVM failed: %s', fitError.message);
end
if ~isempty(progressFcn)
    progressFcn(1, 'Final model trained');
end

model = struct();
model.formatVersion   = 2;
model.classifier      = compactIfPossible(svm);
model.kernel          = chosen.kernel;
model.boxConstraint   = chosen.boxConstraint;
model.kernelScale     = chosen.kernelScale;
model.featureNames    = cfg.features.names;
model.standardization = stdFinal;
model.classNames      = classNames;
model.positiveClass   = positiveClass;
model.pipelineConfig  = cfg;
model.selection       = selection;
model.bestValidationBalancedAccuracy = bestScore;
model.trainingInfo = struct( ...
    'trainedOn', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'environment', runtimeDescription(), ...
    'numTrain', numel(yTrain), 'numValidation', numel(yVal), ...
    'numFinalFit', numel(yFinal), 'refitOnTrainVal', cfg.svm.refitOnTrainVal, ...
    'trainClassCounts', classCounts(yTrain, classNames), ...
    'validationClassCounts', classCounts(yVal, classNames), ...
    'balanceWeights', cfg.svm.balanceWeights, ...
    'constantFeatures', {cfg.features.names(stdFinal.constant)});
if any(stdFinal.constant)
    logMessage('WARN', 'Constant feature(s) in training data: %s', ...
        strjoin(cfg.features.names(stdFinal.constant), ', '));
end
end

% =========================================================================
function validateTrainingData(X, y, setName, minPerClass, numFeatures, classNames)
y = y(:);
if isempty(X) || size(X, 1) ~= numel(y)
    error('CXR:insufficientData', 'The %s set is empty or its feature matrix and labels differ in length.', setName);
end
if size(X, 2) ~= numFeatures
    error('CXR:featureDefinition', 'The %s set has %d features; %d are expected.', setName, size(X, 2), numFeatures);
end
if any(~isfinite(X(:)))
    error('CXR:nonFiniteFeature', 'The %s set contains NaN or Inf feature values.', setName);
end
if ~iscellstr(y) || any(~ismember(y, classNames))
    error('CXR:invalidLabels', 'The %s labels must be one of: %s.', setName, strjoin(classNames, ', '));
end
counts = classCounts(y, classNames);
if any(counts == 0)
    error('CXR:singleClass', ['The %s set contains only one class (%s). Both Normal and ' ...
        'Abnormal images are required.'], setName, strjoin(classNames(counts > 0), ', '));
end
if any(counts < minPerClass)
    error('CXR:insufficientData', ['The %s set has too few samples (%d Normal, %d Abnormal); ' ...
        'at least %d per class are required. Increase the subset size.'], ...
        setName, counts(1), counts(2), minPerClass);
end
end

function counts = classCounts(y, classNames)
counts = zeros(1, numel(classNames));
for c = 1:numel(classNames)
    counts(c) = nnz(strcmp(y, classNames{c}));
end
end

function svm = fitSvm(Z, y, candidate, cfg)
args = {'KernelFunction', candidate.kernel, 'BoxConstraint', candidate.boxConstraint, ...
        'ClassNames', cfg.svm.classNames, 'Standardize', false};
if strcmp(candidate.kernel, 'rbf')
    args = [args, {'KernelScale', candidate.kernelScale}];
end
if cfg.svm.balanceWeights
    args = [args, {'Prior', 'uniform'}];   % equal total weight per class (see header)
end
svm = fitcsvm(Z, y(:), args{:});
end

function c = compactIfPossible(svm)
try
    c = compact(svm);
catch
    c = svm;
end
end

function txt = runtimeDescription()
if isOctaveRuntime()
    txt = ['GNU Octave ' OCTAVE_VERSION];
else
    txt = ['MATLAB ' version];
end
end
