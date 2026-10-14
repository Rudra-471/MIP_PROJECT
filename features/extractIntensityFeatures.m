function [values, names] = extractIntensityFeatures(img, roiMask)
%EXTRACTINTENSITYFEATURES First-order intensity statistics of the ROI pixels.
%   [values, names] = extractIntensityFeatures(img, roiMask), img double [0,1].
%     Mean      average intensity (overall brightness / density of the region)
%     Std       standard deviation (spread of intensities)
%     Variance  Std^2
%     Min, Max  darkest / brightest ROI pixel
%     Entropy   Shannon entropy of the 256-bin ROI histogram (bits); higher
%               values mean a more varied, less predictable intensity
%               distribution (entropy, Image Processing Toolbox)
%   Only pixels inside roiMask are used.

pixels = img(roiMask);
pixels = pixels(:);
mu = mean(pixels);
sigma = std(pixels);   % normalised by N-1
values = [mu, sigma, sigma ^ 2, min(pixels), max(pixels), entropy(pixels)];
names = {'Mean', 'Std', 'Variance', 'Min', 'Max', 'Entropy'};
end
