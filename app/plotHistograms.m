function plotHistograms(ax, histOriginal, histEnhanced, theme, enhancedName)
%PLOTHISTOGRAMS Overlay the original and enhanced intensity histograms.
%   plotHistograms(ax, histOriginal, histEnhanced, theme, enhancedName)
%   Inputs come from computeHistogramData. histEnhanced may be empty.
%   X axis: pixel intensity (0 = black, 1 = white); Y axis: pixel count.

cla(ax);
hold(ax, 'on');
handles = gobjects(0);
names = {};
if ~isempty(histOriginal)
    handles(end + 1) = area(ax, histOriginal.binCenters, histOriginal.counts, ...
        'FaceColor', theme.info, 'FaceAlpha', 0.35, 'EdgeColor', theme.info, 'LineWidth', 1.2);
    names{end + 1} = 'Original (grayscale)';
end
if ~isempty(histEnhanced)
    handles(end + 1) = area(ax, histEnhanced.binCenters, histEnhanced.counts, ...
        'FaceColor', theme.accent, 'FaceAlpha', 0.35, 'EdgeColor', theme.accent, 'LineWidth', 1.2);
    names{end + 1} = enhancedName;
end
hold(ax, 'off');

ax.XLim = [0 1];
ax.YLimMode = 'auto';
ax.XTickMode = 'auto';
ax.YTickMode = 'auto';
ax.XColor = theme.textMuted;
ax.YColor = theme.textMuted;
ax.Color = theme.axesBg;
ax.DataAspectRatioMode = 'auto';
ax.XGrid = 'on';
ax.YGrid = 'on';
ax.GridColor = theme.border;
ax.GridAlpha = 0.6;
xlabel(ax, 'Pixel Intensity', 'Color', theme.textMuted);
ylabel(ax, 'Pixel Count', 'Color', theme.textMuted);
title(ax, 'Intensity histogram: original vs. enhanced', 'Color', theme.text, 'FontWeight', 'normal');
if ~isempty(handles)
    lgd = legend(ax, handles, names, 'Location', 'northeast');
    lgd.TextColor = theme.text;
    lgd.Color = theme.card;
    lgd.EdgeColor = theme.border;
end
end
