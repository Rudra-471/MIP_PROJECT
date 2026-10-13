function model = loadTrainedModel(modelFile)
%LOADTRAINEDMODEL Load and validate models/trainedModel.mat.
%   model = loadTrainedModel() / loadTrainedModel(modelFile)
%   Throws CXR:missingModel when no model has been trained yet and
%   CXR:invalidModel when the file is not a complete model.

if nargin < 1 || isempty(modelFile)
    modelFile = defaultModelFile();
end
modelFile = char(modelFile);
if exist(modelFile, 'file') ~= 2
    error('CXR:missingModel', ['No trained model found (%s). Train the model on the ' ...
        'Dataset & Training page (or run runTrainingWorkflow) first.'], modelFile);
end
try
    loaded = load(modelFile, 'model');
catch loadError
    error('CXR:invalidModel', 'Could not load %s: %s', modelFile, loadError.message);
end
if ~isfield(loaded, 'model')
    error('CXR:invalidModel', '%s does not contain a variable named "model".', modelFile);
end
model = loaded.model;
validateModel(model);
model.file = modelFile;
end
