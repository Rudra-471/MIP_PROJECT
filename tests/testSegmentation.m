function results = testSegmentation()
%TESTSEGMENTATION Unit tests: lung segmentation, morphological operations,
%empty/failed masks, and the step-wise analysis pipeline.
%   Synthetic phantoms test the code paths; the real NIH samples (when
%   present) check that a plausible two-region mask is produced on real
%   radiographs. No accuracy claim is derived from these few images.

cfg = appConfig();
results = struct('name', {}, 'status', {}, 'message', {});

phantom = makeChestPhantom(512, 7);
results(end+1) = runCase('phantom: two plausible lung regions are found', @() checkPhantom(phantom, cfg));
results(end+1) = runCase('inverted polarity is detected', @() checkInverted(phantom, cfg));
results(end+1) = runCase('uniform image -> segmentation failure, empty mask', @() checkUniform(cfg));
results(end+1) = runCase('opening removes small noise objects', @() checkOpening(cfg));
results(end+1) = runCase('closing bridges a small gap', @() checkClosing(cfg));
results(end+1) = runCase('hole filling fills enclosed holes', @() checkFilling(cfg));
results(end+1) = runCase('erosion shrinks and dilation grows the mask', @() checkErodeDilate(cfg));
results(end+1) = runCase('morphology on an empty mask is safe', @() checkEmptyMorph(cfg));
results(end+1) = runCase('refineLungMask: empty mask -> failed', @() checkRefineEmpty(cfg));
results(end+1) = runCase('refineLungMask: one region -> partial', @() checkRefinePartial(cfg));
results(end+1) = runCase('refineLungMask: keeps one region per side', @() checkRefineSides(cfg));
results(end+1) = runCase('pipeline steps enforce their prerequisites', @() checkStepOrder(phantom, cfg));
results(end+1) = runCase('re-running enhancement keeps the lung mask', @() checkInvalidation(phantom, cfg));
results(end+1) = runCase('failed segmentation: whole-image ROI only on request', @() checkWholeImageFallback(cfg));

samples = sampleImages();
if isempty(samples)
    results(end+1) = runCase('real NIH samples: plausible lung masks', @() skip('no sample images'));
else
    results(end+1) = runCase('real NIH samples: plausible lung masks', @() checkReal(samples, cfg));
end
end

% =========================================================================
function checkPhantom(img, cfg)
seg = segmentLungs(img, cfg);
assert(strcmp(seg.status, 'ok'), 'segmentation failed: %s', seg.message);
morph = morphologicalProcessing(seg.initialMask, cfg);
[mask, r] = refineLungMask(morph.output, cfg);
assert(strcmp(r.status, 'ok'), 'refinement status %s: %s', r.status, r.message);
assert(r.numRegions == 2, 'expected two regions');
[x, y] = meshgrid(linspace(0, 1, 512), linspace(0, 1, 512));
truth = ((x - 0.31) / 0.13) .^ 2 + ((y - 0.45) / 0.27) .^ 2 <= 1 | ...
        ((x - 0.69) / 0.13) .^ 2 + ((y - 0.45) / 0.27) .^ 2 <= 1;
dice = 2 * nnz(mask & truth) / (nnz(mask) + nnz(truth));
assert(dice > 0.8, 'Dice overlap with the phantom lungs is only %.2f', dice);
end

function checkInverted(img, cfg)
seg = segmentLungs(1 - img, cfg);
assert(seg.info.polarityInverted, 'inverted image not detected');
assert(strcmp(seg.status, 'ok'), 'inverted phantom should still be segmented');
end

function checkUniform(cfg)
seg = segmentLungs(0.5 * ones(256), cfg);
assert(strcmp(seg.status, 'failed') && ~any(seg.initialMask(:)), 'uniform image must fail with an empty mask');
assert(~isempty(seg.message), 'a failure message is required');
end

function checkOpening(cfg)
mask = false(200);
mask(50:150, 40:90) = true;
mask(20, 20) = true;           % single-pixel noise
mask(180:182, 180:182) = true; % tiny blob
m = morphologicalProcessing(mask, cfg);
assert(~m.opened(20, 20) && ~any(any(m.opened(180:182, 180:182))), 'small objects must be removed');
assert(nnz(m.opened(50:150, 40:90)) > 0.9 * 101 * 51, 'the large region must survive opening');
end

