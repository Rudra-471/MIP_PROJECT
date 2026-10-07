function [lungMask, info] = segmentLung(img, cfg)
%SEGMENTLUNG Approximate classical lung-field segmentation of a chest X-ray.
%   [lungMask, info] = segmentLung(img, cfg) where img is the preprocessed
%   (normalised + denoised) grayscale image in [0,1]. Returns a logical mask
%   of the candidate lung regions BEFORE morphological refinement, and an
%   info struct describing how the mask was obtained.
%
%   Method (no single fixed threshold is assumed):
%     1. Gaussian smoothing suppresses rib/vessel texture so thresholding
%        responds to the large dark lung fields rather than to fine detail.
%     2. Global Otsu threshold (graythresh/imbinarize), computed on the
%        central part of the image only (so borders, collimation and labels do
%        not bias it), gives a coarse "dark = air-filled" map.
%     3. Adaptive (local) thresholding (adaptthresh) compensates for uneven
%        exposure across the film. Several sensitivities are tried, with and
%        without the global gate (low-contrast films can fail the global one).
%     4. Air OUTSIDE the body touches the image border; it is removed with a
%        border-clearing step performed on an eroded copy, so lungs that are
%        only thinly connected to the outside air are not discarded.
%     5. Connected-component analysis (bwconncomp + regionprops) keeps only
%        components with lung-like size and position.
%     6. Each candidate mask gets a plausibility score (total area, one lung
%        per side, left/right size symmetry). The best candidate wins.
%   If nothing plausible is found the mask is empty and info.isEmpty = true;
%   callers report this as a segmentation failure instead of guessing.

if nargin < 2
    cfg = getConfig();
end
img = im2double(img);
[h, w] = size(img);
numPixels = h * w;

lungMask = false(h, w);
info = struct('isEmpty', true, 'sensitivity', NaN, 'usedGlobalGate', false, ...
              'globalLevel', NaN, 'areaFraction', 0, 'numRegions', 0, ...
              'score', -Inf, 'thresholdMask', false(h, w));
if std(img(:)) < 0.01
    return;   % (almost) uniform image: there is no structure to segment
end

smoothed = imgaussfilt(img, cfg.segSmoothingSigma);

% Global (Otsu) dark-region map from the central region of the image
rows = round(0.15 * h) + 1:round(0.85 * h);
cols = round(0.15 * w) + 1:round(0.85 * w);
globalLevel = graythresh(smoothed(rows, cols));
darkGlobal  = ~imbinarize(smoothed, globalLevel);
gates = {darkGlobal, true(h, w)};

% Odd neighbourhood size for the adaptive threshold
nbh = 2 * floor(cfg.segNeighborhoodFrac * [h w] / 2) + 1;

bestScore = -Inf;
info.globalLevel = globalLevel;

for g = 1:numel(gates)
    for s = cfg.segSensitivities
        localLevel = adaptthresh(smoothed, s, 'ForegroundPolarity', 'dark', ...
                                 'NeighborhoodSize', nbh);
        darkLocal = ~imbinarize(smoothed, localLevel);
        thresholdMask = darkLocal & gates{g};

        candidate = removeOutsideAir(thresholdMask, cfg);
        [candidate, numRegions] = selectLungComponents(candidate, cfg);
        score = plausibilityScore(candidate, numRegions, numPixels, w, cfg);

        if score > bestScore
            bestScore = score;
            lungMask  = candidate;
            info.sensitivity   = s;
            info.usedGlobalGate = (g == 1);
            info.numRegions    = numRegions;
            info.score         = score;
            info.thresholdMask = thresholdMask;
        end
    end
end

info.areaFraction = nnz(lungMask) / numPixels;
info.isEmpty = ~any(lungMask(:));
end

% -------------------------------------------------------------------------
function mask = removeOutsideAir(mask, cfg)
% Erode to cut thin bridges between lungs and the air around the body,
% drop everything still touching the border, then grow the survivors back
% inside the original mask (a geodesic-style reconstruction limited to r).
r = cfg.morphOpenRadius;
se = strel('disk', r, 0);
markers = imclearborder(imerode(mask, se));
mask = imdilate(markers, se) & mask;
end

function [selected, numRegions] = selectLungComponents(mask, cfg)
[h, w] = size(mask);
numPixels = h * w;
cc = bwconncomp(mask, 8);
selected = false(h, w);
numRegions = 0;
if cc.NumObjects == 0
    return;
end
props = regionprops(cc, 'Area', 'Centroid');
areas = [props.Area];
centroids = reshape([props.Centroid], 2, []).';
cx = centroids(:, 1).' / w;
cy = centroids(:, 2).' / h;

valid = areas >= cfg.segMinComponentFrac * numPixels & ...
        areas <= cfg.segMaxComponentFrac * numPixels & ...
        cx >= cfg.segCentralBand(1) & cx <= cfg.segCentralBand(2) & ...
        cy >= cfg.segVerticalBand(1) & cy <= cfg.segVerticalBand(2);
if ~any(valid)
    return;
end

% Largest valid component on each side of the image = right / left lung
keep = [];
for side = 1:2
    if side == 1
        onSide = valid & cx < 0.5;
    else
        onSide = valid & cx >= 0.5;
    end
    if any(onSide)
        idx = find(onSide);
        [~, k] = max(areas(idx));
        keep(end+1) = idx(k); %#ok<AGROW>
    end
end
for k = keep
    selected(cc.PixelIdxList{k}) = true;
end
numRegions = numel(keep);
end

function score = plausibilityScore(mask, numRegions, numPixels, w, cfg)
if numRegions == 0
    score = -Inf;
    return;
end
areaFrac = nnz(mask) / numPixels;
lo = cfg.segTargetAreaFrac(1);
hi = cfg.segTargetAreaFrac(2);
if areaFrac < lo
    areaPenalty = (lo - areaFrac) / lo;
elseif areaFrac > hi
    areaPenalty = (areaFrac - hi) / hi;
else
    areaPenalty = 0;
end
% Left/right symmetry: area of the smaller half divided by the larger one
leftArea  = nnz(mask(:, 1:floor(w/2)));
rightArea = nnz(mask(:, floor(w/2)+1:end));
symmetry  = min(leftArea, rightArea) / max(max(leftArea, rightArea), 1);

score = 2 * (numRegions == 2) + symmetry - 3 * areaPenalty + areaFrac;
end
