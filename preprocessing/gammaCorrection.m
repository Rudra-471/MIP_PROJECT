function corrected = gammaCorrection(img, gammaValue, cfg)
%GAMMACORRECTION Power-law intensity transform: out = in .^ gamma.
%   gamma < 1 brightens dark regions (e.g. reveals detail inside the dark
%   lung fields); gamma > 1 darkens the image and emphasises bright
%   structures (bones, dense opacities). gamma = 1 leaves the image unchanged.

if nargin < 3
    cfg = getConfig();
end
if ~isnumeric(gammaValue) || ~isscalar(gammaValue) || ~isfinite(gammaValue) ...
        || gammaValue < cfg.gammaRange(1) || gammaValue > cfg.gammaRange(2)
    error('CXR:invalidOption', 'Gamma must be a number between %.1f and %.1f.', ...
        cfg.gammaRange(1), cfg.gammaRange(2));
end
corrected = imadjust(im2double(img), [], [], gammaValue);
end
