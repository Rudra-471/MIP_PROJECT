function [file, folder] = uiputfile(varargin)
% TEST SHIM: returns the next path queued in MOCK_UI.files (0 = cancel).
global MOCK_UI
p = MOCK_UI.files{1};
MOCK_UI.files(1) = [];
if isequal(p, 0)
    file = 0; folder = 0;
else
    [folder, name, ext] = fileparts(p);
    file = [name ext];
end
end
