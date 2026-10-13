function [values, names, glcm] = extractGLCMFeatures(img, roiMask, cfg)
%EXTRACTGLCMFEATURES Grey-level co-occurrence matrix (GLCM) texture features.
%   [values, names, glcm] = extractGLCMFeatures(img, roiMask, cfg)
%
%   GLCM parameters (identical for every image, from cfg.features):
%     NumLevels  = 32 grey levels (quantisation of [0,1])
%     GrayLimits = [0 1] fixed, so the same intensity always maps to the same
%                  level in every image (no per-image rescaling)
%     Offsets    = [0 1; -1 1; -1 0; -1 -1]  ->  0, 45, 90, 135 degrees, distance 1
%     Symmetric  = true (pairs counted in both directions)
%   Pixels outside the ROI are set to NaN; graycomatrix ignores every pixel
%   pair that contains a NaN, so only pairs inside the ROI are counted.
%   Each property is averaged over the four directions (rotation tolerance).
%
%   graycoprops definitions (p(i,j) = normalised GLCM):
%     Contrast    = sum |i-j|^2 p(i,j)          local intensity variation
%     Correlation = sum (i-mi)(j-mj)p(i,j)/(si sj)  linear dependency of
%                   neighbouring grey levels (NaN for a constant region)
%     Energy      = sum p(i,j)^2                uniformity / orderliness
%     Homogeneity = sum p(i,j)/(1+|i-j|)        closeness to the GLCM diagonal

masked = im2double(img);
masked(~roiMask) = NaN;
glcm = graycomatrix(masked, 'NumLevels', cfg.features.glcmNumLevels, ...
                    'GrayLimits', cfg.features.glcmGrayLimits, ...
                    'Offset', cfg.features.glcmOffsets, ...
                    'Symmetric', cfg.features.glcmSymmetric);
if sum(glcm(:)) == 0
    error('CXR:emptyROI', 'The ROI contains no neighbouring pixel pairs for the GLCM.');
end
names = {'Contrast', 'Correlation', 'Energy', 'Homogeneity'};
stats = graycoprops(glcm, names);
values = [mean(stats.Contrast), mean(stats.Correlation), ...
          mean(stats.Energy), mean(stats.Homogeneity)];
end
