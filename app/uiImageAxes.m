function ax = uiImageAxes(parent, theme)
%UIIMAGEAXES Create a dark, non-interactive axes for image or chart display.
ax = uiaxes(parent);
ax.BackgroundColor = theme.card;
ax.Color = theme.axesBg;
ax.XColor = theme.textMuted;
ax.YColor = theme.textMuted;
ax.GridColor = theme.border;
ax.FontName = theme.font;
ax.FontSize = theme.fontSize.caption;
ax.Box = 'off';
ax.XTick = [];
ax.YTick = [];
ax.Title.Color = theme.text;
try
    ax.Toolbar.Visible = 'off';
    disableDefaultInteractivity(ax);
catch
    % older releases: interactivity controls not available
end
end
