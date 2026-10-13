function seg = segmentLungs(img, cfg)
%SEGMENTLUNGS Approximate classical lung-field segmentation of a frontal chest X-ray.
%   seg = segmentLungs(img, cfg) where img is the preprocessed (denoised)
%   grayscale image in [0,1]. Segmentation deliberately works on the
%   denoised image and NOT on the display-enhanced image, so the lung mask
%   does not change when a user explores enhancement settings.
%
%   Output struct
%     thresholdMask - raw "dark = air-filled" binary map of the chosen threshold
%     initialMask   - candidate lung components selected from thresholdMask
%                     (input of morphologicalProcessing)
%     status        - 'ok' | 'failed'
%     message       - explanation, especially when status = 'failed'
%     info          - polarityInverted, sensitivity, usedGlobalGate,
%                     globalLevel, numRegions, score, areaFraction
%
%   Method (no single global threshold is assumed to work for every image)
%     1. Contrast stretching normalises the intensity range.
%     2. Polarity check: in a standard radiograph the mediastinum (centre
%        strip) is brighter than the lung fields on either side. If the
%        centre is darker, the image is treated as inverted (MONOCHROME1-
%        style) and complemented for segmentation only.
%     3. Gaussian smoothing suppresses rib / vessel texture.
%     4. Global Otsu threshold (graythresh) from the central image region
%        gives a coarse "dark region" gate.
%     5. Adaptive local thresholds (adaptthresh, several sensitivities)
%        compensate for uneven exposure; each is tried with and without the
%        global gate.
%     6. Air outside the body touches the image border and is removed
%        (imclearborder on an eroded copy, then grown back).
%     7. Connected components (bwconncomp + regionprops) are filtered by
%        area and centroid position; the largest valid component on each
%        side of the image is kept (approximate right / left lung).
%     8. A plausibility score (two regions, total area, left/right
%        symmetry) picks the best candidate. If no candidate is plausible,
%        status = 'failed' and the mask is empty - nothing is invented.
%
%   Limitations: this is a heuristic. It is not validated against
%   annotated lung masks, and it can fail on rotated images, very dense
%   opacities, lateral views, or images with large external objects.

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
p = cfg.segment;
img = im2double(img);
[h, w] = size(img);
numPixels = h * w;

seg = struct();
seg.thresholdMask = false(h, w);
seg.initialMask   = false(h, w);
seg.status  = 'failed';
seg.message = '';
seg.info = struct('polarityInverted', false, 'sensitivity', NaN, 'usedGlobalGate', false, ...
                  'globalLevel', NaN, 'numRegions', 0, 'score', -Inf, 'areaFraction', 0);

normalized = enhanceImage(img, 'stretch', cfg);
if std(normalized(:)) < p.minContrast
    seg.message = 'The image has almost no contrast, so no lung region can be identified.';
    return;
end

% 2) Polarity: compare the mediastinal strip with the lateral lung bands
rows = max(1, round(0.25 * h)):max(1, round(0.70 * h));
centreCols = max(1, round(0.45 * w)):max(1, round(0.55 * w));
lateralCols = [max(1, round(0.20 * w)):round(0.35 * w), round(0.65 * w):min(w, round(0.80 * w))];
centreMean  = mean(mean(normalized(rows, centreCols)));
lateralMean = mean(mean(normalized(rows, lateralCols)));
if centreMean < lateralMean
    normalized = 1 - normalized;
    seg.info.polarityInverted = true;
end

% 3) Smoothing
smoothed = imgaussfilt(normalized, p.smoothingSigma);

% 4) Global Otsu gate computed on the central part of the image
cRows = max(1, round(0.15 * h)):max(1, round(0.85 * h));
cCols = max(1, round(0.15 * w)):max(1, round(0.85 * w));
globalLevel = graythresh(smoothed(cRows, cCols));
darkGlobal  = ~imbinarize(smoothed, globalLevel);
gates = {darkGlobal, true(h, w)};
seg.info.globalLevel = globalLevel;

