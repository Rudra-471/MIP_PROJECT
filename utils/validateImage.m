function [img, info] = validateImage(source, cfg)
%VALIDATEIMAGE Read (if needed) and validate a chest X-ray image.
%   [img, info] = validateImage(filePath) reads the file with imread after
%   checking that it exists and has a supported extension, then validates
%   the pixel data. [img, info] = validateImage(array) validates an image
%   already in memory.
%
%   img  - original pixel data (class preserved: uint8, uint16, double, ...),
%          grayscale (H x W) or RGB (H x W x 3). Indexed images are converted
%          to RGB and alpha channels are dropped.
%   info - struct: fileName, filePath, format, width, height, channels,
%          colorType ('grayscale' | 'rgb'), bitDepth, class
%
%   Errors (identifiers are caught and shown by the GUI):
%     CXR:noImage        nothing selected / empty input
%     CXR:fileNotFound   file does not exist
%     CXR:invalidFormat  unsupported extension or unsupported pixel layout
%     CXR:corruptImage   the file cannot be decoded
%     CXR:invalidSize    image smaller/larger than the configured limits

if nargin < 2 || isempty(cfg)
    cfg = appConfig();
end
info = struct('fileName', '', 'filePath', '', 'format', '', 'width', 0, 'height', 0, ...
              'channels', 0, 'colorType', '', 'bitDepth', 0, 'class', '');

if nargin < 1 || isempty(source) || isequal(source, 0)
    error('CXR:noImage', 'No image was selected.');
end

if ischar(source) || (isstring(source) && isscalar(source))
    filePath = char(source);
    if exist(filePath, 'file') ~= 2
        error('CXR:fileNotFound', 'Image file not found: %s', filePath);
    end
    [~, name, ext] = fileparts(filePath);
    if ~any(strcmpi(ext, cfg.input.supportedExtensions))
        error('CXR:invalidFormat', 'Unsupported file type "%s". Supported: %s.', ext, ...
            strjoin(upper(strrep(cfg.input.supportedExtensions, '.', '')), ', '));
    end
    try
        [img, map] = imread(filePath);
    catch readError
        error('CXR:corruptImage', 'The file "%s" could not be decoded as an image: %s', ...
            [name ext], readError.message);
    end
    if ~isempty(map)
        img = ind2rgb(img, map);   % indexed colour -> RGB (double)
    end
    info.fileName = [name ext];
    info.filePath = filePath;
    info.format = upper(strrep(ext, '.', ''));
elseif isnumeric(source) || islogical(source)
    img = source;
    info.fileName = '(in-memory image)';
    info.format = 'array';
else
    error('CXR:invalidFormat', 'Input must be a file path or a numeric image array.');
end

if isempty(img)
    error('CXR:corruptImage', 'The image contains no pixel data.');
end
if ndims(img) == 3 && size(img, 3) == 4
    img = img(:, :, 1:3);          % drop alpha channel
end
if ndims(img) > 3 || ~any(size(img, 3) == [1 3])
    error('CXR:invalidFormat', 'Unsupported image layout %s (expected H x W or H x W x 3).', ...
        mat2str(size(img)));
end
if ~(isnumeric(img) || islogical(img)) || ~isreal(img)
    error('CXR:invalidFormat', 'Pixel data must be real-valued numeric data.');
end
if isfloat(img) && any(~isfinite(img(:)))
    error('CXR:corruptImage', 'The image contains NaN or Inf pixel values.');
end

[h, w, c] = size(img);
if min(h, w) < cfg.input.minDimension
    error('CXR:invalidSize', 'Image is too small (%d x %d pixels); at least %d pixels per side are required.', ...
        w, h, cfg.input.minDimension);
end
if max(h, w) > cfg.input.maxDimension
    error('CXR:invalidSize', 'Image is too large (%d x %d pixels); the limit is %d pixels per side.', ...
        w, h, cfg.input.maxDimension);
end

info.width = w;
info.height = h;
info.channels = c;
info.class = class(img);
if c == 3
    info.colorType = 'rgb';
else
    info.colorType = 'grayscale';
end
switch class(img)
    case {'uint8', 'int8'},   info.bitDepth = 8 * c;
    case {'uint16', 'int16'}, info.bitDepth = 16 * c;
    case 'logical',           info.bitDepth = 1;
    otherwise,                info.bitDepth = 64 * c;
end
end
