function corrected = applyGammaCorrection(img, gammaValue, cfg)
%APPLYGAMMACORRECTION Power-law intensity transform out = in .^ gamma (imadjust).
%   corrected = applyGammaCorrection(img, gammaValue, cfg)
%     gamma < 1 brightens dark regions (more detail inside the dark lungs)
%     gamma > 1 darkens the image and emphasises bright structures
%     gamma = 1 leaves the image unchanged
%   gammaValue must lie inside cfg.enhance.gammaRange.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
range = cfg.enhance.gammaRange;
if ~isnumeric(gammaValue) || ~isscalar(gammaValue) || ~isfinite(gammaValue) || ...
        gammaValue < range(1) || gammaValue > range(2)
    error('CXR:invalidOption', 'Gamma must be a number between %.2f and %.2f.', range(1), range(2));
end
img = im2double(img);
if abs(gammaValue - 1) < 1e-12
    corrected = img;
else
    corrected = imadjust(img, [0; 1], [0; 1], gammaValue);
end
end
