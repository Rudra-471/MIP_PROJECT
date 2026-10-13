function h = buildEvaluationPage(parent, theme, ctrl)
%BUILDEVALUATIONPAGE Held-out test-set metrics, confusion matrix, model details.
%   Shows "Evaluation pending" until a model has been trained AND evaluated
%   on its patient-wise held-out test set. Filled by AppController.refreshEvaluation.

h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg, 'Visible', 'off');
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [2 1], 'RowHeight', {108, '1x'}, 'Padding', [0 0 0 0], ...
                    'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);

metrics = {'accuracy',    'Accuracy',             '(TP+TN) / all'
           'precision',   'Precision',            'TP / (TP+FP)'
           'sensitivity', 'Sensitivity / Recall', 'TP / (TP+FN)'
           'specificity', 'Specificity',          'TN / (TN+FP)'
           'f1',          'F1-score',             '2PR / (P+R)'
           'samples',     'Evaluated samples',    'held-out test set'};
row = uigridlayout(page, [1 size(metrics, 1)], 'Padding', [0 0 0 0], 'ColumnSpacing', theme.gap, ...
                   'BackgroundColor', theme.bg);
row.Layout.Row = 1;
for k = 1:size(metrics, 1)
    [card, body] = uiCard(row, theme, metrics{k, 2}, [2 1]);
    card.Layout.Column = k;
    body.RowHeight = {34, '1x'};
    value = uiText(body, theme, 'Pending', 'h2', 'WordWrap', 'off');
    value.Layout.Row = 1;
    caption = uiText(body, theme, metrics{k, 3}, 'caption', 'WordWrap', 'off');
    caption.Layout.Row = 2;
    h.metric.(metrics{k, 1}) = struct('value', value, 'caption', caption);
end

bottom = uigridlayout(page, [1 2], 'ColumnWidth', {'1x', '1.15x'}, 'Padding', [0 0 0 0], ...
                      'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);
bottom.Layout.Row = 2;

[cmCard, cmBody] = uiCard(bottom, theme, 'Confusion matrix (positive class = Abnormal)', [2 1]);
cmCard.Layout.Column = 1;
cmBody.RowHeight = {'1x', 34};
h.confusionAxes = uiImageAxes(cmBody, theme);
h.confusionAxes.Layout.Row = 1;
buttons = uigridlayout(cmBody, [1 3], 'ColumnWidth', {'1x', '1x', '1x'}, 'Padding', [0 0 0 0], ...
                       'ColumnSpacing', 8, 'BackgroundColor', theme.card);
buttons.Layout.Row = 2;
h.exportMetricsButton = uiButton(buttons, theme, 'Export Metrics', 'secondary', @(~, ~) ctrl.exportEvaluationResults());
h.exportFigureButton = uiButton(buttons, theme, 'Export Matrix (PNG)', 'secondary', @(~, ~) ctrl.exportConfusionFigure());
h.loadModelButton = uiButton(buttons, theme, 'Load Model...', 'ghost', @(~, ~) ctrl.loadModelFromFile());

right = uigridlayout(bottom, [2 1], 'RowHeight', {'1x', 206}, 'Padding', [0 0 0 0], ...
                     'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);
right.Layout.Column = 2;
[dCard, dBody] = uiCard(right, theme, 'Evaluation details', [1 1]);
dCard.Layout.Row = 1;
h.details = uitextarea(dBody, 'Value', {'Evaluation pending.'}, 'Editable', 'off', ...
    'BackgroundColor', theme.axesBg, 'FontColor', theme.text, 'FontName', theme.font, ...
    'FontSize', theme.fontSize.label);
[sCard, sBody] = uiCard(right, theme, 'Model selection on the validation set (no test data used)', [1 1]);
sCard.Layout.Row = 2;
h.selectionTable = uitable(sBody, 'Data', cell(0, 4), ...
    'ColumnName', {'Kernel', 'BoxConstraint', 'KernelScale', 'Val. balanced acc.'}, 'RowName', {}, ...
    'FontName', theme.font, 'FontSize', theme.fontSize.label, ...
    'BackgroundColor', [theme.card; theme.cardAlt], 'ForegroundColor', theme.text);
end
