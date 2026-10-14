function [featureVector, featureTable, details] = extractFeatures(img, roiMask, cfg)
%EXTRACTFEATURES Intensity and GLCM texture features of a grayscale image region.
%   [featureVector, featureTable, details] = extractFeatures(img, roiMask, cfg)
%     img     - grayscale image (any numeric class; converted to double [0,1])
%     roiMask - optional logical mask of the region of interest (normally the
%               final lung mask). Empty or omitted = whole image.
%     cfg     - configuration (appConfig); training and inference must pass
%               the same configuration.
%
%   Feature order (fixed, = cfg.features.names):
%     1 Mean  2 Std  3 Variance  4 Min  5 Max  6 Entropy           (intensity)
%     7 Contrast  8 Correlation  9 Energy  10 Homogeneity          (GLCM texture)
%
%   featureVector - 1 x 10 double
%   featureTable  - table with columns Feature, Group, Value (MATLAB). Under
%                   GNU Octave, which has no table class, a struct array with
%                   the same fields is returned instead.
%   details       - numRoiPixels, roiFraction, usedWholeImage, glcm
%
%   Errors (never replaced by arbitrary values):
%     CXR:invalidMask        mask size/type does not match the image
%     CXR:emptyROI           ROI has fewer than cfg.features.minRoiPixels pixels
%     CXR:nonFiniteFeature   a feature is NaN/Inf (e.g. GLCM correlation of a
%                            constant region is mathematically undefined)
%
%   The features describe the image; no rule such as "brighter = diseased"
%   is applied here. The SVM learns any relationship from labelled data.

if nargin < 3 || isempty(cfg)
    cfg = appConfig();
end
if nargin < 2
    roiMask = [];
end
if isempty(img) || ~(isnumeric(img) || islogical(img)) || ~ismatrix(img)
    error('CXR:invalidImage', 'extractFeatures expects a non-empty 2-D grayscale image.');
end
img = im2double(img);
if any(~isfinite(img(:)))
    error('CXR:invalidImage', 'The image contains NaN or Inf values.');
end

usedWholeImage = isempty(roiMask);
if usedWholeImage
    roiMask = true(size(img));
else
    if ~isequal(size(roiMask), size(img))
        error('CXR:invalidMask', 'ROI mask size %s does not match image size %s.', ...
            mat2str(size(roiMask)), mat2str(size(img)));
    end
    if ~islogical(roiMask)
        if ~isnumeric(roiMask) || any(roiMask(:) ~= 0 & roiMask(:) ~= 1)
            error('CXR:invalidMask', 'ROI mask must be logical or contain only 0 and 1.');
        end
        roiMask = logical(roiMask);
    end
end

numRoiPixels = nnz(roiMask);
if numRoiPixels < cfg.features.minRoiPixels
    error('CXR:emptyROI', ['The region of interest contains %d pixels; at least %d are ' ...
        'required for reliable features.'], numRoiPixels, cfg.features.minRoiPixels);
end

[intensityValues, intensityNames] = extractIntensityFeatures(img, roiMask);
[textureValues, textureNames, glcm] = extractGLCMFeatures(img, roiMask, cfg);

featureVector = [intensityValues, textureValues];
names = [intensityNames, textureNames];
if ~isequal(names, cfg.features.names)
    error('CXR:featureDefinition', 'Feature order does not match cfg.features.names.');
end

bad = ~isfinite(featureVector);
if any(bad)
    error('CXR:nonFiniteFeature', ['Feature(s) %s could not be computed (NaN/Inf). This ' ...
        'happens for constant or almost constant regions.'], strjoin(names(bad), ', '));
end

featureTable = makeFeatureTable(names, cfg.features.groups, featureVector);
details = struct('numRoiPixels', numRoiPixels, 'roiFraction', numRoiPixels / numel(roiMask), ...
                 'usedWholeImage', usedWholeImage, 'glcm', glcm);
end

function t = makeFeatureTable(names, groups, values)
if ~isOctaveRuntime()
    t = table(names(:), groups(:), values(:), 'VariableNames', {'Feature', 'Group', 'Value'});
else
    t = struct('Feature', names(:), 'Group', groups(:), 'Value', num2cell(values(:)));
end
end
