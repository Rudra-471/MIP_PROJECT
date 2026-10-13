function data = buildFeatureDataset(datasetDir, featuresFile, cfg, forceRecompute)
%BUILDFEATUREDATASET Extract features for every image in dataset/Normal and dataset/Abnormal.
%   data = buildFeatureDataset(datasetDir, featuresFile, cfg, forceRecompute)
%
%   Images are discovered automatically (no hard-coded file names): every
%   JPG/JPEG/PNG/BMP file inside <datasetDir>/<ClassName>/ is processed with
%   runPipeline (resize -> grayscale -> denoise -> enhance -> segment ->
%   morphology -> features). Images that fail (corrupted file, failed
%   segmentation, ...) are skipped and listed in data.failedImages.
%
%   The result is saved to featuresFile (features.mat) and re-used on the
%   next call as long as the image list and configuration are unchanged,
%   so feature extraction does not have to be repeated every time.
%
%   features.mat contains:
%     featureTable  - MATLAB table: one row per image, one column per
%                     feature, plus Label (categorical) and File columns
%     featureMatrix - N x F double matrix (same values, plain numeric)
%     labels        - N x 1 cell array of class names
%     featureNames, imageFiles (relative to datasetDir), failedImages, cfg

if nargin < 3 || isempty(cfg)
    cfg = getConfig();
end
if nargin < 4
    forceRecompute = false;
end

imageList = listDatasetImages(datasetDir, cfg);

if ~forceRecompute && exist(featuresFile, 'file') == 2
    cached = load(featuresFile);
    if isfield(cached, 'cfg') && isequal(cached.cfg, cfg) && ...
            isfield(cached, 'runtime') && strcmp(cached.runtime, runtimeName()) && ...
            isequal(sort(cached.allImageFiles(:)), sort(imageList.relativePath(:)))
        fprintf('Re-using cached features from %s (%d images).\n', featuresFile, numel(cached.labels));
        data = cached;
        return;
    end
    fprintf('Dataset or configuration changed - recomputing features.\n');
end

numImages = numel(imageList.relativePath);
numFeatures = numel(cfg.featureNames);
featureMatrix = nan(numImages, numFeatures);
succeeded = false(numImages, 1);
failedImages = cell(0, 2);
fprintf('Extracting features from %d images...\n', numImages);
tStart = tic;
for k = 1:numImages
    try
        result = runPipeline(imageList.fullPath{k}, cfg);
        featureMatrix(k, :) = result.features;
        succeeded(k) = true;
    catch pipelineError
        failedImages(end+1, :) = {imageList.relativePath{k}, pipelineError.message}; %#ok<AGROW>
        fprintf('  [skipped] %s: %s\n', imageList.relativePath{k}, pipelineError.message);
    end
    if mod(k, 25) == 0 || k == numImages
        fprintf('  %d / %d processed (%.0f s)\n', k, numImages, toc(tStart));
    end
end

data = struct();
data.featureMatrix = featureMatrix(succeeded, :);
data.labels        = imageList.label(succeeded);
data.imageFiles    = imageList.relativePath(succeeded);
data.allImageFiles = imageList.relativePath;
data.featureNames  = cfg.featureNames;
data.failedImages  = failedImages;
data.cfg           = cfg;
data.runtime       = runtimeName();
data.createdOn     = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if exist('array2table', 'file') == 2
    % Structured MATLAB table (not available in GNU Octave)
    featureTable = array2table(data.featureMatrix, 'VariableNames', cfg.featureNames);
    featureTable.Label = categorical(data.labels, cfg.classNames);
    featureTable.File  = data.imageFiles;
    data.featureTable  = featureTable;
end

fprintf('Feature extraction finished: %d succeeded, %d failed.\n', nnz(succeeded), size(failedImages, 1));
save(featuresFile, '-struct', 'data', '-v7');
fprintf('Saved features to %s\n', featuresFile);
end

function name = runtimeName()
% Features computed in Octave (test shims) are never re-used by MATLAB.
if isOctaveRuntime()
    name = 'Octave';
else
    name = 'MATLAB';
end
end

function imageList = listDatasetImages(datasetDir, cfg)
if exist(datasetDir, 'dir') ~= 7
    error('CXR:missingDataset', ...
        ['Dataset folder not found: %s\nCreate dataset/Normal and dataset/Abnormal ' ...
         'and add chest X-ray images (see README.md, section "Dataset setup").'], datasetDir);
end
relativePath = {};
fullPath = {};
label = {};
for c = 1:numel(cfg.classNames)
    className = cfg.classNames{c};
    classDir = fullfile(datasetDir, className);
    if exist(classDir, 'dir') ~= 7
        error('CXR:missingDataset', 'Class folder not found: %s (see README.md).', classDir);
    end
    entries = dir(classDir);
    entries = entries(~[entries.isdir]);
    names = sort({entries.name});
    for k = 1:numel(names)
        [~, ~, ext] = fileparts(names{k});
        if names{k}(1) == '.' || ~any(strcmpi(ext, cfg.supportedExtensions))
            continue;
        end
        relativePath{end+1, 1} = [className '/' names{k}]; %#ok<AGROW>
        fullPath{end+1, 1}     = fullfile(classDir, names{k}); %#ok<AGROW>
        label{end+1, 1}        = className; %#ok<AGROW>
    end
    if ~any(strcmp(label, className))
        error('CXR:missingDataset', ...
            'No images (JPG/JPEG/PNG/BMP) found in %s (see README.md).', classDir);
    end
end
imageList = struct('relativePath', {relativePath}, 'fullPath', {fullPath}, 'label', {label});
end
