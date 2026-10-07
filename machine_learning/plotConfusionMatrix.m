function plotConfusionMatrix(ax, confusionMatrix, classNames, titleText)
%PLOTCONFUSIONMATRIX Draw an annotated confusion matrix into axes ax.
%   Works with regular axes and App Designer uiaxes. Rows = true class,
%   columns = predicted class. Each cell shows the count and the
%   percentage of its true-class row.

if nargin < 4
    titleText = 'Confusion matrix';
end
cla(ax);
numClasses = numel(classNames);
rowTotals = max(sum(confusionMatrix, 2), 1);
rowFraction = confusionMatrix ./ repmat(rowTotals, 1, numClasses);

imagesc(ax, rowFraction, [0 1]);
whiteToBlue = [linspace(1, 0.10, 256)', linspace(1, 0.30, 256)', linspace(1, 0.60, 256)'];
colormap(ax, whiteToBlue);
axis(ax, 'image');
set(ax, 'XTick', 1:numClasses, 'XTickLabel', classNames, ...
        'YTick', 1:numClasses, 'YTickLabel', classNames, 'TickLength', [0 0]);
xlabel(ax, 'Predicted class');
ylabel(ax, 'True class');
title(ax, titleText);
for i = 1:numClasses
    for j = 1:numClasses
        if rowFraction(i, j) > 0.5
            textColor = [1 1 1];
        else
            textColor = [0 0 0];
        end
        text(ax, j, i, sprintf('%d\n(%.1f%%)', confusionMatrix(i, j), 100 * rowFraction(i, j)), ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', textColor);
    end
end
end
