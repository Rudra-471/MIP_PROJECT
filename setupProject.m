function root = setupProject()
%SETUPPROJECT Add the project folders to the MATLAB path.
%   root = setupProject() adds every source folder (paths relative to this
%   file, nothing hard-coded) and returns the project root. main.m calls it
%   automatically; call it yourself before using functions from the
%   command line, e.g. runTrainingWorkflow or predictImage.

root = fileparts(mfilename('fullpath'));
folders = {'app', 'pipeline', 'preprocessing', 'segmentation', 'features', ...
           'machine_learning', 'utils'};
for k = 1:numel(folders)
    addpath(fullfile(root, folders{k}));
end
addpath(root);
end
