function morph = morphologicalProcessing(mask, cfg)
%MORPHOLOGICALPROCESSING Refine a raw lung mask with morphological operators.
%   morph = morphologicalProcessing(mask, cfg) returns a struct with every
%   intermediate stage (useful for visualisation) and the final mask:
%
%     input   - raw mask from segmentLung
%     opened  - imopen  (disk r1): removes small noise and thin spurs that
%                         leak out of the lungs (e.g. along the trachea)
%     cleaned - bwareaopen: removes small unwanted isolated objects
%     closed  - imclose (disk r2): connects broken pieces of a lung and
%                         smooths concave notches along the boundary
%     filled  - imfill 'holes': fills holes left by vessels, ribs or bright
%                         opacities inside the lung. This matters: dense
%                         abnormal regions are bright and would otherwise be
%                         excluded from the lung region of interest
%     eroded  - imerode (disk r3): peels a thin layer off the boundary
%     dilated - imdilate(disk r3): grows it back; erosion followed by
%                         dilation smooths the final contour
%     final   - at most cfg.morphMaxLungs largest regions (left/right lung)
%
%   All structuring elements are created with strel('disk', r, 0) (an exact
%   disk; N = 0 disables MATLAB's periodic-line approximation).

if nargin < 2
    cfg = getConfig();
end
mask = logical(mask);
minObjectArea = round(cfg.morphMinObjectFrac * numel(mask));

morph = struct();
morph.input   = mask;
morph.opened  = imopen(mask, strel('disk', cfg.morphOpenRadius, 0));
morph.cleaned = bwareaopen(morph.opened, minObjectArea);
morph.closed  = imclose(morph.cleaned, strel('disk', cfg.morphCloseRadius, 0));
morph.filled  = imfill(morph.closed, 'holes');
morph.eroded  = imerode(morph.filled, strel('disk', cfg.morphErodeRadius, 0));
morph.dilated = imdilate(morph.eroded, strel('disk', cfg.morphDilateRadius, 0));
morph.final   = keepLargestRegions(morph.dilated, cfg.morphMaxLungs);
morph.isEmpty = ~any(morph.final(:));
end

function out = keepLargestRegions(mask, maxRegions)
out = false(size(mask));
cc = bwconncomp(mask, 8);
if cc.NumObjects == 0
    return;
end
areas = cellfun(@numel, cc.PixelIdxList);
[~, order] = sort(areas, 'descend');
for k = order(1:min(maxRegions, end))
    out(cc.PixelIdxList{k}) = true;
end
end
