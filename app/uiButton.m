function b = uiButton(parent, theme, text, style, callback)
%UIBUTTON Themed push button.
%   b = uiButton(parent, theme, text, style, callback)
%   style: 'primary' (teal, main action) | 'secondary' | 'ghost' | 'danger'

if nargin < 4 || isempty(style)
    style = 'secondary';
end
switch style
    case 'primary'
        bg = theme.accent;   fg = theme.onAccent; weight = 'bold';
    case 'danger'
        bg = theme.cardAlt;  fg = theme.danger;   weight = 'bold';
    case 'ghost'
        bg = theme.card;     fg = theme.textMuted; weight = 'normal';
    otherwise
        bg = theme.input;    fg = theme.text;     weight = 'normal';
end
b = uibutton(parent, 'push', 'Text', text, 'BackgroundColor', bg, 'FontColor', fg, ...
    'FontName', theme.font, 'FontSize', theme.fontSize.label, 'FontWeight', weight);
if nargin >= 5 && ~isempty(callback)
    b.ButtonPushedFcn = callback;
end
end
