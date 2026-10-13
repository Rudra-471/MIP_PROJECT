function out = reduceNoise(img, method, cfg)
%REDUCENOISE Noise reduction of a grayscale double image in [0, 1].
%   out = reduceNoise(img, method, cfg), method:
%     'median'   - medfilt2 with cfg.preprocess.medianWindow (default 3x3).
%                  Removes impulse-like noise (dead/hot detector pixels,
%                  compression artefacts) while keeping edges such as the
%                  lung border, ribs and diaphragm sharp. Default.
%     'gaussian' - imgaussfilt with cfg.preprocess.gaussianSigma. Suppresses
%                  fine Gaussian-like quantum noise but blurs edges evenly.
%     'none'     - no filtering.
%   Small windows are used on purpose: aggressive smoothing would erase the
%   lung texture that the GLCM features measure.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 2 || isempty(method)
    method = cfg.preprocess.noiseMethod;
end
img = im2double(img);

switch lower(method)
    case 'median'
        out = medfilt2(img, cfg.preprocess.medianWindow, 'symmetric');
    case 'gaussian'
        out = imgaussfilt(img, cfg.preprocess.gaussianSigma);
    case 'none'
        out = img;
    otherwise
        error('CXR:invalidOption', 'Unknown noise-reduction method "%s" (median, gaussian or none).', method);
end
out = min(max(out, 0), 1);
end
