function overlay = createMaskOverlay(grayImg, mask, color, alpha)
%CREATEMASKOVERLAY Tint a binary mask and draw its outline on a grayscale image.
%   overlay = createMaskOverlay(grayImg, mask) returns an RGB double image.
%   It is used to show the APPROXIMATE LUNG REGION found by segmentation.
%   It is not a lesion or abnormality localisation.

if nargin < 3 || isempty(color)
    color = [0.18 0.79 0.77];   % teal
end
if nargin < 4 || isempty(alpha)
    alpha = 0.25;
end
grayImg = im2double(grayImg);
if size(grayImg, 3) == 3
    grayImg = rgb2gray(grayImg);
end
overlay = repmat(grayImg, [1 1 3]);
if isempty(mask) || ~any(mask(:))
    return;
end
if ~isequal(size(mask), size(grayImg))
    mask = imresize(logical(mask), size(grayImg), 'nearest');
end
mask = logical(mask);
outline = mask & ~imerode(mask, strel('disk', 2, 0));
for c = 1:3
    channel = overlay(:, :, c);
    channel(mask) = (1 - alpha) * channel(mask) + alpha * color(c);
    channel(outline) = color(c);
    overlay(:, :, c) = channel;
end
end
