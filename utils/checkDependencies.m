function report = checkDependencies(throwOnMissing)
%CHECKDEPENDENCIES Verify that the required MATLAB products and functions exist.
%   report = checkDependencies() returns a struct with fields
%     ok          - true when everything required is available
%     missing     - cellstr of missing products / functions
%     uiAvailable - true when the uifigure-based dashboard can be created
%     message     - human-readable summary
%   checkDependencies(true) throws CXR:missingToolbox when something is missing.
%
%   Required:
%     Image Processing Toolbox                 (imadjust, adapthisteq, graycomatrix, ...)
%     Statistics and Machine Learning Toolbox  (fitcsvm, predict, confusionmat)
%   Under GNU Octave (used only for automated tests) the "image" and
%   "statistics" packages are loaded instead and the GUI is reported as
%   unavailable, because Octave does not implement uifigure.

if nargin < 1
    throwOnMissing = false;
end

missing = {};
if isOctaveRuntime()
    for pkgName = {'image', 'statistics'}
        try
            pkg('load', pkgName{1});
        catch
            missing{end+1} = sprintf('Octave package "%s"', pkgName{1}); %#ok<AGROW>
        end
    end
    requiredFunctions = {'medfilt2', 'imadjust', 'histeq', 'imhist', 'imerode', 'imdilate', ...
        'imopen', 'imclose', 'imfill', 'bwconncomp', 'regionprops', 'graycomatrix', ...
        'entropy', 'fitcsvm', 'confusionmat'};
    uiAvailable = false;
else
    products = { ...
        'Image_Toolbox',      'Image Processing Toolbox'; ...
        'Statistics_Toolbox', 'Statistics and Machine Learning Toolbox'};
    for k = 1:size(products, 1)
        if ~license('test', products{k, 1})
            missing{end+1} = sprintf('%s (no licence)', products{k, 2}); %#ok<AGROW>
        end
    end
    requiredFunctions = {'rgb2gray', 'medfilt2', 'imgaussfilt', 'imhist', 'imadjust', ...
        'histeq', 'adapthisteq', 'imbinarize', 'adaptthresh', 'graythresh', 'imerode', ...
        'imdilate', 'imopen', 'imclose', 'imfill', 'bwareaopen', 'imclearborder', ...
        'bwconncomp', 'regionprops', 'graycomatrix', 'graycoprops', 'entropy', ...
        'fitcsvm', 'confusionmat'};
    uiAvailable = exist('uifigure', 'file') ~= 0 && exist('uigridlayout', 'file') ~= 0;
    if ~uiAvailable
        missing{end+1} = 'uifigure / uigridlayout (MATLAB R2021a or newer is required for the GUI)';
    end
end

for k = 1:numel(requiredFunctions)
    if exist(requiredFunctions{k}, 'file') == 0 && exist(requiredFunctions{k}, 'builtin') == 0
        missing{end+1} = sprintf('function %s', requiredFunctions{k}); %#ok<AGROW>
    end
end

report = struct();
report.ok = isempty(missing);
report.missing = missing;
report.uiAvailable = uiAvailable;
if report.ok
    report.message = 'All required toolboxes and functions are available.';
else
    report.message = sprintf(['Missing dependencies: %s.\nInstall the Image Processing ' ...
        'Toolbox and the Statistics and Machine Learning Toolbox (see requirements.md).'], ...
        strjoin(missing, '; '));
    if throwOnMissing
        error('CXR:missingToolbox', '%s', report.message);
    end
end
end
