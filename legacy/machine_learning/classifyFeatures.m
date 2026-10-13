function prediction = classifyFeatures(featureMatrix, model)
%CLASSIFYFEATURES Apply the trained SVM to one or more feature vectors.
%   prediction = classifyFeatures(featureMatrix, model) returns a struct:
%     label        - N x 1 cell: 'Normal' or 'Abnormal' (model prediction)
%     svmScore     - raw SVM decision value for the Abnormal class
%     probAbnormal - Platt-calibrated probability of the Abnormal class
%     confidence   - calibrated probability of the predicted class
%
%   The probability comes from the trained model itself: Platt scaling
%   parameters were fitted on out-of-fold cross-validation scores during
%   training (see trainModel / fitPlattScaling).

numSamples = size(featureMatrix, 1);
if size(featureMatrix, 2) ~= numel(model.featureNames)
    error('CXR:featureExtraction', 'Expected %d features, got %d.', ...
        numel(model.featureNames), size(featureMatrix, 2));
end
Z = (featureMatrix - repmat(model.mu, numSamples, 1)) ./ repmat(model.sigma, numSamples, 1);
if numSamples == 1 && isOctaveRuntime()
    % Octave statistics 1.7.0 crashes in predict() for a single row (test
    % runs only); predicting a duplicated row gives the same score.
    [~, scores] = predict(model.svm, [Z; Z]);
    scores = scores(1, :);
else
    [~, scores] = predict(model.svm, Z);
end
svmScore = scores(:, strcmp(cellstr(model.svm.ClassNames), model.positiveClass));

probAbnormal = 1 ./ (1 + exp(model.plattA * svmScore + model.plattB));
label = repmat({'Normal'}, numSamples, 1);
label(probAbnormal >= 0.5) = {'Abnormal'};
confidence = probAbnormal;
confidence(probAbnormal < 0.5) = 1 - probAbnormal(probAbnormal < 0.5);

prediction = struct('label', {label}, 'svmScore', svmScore, ...
                    'probAbnormal', probAbnormal, 'confidence', confidence);
end
