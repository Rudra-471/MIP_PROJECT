function file = defaultModelFile()
%DEFAULTMODELFILE Location of the saved model: <project>/models/trainedModel.mat
file = fullfile(projectRoot(), 'models', 'trainedModel.mat');
end
