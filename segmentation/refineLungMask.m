function [finalMask, result] = refineLungMask(mask, cfg)
%REFINELUNGMASK Select the final candidate lung regions and check plausibility.
%   [finalMask, result] = refineLungMask(mask, cfg) takes the mask after
%   morphological processing and
%     1. keeps at most one connected region per image half (the largest),
%        i.e. an approximate right and left lung (cfg.morph.maxLungRegions),
%     2. checks that the total area is plausible for lung fields.
%
%   result.status
%     'ok'      - two regions with a plausible total area
%     'partial' - only one lung-like region, or the area is outside the
%                 expected range; the mask is kept but flagged
%     'failed'  - nothing usable is left; finalMask is empty
%   result.message, result.numRegions, result.areaFraction, result.regionAreas
%
%   A failed result is reported to the caller; no substitute mask is made up.

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
mask = logical(mask);
[h, w] = size(mask);
finalMask = false(h, w);
result = struct('status', 'failed', 'message', '', 'numRegions', 0, ...
                'areaFraction', 0, 'regionAreas', []);

cc = bwconncomp(mask, 8);
if cc.NumObjects == 0
    result.message = 'The lung mask is empty after morphological processing.';
    return;
end
props = regionprops(cc, 'Area', 'Centroid');
areas = [props.Area];
centroids = reshape([props.Centroid], 2, []).';
isLeftHalf = centroids(:, 1).' < w / 2;

keep = [];
for side = [true false]
    idx = find(isLeftHalf == side);
    if ~isempty(idx)
        [~, k] = max(areas(idx));
        keep(end + 1) = idx(k); %#ok<AGROW>
    end
end
if numel(keep) > cfg.morph.maxLungRegions
    [~, order] = sort(areas(keep), 'descend');
    keep = keep(order(1:cfg.morph.maxLungRegions));
end
for k = keep
    finalMask(cc.PixelIdxList{k}) = true;
end

result.numRegions = numel(keep);
result.regionAreas = areas(keep);
result.areaFraction = nnz(finalMask) / (h * w);
range = cfg.segment.targetAreaFrac;
plausibleArea = result.areaFraction >= range(1) && result.areaFraction <= range(2);

if result.numRegions == 2 && plausibleArea
    result.status = 'ok';
    result.message = sprintf('Two candidate lung regions, %.1f %% of the image.', 100 * result.areaFraction);
else
    result.status = 'partial';
    reasons = {};
    if result.numRegions < 2
        reasons{end + 1} = 'only one lung-like region was found';
    end
    if ~plausibleArea
        reasons{end + 1} = sprintf('the total area (%.1f %%) is outside the expected %.0f-%.0f %%', ...
            100 * result.areaFraction, 100 * range(1), 100 * range(2));
    end
    result.message = ['Segmentation is uncertain: ' strjoin(reasons, ' and ') '.'];
end
end
