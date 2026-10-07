function img = readXrayImage(filePath, cfg)
%READXRAYIMAGE Safely read a chest X-ray image from disk.
%   img = readXrayImage(filePath) validates the file (existence, extension,
%   readability) and returns the raw image (any class, gray or RGB).
%   Indexed images are converted to RGB and alpha channels are dropped.
%
%   Errors (all with readable messages, caught by the GUI):
%     CXR:noImage        - empty path / nothing selected
%     CXR:fileNotFound   - file does not exist
%     CXR:invalidFormat  - extension is not JPG/JPEG/PNG/BMP
%     CXR:corruptImage   - the file cannot be decoded as an image

if nargin < 2
    cfg = getConfig();
end
if nargin < 1 || isempty(filePath) || isequal(filePath, 0)
    error('CXR:noImage', 'No image was selected.');
end
filePath = char(filePath);
if exist(filePath, 'file') ~= 2
    error('CXR:fileNotFound', 'Image file not found: %s', filePath);
end

[~, ~, ext] = fileparts(filePath);
if ~any(strcmpi(ext, cfg.supportedExtensions))
    error('CXR:invalidFormat', ...
        'Unsupported file format "%s". Supported formats: %s.', ...
        ext, strjoin(upper(strrep(cfg.supportedExtensions, '.', '')), ', '));
end

try
    [img, map] = imread(filePath);
catch readError
    error('CXR:corruptImage', ...
        'The file "%s" could not be read as an image (it may be corrupted): %s', ...
        filePath, readError.message);
end

if isempty(img)
    error('CXR:corruptImage', 'The file "%s" contains no image data.', filePath);
end
if ~isempty(map)
    img = ind2rgb(img, map);        % indexed colour -> RGB
end
if ndims(img) == 3 && size(img, 3) == 4
    img = img(:, :, 1:3);           % drop alpha channel
end
if ndims(img) > 3 || ~any(size(img, 3) == [1 3])
    error('CXR:corruptImage', 'Unsupported image layout (size %s).', mat2str(size(img)));
end
if min(size(img, 1), size(img, 2)) < 32
    error('CXR:invalidFormat', 'Image is too small (%dx%d) to be a chest X-ray.', ...
        size(img, 1), size(img, 2));
end
end
