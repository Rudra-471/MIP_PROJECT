function result = predictImage(source, model)
%PREDICTIMAGE Classify one chest X-ray as Normal or Abnormal with a trained model.
%   result = predictImage(filePathOrArray, model)
%   result = predictImage(filePathOrArray)       % loads models/trainedModel.mat
%
%   The image is processed with model.pipelineConfig - the configuration
%   the model was trained with - so the features are computed exactly as
%   during training, independent of any GUI settings.
%
%   result fields
%     label        'Normal' | 'Abnormal' (model prediction, not a diagnosis)
%     score        uncalibrated SVM decision value for the Abnormal class
%                  (> 0 -> Abnormal side of the decision boundary). It is
%                  not a probability or confidence.
%     features     1 x F feature vector, featureNames
%     analysis     full pipeline output (images, masks, ...)
%
%   Throws CXR:missingModel, CXR:segmentationFailed, CXR:predictionFailed, ...

if nargin < 2 || isempty(model)
    model = loadTrainedModel();
elseif ischar(model) || isstring(model)
    model = loadTrainedModel(model);
end
validateModel(model);
analysis = runImagePipeline(source, model.pipelineConfig);
[labels, scores] = classifyFeatures(analysis.features, model);

result = struct();
result.label        = labels{1};
result.score        = scores(1);
result.features     = analysis.features;
result.featureNames = model.featureNames;
result.analysis     = analysis;
end
