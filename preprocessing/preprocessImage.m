function pre = preprocessImage(img, cfg)
%PREPROCESSIMAGE Grayscale conversion, intensity normalisation, resizing and denoising.
%   pre = preprocessImage(img, cfg) accepts a validated image (see
%   validateImage): grayscale or RGB, any numeric class, any size.
%
%   Steps
%     1. Keep an untouched copy of the original pixel data.
%     2. RGB -> grayscale with rgb2gray (luminance weighting). Grayscale
%        images are used as they are. Images whose three channels are
%        identical (common for X-rays saved as RGB) lose no information.
%     3. Convert to double in [0, 1] with im2double, so uint8, uint16 and
%        floating-point inputs all share one numeric representation.
%     4. Resize so that the longest side equals processingSize. The aspect
%        ratio is preserved; all pixel-based parameters assume this scale.
%     5. Noise reduction (reduceNoise, median 3x3 by default).
%
%   Output struct fields
%     original   - input pixel data, unchanged
%     gray       - grayscale double [0,1] at the original resolution
%     resized    - grayscale double [0,1] at the processing resolution
%     denoised   - noise-reduced version of resized (input of later steps)
%     scale      - resize factor applied
%     noiseMethod- noise-reduction method that was used

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
if isempty(img)
    error('CXR:noImage', 'Cannot preprocess an empty image.');
end

if ndims(img) == 3 && size(img, 3) == 3
    gray = rgb2gray(img);
elseif ismatrix(img)
    gray = img;
else
    error('CXR:invalidFormat', 'Unsupported image layout %s.', mat2str(size(img)));
end
gray = im2double(gray);
gray = min(max(gray, 0), 1);   % float inputs outside [0,1] are clipped, not rescaled

[h, w] = size(gray);
scale = cfg.preprocess.processingSize / max(h, w);
if abs(scale - 1) > 1e-9
    targetSize = max(1, round([h w] * scale));
    resized = imresize(gray, targetSize, 'bilinear');
    resized = min(max(resized, 0), 1);   % bilinear interpolation can overshoot slightly
else
    resized = gray;
end

denoised = reduceNoise(resized, cfg.preprocess.noiseMethod, cfg);

pre = struct();
pre.original    = img;
pre.gray        = gray;
pre.resized     = resized;
pre.denoised    = denoised;
pre.scale       = scale;
pre.noiseMethod = cfg.preprocess.noiseMethod;
end
