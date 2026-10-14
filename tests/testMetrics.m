function results = testMetrics()
%TESTMETRICS Unit tests for evaluateModel (hand-computed reference values).

results = struct('name', {}, 'status', {}, 'message', {});
results(end+1) = runCase('metrics on a known example', @checkKnown);
results(end+1) = runCase('positive class is Abnormal and explicit', @checkPositive);
results(end+1) = runCase('zero denominators are reported as undefined', @checkUndefined);
results(end+1) = runCase('perfect predictions', @checkPerfect);
results(end+1) = runCase('empty evaluation is rejected', ...
    @() expectError(@() evaluateModel({}, {}), 'CXR:emptyEvaluation'));
results(end+1) = runCase('length mismatch is rejected', ...
    @() expectError(@() evaluateModel({'Normal'}, {'Normal'; 'Abnormal'}), 'CXR:emptyEvaluation'));
results(end+1) = runCase('unknown labels are rejected', ...
    @() expectError(@() evaluateModel({'Normal'; 'Sick'}, {'Normal'; 'Normal'}), 'CXR:invalidLabels'));
end

function checkKnown()
yTrue = {'Normal'; 'Normal'; 'Normal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Abnormal'};
yPred = {'Normal'; 'Normal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Normal'};
m = evaluateModel(yTrue, yPred, 'Abnormal', {'Normal', 'Abnormal'});
assert(isequal(m.confusionMatrix, [2 1; 1 3]), 'confusion matrix wrong');
assert(m.TP == 3 && m.TN == 2 && m.FP == 1 && m.FN == 1, 'TP/TN/FP/FN wrong');
assert(abs(m.accuracy - 5/7) < 1e-12, 'accuracy wrong');
assert(abs(m.precision - 3/4) < 1e-12, 'precision wrong');
assert(abs(m.sensitivity - 3/4) < 1e-12 && abs(m.recall - 3/4) < 1e-12, 'sensitivity wrong');
assert(abs(m.specificity - 2/3) < 1e-12, 'specificity wrong');
assert(abs(m.f1 - 0.75) < 1e-12, 'F1 wrong');
assert(abs(m.balancedAccuracy - (3/4 + 2/3) / 2) < 1e-12, 'balanced accuracy wrong');
assert(m.numSamples == 7 && isequal(m.trueClassCounts, [3 4]), 'counts wrong');
end

function checkPositive()
m = evaluateModel({'Normal'; 'Abnormal'}, {'Abnormal'; 'Abnormal'});
assert(strcmp(m.positiveClass, 'Abnormal') && m.FP == 1 && m.TP == 1, 'default positive class must be Abnormal');
end

function checkUndefined()
% No predicted Abnormal -> precision 0/0; no true Abnormal -> sensitivity 0/0
m = evaluateModel({'Normal'; 'Normal'}, {'Normal'; 'Normal'});
assert(isnan(m.precision) && isnan(m.sensitivity) && isnan(m.f1), 'undefined metrics must be NaN');
assert(m.specificity == 1 && m.accuracy == 1, 'defined metrics must still be computed');
assert(all(ismember({'precision', 'sensitivity', 'f1'}, m.undefined)), 'undefined list incomplete');
end

function checkPerfect()
y = {'Normal'; 'Abnormal'; 'Abnormal'};
m = evaluateModel(y, y);
assert(m.accuracy == 1 && m.precision == 1 && m.sensitivity == 1 && m.specificity == 1 && m.f1 == 1, ...
    'perfect predictions must give 1 for every metric');
assert(isempty(m.undefined), 'nothing should be undefined');
end
