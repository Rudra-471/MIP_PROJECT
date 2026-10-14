function saveConfusionFigure(metrics, filePath)
%SAVECONFUSIONFIGURE Save the test-set confusion matrix as a PNG figure.
%   saveConfusionFigure(metrics, filePath) uses confusionchart (Statistics
%   and Machine Learning Toolbox) in an invisible figure. If confusionchart
%   is unavailable, an annotated imagesc plot is drawn instead.

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 620 520]);
cleaner = onCleanup(@() close(fig));
titleText = sprintf('Held-out test set (n = %d), positive class = %s', ...
    metrics.numSamples, metrics.positiveClass);
try
    chart = confusionchart(fig, metrics.confusionMatrix, metrics.classNames, ...
        'Title', titleText, 'RowSummary', 'row-normalized', 'ColumnSummary', 'column-normalized');
    chart.XLabel = 'Predicted class';
    chart.YLabel = 'Dataset label (reference)';
catch
    ax = axes('Parent', fig);
    cm = metrics.confusionMatrix;
    imagesc(ax, cm ./ max(sum(cm, 2), 1), [0 1]);
    colormap(ax, [linspace(1, 0.1, 128)', linspace(1, 0.45, 128)', linspace(1, 0.45, 128)']);
    axis(ax, 'image');
    set(ax, 'XTick', 1:2, 'XTickLabel', metrics.classNames, 'YTick', 1:2, 'YTickLabel', metrics.classNames);
    xlabel(ax, 'Predicted class');
    ylabel(ax, 'Dataset label (reference)');
    title(ax, titleText);
    for i = 1:2
        for j = 1:2
            text(ax, j, i, sprintf('%d', cm(i, j)), 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
        end
    end
end
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, filePath, 'Resolution', 150);
else
    print(fig, filePath, '-dpng', '-r150');
end
end
