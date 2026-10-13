function lbl = uiText(parent, theme, text, style, varargin)
%UITEXT Themed label.
%   lbl = uiText(parent, theme, text, style, Name, Value, ...)
%   style: 'h1' | 'h2' | 'h3' | 'body' | 'muted' | 'caption' | 'value' | 'mono'
%   Extra name/value pairs are passed to uilabel (e.g. 'HorizontalAlignment').

if nargin < 4 || isempty(style)
    style = 'body';
end
color = theme.text;
weight = 'normal';
font = theme.font;
switch style
    case 'h1',      size = theme.fontSize.h1;      weight = 'bold';
    case 'h2',      size = theme.fontSize.h2;      weight = 'bold';
    case 'h3',      size = theme.fontSize.h3;      weight = 'bold';
    case 'value',   size = theme.fontSize.value;   weight = 'bold';
    case 'muted',   size = theme.fontSize.body;    color = theme.textMuted;
    case 'caption', size = theme.fontSize.caption; color = theme.textFaint;
    case 'mono',    size = theme.fontSize.label;   font = theme.monoFont;
    otherwise,      size = theme.fontSize.body;
end
lbl = uilabel(parent, 'Text', text, 'FontName', font, 'FontSize', size, ...
    'FontWeight', weight, 'FontColor', color, 'WordWrap', 'on', varargin{:});
end
