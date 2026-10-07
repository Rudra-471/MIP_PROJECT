function [featureVector, featureNames, details] = extractFeatures(intensityImg, textureImg, lungMask, cfg)
%EXTRACTFEATURES Intensity + GLCM texture features of the lung region.
%   [f, names, details] = extractFeatures(intensityImg, textureImg, lungMask, cfg)
%     intensityImg - normalised, denoised grayscale image in [0,1]
%                    (global intensities are comparable between images)
%     textureImg   - contrast-enhanced image in [0,1] (CLAHE makes lung
%                    texture visible for the co-occurrence matrix)
%     lungMask     - final lung mask after morphological processing
%
%   Feature vector (1 x 13, order = cfg.featureNames):
%     Intensity : Mean, Std, Variance, Min, Max, Entropy, Skewness, Kurtosis
%     Texture   : Contrast, Correlation, Energy, Homogeneity (GLCM, averaged
%                 over 0/45/90/135 degrees, distance 1, symmetric)
%     Shape     : LungAreaRatio (segmented lung area / image area)
%
%   Only pixels inside the lung mask are used: GLCM ignores NaN pixels, so
%   everything outside the mask is set to NaN before graycomatrix.

if nargin < 4
    cfg = getConfig();
end
minPixels = 500;
if isempty(lungMask) || nnz(lungMask) < minPixels
    error('CXR:emptySegmentation', ...
        ['The lung segmentation is empty or too small (%d pixels) to extract ' ...
         'reliable features. Try a different image.'], nnz(lungMask));
end
if ~isequal(size(intensityImg), size(lungMask)) || ~isequal(size(textureImg), size(lungMask))
    error('CXR:featureExtraction', 'Image and mask sizes do not match.');
end

try
    lungPixels = im2double(intensityImg(lungMask));
    mu    = mean(lungPixels);
    sigma = std(lungPixels);
    centered = lungPixels - mu;
    if sigma > 0
        skew = mean(centered .^ 3) / sigma ^ 3;
        kurt = mean(centered .^ 4) / sigma ^ 4;
    else
        skew = 0;
        kurt = 0;
    end
    intensityFeatures = [mu, sigma, sigma ^ 2, min(lungPixels), max(lungPixels), ...
                         entropy(lungPixels), skew, kurt];

    maskedTexture = im2double(textureImg);
    maskedTexture(~lungMask) = NaN;
    glcm = graycomatrix(maskedTexture, 'NumLevels', cfg.glcmNumLevels, ...
                        'GrayLimits', [0 1], 'Offset', cfg.glcmOffsets, ...
                        'Symmetric', true);
    stats = graycoprops(glcm, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
    textureFeatures = [mean(stats.Contrast), mean(stats.Correlation), ...
                       mean(stats.Energy), mean(stats.Homogeneity)];

    shapeFeatures = nnz(lungMask) / numel(lungMask);
catch extractionError
    error('CXR:featureExtraction', 'Feature extraction failed: %s', extractionError.message);
end

featureVector = [intensityFeatures, textureFeatures, shapeFeatures];
featureNames  = cfg.featureNames;
if numel(featureVector) ~= numel(featureNames) || any(~isfinite(featureVector))
    error('CXR:featureExtraction', ...
        'Feature extraction produced invalid (NaN/Inf) values for this image.');
end
details = struct('glcm', glcm, 'numLungPixels', nnz(lungMask));
end
