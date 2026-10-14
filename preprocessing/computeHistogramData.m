function hist = computeHistogramData(img, numBins)
%COMPUTEHISTOGRAMDATA Intensity histogram (imhist) of a grayscale image.
%   hist = computeHistogramData(img, numBins) returns a struct with
%     counts      - pixel count per bin (column vector)
%     binCenters  - bin centre intensities in [0, 1] (column vector)
%     mean, std, min, max - summary statistics of the intensities
%     numPixels
%   Axes convention used by the GUI: x = pixel intensity, y = pixel count.

if nargin < 2 || isempty(numBins)
    numBins = 64;
end
img = im2double(img);
if size(img, 3) == 3
    img = rgb2gray(img);
end
[counts, binCenters] = imhist(img, numBins);
hist = struct();
hist.counts     = double(counts(:));
hist.binCenters = double(binCenters(:));
hist.mean       = mean(img(:));
hist.std        = std(img(:));
hist.min        = min(img(:));
hist.max        = max(img(:));
hist.numPixels  = numel(img);
end
