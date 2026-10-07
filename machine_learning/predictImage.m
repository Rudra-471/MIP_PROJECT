function [prediction, pipeline] = predictImage(imgOrPath, model)
%PREDICTIMAGE Run the full pipeline on one X-ray and classify it.
%   [prediction, pipeline] = predictImage(imgOrPath) loads the default model
%   (models/trainedModel.mat). A model struct or a .mat path can be passed
%   as the second argument. prediction contains label ('Normal'/'Abnormal'),
%   svmScore, probAbnormal and confidence (see classifyFeatures); pipeline
%   contains every intermediate image (see runPipeline).
%
%   The output is a MODEL PREDICTION for educational/research use only and
%   is not a medical diagnosis.

if nargin < 2 || isempty(model)
    model = loadTrainedModel();
elseif ischar(model) || isstring(model)
    model = loadTrainedModel(model);
end
pipeline = runPipeline(imgOrPath, model.cfg);
prediction = classifyFeatures(pipeline.features, model);
prediction.label = prediction.label{1};
end
