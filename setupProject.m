function projectRoot = setupProject()
%SETUPPROJECT Add all project folders to the MATLAB path.
%   projectRoot = setupProject() adds the project sub-folders to the path
%   (no hard-coded absolute paths: everything is relative to this file) and
%   returns the absolute path of the project root.
%
%   Run this once per MATLAB session before using any project function,
%   or simply call trainModel / ChestXrayApp via the scripts in this folder.

projectRoot = fileparts(mfilename('fullpath'));
subFolders = {'main', 'preprocessing', 'segmentation', 'features', ...
              'machine_learning', 'utils', 'setup'};
for k = 1:numel(subFolders)
    addpath(fullfile(projectRoot, subFolders{k}));
end
addpath(projectRoot);
end
