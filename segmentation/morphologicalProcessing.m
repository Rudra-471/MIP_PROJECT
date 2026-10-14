function morph = morphologicalProcessing(mask, cfg)
%MORPHOLOGICALPROCESSING Refine a binary lung mask with morphological operators.
%   morph = morphologicalProcessing(mask, cfg) returns every intermediate
%   stage (for visualisation) plus pixel counts:
%
%     input   - initial binary mask from segmentLungs
%     opened  - OPENING (imopen = erosion followed by dilation, disk r_open).
%               Removes small noise blobs and thin spurs that leak out of the
%               lungs (e.g. along the trachea) without shrinking large regions.
%     cleaned - small-object removal (bwareaopen): isolated objects smaller
%               than minObjectFrac of the image are deleted.
%     closed  - CLOSING (imclose = dilation followed by erosion, disk r_close).
%               Bridges small gaps, reconnects broken lung pieces and smooths
%               concave notches of the boundary.
%     filled  - HOLE FILLING (imfill 'holes'). Fills enclosed holes caused by
%               vessels, ribs or bright opacities inside the lung field, so the
%               ROI covers the whole lung, including dense regions.
%     eroded  - EROSION (imerode, disk r_erode): peels a thin layer off the
%               boundary and removes one-pixel protrusions.
%     dilated - DILATION (imdilate, disk r_dilate): grows the region back.
%               Erosion followed by dilation of the same size smooths the
%               final contour (an additional, gentle opening).
%     output  - final refined mask (= dilated)
%     counts  - struct with the number of foreground pixels after each stage
%     isEmpty - true when nothing is left
%
%   Structuring elements are exact disks: strel('disk', r, 0).
%   These operations only make the mask more consistent. They do not detect
%   disease and do not identify pathological regions.

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
p = cfg.morph;
mask = logical(mask);

morph = struct();
morph.input = mask;
if ~any(mask(:))
    stages = {'opened', 'cleaned', 'closed', 'filled', 'eroded', 'dilated', 'output'};
    for k = 1:numel(stages)
        morph.(stages{k}) = mask;
    end
    morph.counts = struct('input', 0, 'opened', 0, 'cleaned', 0, 'closed', 0, ...
                          'filled', 0, 'eroded', 0, 'dilated', 0);
    morph.isEmpty = true;
    return;
end

minObjectArea = max(1, round(p.minObjectFrac * numel(mask)));
morph.opened  = imopen(mask, strel('disk', p.openRadius, 0));
morph.cleaned = bwareaopen(morph.opened, minObjectArea);
morph.closed  = imclose(morph.cleaned, strel('disk', p.closeRadius, 0));
morph.filled  = imfill(morph.closed, 'holes');
morph.eroded  = imerode(morph.filled, strel('disk', p.erodeRadius, 0));
morph.dilated = imdilate(morph.eroded, strel('disk', p.dilateRadius, 0));
morph.output  = morph.dilated;

morph.counts = struct('input', nnz(mask), 'opened', nnz(morph.opened), ...
    'cleaned', nnz(morph.cleaned), 'closed', nnz(morph.closed), ...
    'filled', nnz(morph.filled), 'eroded', nnz(morph.eroded), 'dilated', nnz(morph.dilated));
morph.isEmpty = ~any(morph.output(:));
end
