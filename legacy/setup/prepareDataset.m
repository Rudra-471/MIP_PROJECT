function prepareDataset(actualmedDir, ieeeDir, datasetDir)
%PREPAREDATASET Copy the reference dataset images into dataset/Normal and dataset/Abnormal.
%   prepareDataset(actualmedDir, ieeeDir) reads setup/dataset_manifest.csv
%   and copies the listed images from local clones of two public GitHub
%   chest X-ray repositories into the project's dataset folder:
%
%     actualmedDir : clone of https://github.com/agchung/Actualmed-COVID-chestxray-dataset
%     ieeeDir      : clone of https://github.com/ieee8023/covid-chestxray-dataset
%
%   The manifest lists 270 frontal (PA/AP) images, ONE image per patient
%   (so no patient appears in both the training and the test set):
%     Normal   (135) : Actualmed "No finding" + ieee8023 "No Finding"
%     Abnormal (135) : Actualmed "COVID-19" + an evenly spaced sample of
%                      ieee8023 pneumonia / COVID-19 / TB / other findings
%   The selection rules are implemented in setup/make_manifest.py.
%
%   Copied files are named <source>_<patientId>_<originalName>.
%   See README.md ("Dataset setup") for the git commands and alternatives.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 3 || isempty(datasetDir)
    datasetDir = fullfile(projectRoot, 'dataset');
end
sourceDirs = struct('actualmed', actualmedDir, 'ieee8023', ieeeDir);
for name = fieldnames(sourceDirs)'
    if exist(sourceDirs.(name{1}), 'dir') ~= 7
        error('CXR:missingDataset', 'Source folder for %s not found: %s', name{1}, sourceDirs.(name{1}));
    end
end

fid = fopen(fullfile(projectRoot, 'setup', 'dataset_manifest.csv'), 'r');
if fid < 0
    error('CXR:missingDataset', 'setup/dataset_manifest.csv not found.');
end
cleaner = onCleanup(@() fclose(fid));
columns = textscan(fid, '%s %s %s %s %s %s %s', 'Delimiter', ',', 'HeaderLines', 1);
[className, source, patientId, sourceFile] = deal(columns{1:4});

copied = 0;
missing = {};
for k = 1:numel(className)
    src = fullfile(sourceDirs.(source{k}), sourceFile{k});
    [~, baseName, ext] = fileparts(sourceFile{k});
    targetDir = fullfile(datasetDir, className{k});
    if exist(targetDir, 'dir') ~= 7
        mkdir(targetDir);
    end
    target = fullfile(targetDir, sprintf('%s_%s_%s%s', source{k}, patientId{k}, baseName, lower(ext)));
    if exist(src, 'file') ~= 2
        missing{end+1} = src; %#ok<AGROW>
        continue;
    end
    if exist(target, 'file') ~= 2
        copyfile(src, target);
    end
    copied = copied + 1;
end
fprintf('Dataset ready: %d of %d images in %s\n', copied, numel(className), datasetDir);
fprintf('  Normal:   %d\n  Abnormal: %d\n', nnz(strcmp(className, 'Normal')), nnz(strcmp(className, 'Abnormal')));
if ~isempty(missing)
    warning('CXR:missingFiles', '%d listed files were not found, e.g. %s', numel(missing), missing{1});
end
end
