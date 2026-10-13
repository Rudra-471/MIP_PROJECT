function uiPill(lbl, theme, text, state)
%UIPILL Turn a label into a status chip: coloured text on a tinted background.
%   uiPill(lbl, theme, text, state), state: 'ok' | 'warn' | 'error' | 'info' | 'neutral'
switch state
    case 'ok',    c = theme.success;
    case 'warn',  c = theme.warning;
    case 'error', c = theme.danger;
    case 'info',  c = theme.accent;
    otherwise,    c = theme.textMuted;
end
lbl.Text = text;
lbl.FontColor = c;
lbl.BackgroundColor = 0.82 * theme.card + 0.18 * c;   % subtle tint of the state colour
lbl.HorizontalAlignment = 'center';
lbl.FontWeight = 'bold';
end
