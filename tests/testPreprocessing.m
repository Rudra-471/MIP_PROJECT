function results = testPreprocessing()
%TESTPREPROCESSING Unit tests: image validation, grayscale conversion, noise
%reduction, enhancement, gamma correction and histograms.
%   Uses synthetic arrays (software tests) and, when present, the real NIH
%   sample images in tests/data/nih_samples.

cfg = appConfig();
results = struct('name', {}, 'status', {}, 'message', {});
tmp = tempname();
mkdir(tmp);
cleaner = onCleanup(@() rmdirQuiet(tmp));

gray8 = im2uint8(makeChestPhantom(300, 3));
rgb8 = cat(3, gray8, gray8, gray8);

results(end+1) = runCase('RGB input is converted to grayscale', @() checkRgb(rgb8, gray8, cfg));
results(end+1) = runCase('grayscale uint8 input is handled', @() checkGray(gray8, cfg));
results(end+1) = runCase('uint16 and double inputs share one representation', @() checkClasses(gray8, cfg));
results(end+1) = runCase('aspect ratio is preserved when resizing', @() checkAspect(cfg));
results(end+1) = runCase('noise reduction: median removes impulse noise', @() checkMedian(cfg));
results(end+1) = runCase('noise reduction: gaussian and none', @() checkOtherNoise(cfg));
results(end+1) = runCase('noise reduction: unknown method is rejected', ...
    @() expectError(@() reduceNoise(rand(10), 'bilateral', cfg), 'CXR:invalidOption'));
results(end+1) = runCase('enhancement methods keep size and [0,1] range', @() checkEnhancement(gray8, cfg));
results(end+1) = runCase('contrast stretching widens a narrow intensity range', @() checkStretch(cfg));
results(end+1) = runCase('enhancement of a constant image does not fail', @() checkFlatEnhancement(cfg));
results(end+1) = runCase('gamma correction direction and identity', @() checkGamma(gray8, cfg));
results(end+1) = runCase('gamma outside the allowed range is rejected', ...
    @() expectError(@() applyGammaCorrection(rand(10), 10, cfg), 'CXR:invalidOption'));
results(end+1) = runCase('histogram data has correct bins and total count', @() checkHistogram(gray8));

% ---- image validation / invalid input ----------------------------------------
corrupt = fullfile(tmp, 'corrupt.png');
fid = fopen(corrupt, 'w'); fwrite(fid, uint8(1:200)); fclose(fid);
textFile = fullfile(tmp, 'notes.txt');
fid = fopen(textFile, 'w'); fprintf(fid, 'not an image'); fclose(fid);
pngFile = fullfile(tmp, 'xray.PNG');
imwrite(gray8, pngFile);
jpgFile = fullfile(tmp, 'xray.jpg');
imwrite(gray8, jpgFile, 'Quality', 95);
bmpFile = fullfile(tmp, 'xray.bmp');
imwrite(gray8, bmpFile);

results(end+1) = runCase('validateImage: nothing selected', @() expectError(@() validateImage('', cfg), 'CXR:noImage'));
results(end+1) = runCase('validateImage: cancelled dialog (0)', @() expectError(@() validateImage(0, cfg), 'CXR:noImage'));
results(end+1) = runCase('validateImage: missing file', ...
    @() expectError(@() validateImage(fullfile(tmp, 'none.png'), cfg), 'CXR:fileNotFound'));
results(end+1) = runCase('validateImage: unsupported format', @() expectError(@() validateImage(textFile, cfg), 'CXR:invalidFormat'));
results(end+1) = runCase('validateImage: corrupted image', @() expectError(@() validateImage(corrupt, cfg), 'CXR:corruptImage'));
results(end+1) = runCase('validateImage: too small', @() expectError(@() validateImage(uint8(ones(20)), cfg), 'CXR:invalidSize'));
results(end+1) = runCase('validateImage: 4-D array', @() expectError(@() validateImage(ones(80, 80, 2, 2), cfg), 'CXR:invalidFormat'));
results(end+1) = runCase('validateImage: NaN pixels', @() expectError(@() validateImage(nan(80), cfg), 'CXR:corruptImage'));
results(end+1) = runCase('validateImage: PNG/JPG/BMP files are read', @() checkFiles({pngFile, jpgFile, bmpFile}, cfg));

samples = sampleImages();
if isempty(samples)
    results(end+1) = runCase('real NIH sample images preprocess', @() skip('tests/data/nih_samples not found'));
else
    results(end+1) = runCase('real NIH sample images preprocess', @() checkRealSamples(samples, cfg));
end
end

% =========================================================================
function checkRgb(rgb8, gray8, cfg)
pre = preprocessImage(rgb8, cfg);
assert(ismatrix(pre.gray), 'grayscale output must be 2-D');
expected = im2double(gray8);
assert(max(abs(pre.gray(:) - expected(:))) < 1 / 255 + 1e-9, 'identical RGB channels must give the same gray image');
colour = rgb8;
colour(:, :, 1) = 255;
pre2 = preprocessImage(colour, cfg);
assert(ismatrix(pre2.gray) && isa(pre2.gray, 'double'), 'colour image must become 2-D double');
end

