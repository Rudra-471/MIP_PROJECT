function results = runPipelineTests(imageDir)
%RUNPIPELINETESTS Functional + error-handling tests for the pipeline.
%   results = runPipelineTests() runs the full pipeline on up to 5 real
%   images per class from dataset/ and checks error handling for invalid
%   input. Works in MATLAB and (with tests/octave_compat) in GNU Octave.
%   Prints PASS/FAIL per test and returns a struct array of results.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setupProject();
if nargin < 1
    imageDir = fullfile(projectRoot, 'dataset');
end
cfg = getConfig();
tmpDir = tempname();
mkdir(tmpDir);
cleaner = onCleanup(@() rmdirQuiet(tmpDir));
results = struct('name', {}, 'passed', {}, 'message', {});

% ---- 1. Real images from both classes -------------------------------------
for className = {'Normal', 'Abnormal'}
    files = dir(fullfile(imageDir, className{1}));
    files = files(~[files.isdir] & ~strncmp({files.name}, '.', 1));
    for k = 1:min(5, numel(files))
        path = fullfile(imageDir, className{1}, files(k).name);
        results(end+1) = runTest(sprintf('pipeline %s/%s', className{1}, files(k).name), ...
            @() checkPipeline(runPipeline(path, cfg), cfg)); %#ok<AGROW>
    end
end

% ---- 2. Input variations (built from a real image) --------------------------
realFiles = dir(fullfile(imageDir, 'Normal'));
realFiles = realFiles(~[realFiles.isdir] & ~strncmp({realFiles.name}, '.', 1));
if ~isempty(realFiles)
    realImg = readXrayImage(fullfile(imageDir, 'Normal', realFiles(1).name), cfg);
    if size(realImg, 3) == 3
        grayImg = rgb2gray(realImg);
        rgbImg = realImg;
    else
        grayImg = realImg;
        rgbImg = cat(3, realImg, realImg, realImg);
    end
    grayImg = im2uint8(grayImg);
    rgbImg = im2uint8(rgbImg);
    results(end+1) = runTest('grayscale uint8 input', @() checkPipeline(runPipeline(grayImg, cfg), cfg));
    results(end+1) = runTest('RGB uint8 input',       @() checkPipeline(runPipeline(rgbImg, cfg), cfg));
    results(end+1) = runTest('uint16 input',          @() checkPipeline(runPipeline(im2uint16(grayImg), cfg), cfg));
    results(end+1) = runTest('small non-square input', ...
        @() checkPipeline(runPipeline(imresize(grayImg, [300 420]), cfg), cfg));
    pngFile = fullfile(tmpDir, 'xray.png');
    bmpFile = fullfile(tmpDir, 'xray.bmp');
    jpgFile = fullfile(tmpDir, 'xray.JPG');
    imwrite(grayImg, pngFile);
    imwrite(grayImg, bmpFile);
    imwrite(grayImg, jpgFile, 'Quality', 95);
    results(end+1) = runTest('read PNG file',             @() assert(~isempty(readXrayImage(pngFile, cfg))));
    results(end+1) = runTest('read BMP file',             @() assert(~isempty(readXrayImage(bmpFile, cfg))));
    results(end+1) = runTest('read upper-case JPG file',  @() assert(~isempty(readXrayImage(jpgFile, cfg))));
    results(end+1) = runTest('gamma correction range', @() checkGamma(grayImg, cfg));
    results(end+1) = runTest('enhancement methods', @() checkEnhancement(grayImg, cfg));
end

% ---- 3. Error handling -------------------------------------------------------
corruptFile = fullfile(tmpDir, 'corrupt.png');
fid = fopen(corruptFile, 'w'); fwrite(fid, uint8(1:200)); fclose(fid);
textFile = fullfile(tmpDir, 'notes.txt');
fid = fopen(textFile, 'w'); fprintf(fid, 'not an image'); fclose(fid);

results(end+1) = runTest('no image selected', @() expectError(@() readXrayImage('', cfg), 'CXR:noImage'));
results(end+1) = runTest('cancelled file dialog', @() expectError(@() readXrayImage(0, cfg), 'CXR:noImage'));
results(end+1) = runTest('missing file', @() expectError(@() readXrayImage(fullfile(tmpDir, 'nope.png'), cfg), 'CXR:fileNotFound'));
results(end+1) = runTest('invalid format', @() expectError(@() readXrayImage(textFile, cfg), 'CXR:invalidFormat'));
results(end+1) = runTest('corrupted image', @() expectError(@() readXrayImage(corruptFile, cfg), 'CXR:corruptImage'));
results(end+1) = runTest('empty segmentation (blank image)', ...
    @() expectError(@() runPipeline(0.5 * ones(512, 512), cfg), 'CXR:emptySegmentation'));
