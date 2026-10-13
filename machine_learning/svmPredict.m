function [labels, scores] = svmPredict(model, Z)
%SVMPREDICT Low-level SVM prediction on ALREADY STANDARDISED features.
%   [labels, scores] = svmPredict(model, Z) returns N x 1 cellstr labels and
%   the raw (uncalibrated) SVM decision value for model.positiveClass.
%   Use classifyFeatures for raw features; it applies the standardisation.

if isOctaveRuntime() && size(Z, 1) == 1
    % Octave's statistics package (test runtime only) crashes when
    % predicting a single row; predicting a duplicated row is equivalent.
    [labels, s] = predict(model.classifier, [Z; Z]);
    labels = labels(1);
    s = s(1, :);
else
    [labels, s] = predict(model.classifier, Z);
end
labels = cellstr(labels);
labels = labels(:);
classOrder = cellstr(model.classifier.ClassNames);
scores = s(:, strcmp(classOrder, model.positiveClass));
end
