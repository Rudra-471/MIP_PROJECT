function showEmptyState(ax, theme, message, color)
%SHOWEMPTYSTATE Clear axes and show a centred explanatory message.
%   showEmptyState(ax, theme, message, color) - color defaults to muted text
%   (pass theme.warning for failure states).
if nargin < 4 || isempty(color)
    color = theme.textFaint;
end
cla(ax);
ax.XLim = [0 1];
ax.YLim = [0 1];
ax.XTick = [];
ax.YTick = [];
ax.XColor = 'none';
ax.YColor = 'none';
ax.Color = theme.axesBg;
ax.DataAspectRatioMode = 'auto';
legend(ax, 'off');
title(ax, '');
xlabel(ax, '');
ylabel(ax, '');
text(ax, 0.5, 0.5, message, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'Color', color, 'FontName', theme.font, 'FontSize', theme.fontSize.label, 'Interpreter', 'none');
end
