function enhanced = enhanceImage(img, method, cfg)
%ENHANCEIMAGE Contrast enhancement of a preprocessed grayscale X-ray.
%   enhanced = enhanceImage(img, method, cfg) where img is double in [0,1].
%   Exactly one method is applied (no blind chaining of enhancements):
%
%     'stretch' - contrast stretching. stretchlim finds the intensities
%                 below/above which 1 % of the pixels lie, and imadjust maps
%                 that range linearly to [0, 1]. The ordering and relative
%                 spacing of intensities is preserved, so dense (bright)
%                 regions stay comparable between images. Default.
%     'histeq'  - global histogram equalisation (histeq). Redistributes
%                 intensities to an approximately flat histogram. Strong
%                 global contrast, but it can amplify noise and wash out
%                 soft tissue.
%     'clahe'   - Contrast-Limited Adaptive Histogram Equalisation
%                 (adapthisteq). Equalises small tiles separately and clips
%                 each tile histogram so noise is not over-amplified. Shows
%                 rib, vessel and lung-field detail in dark and bright areas.
%
%   Gamma correction is a separate, explicit step (applyGammaCorrection).
%   No claim is made that any method improves diagnostic accuracy.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 2 || isempty(method)
    method = cfg.enhance.method;
end
img = im2double(img);

switch lower(method)
    case 'stretch'
        limits = stretchlim(img, cfg.enhance.stretchTolerance);
        if limits(2) - limits(1) < eps
            enhanced = img;      % flat image: nothing to stretch
        else
            enhanced = imadjust(img, limits, [0; 1]);
        end
    case 'histeq'
        enhanced = histeq(img, cfg.enhance.histeqBins);
    case 'clahe'
        enhanced = adapthisteq(img, 'ClipLimit', cfg.enhance.claheClipLimit, ...
                               'NumTiles', cfg.enhance.claheNumTiles, ...
                               'Distribution', 'uniform');
    otherwise
        error('CXR:invalidOption', ...
            'Unknown enhancement method "%s" (use stretch, histeq or clahe).', method);
end
enhanced = min(max(im2double(enhanced), 0), 1);
end
