function choice = uiconfirm(~, ~, ~, varargin)
% TEST SHIM: answers with the next entry of MOCK_UI.answers.
global MOCK_UI
choice = MOCK_UI.answers{1};
MOCK_UI.answers(1) = [];
end
