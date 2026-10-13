function uialert(~, message, titleText, varargin)
% TEST SHIM: records alerts in the global MOCK_UI.alerts list.
global MOCK_UI
icon = 'error';
k = find(strcmp(varargin, 'Icon'), 1);
if ~isempty(k), icon = varargin{k + 1}; end
MOCK_UI.alerts{end + 1} = struct('title', titleText, 'message', message, 'icon', icon);
end
