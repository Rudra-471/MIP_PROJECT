function comparison = compareEnhancement(img, cfg)
%COMPAREENHANCEMENT Apply all enhancement methods and quantify the result.
%   comparison = compareEnhancement(img) returns a struct array with fields
%   name, method, image, stdDev (global contrast), entropy (information
%   content) and edgeStrength (mean gradient magnitude, a proxy for how
%   visible structure boundaries are). The first entry is the input image.

if nargin < 2
    cfg = getConfig();
end
img = im2double(img);
names   = {'Input (denoised)', 'imadjust', 'Histogram equalisation', 'CLAHE'};
methods = {'',                 'imadjust', 'histeq',                 'clahe'};

comparison = struct('name', names, 'method', methods, 'image', [], ...
                    'stdDev', [], 'entropy', [], 'edgeStrength', []);
for k = 1:numel(names)
    if isempty(methods{k})
        out = img;
    else
        out = enhanceImage(img, methods{k}, cfg);
    end
    [gx, gy] = gradient(out);
    comparison(k).image        = out;
    comparison(k).stdDev       = std(out(:));
    comparison(k).entropy      = entropy(out);
    comparison(k).edgeStrength = mean(hypot(gx(:), gy(:)));
end
end
