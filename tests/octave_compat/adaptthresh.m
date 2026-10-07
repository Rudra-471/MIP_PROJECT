function T = adaptthresh(img, sensitivity, varargin)
% TEST SHIM (Octave only) - Bradley local-mean adaptive threshold, following
% the behaviour documented for MATLAB's adaptthresh ('Statistic','mean').
if nargin < 2 || isempty(sensitivity), sensitivity = 0.5; end
img = im2double(img);
polarity = 'bright';
nbh = 2 * floor(size(img) / 16) + 1;
for k = 1:2:numel(varargin)
    switch lower(varargin{k})
        case 'foregroundpolarity', polarity = varargin{k+1};
        case 'neighborhoodsize',   nbh = varargin{k+1};
    end
end
if isscalar(nbh), nbh = [nbh nbh]; end
if strcmpi(polarity, 'dark')
    img = 1 - img;
end
% Box (mean) filter with replicate padding, computed with cumulative sums
padR = floor(nbh(1) / 2); padC = floor(nbh(2) / 2);
padded = padarray(img, [padR padC], 'replicate');
c = cumsum(padarray(padded, [1 1], 0, 'pre'), 1);
c = cumsum(c, 2);
[rows, cols] = size(img);
r1 = 1:rows; r2 = r1 + nbh(1); c1 = 1:cols; c2 = c1 + nbh(2);
localMean = (c(r2, c2) - c(r1, c2) - c(r2, c1) + c(r1, c1)) / prod(nbh);
scaleFactor = 0.6 + (1 - sensitivity);
T = scaleFactor * localMean;
if strcmpi(polarity, 'dark')
    T = 1 - T;
end
T = min(max(T, 0), 1);
end
