function pre = preprocessImage(img, cfg)
%PREPROCESSIMAGE Grayscale conversion, resizing, normalisation, denoising.
%   pre = preprocessImage(img, cfg) accepts an RGB or grayscale image of any
%   class (uint8, uint16, double, ...) and any size and returns a struct:
%     pre.gray      - grayscale image, double in [0,1], resized to cfg.imageSize
%     pre.normalized- robust percentile-stretched version of pre.gray
%     pre.denoised  - median-filtered version of pre.normalized (pipeline output)
%
%   Why a MEDIAN filter?
%   Digital radiographs contain impulse-like noise (dead/hot detector pixels,
%   quantum mottle, compression artefacts). A median filter removes such
%   outliers while preserving edges - lung borders, ribs and the diaphragm -
%   much better than a Gaussian filter, which blurs edges uniformly and would
%   make the later threshold-based lung segmentation less precise. A small
%   3x3 window is used so fine lung texture (needed for GLCM features) is kept.

if nargin < 2
    cfg = getConfig();
end
if isempty(img)
    error('CXR:noImage', 'Cannot preprocess an empty image.');
end

% 1) Grayscale conversion (RGB -> gray with rgb2gray, gray kept as-is)
if ndims(img) == 3 && size(img, 3) == 3
    gray = rgb2gray(img);
elseif ismatrix(img)
    gray = img;
else
    error('CXR:corruptImage', 'Unsupported image layout (size %s).', mat2str(size(img)));
end
gray = im2double(gray);   % works for uint8, uint16, int16, logical, double

% 2) Consistent resolution so features are comparable across images
gray = imresize(gray, cfg.imageSize, 'bilinear');
gray = min(max(gray, 0), 1);

% 3) Robust intensity normalisation: stretch between low/high percentiles
%    so images acquired with different exposure end up in a similar range.
normalized = stretchToPercentiles(gray, cfg.stretchPercentiles);

% 4) Noise reduction (median filter, see header for the rationale)
denoised = medfilt2(normalized, cfg.medianFilterSize, 'symmetric');

pre = struct('gray', gray, 'normalized', normalized, 'denoised', denoised);
end

function out = stretchToPercentiles(img, pct)
values = sort(img(:));
n = numel(values);
lo = values(max(1, round(pct(1) / 100 * n)));
hi = values(max(1, round(pct(2) / 100 * n)));
if hi - lo < eps
    out = img;              % flat image: nothing to stretch
    return;
end
out = imadjust(img, [lo; hi], [0; 1]);
end
