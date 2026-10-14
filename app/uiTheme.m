function t = uiTheme()
%UITHEME Colour palette, typography and spacing of the dashboard.
%   Dark navy medical-imaging theme: neutral surfaces, teal accent, and
%   status colours used only for meaning (success / warning / error).

t = struct();
% Surfaces (darkest -> lightest)
t.sidebar   = [0.043 0.063 0.098];   % #0B1019
t.bg        = [0.063 0.086 0.129];   % #101621
t.card      = [0.098 0.125 0.180];   % #19202E
t.cardAlt   = [0.125 0.157 0.220];   % #202838
t.input     = [0.141 0.176 0.243];   % #242D3E
t.border    = [0.180 0.220 0.290];   % #2E384A
t.axesBg    = [0.051 0.071 0.106];   % #0D121B  (image viewers)

% Text
t.text      = [0.925 0.945 0.965];   % primary
t.textMuted = [0.600 0.650 0.725];   % secondary
t.textFaint = [0.420 0.470 0.545];   % captions / disabled

% Accent and status
t.accent     = [0.180 0.788 0.769];  % teal  #2EC9C4
t.accentDark = [0.106 0.478 0.471];
t.onAccent   = [0.031 0.090 0.098];  % text on accent buttons
t.success    = [0.322 0.788 0.502];  % green
t.warning    = [0.961 0.729 0.278];  % amber
t.danger     = [0.906 0.384 0.384];  % restrained red
t.info       = [0.400 0.640 0.960];  % blue (secondary data series)

% Typography
if ispc
    t.font = 'Segoe UI';
elseif ismac
    t.font = 'Helvetica Neue';
else
    t.font = 'Helvetica';
end
t.monoFont = 'Consolas';
if ~ispc
    t.monoFont = 'Courier New';
end
t.fontSize = struct('caption', 11, 'body', 13, 'label', 12, 'h3', 14, 'h2', 17, 'h1', 22, 'value', 26, 'hero', 28);

% Spacing
t.pad = 16;
t.gap = 12;
end
