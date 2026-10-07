function bw = imbinarize(img, level)
% TEST SHIM (Octave only) - see README.md in this folder.
img = im2double(img);
if nargin < 2 || ischar(level)
    level = graythresh(img);
end
bw = img > level;
end
