function metrics = evaluateModel(trueLabels, predictedLabels, positiveClass, classNames)
%EVALUATEMODEL Binary classification metrics with an explicit positive class.
%   metrics = evaluateModel(trueLabels, predictedLabels, positiveClass, classNames)
%   Defaults: positiveClass = 'Abnormal', classNames = {'Normal','Abnormal'}.
%
%   With TP/TN/FP/FN counted for the POSITIVE class (Abnormal):
%     Accuracy    = (TP + TN) / (TP + TN + FP + FN)
%     Precision   = TP / (TP + FP)
%     Sensitivity = TP / (TP + FN)        (= recall)
%     Specificity = TN / (TN + FP)
%     F1-score    = 2 * Precision * Recall / (Precision + Recall)
%     Balanced accuracy = (Sensitivity + Specificity) / 2
%   A metric whose denominator is zero is undefined: it is returned as NaN
%   and listed in metrics.undefined (never silently reported as 0 or 1).
%
%   metrics.confusionMatrix: rows = true class, columns = predicted class,
%   both in classNames order (computed with confusionmat).

if nargin < 3 || isempty(positiveClass)
    positiveClass = 'Abnormal';
end
if nargin < 4 || isempty(classNames)
    classNames = {'Normal', 'Abnormal'};
end
trueLabels = cellstr(trueLabels);
predictedLabels = cellstr(predictedLabels);
trueLabels = trueLabels(:);
predictedLabels = predictedLabels(:);
if isempty(trueLabels)
    error('CXR:emptyEvaluation', 'There are no samples to evaluate.');
end
if numel(trueLabels) ~= numel(predictedLabels)
    error('CXR:emptyEvaluation', 'True and predicted label lists differ in length (%d vs %d).', ...
        numel(trueLabels), numel(predictedLabels));
end
if numel(classNames) ~= 2 || ~any(strcmp(classNames, positiveClass))
    error('CXR:invalidOption', 'classNames must contain two classes including the positive class.');
end
unknown = setdiff(unique([trueLabels; predictedLabels]), classNames);
if ~isempty(unknown)
    error('CXR:invalidLabels', 'Unknown label(s) in evaluation: %s.', strjoin(unknown, ', '));
end

cm = confusionmat(trueLabels, predictedLabels, 'Order', classNames);
pos = find(strcmp(classNames, positiveClass));
neg = 3 - pos;
TP = cm(pos, pos);
FN = cm(pos, neg);
FP = cm(neg, pos);
TN = cm(neg, neg);

metrics = struct();
metrics.classNames      = classNames;
metrics.positiveClass   = positiveClass;
metrics.negativeClass   = classNames{neg};
metrics.confusionMatrix = cm;
metrics.TP = TP;
metrics.TN = TN;
metrics.FP = FP;
metrics.FN = FN;
metrics.numSamples = numel(trueLabels);
metrics.trueClassCounts = sum(cm, 2).';
metrics.predictedClassCounts = sum(cm, 1);
metrics.undefined = {};

metrics.accuracy    = ratio(TP + TN, TP + TN + FP + FN);
metrics.precision   = ratio(TP, TP + FP);
metrics.sensitivity = ratio(TP, TP + FN);
metrics.recall      = metrics.sensitivity;
metrics.specificity = ratio(TN, TN + FP);
if isnan(metrics.precision) || isnan(metrics.recall)
    metrics.f1 = NaN;
else
    metrics.f1 = ratio(2 * metrics.precision * metrics.recall, metrics.precision + metrics.recall);
end
metrics.balancedAccuracy = (metrics.sensitivity + metrics.specificity) / 2;

names = {'accuracy', 'precision', 'sensitivity', 'specificity', 'f1'};
for k = 1:numel(names)
    if isnan(metrics.(names{k}))
        metrics.undefined{end + 1} = names{k};
    end
end
end

function r = ratio(a, b)
if b == 0
    r = NaN;
else
    r = a / b;
end
end
