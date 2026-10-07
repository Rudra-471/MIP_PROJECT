function glcm = graycomatrix(img, varargin)
% TEST SHIM (Octave only) - MATLAB-style graycomatrix; NaN pixels are ignored.
numLevels = 8; grayLimits = []; offsets = [0 1]; symmetric = false;
for k = 1:2:numel(varargin)
    switch lower(varargin{k})
        case 'numlevels',  numLevels = varargin{k+1};
        case 'graylimits', grayLimits = varargin{k+1};
        case 'offset',     offsets = varargin{k+1};
        case 'symmetric',  symmetric = varargin{k+1};
    end
end
img = double(img);
if isempty(grayLimits)
    grayLimits = [min(img(:)) max(img(:))];
end
lo = grayLimits(1); hi = grayLimits(2);
if hi == lo
    scaled = ones(size(img));
else
    slope = (numLevels - 1) / (hi - lo);
    scaled = round(slope * img + (1 - slope * lo));
end
nanMask = isnan(scaled);
scaled = min(max(scaled, 1), numLevels);
scaled(nanMask) = NaN;
[rows, cols] = size(scaled);
glcm = zeros(numLevels, numLevels, size(offsets, 1));
for k = 1:size(offsets, 1)
    dr = offsets(k, 1); dc = offsets(k, 2);
    r1 = max(1, 1 - dr):min(rows, rows - dr);
    c1 = max(1, 1 - dc):min(cols, cols - dc);
    a = scaled(r1, c1);
    b = scaled(r1 + dr, c1 + dc);
    valid = ~isnan(a) & ~isnan(b);
    g = accumarray([a(valid) b(valid)], 1, [numLevels numLevels]);
    if symmetric
        g = g + g.';
    end
    glcm(:, :, k) = g;
end
end
