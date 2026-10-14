function folder = uigetdir(varargin)
% TEST SHIM: returns the next folder queued in MOCK_UI.files (0 = cancel).
global MOCK_UI
folder = MOCK_UI.files{1};
MOCK_UI.files(1) = [];
end
