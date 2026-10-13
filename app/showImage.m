function showImage(ax, img, theme, titleText)
%SHOWIMAGE Display an image in axes without distorting its proportions.
%   showImage(ax, img, theme) - img is grayscale (H x W), RGB (H x W x 3)
%   or logical. It is drawn as true-colour data, so no colormap is needed,
%   and 'axis image' keeps square pixels whatever the panel size.
%   titleText (optional) is drawn above the image.

cla(ax);
maxDisplaySide = 1024;            % large radiographs are downscaled for display only
if max(size(img, 1), size(img, 2)) > maxDisplaySide
    if islogical(img)
        img = imresize(img, maxDisplaySide / max(size(img, 1), size(img, 2)), 'nearest');
    else
        img = imresize(img, maxDisplaySide / max(size(img, 1), size(img, 2)), 'bilinear');
    end
end
img = im2double(img);
if ismatrix(img)
    img = repmat(img, [1 1 3]);
end
img = min(max(img, 0), 1);
image(ax, img);
axis(ax, 'image');
ax.XTick = [];
ax.YTick = [];
ax.Color = theme.axesBg;
ax.XColor = 'none';
ax.YColor = 'none';
if nargin >= 4 && ~isempty(titleText)
    title(ax, titleText, 'Color', theme.textMuted, 'FontWeight', 'normal', ...
        'FontSize', theme.fontSize.caption, 'Interpreter', 'none');
else
    title(ax, '');
end
end
