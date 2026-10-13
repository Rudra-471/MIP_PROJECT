function d = uiprogressdlg(varargin)
% TEST SHIM: progress dialog that never requests cancellation.
d = MockComponent('uiprogressdlg', varargin{:});
d.CancelRequested = false;
end