% adaptthresh needs an odd neighbourhood size
nbh = 2 * floor(p.neighborhoodFrac * [h w] / 2) + 1;

bestScore = -Inf;
for g = 1:numel(gates)
    for s = p.sensitivities
        localLevel = adaptthresh(smoothed, s, 'ForegroundPolarity', 'dark', ...
                                 'NeighborhoodSize', nbh);
        darkLocal = ~imbinarize(smoothed, localLevel);
        thresholdMask = darkLocal & gates{g};

        candidate = removeOutsideAir(thresholdMask, p.borderClearRadius);
        [candidate, numRegions] = selectLungComponents(candidate, p);
        score = plausibilityScore(candidate, numRegions, numPixels, w, p);

        if score > bestScore
            bestScore = score;
            seg.initialMask   = candidate;
            seg.thresholdMask = thresholdMask;
            seg.info.sensitivity    = s;
            seg.info.usedGlobalGate = (g == 1);
            seg.info.numRegions     = numRegions;
            seg.info.score          = score;
        end
    end
end

seg.info.areaFraction = nnz(seg.initialMask) / numPixels;
if ~any(seg.initialMask(:))
    seg.message = ['No lung-like region was found. The image may not be a frontal chest ' ...
                   'X-ray, or its contrast/exposure is unusual.'];
    return;
end
seg.status = 'ok';
seg.message = sprintf('%d candidate lung region(s), %.1f %% of the image (sensitivity %.2f%s).', ...
    seg.info.numRegions, 100 * seg.info.areaFraction, seg.info.sensitivity, ...
    ternary(seg.info.polarityInverted, ', inverted polarity', ''));
end

% =========================================================================
function mask = removeOutsideAir(mask, radius)
% Erode to cut thin bridges between the lungs and the air around the body,
% drop everything that still touches the border, then grow the survivors
% back inside the original mask.
se = strel('disk', radius, 0);
markers = imclearborder(imerode(mask, se));
mask = imdilate(markers, se) & mask;
end

function [selected, numRegions] = selectLungComponents(mask, p)
[h, w] = size(mask);
numPixels = h * w;
selected = false(h, w);
numRegions = 0;
cc = bwconncomp(mask, 8);
if cc.NumObjects == 0
    return;
end
props = regionprops(cc, 'Area', 'Centroid');
areas = [props.Area];
centroids = reshape([props.Centroid], 2, []).';
cx = centroids(:, 1).' / w;
cy = centroids(:, 2).' / h;
valid = areas >= p.minComponentFrac * numPixels & areas <= p.maxComponentFrac * numPixels & ...
        cx >= p.centralBand(1) & cx <= p.centralBand(2) & ...
        cy >= p.verticalBand(1) & cy <= p.verticalBand(2);
for side = 1:2
    if side == 1
        onSide = valid & cx < 0.5;
    else
        onSide = valid & cx >= 0.5;
    end
    if any(onSide)
        idx = find(onSide);
        [~, k] = max(areas(idx));
        selected(cc.PixelIdxList{idx(k)}) = true;
        numRegions = numRegions + 1;
    end
end
end

function score = plausibilityScore(mask, numRegions, numPixels, w, p)
if numRegions == 0
    score = -Inf;
    return;
end
areaFrac = nnz(mask) / numPixels;
lo = p.targetAreaFrac(1);
hi = p.targetAreaFrac(2);
if areaFrac < lo
    areaPenalty = (lo - areaFrac) / lo;
elseif areaFrac > hi
    areaPenalty = (areaFrac - hi) / hi;
else
    areaPenalty = 0;
end
half = floor(w / 2);
leftArea  = nnz(mask(:, 1:half));
rightArea = nnz(mask(:, half + 1:end));
symmetry  = min(leftArea, rightArea) / max(max(leftArea, rightArea), 1);
score = 2 * (numRegions == 2) + symmetry - 3 * areaPenalty + areaFrac;
end

function out = ternary(condition, a, b)
if condition
    out = a;
else
    out = b;
end
end