function checkClosing(cfg)
mask = false(200);
mask(50:150, 40:99) = true;
mask(50:150, 104:160) = true;   % 4-pixel gap
m = morphologicalProcessing(mask, cfg);
cc = bwconncomp(m.closed);
assert(cc.NumObjects == 1, 'closing must bridge the gap (got %d objects)', cc.NumObjects);
end

function checkFilling(cfg)
mask = false(200);
mask(40:160, 40:160) = true;
mask(90:110, 90:110) = false;   % enclosed hole (larger than the closing disk)
m = morphologicalProcessing(mask, cfg);
assert(all(all(m.filled(90:110, 90:110))), 'the enclosed hole must be filled');
end

function checkErodeDilate(cfg)
mask = false(200);
mask(40:160, 40:160) = true;
m = morphologicalProcessing(mask, cfg);
assert(m.counts.eroded < m.counts.filled, 'erosion must shrink the mask');
assert(m.counts.dilated > m.counts.eroded, 'dilation must grow the mask');
end

function checkEmptyMorph(cfg)
m = morphologicalProcessing(false(100), cfg);
assert(m.isEmpty && ~any(m.output(:)), 'empty input must give an empty, flagged output');
end

function checkRefineEmpty(cfg)
[mask, r] = refineLungMask(false(100), cfg);
assert(strcmp(r.status, 'failed') && ~any(mask(:)), 'empty mask must be reported as failed');
end

function checkRefinePartial(cfg)
mask = false(200);
mask(40:160, 20:80) = true;
[~, r] = refineLungMask(mask, cfg);
assert(strcmp(r.status, 'partial') && r.numRegions == 1, 'one region must be flagged as partial');
end

function checkRefineSides(cfg)
mask = false(200);
mask(40:160, 20:80) = true;     % left, large
mask(40:60, 85:95) = true;      % left, small
mask(40:160, 120:180) = true;   % right
[final, r] = refineLungMask(mask, cfg);
assert(r.numRegions == 2 && ~any(any(final(40:60, 85:95))), 'only the largest region per side may be kept');
end

function checkStepOrder(img, cfg)
a = createAnalysis(im2uint8(img), cfg);
expectError(@() runAnalysisStep(a, 'enhance', cfg), 'CXR:stepOrder');
expectError(@() runAnalysisStep(a, 'features', cfg), 'CXR:stepOrder');
a = runAnalysisStep(a, 'preprocess', cfg);
expectError(@() runAnalysisStep(a, 'morphology', cfg), 'CXR:stepOrder');
assert(analysisPrerequisites(a, 'enhance') && analysisPrerequisites(a, 'segment'), 'enhance/segment should be allowed');
end

function checkInvalidation(img, cfg)
a = runImagePipeline(im2uint8(img), cfg);
assert(a.done.features && ~isempty(a.overlay), 'full pipeline should finish');
cfg2 = cfg;
cfg2.enhance.method = 'clahe';
cfg2.enhance.gamma = 0.8;
b = runAnalysisStep(a, 'enhance', cfg2);
assert(b.done.segment && b.done.morphology && isequal(b.finalMask, a.finalMask), 'mask must be kept');
assert(~b.done.features && isempty(b.features), 'features must be invalidated');
assert(~isempty(b.overlay), 'overlay must be recomputed for the new enhancement');
b = runAnalysisStep(b, 'preprocess', cfg2);
assert(~b.done.enhance && ~b.done.segment && isempty(b.finalMask), 'preprocess must clear everything below it');
end

function checkWholeImageFallback(cfg)
img = 0.5 * ones(256) + 0.05 * rand(256);
a = createAnalysis(img, cfg);
a = runAnalysisStep(a, 'preprocess', cfg);
a = runAnalysisStep(a, 'enhance', cfg);
a = runAnalysisStep(a, 'segment', cfg);
assert(~strcmp(a.seg.status, 'ok'), 'noise image should fail segmentation');
expectError(@() runAnalysisStep(a, 'features', cfg, false), 'CXR:segmentationFailed');
b = runAnalysisStep(a, 'features', cfg, true);
assert(strcmp(b.roiType, 'wholeImage') && numel(b.features) == 10, 'whole-image ROI expected');
expectError(@() runImagePipeline(img, cfg), 'CXR:segmentationFailed');
end

function checkReal(samples, cfg)
for k = 1:numel(samples)
    a = runImagePipeline(samples{k}, cfg);
    assert(a.refine.numRegions == 2, '%s: expected two lung regions', samples{k});
    assert(a.refine.areaFraction > 0.08 && a.refine.areaFraction < 0.45, '%s: implausible lung area', samples{k});
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
