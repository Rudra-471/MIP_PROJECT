function h = buildTrainingPage(parent, theme, ctrl)
%BUILDTRAININGPAGE Dataset configuration, validation and SVM training page.
%   Left : dataset folder + metadata CSV, subset/split options, Start Training
%   Right: dataset summary, planned patient-wise subset, validation
%          messages, training progress and log

cfg = ctrl.Config;
h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg, 'Visible', 'off');
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [1 2], 'ColumnWidth', {360, '1x'}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);

% =========================================================== left column
left = uigridlayout(page, [4 1], 'RowHeight', {196, '1x', 44, 34}, 'Padding', [0 0 0 0], ...
                    'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);
left.Layout.Column = 1;

[c1, b1] = uiCard(left, theme, 'NIH ChestX-ray14 dataset', [6 2]);
c1.Layout.Row = 1;
b1.ColumnWidth = {'1x', 78};
b1.RowHeight = {16, 28, 16, 28, 6, 30};
b1.RowSpacing = 4;
l = uiText(b1, theme, 'Dataset folder (contains images_001 ... images_012)', 'caption');
l.Layout.Row = 1; l.Layout.Column = [1 2];
h.datasetField = uieditfield(b1, 'text', 'Value', '', 'Editable', 'off', ...
    'BackgroundColor', theme.input, 'FontColor', theme.text, 'FontName', theme.font, 'FontSize', theme.fontSize.caption);
h.datasetField.Layout.Row = 2; h.datasetField.Layout.Column = 1;
b = uiButton(b1, theme, 'Browse', 'secondary', @(~, ~) ctrl.browseDataset());
b.Layout.Row = 2; b.Layout.Column = 2;
l = uiText(b1, theme, 'Metadata CSV (Data_Entry_2017_v2020.csv, detected automatically)', 'caption');
l.Layout.Row = 3; l.Layout.Column = [1 2];
h.metadataField = uieditfield(b1, 'text', 'Value', '', 'Editable', 'off', ...
    'BackgroundColor', theme.input, 'FontColor', theme.text, 'FontName', theme.font, 'FontSize', theme.fontSize.caption);
h.metadataField.Layout.Row = 4; h.metadataField.Layout.Column = 1;
b = uiButton(b1, theme, 'Browse', 'secondary', @(~, ~) ctrl.browseMetadata());
b.Layout.Row = 4; b.Layout.Column = 2;
h.scanButton = uiButton(b1, theme, 'Scan & Validate Dataset', 'secondary', @(~, ~) ctrl.scanDataset());
h.scanButton.Layout.Row = 6; h.scanButton.Layout.Column = [1 2];

[c2, b2] = uiCard(left, theme, 'Subset and split', [9 2]);
c2.Layout.Row = 2;
b2.ColumnWidth = {'1x', 120};
b2.RowHeight = repmat({26}, 1, 9);
b2.RowSpacing = 6;
numericStyle = {'BackgroundColor', theme.input, 'FontColor', theme.text, 'FontName', theme.font, ...
                'FontSize', theme.fontSize.label};
h.subsetSize = uieditfield(b2, 'numeric', 'Value', cfg.dataset.subsetSize, 'Limits', [20 112120], ...
    'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%d', numericStyle{:});
addOption(b2, theme, 1, 'Requested subset size (images)', h.subsetSize);
h.balance = uidropdown(b2, 'Items', {'Balanced', 'Natural'}, 'ItemsData', {true, false}, ...
    'Value', cfg.dataset.balanceClasses, numericStyle{:});
addOption(b2, theme, 2, 'Class balance', h.balance);
h.views = uidropdown(b2, 'Items', {'PA only', 'PA + AP'}, 'ItemsData', {'PA', 'PA+AP'}, ...
    'Value', 'PA', numericStyle{:});
addOption(b2, theme, 3, 'View positions', h.views);
h.maxPerPatient = uidropdown(b2, 'Items', {'1', '2', '5', 'All'}, 'ItemsData', {1, 2, 5, Inf}, ...
    'Value', cfg.dataset.maxImagesPerPatient, numericStyle{:});
addOption(b2, theme, 4, 'Max images per patient', h.maxPerPatient);
h.testFraction = uieditfield(b2, 'numeric', 'Value', cfg.dataset.testFraction, 'Limits', [0.05 0.5], ...
    'ValueDisplayFormat', '%.2f', numericStyle{:});
addOption(b2, theme, 5, 'Test fraction (no official list)', h.testFraction);
h.valFraction = uieditfield(b2, 'numeric', 'Value', cfg.dataset.validationFraction, 'Limits', [0.05 0.5], ...
    'ValueDisplayFormat', '%.2f', numericStyle{:});
addOption(b2, theme, 6, 'Validation fraction', h.valFraction);
h.seed = uieditfield(b2, 'numeric', 'Value', cfg.dataset.randomSeed, 'Limits', [0 1e6], ...
    'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%d', numericStyle{:});
addOption(b2, theme, 7, 'Random seed', h.seed);
h.kernels = uidropdown(b2, 'Items', {'Linear + RBF', 'Linear', 'RBF'}, ...
    'ItemsData', {'both', 'linear', 'rbf'}, 'Value', 'both', numericStyle{:});
addOption(b2, theme, 8, 'SVM kernels to compare', h.kernels);
h.useCache = uidropdown(b2, 'Items', {'Re-use cached features', 'Recompute features'}, ...
    'ItemsData', {true, false}, 'Value', true, numericStyle{:});
addOption(b2, theme, 9, 'Feature cache', h.useCache);

h.trainButton = uiButton(left, theme, 'Start Training', 'primary', @(~, ~) ctrl.startTraining());
h.trainButton.Layout.Row = 3;
h.pipelineInfo = uiText(left, theme, '', 'caption');
h.pipelineInfo.Layout.Row = 4;

% =========================================================== right column
right = uigridlayout(page, [4 1], 'RowHeight', {96, 150, '1x', 150}, 'Padding', [0 0 0 0], ...
                     'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);
right.Layout.Column = 2;

stats = uigridlayout(right, [1 5], 'Padding', [0 0 0 0], 'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);
stats.Layout.Row = 1;
items = {'rows', 'Metadata rows'; 'found', 'Labelled images on disk'; 'normal', 'Normal (No Finding)'; ...
         'abnormal', 'Abnormal (any finding)'; 'patients', 'Patients on disk'};
for k = 1:size(items, 1)
    [card, body] = uiCard(stats, theme, items{k, 2}, [1 1]);
    card.Layout.Column = k;
    h.stats.(items{k, 1}) = uiText(body, theme, 'Not available', 'h2');
end

[c3, b3] = uiCard(right, theme, 'Planned patient-wise subset', [2 1]);
c3.Layout.Row = 2;
b3.RowHeight = {'1x', 18};
h.splitTable = uitable(b3, 'Data', cell(0, 5), ...
    'ColumnName', {'Split', 'Normal', 'Abnormal', 'Patients', 'Requested (N / A)'}, 'RowName', {}, ...
    'FontName', theme.font, 'FontSize', theme.fontSize.label, ...
    'BackgroundColor', [theme.card; theme.cardAlt], 'ForegroundColor', theme.text);
h.splitTable.Layout.Row = 1;
h.splitSource = uiText(b3, theme, 'Scan the dataset to preview the split.', 'caption');
h.splitSource.Layout.Row = 2;

[c4, b4] = uiCard(right, theme, 'Dataset validation messages', [1 1]);
c4.Layout.Row = 3;
h.messages = uitextarea(b4, 'Value', datasetHelpText(), 'Editable', 'off', ...
    'BackgroundColor', theme.axesBg, 'FontColor', theme.textMuted, 'FontName', theme.font, ...
    'FontSize', theme.fontSize.label);

[c5, b5] = uiCard(right, theme, 'Training progress', [3 1]);
c5.Layout.Row = 4;
b5.RowHeight = {10, 18, '1x'};
b5.RowSpacing = 6;
h.progressTrack = uigridlayout(b5, [1 2], 'ColumnWidth', {'0.0001x', '1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 0, 'BackgroundColor', theme.input);
h.progressTrack.Layout.Row = 1;
h.progressFill = uilabel(h.progressTrack, 'Text', '', 'BackgroundColor', theme.accent);
h.progressFill.Layout.Column = 1;
h.progressStatus = uiText(b5, theme, 'Model training status: not started', 'muted', ...
    'FontSize', theme.fontSize.label, 'WordWrap', 'off');
h.progressStatus.Layout.Row = 2;
h.log = uitextarea(b5, 'Value', {''}, 'Editable', 'off', 'BackgroundColor', theme.axesBg, ...
    'FontColor', theme.textMuted, 'FontName', theme.monoFont, 'FontSize', theme.fontSize.caption);
h.log.Layout.Row = 3;
end

function addOption(grid, theme, row, labelText, component)
lab = uiText(grid, theme, labelText, 'muted', 'FontSize', theme.fontSize.label, 'WordWrap', 'off');
lab.Layout.Row = row;
lab.Layout.Column = 1;
component.Layout.Row = row;
component.Layout.Column = 2;
end

function lines = datasetHelpText()
lines = {
    'DATASET SETUP (NIH ChestX-ray14)'
    '1. Open https://nihcc.app.box.com/v/ChestXray-NIHCC'
    '2. Download Data_Entry_2017_v2020.csv and one or more image archives (images_001.tar.gz ... images_012.tar.gz, about 4-5 GB each). One archive (~5,000 images) is enough for a 1,000-image experiment.'
    '3. Optional: download train_val_list.txt and test_list.txt to use the official patient-wise split.'
    '4. Extract everything into one folder, e.g.  NIH/images_001/images/00000001_000.png  and  NIH/Data_Entry_2017_v2020.csv'
    '5. Click Browse, select that folder, then Scan & Validate Dataset.'
    ''
    'Labels: "No Finding" -> Normal; any of the 14 findings -> Abnormal. Rows with empty, unknown or conflicting labels are excluded and reported here. The labels were mined from radiology reports by NLP and are imperfect reference labels, not clinical ground truth.'
    };
end
