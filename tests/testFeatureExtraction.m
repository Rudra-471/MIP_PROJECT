function results = testFeatureExtraction()
%TESTFEATUREEXTRACTION Unit tests for extractFeatures and its helpers.

cfg = appConfig();
results = struct('name', {}, 'status', {}, 'message', {});
img = makeChestPhantom(256, 11);
mask = false(256);
mask(60:200, 40:110) = true;

results(end+1) = runCase('feature vector has 10 values in the documented order', @() checkDims(img, mask, cfg));
results(end+1) = runCase('feature names match appConfig and the table', @() checkNames(img, mask, cfg));
results(end+1) = runCase('intensity features match direct computation', @() checkIntensity(img, mask, cfg));
results(end+1) = runCase('only ROI pixels are used', @() checkRoiOnly(img, mask, cfg));
results(end+1) = runCase('GLCM features are in their valid ranges', @() checkGlcmRanges(img, mask, cfg));
results(end+1) = runCase('identical input gives identical features', @() checkDeterministic(img, mask, cfg));
results(end+1) = runCase('omitted mask = whole image', @() checkWholeImage(img, cfg));
results(end+1) = runCase('empty ROI is rejected', ...
    @() expectError(@() extractFeatures(img, false(256), cfg), 'CXR:emptyROI'));
results(end+1) = runCase('mask of wrong size is rejected', ...
    @() expectError(@() extractFeatures(img, true(100), cfg), 'CXR:invalidMask'));
results(end+1) = runCase('non-binary mask is rejected', ...
    @() expectError(@() extractFeatures(img, 2 * double(mask), cfg), 'CXR:invalidMask'));
results(end+1) = runCase('constant image -> undefined correlation is reported', ...
    @() expectError(@() extractFeatures(0.5 * ones(64), [], cfg), 'CXR:nonFiniteFeature'));
results(end+1) = runCase('image with NaN values is rejected', @() checkNanImage(cfg));
end

% =========================================================================
function checkDims(img, mask, cfg)
[f, ~, d] = extractFeatures(img, mask, cfg);
assert(isequal(size(f), [1 10]), 'expected 1 x 10, got %s', mat2str(size(f)));
assert(all(isfinite(f)), 'features must be finite');
assert(d.numRoiPixels == nnz(mask), 'ROI pixel count wrong');
end

function checkNames(img, mask, cfg)
expected = {'Mean', 'Std', 'Variance', 'Min', 'Max', 'Entropy', ...
            'Contrast', 'Correlation', 'Energy', 'Homogeneity'};
assert(isequal(cfg.features.names, expected), 'appConfig feature order changed');
[f, t] = extractFeatures(img, mask, cfg);
if isstruct(t)
    names = {t.Feature};
    values = [t.Value];
else
    names = t.Feature.';
    values = t.Value.';
end
assert(isequal(names(:).', expected), 'table feature names differ');
assert(isequal(values, f), 'table values differ from the vector');
end

function checkIntensity(img, mask, cfg)
f = extractFeatures(img, mask, cfg);
p = img(mask);
expected = [mean(p), std(p), var(p), min(p), max(p), entropy(p)];
assert(max(abs(f(1:6) - expected)) < 1e-10, 'intensity features differ');
assert(abs(f(3) - f(2) ^ 2) < 1e-12, 'variance must equal std^2');
end

function checkRoiOnly(img, mask, cfg)
a = extractFeatures(img, mask, cfg);
changed = img;
changed(~mask) = rand(nnz(~mask), 1);   % change pixels outside the ROI only
b = extractFeatures(changed, mask, cfg);
assert(isequal(a, b), 'pixels outside the ROI influenced the features');
end

function checkGlcmRanges(img, mask, cfg)
f = extractFeatures(img, mask, cfg);
assert(f(7) >= 0, 'contrast must be >= 0');
assert(f(8) >= -1 - 1e-9 && f(8) <= 1 + 1e-9, 'correlation must be in [-1,1]');
assert(f(9) > 0 && f(9) <= 1, 'energy must be in (0,1]');
assert(f(10) > 0 && f(10) <= 1, 'homogeneity must be in (0,1]');
end

function checkDeterministic(img, mask, cfg)
assert(isequal(extractFeatures(img, mask, cfg), extractFeatures(img, mask, cfg)), 'not deterministic');
end

function checkWholeImage(img, cfg)
[a, ~, d] = extractFeatures(img, [], cfg);
b = extractFeatures(img, true(size(img)), cfg);
assert(d.usedWholeImage && isequal(a, b), 'empty mask must mean whole image');
end

function checkNanImage(cfg)
img = rand(64);
img(5, 5) = NaN;
expectError(@() extractFeatures(img, [], cfg), 'CXR:invalidImage');
end
