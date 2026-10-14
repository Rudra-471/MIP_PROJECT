function plotConfusion(ax, metrics, theme)
%PLOTCONFUSION Draw an annotated confusion matrix (dark theme) into axes.
%   plotConfusion(ax, metrics, theme) - metrics from evaluateModel.
%   Rows = dataset label (true class), columns = predicted class. Each cell
%   shows the count and the percentage of its row. Cell colour encodes the
%   row percentage (dark = 0 %, teal = 100 %).

cm = metrics.confusionMatrix;
names = metrics.classNames;
n = numel(names);
rowTotals = max(sum(cm, 2), 1);
fraction = cm ./ repmat(rowTotals, 1, n);

cla(ax);
imagesc(ax, fraction, [0 1]);
ramp = linspace(0, 1, 128)';
colormap(ax, (1 - ramp) * theme.cardAlt + ramp * theme.accentDark);
axis(ax, 'image');
ax.XTick = 1:n;
ax.YTick = 1:n;
ax.XTickLabel = names;
ax.YTickLabel = names;
ax.TickLength = [0 0];
ax.XColor = theme.textMuted;
ax.YColor = theme.textMuted;
ax.FontSize = theme.fontSize.label;
ax.Color = theme.axesBg;
xlabel(ax, 'Predicted class', 'Color', theme.textMuted);
ylabel(ax, 'Dataset label (reference)', 'Color', theme.textMuted);
title(ax, sprintf('Held-out test set (n = %d)', metrics.numSamples), 'Color', theme.text, 'FontWeight', 'normal');
for i = 1:n
    for j = 1:n
        text(ax, j, i, sprintf('%d\n%.1f %%', cm(i, j), 100 * fraction(i, j)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', theme.font, 'FontSize', theme.fontSize.h3, 'FontWeight', 'bold', ...
            'Color', theme.text);
    end
end
end
