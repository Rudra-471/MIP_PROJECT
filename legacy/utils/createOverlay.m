function overlay = createOverlay(grayImg, mask, color, alpha)
%CREATEOVERLAY Blend a coloured lung mask and its outline onto an X-ray.
%   overlay = createOverlay(grayImg, mask) returns an RGB image (double)
%   where the lung region is tinted and its boundary drawn in bright colour.
%   Implemented with basic array operations so it works in every MATLAB
%   release (no dependency on labeloverlay).

if nargin < 3 || isempty(color)
    color = [0 0.85 0.3];
end
if nargin < 4 || isempty(alpha)
    alpha = 0.30;
end
grayImg = im2double(grayImg);
if ~isequal(size(mask), size(grayImg))
    mask = imresize(mask, size(grayImg), 'nearest');
end
mask = logical(mask);
boundary = mask & ~imerode(mask, strel('disk', 2, 0));

overlay = repmat(grayImg, [1 1 3]);
for c = 1:3
    channel = overlay(:, :, c);
    channel(mask) = (1 - alpha) * channel(mask) + alpha * color(c);
    channel(boundary) = color(c);
    overlay(:, :, c) = channel;
end
end
