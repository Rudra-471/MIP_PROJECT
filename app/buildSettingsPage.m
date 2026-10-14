function h = buildSettingsPage(parent, theme, ctrl)
%BUILDSETTINGSPAGE Processing parameters used for analysis and for new training runs.
%   A trained model always keeps the configuration it was trained with;
%   these settings affect the Image Analysis display and future training.

cfg = ctrl.Config;
h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg, 'Visible', 'off');
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [2 3], 'RowHeight', {196, '1x'}, 'ColumnWidth', {'1x', '1x', '1x'}, ...
                    'Padding', [0 0 0 0], 'RowSpacing', theme.gap, 'ColumnSpacing', theme.gap, ...
                    'BackgroundColor', theme.bg);
style = {'BackgroundColor', theme.input, 'FontColor', theme.text, 'FontName', theme.font, ...
         'FontSize', theme.fontSize.label};

% ---- Preprocessing ------------------------------------------------------------------
[c1, b1] = uiCard(page, theme, 'Preprocessing', [4 2]);
c1.Layout.Row = 1; c1.Layout.Column = 1;
prepGrid(b1);
h.processingSize = uidropdown(b1, 'Items', {'256 px', '512 px (default)', '768 px'}, ...
    'ItemsData', {256, 512, 768}, 'Value', cfg.preprocess.processingSize, style{:});
place(b1, theme, 1, 'Processing size (longest side)', h.processingSize);
h.noiseMethod = uidropdown(b1, 'Items', {'Median filter', 'Gaussian filter', 'None'}, ...
    'ItemsData', {'median', 'gaussian', 'none'}, 'Value', cfg.preprocess.noiseMethod, style{:});
place(b1, theme, 2, 'Noise reduction', h.noiseMethod);
h.medianWindow = uidropdown(b1, 'Items', {'3 x 3', '5 x 5'}, 'ItemsData', {3, 5}, ...
    'Value', cfg.preprocess.medianWindow(1), style{:});
place(b1, theme, 3, 'Median window', h.medianWindow);
h.gaussianSigma = uieditfield(b1, 'numeric', 'Value', cfg.preprocess.gaussianSigma, ...
    'Limits', [0.3 3], 'ValueDisplayFormat', '%.2f', style{:});
place(b1, theme, 4, 'Gaussian sigma', h.gaussianSigma);

% ---- Enhancement + features -------------------------------------------------------------
[c2, b2] = uiCard(page, theme, 'Enhancement and features', [4 2]);
c2.Layout.Row = 1; c2.Layout.Column = 2;
prepGrid(b2);
h.claheClip = uieditfield(b2, 'numeric', 'Value', cfg.enhance.claheClipLimit, ...
    'Limits', [0.001 0.1], 'ValueDisplayFormat', '%.3f', style{:});
place(b2, theme, 1, 'CLAHE clip limit', h.claheClip);
h.claheTiles = uidropdown(b2, 'Items', {'4 x 4', '8 x 8', '16 x 16'}, 'ItemsData', {4, 8, 16}, ...
    'Value', cfg.enhance.claheNumTiles(1), style{:});
place(b2, theme, 2, 'CLAHE tiles', h.claheTiles);
h.glcmLevels = uidropdown(b2, 'Items', {'8', '16', '32', '64'}, 'ItemsData', {8, 16, 32, 64}, ...
    'Value', cfg.features.glcmNumLevels, style{:});
place(b2, theme, 3, 'GLCM grey levels', h.glcmLevels);
h.stretchTol = uieditfield(b2, 'numeric', 'Value', 100 * cfg.enhance.stretchTolerance(1), ...
    'Limits', [0 5], 'ValueDisplayFormat', '%.1f %%', style{:});
place(b2, theme, 4, 'Stretching saturation (each end)', h.stretchTol);

% ---- Morphology ----------------------------------------------------------------------------
[c3, b3] = uiCard(page, theme, 'Morphology (disk radius, pixels)', [4 2]);
c3.Layout.Row = 1; c3.Layout.Column = 3;
prepGrid(b3);
radii = {'openRadius', 'Opening', [1 15]; 'closeRadius', 'Closing', [1 30]; ...
         'erodeRadius', 'Erosion', [0 10]; 'dilateRadius', 'Dilation', [0 10]};
for k = 1:size(radii, 1)
    field = uieditfield(b3, 'numeric', 'Value', cfg.morph.(radii{k, 1}), 'Limits', radii{k, 3}, ...
        'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%d', style{:});
    place(b3, theme, k, radii{k, 2}, field);
    h.(radii{k, 1}) = field;
end

% ---- Actions + explanation ---------------------------------------------------------------
[c4, b4] = uiCard(page, theme, 'Apply', [2 3]);
c4.Layout.Row = 2; c4.Layout.Column = [1 3];
b4.RowHeight = {34, '1x'};
b4.ColumnWidth = {180, 180, '1x'};
h.applyButton = uiButton(b4, theme, 'Apply Settings', 'primary', @(~, ~) ctrl.applySettings());
h.applyButton.Layout.Row = 1; h.applyButton.Layout.Column = 1;
h.defaultsButton = uiButton(b4, theme, 'Restore Defaults', 'secondary', @(~, ~) ctrl.restoreDefaultSettings());
h.defaultsButton.Layout.Row = 1; h.defaultsButton.Layout.Column = 2;
h.note = uiText(b4, theme, ['Applying settings clears the current analysis results. ' ...
    'A trained model keeps the configuration it was trained with: predictions always ' ...
    're-process the image with the model''s own settings when they differ from these. ' ...
    'New settings take effect for the next training run.'], 'muted', 'VerticalAlignment', 'top');
h.note.Layout.Row = 2; h.note.Layout.Column = [1 3];
h.state = uiText(b4, theme, '', 'caption', 'WordWrap', 'off');
h.state.Layout.Row = 1; h.state.Layout.Column = 3;
end

function prepGrid(grid)
grid.ColumnWidth = {'1x', 130};
grid.RowHeight = repmat({28}, 1, 4);
grid.RowSpacing = 8;
end

function place(grid, theme, row, labelText, component)
lab = uiText(grid, theme, labelText, 'muted', 'FontSize', theme.fontSize.label, 'WordWrap', 'off');
lab.Layout.Row = row;
lab.Layout.Column = 1;
component.Layout.Row = row;
component.Layout.Column = 2;
end
