function enhanced = enhanceImage(img, method, cfg)
%ENHANCEIMAGE Contrast enhancement of a preprocessed grayscale X-ray.
%   enhanced = enhanceImage(img, method) with img a double image in [0,1].
%   method:
%     'imadjust' - global linear stretch (saturates 1% at both ends).
%                  Simple, but one mapping for the whole image.
%     'histeq'   - global histogram equalisation. Maximises global contrast
%                  but tends to over-enhance noise and wash out the
%                  mediastinum / soft tissue.
%     'clahe'    - Contrast Limited Adaptive Histogram Equalisation
%                  (adapthisteq). Equalises small tiles independently and
%                  clips the histogram to avoid amplifying noise. It
%                  reveals rib, vessel and lung-field detail in both dark and
%                  bright parts of the image; this is the default.
%
%   See also compareEnhancement, gammaCorrection.

if nargin < 3
    cfg = getConfig();
end
if nargin < 2 || isempty(method)
    method = cfg.enhancementMethod;
end
img = im2double(img);

switch lower(method)
    case 'imadjust'
        enhanced = imadjust(img, stretchlim(img, [0.01 0.99]), []);
    case 'histeq'
        enhanced = histeq(img, 256);
    case 'clahe'
        enhanced = adapthisteq(img, 'ClipLimit', cfg.claheClipLimit, ...
                               'NumTiles', cfg.claheNumTiles, ...
                               'Distribution', 'uniform');
    otherwise
        error('CXR:invalidOption', ...
            'Unknown enhancement method "%s" (use clahe, histeq or imadjust).', method);
end
enhanced = min(max(im2double(enhanced), 0), 1);
end
