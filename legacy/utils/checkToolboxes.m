function [ok, message] = checkToolboxes(throwOnMissing)
%CHECKTOOLBOXES Verify that the required toolboxes are installed/licensed.
%   [ok, message] = checkToolboxes() returns true when both the Image
%   Processing Toolbox and the Statistics and Machine Learning Toolbox are
%   available. checkToolboxes(true) throws 'CXR:missingToolbox' instead.
%
%   Under GNU Octave (used only for automated testing) the equivalent
%   'image' and 'statistics' packages are loaded instead.

if nargin < 1
    throwOnMissing = false;
end

missing = {};
if isOctaveRuntime()
    pkgs = {'image', 'statistics'};
    for k = 1:numel(pkgs)
        try
            pkg('load', pkgs{k});
        catch
            missing{end+1} = sprintf('Octave package "%s"', pkgs{k}); %#ok<AGROW>
        end
    end
else
    required = { ...
        'Image_Toolbox',      'Image Processing Toolbox',            'imbinarize'; ...
        'Statistics_Toolbox', 'Statistics and Machine Learning Toolbox', 'fitcsvm'};
    for k = 1:size(required, 1)
        hasLicense = license('test', required{k, 1});
        hasCode    = exist(required{k, 3}, 'file') == 2;
        if ~(hasLicense && hasCode)
            missing{end+1} = required{k, 2}; %#ok<AGROW>
        end
    end
end

ok = isempty(missing);
if ok
    message = 'All required toolboxes are available.';
else
    message = sprintf('Missing required toolbox(es): %s.', strjoin(missing, ', '));
    if throwOnMissing
        error('CXR:missingToolbox', '%s', message);
    end
end
end