results(end+1) = runTest('feature extraction with empty mask', ...
    @() expectError(@() extractFeatures(rand(64), rand(64), false(64), cfg), 'CXR:emptySegmentation'));
results(end+1) = runTest('missing dataset', ...
    @() expectError(@() buildFeatureDataset(fullfile(tmpDir, 'noDataset'), fullfile(tmpDir, 'f.mat'), cfg), 'CXR:missingDataset'));
results(end+1) = runTest('missing model', ...
    @() expectError(@() loadTrainedModel(fullfile(tmpDir, 'noModel.mat')), 'CXR:missingModel'));
results(end+1) = runTest('invalid gamma', ...
    @() expectError(@() gammaCorrection(rand(10), -1, cfg), 'CXR:invalidOption'));
results(end+1) = runTest('toolbox check', @() assert(checkToolboxes()));

% ---- 4. Metric computation on a known example --------------------------------
results(end+1) = runTest('evaluation metrics', @checkMetrics);

numPassed = nnz([results.passed]);
fprintf('\n%d / %d tests passed.\n', numPassed, numel(results));
end

% =============================================================================
function r = runTest(name, fn)
try
    fn();
    r = struct('name', name, 'passed', true, 'message', '');
    fprintf('PASS  %s\n', name);
catch err
    r = struct('name', name, 'passed', false, 'message', err.message);
    fprintf('FAIL  %s: %s\n', name, err.message);
end
end

function expectError(fn, expectedId)
try
    fn();
catch err
    assert(strcmp(err.identifier, expectedId), ...
        'Expected error %s but got %s (%s)', expectedId, err.identifier, err.message);
    return;
end
error('test:noError', 'Expected error %s, but no error was thrown.', expectedId);
end

function checkPipeline(result, cfg)
assert(isequal(size(result.preprocessed.denoised), cfg.imageSize), 'wrong preprocessed size');
assert(all(result.enhanced(:) >= 0 & result.enhanced(:) <= 1), 'enhanced out of range');
assert(islogical(result.lungMask) && any(result.lungMask(:)), 'empty lung mask');
areaFraction = nnz(result.lungMask) / numel(result.lungMask);
assert(areaFraction > 0.03 && areaFraction < 0.6, 'implausible lung area %.3f', areaFraction);
assert(numel(result.features) == numel(cfg.featureNames), 'wrong feature count');
assert(all(isfinite(result.features)), 'non-finite features');
assert(isequal(size(result.overlay), [cfg.imageSize 3]), 'wrong overlay size');
end

function checkGamma(img, cfg)
img = im2double(img);
bright = gammaCorrection(img, 0.5, cfg);
dark = gammaCorrection(img, 2.0, cfg);
assert(mean(bright(:)) > mean(img(:)) && mean(dark(:)) < mean(img(:)), 'gamma direction wrong');
same = gammaCorrection(img, 1.0, cfg);
assert(max(abs(same(:) - img(:))) < 1e-6, 'gamma = 1 must not change the image');
end

function checkEnhancement(img, cfg)
pre = preprocessImage(img, cfg);
for method = {'clahe', 'histeq', 'imadjust'}
    out = enhanceImage(pre.denoised, method{1}, cfg);
    assert(isequal(size(out), size(pre.denoised)), 'size changed by %s', method{1});
end
comparison = compareEnhancement(pre.denoised, cfg);
assert(numel(comparison) == 4, 'comparison should contain 4 entries');
end

function checkMetrics()
yTrue = {'Normal'; 'Normal'; 'Normal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Abnormal'};
yPred = {'Normal'; 'Normal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Abnormal'; 'Normal'};
m = evaluateModel(yTrue, yPred, 'Abnormal', {'Normal', 'Abnormal'}, [0.1 0.2 0.6 0.9 0.8 0.7 0.3]);
assert(isequal(m.confusionMatrix, [2 1; 1 3]), 'confusion matrix wrong');
assert(abs(m.accuracy - 5/7) < 1e-12 && abs(m.precision - 3/4) < 1e-12, 'accuracy/precision wrong');
assert(abs(m.sensitivity - 3/4) < 1e-12 && abs(m.specificity - 2/3) < 1e-12, 'sens/spec wrong');
assert(abs(m.f1 - 0.75) < 1e-12, 'F1 wrong');
assert(abs(m.auc - 11/12) < 1e-12, 'AUC wrong');
end

function rmdirQuiet(folder)
try
    rmdir(folder, 's');
catch
end
end
