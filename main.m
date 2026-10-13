function ctrl = main()
%MAIN Start the Chest X-Ray Abnormality Detection dashboard.
%   In MATLAB, cd into the project folder and run:
%       main
%   The project folders are added to the path, the required toolboxes are
%   checked, and the dashboard opens. If a trained model exists in
%   models/trainedModel.mat it is loaded automatically.
%
%   Requirements: MATLAB R2021a or newer, Image Processing Toolbox,
%   Statistics and Machine Learning Toolbox (see requirements.md).
%
%   This project is intended for educational and research purposes only.
%   Its predictions are not a medical diagnosis and must not be used for
%   clinical decision-making.

root = fileparts(mfilename('fullpath'));
addpath(root);
setupProject();

deps = checkDependencies(false);
if ~deps.uiAvailable
    error('CXR:missingToolbox', ['The dashboard needs MATLAB R2021a or newer (uifigure / ' ...
        'uigridlayout). GNU Octave is supported only for the automated tests ' ...
        '(tests/runAllTests.m).\n%s'], deps.message);
end
if ~deps.ok
    warning('CXR:missingToolbox', '%s', deps.message);   % the app shows the same message
end
logMessage('INFO', 'Starting dashboard (%s).', version);
app = launchApp();
if nargout > 0
    ctrl = app;
end
end