function checkGray(gray8, cfg)
pre = preprocessImage(gray8, cfg);
assert(isa(pre.denoised, 'double') && ismatrix(pre.denoised), 'output must be 2-D double');
assert(max(size(pre.denoised)) == cfg.preprocess.processingSize, 'longest side must equal processingSize');
assert(all(pre.denoised(:) >= 0 & pre.denoised(:) <= 1), 'range must be [0,1]');
assert(isequal(pre.original, gray8), 'the original image must be preserved unchanged');
end

function checkClasses(gray8, cfg)
a = preprocessImage(gray8, cfg);
b = preprocessImage(im2uint16(gray8), cfg);
c = preprocessImage(im2double(gray8), cfg);
assert(max(abs(a.resized(:) - b.resized(:))) < 1e-6, 'uint8 and uint16 inputs must give the same result');
assert(max(abs(a.resized(:) - c.resized(:))) < 1e-6, 'uint8 and double inputs must give the same result');
end

function checkAspect(cfg)
pre = preprocessImage(rand(300, 600), cfg);
assert(isequal(size(pre.resized), [256 512]), 'expected 256 x 512, got %s', mat2str(size(pre.resized)));
end

function checkMedian(cfg)
img = 0.5 * ones(64);
img(10, 10) = 1;            % impulse
img(40, 20) = 0;
out = reduceNoise(img, 'median', cfg);
assert(abs(out(10, 10) - 0.5) < 1e-12 && abs(out(40, 20) - 0.5) < 1e-12, 'impulses must be removed');
step = [zeros(64, 32), ones(64, 32)];
outStep = reduceNoise(step, 'median', cfg);
assert(isequal(outStep, step), 'median filtering must preserve a straight edge');
end

function checkOtherNoise(cfg)
img = rand(64);
g = reduceNoise(img, 'gaussian', cfg);
assert(std(g(:)) < std(img(:)), 'gaussian filtering must reduce noise variance');
assert(isequal(reduceNoise(img, 'none', cfg), img), '"none" must not change the image');
end

function checkEnhancement(gray8, cfg)
pre = preprocessImage(gray8, cfg);
for m = {'stretch', 'histeq', 'clahe'}
    out = enhanceImage(pre.denoised, m{1}, cfg);
    assert(isequal(size(out), size(pre.denoised)), 'size changed by %s', m{1});
    assert(all(out(:) >= 0 & out(:) <= 1), '%s output out of range', m{1});
end
expectError(@() enhanceImage(pre.denoised, 'magic', cfg), 'CXR:invalidOption');
end

function checkStretch(cfg)
img = 0.4 + 0.2 * rand(100);
out = enhanceImage(img, 'stretch', cfg);
assert(max(out(:)) - min(out(:)) > 0.95, 'stretched range must be close to [0,1]');
assert(corr(img(:), out(:)) > 0.95, 'stretching must preserve the intensity ordering');
end

function checkFlatEnhancement(cfg)
flat = 0.5 * ones(64);
for m = {'stretch', 'histeq', 'clahe'}
    out = enhanceImage(flat, m{1}, cfg);
    assert(all(isfinite(out(:))), '%s produced non-finite values', m{1});
end
end

function checkGamma(gray8, cfg)
img = im2double(gray8);
bright = applyGammaCorrection(img, 0.5, cfg);
dark = applyGammaCorrection(img, 2.0, cfg);
assert(mean(bright(:)) > mean(img(:)) && mean(dark(:)) < mean(img(:)), 'gamma direction wrong');
same = applyGammaCorrection(img, 1.0, cfg);
assert(isequal(same, img), 'gamma = 1 must not change the image');
v = applyGammaCorrection(0.25 * ones(4), 2, cfg);
assert(abs(v(1) - 0.0625) < 1e-6, 'gamma must implement out = in^gamma');
end

function checkHistogram(gray8)
h = computeHistogramData(gray8, 64);
assert(numel(h.counts) == 64 && numel(h.binCenters) == 64, 'expected 64 bins');
assert(sum(h.counts) == numel(gray8), 'counts must sum to the number of pixels');
assert(h.binCenters(1) == 0 && abs(h.binCenters(end) - 1) < 1e-12, 'bins must span [0,1]');
end

function checkFiles(files, cfg)
for k = 1:numel(files)
    [img, info] = validateImage(files{k}, cfg);
    assert(~isempty(img) && info.width == 300 && info.height == 300, 'could not read %s', files{k});
end
end

function checkRealSamples(samples, cfg)
for k = 1:numel(samples)
    [img, info] = validateImage(samples{k}, cfg);
    pre = preprocessImage(img, cfg);
    assert(info.width >= 64 && strcmp(info.colorType, 'grayscale'), 'unexpected image info');
    assert(max(size(pre.denoised)) == cfg.preprocess.processingSize, 'unexpected processing size');
end
end

function samples = sampleImages()
folder = fullfile(fileparts(mfilename('fullpath')), 'data', 'nih_samples');
files = dir(fullfile(folder, '*.png'));
samples = cellfun(@(n) fullfile(folder, n), {files.name}, 'UniformOutput', false);
end

function skip(message)
error('CXR:testSkipped', '%s', message);
end

function rmdirQuiet(folder)
try
    rmdir(folder, 's');
catch
end
end
