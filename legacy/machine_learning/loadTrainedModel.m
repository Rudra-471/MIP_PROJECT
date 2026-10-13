function model = loadTrainedModel(modelFile)
%LOADTRAINEDMODEL Load and validate models/trainedModel.mat.
%   Throws 'CXR:missingModel' with instructions if the model has not been
%   trained yet or the file is not a valid model.

if nargin < 1 || isempty(modelFile)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    modelFile = fullfile(projectRoot, 'models', 'trainedModel.mat');
end
modelFile = char(modelFile);
if exist(modelFile, 'file') ~= 2
    error('CXR:missingModel', ...
        ['No trained model found at %s.\nThe model still needs to be trained: ' ...
         'prepare the dataset and run "trainModel" (see README.md).'], modelFile);
end
try
    loaded = load(modelFile, 'model');
catch loadError
    error('CXR:missingModel', 'Could not load %s: %s', modelFile, loadError.message);
end
required = {'svm', 'mu', 'sigma', 'plattA', 'plattB', 'featureNames', 'positiveClass', 'cfg'};
if ~isfield(loaded, 'model') || ~all(isfield(loaded.model, required))
    error('CXR:missingModel', ...
        '%s is not a valid model file. Re-run trainModel to create it.', modelFile);
end
model = loaded.model;
end
