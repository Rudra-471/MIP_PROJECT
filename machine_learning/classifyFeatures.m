function [labels, scores] = classifyFeatures(X, model)
%CLASSIFYFEATURES Predict Normal/Abnormal for raw feature vectors.
%   [labels, scores] = classifyFeatures(X, model)
%     X      - N x F raw features in model.featureNames order
%     labels - N x 1 cellstr predicted class
%     scores - SVM decision values for model.positiveClass. They are NOT
%              probabilities and are not calibrated; the application never
%              presents them as a confidence percentage.
%   The stored training standardisation is applied before prediction.

validateModel(model);
if size(X, 2) ~= numel(model.featureNames)
    error('CXR:featureDefinition', 'The model expects %d features but %d were given.', ...
        numel(model.featureNames), size(X, 2));
end
if any(~isfinite(X(:)))
    error('CXR:nonFiniteFeature', 'Cannot classify feature vectors containing NaN or Inf.');
end
Z = standardizeFeatures(X, model.standardization);
try
    [labels, scores] = svmPredict(model, Z);
catch predictError
    error('CXR:predictionFailed', 'SVM prediction failed: %s', predictError.message);
end
end
