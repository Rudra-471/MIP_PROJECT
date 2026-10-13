function h = buildTopBar(parent, theme, ctrl)
%BUILDTOPBAR Page title, workflow status, dataset/model chips, reset + home.
%   Chips and buttons are 30 px high and vertically centred (row 2 of a
%   3-row grid); the title block spans all rows.
grid = uigridlayout(parent, [3 5], 'ColumnWidth', {'1x', 230, 200, 92, 108}, ...
                    'RowHeight', {'1x', 30, '1x'}, 'Padding', [18 8 18 8], 'RowSpacing', 0, ...
                    'ColumnSpacing', 10, 'BackgroundColor', theme.sidebar);
grid.Layout.Row = 1;

titleGrid = uigridlayout(grid, [2 1], 'RowHeight', {'1x', '1x'}, 'Padding', [0 0 0 0], ...
                         'RowSpacing', 0, 'BackgroundColor', theme.sidebar);
titleGrid.Layout.Row = [1 3];
titleGrid.Layout.Column = 1;

h = struct();
h.title = uilabel(titleGrid, 'Text', 'Dashboard', 'FontName', theme.font, 'FontSize', theme.fontSize.h2, ...
    'FontWeight', 'bold', 'FontColor', theme.text, 'VerticalAlignment', 'bottom');
h.title.Layout.Row = 1;
h.status = uilabel(titleGrid, 'Text', 'No image loaded', 'FontName', theme.font, ...
    'FontSize', theme.fontSize.label, 'FontColor', theme.textMuted, 'VerticalAlignment', 'top');
h.status.Layout.Row = 2;

h.datasetChip = uilabel(grid, 'Text', '', 'FontName', theme.font, 'FontSize', theme.fontSize.caption);
h.datasetChip.Layout.Row = 2;
h.datasetChip.Layout.Column = 2;
uiPill(h.datasetChip, theme, 'Dataset: not configured', 'neutral');

h.modelChip = uilabel(grid, 'Text', '', 'FontName', theme.font, 'FontSize', theme.fontSize.caption);
h.modelChip.Layout.Row = 2;
h.modelChip.Layout.Column = 3;
uiPill(h.modelChip, theme, 'Model: not trained', 'neutral');

h.resetButton = uiButton(grid, theme, 'Reset', 'ghost', @(~, ~) ctrl.resetAnalysis(true));
h.resetButton.Layout.Row = 2;
h.resetButton.Layout.Column = 4;
h.resetButton.Tooltip = 'Clear the current image and all analysis results';

h.homeButton = uiButton(grid, theme, 'Dashboard', 'secondary', @(~, ~) ctrl.navigate('dashboard'));
h.homeButton.Layout.Row = 2;
h.homeButton.Layout.Column = 5;
end
