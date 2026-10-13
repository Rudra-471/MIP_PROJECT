function h = buildAnalysisPage(parent, theme, ctrl)
%BUILDANALYSISPAGE Image Analysis workspace.
%   Left   : four image viewers (original, enhanced, lung mask, final) and an
%            inspector that switches between histograms and morphology stages
%   Middle : input, enhancement settings, step-by-step pipeline controls
%   Right  : prediction, processing status and the extracted feature table
%   All callbacks go to AppController; enable states come from
%   analysisPrerequisites via AppController.refreshAnalysisControls.

h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg, 'Visible', 'off');
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [1 3], 'ColumnWidth', {'1x', 272, 318}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);

% =========================================================== viewers
viewer = uigridlayout(page, [3 2], 'RowHeight', {'1x', '1x', 218}, 'Padding', [0 0 0 0], ...
                      'RowSpacing', theme.gap, 'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);
viewer.Layout.Column = 1;
panels = {'original', '1  Original X-Ray',           1, 1
          'enhanced', '2  Enhanced X-Ray',           1, 2
          'mask',     '3  Lung Segmentation Mask',   2, 1
          'final',    '4  Final Processed Image',    2, 2};
for k = 1:size(panels, 1)
    [card, body] = uiCard(viewer, theme, panels{k, 2}, [2 1]);
    card.Layout.Row = panels{k, 3};
    card.Layout.Column = panels{k, 4};
    body.RowHeight = {'1x', 18};
    ax = uiImageAxes(body, theme);
    ax.Layout.Row = 1;
    info = uiText(body, theme, '', 'caption', 'WordWrap', 'off');
    info.Layout.Row = 2;
    h.axes.(panels{k, 1}) = ax;
    h.info.(panels{k, 1}) = info;
end

% Inspector: histograms | morphology stages
[inspCard, insp] = uiCard(viewer, theme, '', [2 1]);
inspCard.Layout.Row = 3;
inspCard.Layout.Column = [1 2];
insp.RowHeight = {26, '1x'};
tabs = uigridlayout(insp, [1 4], 'ColumnWidth', {80, 120, 150, '1x'}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', 6, 'BackgroundColor', theme.card);
tabs.Layout.Row = 1;
lbl = uilabel(tabs, 'Text', 'INSPECT', 'FontName', theme.font, 'FontSize', theme.fontSize.caption, ...
    'FontWeight', 'bold', 'FontColor', theme.textMuted);
lbl.Layout.Column = 1;
h.histToggle = uiButton(tabs, theme, 'Histograms', 'secondary', @(~, ~) ctrl.showInspector('histogram'));
h.histToggle.Layout.Column = 2;
h.morphToggle = uiButton(tabs, theme, 'Morphology stages', 'ghost', @(~, ~) ctrl.showInspector('morphology'));
h.morphToggle.Layout.Column = 3;

host = uigridlayout(insp, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', theme.card);
host.Layout.Row = 2;
h.histPanel = uipanel(host, 'BorderType', 'none', 'BackgroundColor', theme.card);
h.histPanel.Layout.Row = 1;
h.histPanel.Layout.Column = 1;
hg = uigridlayout(h.histPanel, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', theme.card);
h.histAxes = uiImageAxes(hg, theme);

h.morphPanel = uipanel(host, 'BorderType', 'none', 'BackgroundColor', theme.card, 'Visible', 'off');
h.morphPanel.Layout.Row = 1;
h.morphPanel.Layout.Column = 1;
host.RowHeight = {'1x'};      % both panels share cell (1,1); undo any auto-added row
host.ColumnWidth = {'1x'};
mg = uigridlayout(h.morphPanel, [1 4], 'ColumnWidth', {'1x', '1x', '1x', 230}, ...
                  'Padding', [0 0 0 0], 'ColumnSpacing', 8, 'BackgroundColor', theme.card);
h.morphAxes = cell(1, 3);
for k = 1:3
    h.morphAxes{k} = uiImageAxes(mg, theme);
    h.morphAxes{k}.Layout.Column = k;
end
h.morphInfo = uiText(mg, theme, '', 'mono', 'VerticalAlignment', 'top');
h.morphInfo.Layout.Column = 4;
h.morphInfo.FontColor = theme.textMuted;
h.morphInfo.FontSize = theme.fontSize.caption;

% =========================================================== controls
controls = uigridlayout(page, [4 1], 'RowHeight', {100, 150, '1x', 122}, 'Padding', [0 0 0 0], ...
                        'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);
controls.Layout.Column = 2;

[c1, b1] = uiCard(controls, theme, 'Input', [2 1]);
c1.Layout.Row = 1;
b1.RowHeight = {32, '1x'};
h.uploadButton = uiButton(b1, theme, 'Upload X-Ray', 'primary', @(~, ~) ctrl.uploadImage());
h.uploadButton.Layout.Row = 1;
h.uploadButton.Tooltip = 'PNG, JPG, JPEG, BMP or TIFF chest radiograph';
h.fileLabel = uiText(b1, theme, 'No image loaded', 'caption');
h.fileLabel.Layout.Row = 2;

[c2, b2] = uiCard(controls, theme, 'Enhancement', [4 1]);
c2.Layout.Row = 2;
b2.RowHeight = {28, 18, '1x', 0};
b2.RowSpacing = 4;
h.method = uidropdown(b2, 'Items', {'Contrast stretching (imadjust)', ...
    'Histogram equalization (histeq)', 'CLAHE (adapthisteq)'}, ...
    'ItemsData', {'stretch', 'histeq', 'clahe'}, 'Value', ctrl.Config.enhance.method, ...
    'BackgroundColor', theme.input, 'FontColor', theme.text, 'FontName', theme.font, ...
    'FontSize', theme.fontSize.label, 'ValueChangedFcn', @(src, ~) ctrl.setEnhancementMethod(src.Value));
h.method.Layout.Row = 1;
h.gammaLabel = uiText(b2, theme, '', 'muted', 'FontSize', theme.fontSize.label);
h.gammaLabel.Layout.Row = 2;
range = ctrl.Config.enhance.gammaRange;
h.gammaSlider = uislider(b2, 'Limits', range, 'Value', ctrl.Config.enhance.gamma, ...
    'MajorTicks', [range(1) 1 2 range(2)], 'MinorTicks', [], 'FontColor', theme.textMuted, ...
    'FontName', theme.font, 'FontSize', theme.fontSize.caption, ...
    'ValueChangingFcn', @(~, evt) ctrl.previewGamma(evt.Value), ...
    'ValueChangedFcn', @(src, ~) ctrl.setGamma(src.Value));
h.gammaSlider.Layout.Row = 3;

steps = AppController.stepList();
stepRows = steps(2:end, :);      % 'load' is the Upload button
[c3, b3] = uiCard(controls, theme, 'Pipeline steps', [size(stepRows, 1) 2]);
c3.Layout.Row = 3;
b3.ColumnWidth = {16, '1x'};
b3.RowHeight = repmat({30}, 1, size(stepRows, 1));
b3.RowSpacing = 6;
for k = 1:size(stepRows, 1)
    key = stepRows{k, 1};
    dot = uilabel(b3, 'Text', char(9679), 'FontSize', 11, 'FontColor', theme.textFaint, ...
                  'HorizontalAlignment', 'center');
    dot.Layout.Row = k; dot.Layout.Column = 1;
    btn = uiButton(b3, theme, stepRows{k, 3}, 'secondary', @(~, ~) ctrl.runStep(key));
    btn.Layout.Row = k; btn.Layout.Column = 2;
    h.stepDots.(key) = dot;
    h.stepButtons.(key) = btn;
end

actions = uigridlayout(controls, [3 1], 'RowHeight', {36, 34, 34}, 'Padding', [0 0 0 0], ...
                       'RowSpacing', 8, 'BackgroundColor', theme.bg);
actions.Layout.Row = 4;
h.runAllButton = uiButton(actions, theme, 'Run Full Analysis', 'primary', @(~, ~) ctrl.runFullAnalysis());
h.runAllButton.Layout.Row = 1;
h.exportButton = uiButton(actions, theme, 'Export Report', 'secondary', @(~, ~) ctrl.exportAnalysisReport());
h.exportButton.Layout.Row = 2;
h.resetButton = uiButton(actions, theme, 'Reset', 'danger', @(~, ~) ctrl.resetAnalysis(true));
h.resetButton.Layout.Row = 3;

% =========================================================== results
results = uigridlayout(page, [3 1], 'RowHeight', {214, 132, '1x'}, 'Padding', [0 0 0 0], ...
                       'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);
results.Layout.Column = 3;

[r1, rb] = uiCard(results, theme, 'Prediction', [6 1]);
r1.Layout.Row = 1;
rb.RowHeight = {38, 'fit', 'fit', 'fit', '1x', 0};
rb.RowSpacing = 4;
h.predictionValue = uilabel(rb, 'Text', 'No prediction', 'FontName', theme.font, ...
    'FontSize', theme.fontSize.value, 'FontWeight', 'bold', 'FontColor', theme.textFaint);
h.predictionValue.Layout.Row = 1;
h.datasetLabel = uiText(rb, theme, 'Dataset label: Not available', 'muted', 'FontSize', theme.fontSize.label);
h.datasetLabel.Layout.Row = 2;
h.scoreLabel = uiText(rb, theme, '', 'caption');
h.scoreLabel.Layout.Row = 3;
h.modelLabel = uiText(rb, theme, '', 'caption');
h.modelLabel.Layout.Row = 4;
h.predictionNote = uiText(rb, theme, '', 'caption', 'VerticalAlignment', 'top');
h.predictionNote.Layout.Row = 5;

[r2, sb] = uiCard(results, theme, 'Processing status', [4 2]);
r2.Layout.Row = 2;
sb.ColumnWidth = {92, '1x'};
sb.RowHeight = repmat({'1x'}, 1, 4);
sb.RowSpacing = 2;
names = {'image', 'Image'; 'segmentation', 'Segmentation'; 'roi', 'Feature ROI'; 'model', 'Model'};
for k = 1:size(names, 1)
    key = uiText(sb, theme, names{k, 2}, 'caption', 'WordWrap', 'off');
    key.Layout.Row = k; key.Layout.Column = 1;
    val = uiText(sb, theme, '-', 'body', 'FontSize', theme.fontSize.label, 'WordWrap', 'off');
    val.Layout.Row = k; val.Layout.Column = 2;
    h.status.(names{k, 1}) = val;
end

[r3, fb] = uiCard(results, theme, 'Extracted features', [2 1]);
r3.Layout.Row = 3;
fb.RowHeight = {'1x', 30};
h.featureTable = uitable(fb, 'Data', cell(0, 3), 'ColumnName', {'Feature', 'Type', 'Value'}, ...
    'RowName', {}, 'ColumnWidth', {96, 82, 'auto'}, 'FontName', theme.font, ...
    'FontSize', theme.fontSize.label, 'BackgroundColor', [theme.card; theme.cardAlt], ...
    'ForegroundColor', theme.text, 'ColumnEditable', false);
h.featureTable.Layout.Row = 1;
h.roiLabel = uiText(fb, theme, 'Features are extracted from the final lung mask.', 'caption');
h.roiLabel.Layout.Row = 2;
end
