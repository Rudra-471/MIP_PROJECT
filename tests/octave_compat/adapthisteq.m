function out = adapthisteq(img, varargin)
% TEST SHIM (Octave only) - CLAHE following MATLAB's adapthisteq conventions
% ('Distribution','uniform', 256 bins, normalised ClipLimit, bilinear
% interpolation between tile mappings).
clipLimit = 0.01; numTiles = [8 8]; numBins = 256;
for k = 1:2:numel(varargin)
    switch lower(varargin{k})
        case 'cliplimit', clipLimit = varargin{k+1};
        case 'numtiles',  numTiles = varargin{k+1};
        case 'nbins',     numBins = varargin{k+1};
    end
end
img = im2double(img);
[rows, cols] = size(img);
% Pad so the image divides evenly into tiles
tileSize = ceil([rows cols] ./ numTiles);
padded = padarray(img, tileSize .* numTiles - [rows cols], 'symmetric', 'post');
bins = min(floor(padded * numBins), numBins - 1) + 1;
numPixTile = prod(tileSize);
minClip = ceil(numPixTile / numBins);
fullClip = minClip + round(clipLimit * (numPixTile - minClip));
maps = zeros(numTiles(1), numTiles(2), numBins);
for ty = 1:numTiles(1)
    for tx = 1:numTiles(2)
        tile = bins((ty-1)*tileSize(1)+1:ty*tileSize(1), (tx-1)*tileSize(2)+1:tx*tileSize(2));
        h = accumarray(tile(:), 1, [numBins 1]);
        excess = sum(max(h - fullClip, 0));
        h = min(h, fullClip) + excess / numBins;   % redistribute clipped mass
        maps(ty, tx, :) = cumsum(h) / sum(h);
    end
end
% Bilinear interpolation between tile centres
[X, Y] = meshgrid(1:cols, 1:rows);
fy = (Y - 0.5) / tileSize(1) + 0.5;  fx = (X - 0.5) / tileSize(2) + 0.5;
y0 = min(max(floor(fy), 1), numTiles(1)); y1 = min(y0 + 1, numTiles(1));
x0 = min(max(floor(fx), 1), numTiles(2)); x1 = min(x0 + 1, numTiles(2));
wy = min(max(fy - y0, 0), 1); wx = min(max(fx - x0, 0), 1);
b = bins(1:rows, 1:cols);
lookup = @(ty, tx) maps(sub2ind(size(maps), ty, tx, b));
out = (1 - wy) .* ((1 - wx) .* lookup(y0, x0) + wx .* lookup(y0, x1)) + ...
      wy .* ((1 - wx) .* lookup(y1, x0) + wx .* lookup(y1, x1));
end
