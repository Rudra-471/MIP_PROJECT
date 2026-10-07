function out = imgaussfilt(img, sigma)
% TEST SHIM (Octave only) - see README.md in this folder.
if nargin < 2, sigma = 0.5; end
sz = 2 * ceil(2 * sigma) + 1;
kernel = fspecial('gaussian', sz, sigma);
out = imfilter(img, kernel, 'replicate');
end
