function img = makeChestPhantom(sz, seed, withOpacity)
%MAKECHESTPHANTOM SYNTHETIC test array that loosely mimics a chest X-ray layout.
%   img = makeChestPhantom(sz, seed, withOpacity) returns a double image in
%   [0,1]: a bright body ellipse on a dark background, two dark "lung"
%   ellipses, a bright mediastinum and textured noise. withOpacity adds a
%   bright blob inside one lung.
%
%   SOFTWARE TESTING ONLY. This is not a medical image and nothing computed
%   from it is a medical result. It exists so the code paths can be tested
%   automatically without the (large) real dataset.

if nargin < 1 || isempty(sz), sz = 512; end
if nargin < 2 || isempty(seed), seed = 1; end
if nargin < 3, withOpacity = false; end
previous = rng();
restore = onCleanup(@() rng(previous));
rng(seed, 'twister');

[x, y] = meshgrid(linspace(0, 1, sz), linspace(0, 1, sz));
img = 0.05 * ones(sz);
body = ((x - 0.5) / 0.44) .^ 2 + ((y - 0.55) / 0.52) .^ 2 <= 1;
img(body) = 0.72;
jitter = 0.02 * randn(1, 4);
leftLung  = ((x - 0.31 - jitter(1)) / 0.13) .^ 2 + ((y - 0.45 - jitter(2)) / 0.27) .^ 2 <= 1;
rightLung = ((x - 0.69 + jitter(3)) / 0.13) .^ 2 + ((y - 0.45 - jitter(4)) / 0.27) .^ 2 <= 1;
img(leftLung | rightLung) = 0.22;
mediastinum = abs(x - 0.5) < 0.07 & y > 0.15 & body;
img(mediastinum) = 0.88;
if withOpacity
    blob = ((x - 0.30) / 0.06) .^ 2 + ((y - 0.55) / 0.08) .^ 2 <= 1;
    img(blob) = 0.6;
end
texture = conv2(randn(sz), ones(5) / 25, 'same');
img = img + 0.03 * texture + 0.01 * randn(sz);
img = min(max(img, 0), 1);
end
