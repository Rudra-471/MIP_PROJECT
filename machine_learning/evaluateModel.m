function metrics = evaluateModel(trueLabels, predictedLabels, positiveClass, classNames, positiveProb)
%EVALUATEMODEL Classification metrics for a binary Normal/Abnormal model.
%   metrics = evaluateModel(trueLabels, predictedLabels, positiveClass, classNames, positiveProb)
%
%   With "positive" = Abnormal:
%     Accuracy    = (TP + TN) / N         overall fraction of correct predictions
%     Precision   = TP / (TP + FP)        of the images predicted Abnormal, the
%                                         fraction that really are Abnormal
%     Recall /
%     Sensitivity = TP / (TP + FN)        ability to correctly identify abnormal cases
%     Specificity = TN / (TN + FP)        ability to correctly identify normal cases
%     F1-score    = 2PR / (P + R)         balance between precision and recall
%     Balanced accuracy = (Sensitivity + Specificity) / 2
%     ROC AUC     (only when positiveProb is supplied)
%
%   metrics.confusionMatrix rows = true class, columns = predicted class,
%   both ordered as classNames (default {'Normal','Abnormal'}).

if nargin < 3 || isempty(positiveClass)
    positiveClass = 'Abnormal';
end
if nargin < 4 || isempty(classNames)
    classNames = {'Normal', 'Abnormal'};
end
trueLabels = cellstr(trueLabels);
predictedLabels = cellstr(predictedLabels);
if numel(trueLabels) ~= numel(predictedLabels) || isempty(trueLabels)
    error('CXR:evaluation', 'True and predicted label lists must be non-empty and of equal length.');
end

numClasses = numel(classNames);
cm = zeros(numClasses);
for i = 1:numClasses
    for j = 1:numClasses
        cm(i, j) = nnz(strcmp(trueLabels, classNames{i}) & strcmp(predictedLabels, classNames{j}));
    end
end

isPosTrue = strcmp(trueLabels, positiveClass);
isPosPred = strcmp(predictedLabels, positiveClass);
TP = nnz(isPosTrue & isPosPred);
TN = nnz(~isPosTrue & ~isPosPred);
FP = nnz(~isPosTrue & isPosPred);
FN = nnz(isPosTrue & ~isPosPred);

metrics = struct();
metrics.classNames      = classNames;
metrics.positiveClass   = positiveClass;
metrics.confusionMatrix = cm;
metrics.TP = TP; metrics.TN = TN; metrics.FP = FP; metrics.FN = FN;
metrics.numSamples  = numel(trueLabels);
metrics.accuracy    = safeDivide(TP + TN, numel(trueLabels));
metrics.precision   = safeDivide(TP, TP + FP);
metrics.recall      = safeDivide(TP, TP + FN);
metrics.sensitivity = metrics.recall;
metrics.specificity = safeDivide(TN, TN + FP);
metrics.f1          = safeDivide(2 * metrics.precision * metrics.recall, ...
                                 metrics.precision + metrics.recall);
metrics.balancedAccuracy = (metrics.sensitivity + metrics.specificity) / 2;
if nargin >= 5 && ~isempty(positiveProb)
    metrics.auc = rocAuc(positiveProb(:), isPosTrue(:));
else
    metrics.auc = NaN;
end
end

function r = safeDivide(a, b)
if b == 0
    r = NaN;
else
    r = a / b;
end
end

function auc = rocAuc(scores, isPositive)
% Area under the ROC curve via the rank-sum (Mann-Whitney U) statistic,
% with ties counted as one half.
numPos = nnz(isPositive);
numNeg = numel(isPositive) - numPos;
if numPos == 0 || numNeg == 0
    auc = NaN;
    return;
end
[sortedScores, order] = sort(scores);
ranks = zeros(size(scores));
k = 1;
while k <= numel(sortedScores)
    tieEnd = k;
    while tieEnd < numel(sortedScores) && sortedScores(tieEnd + 1) == sortedScores(k)
        tieEnd = tieEnd + 1;
    end
    ranks(order(k:tieEnd)) = (k + tieEnd) / 2;
    k = tieEnd + 1;
end
auc = (sum(ranks(isPositive)) - numPos * (numPos + 1) / 2) / (numPos * numNeg);
end
