function h = buildDashboard(parent, theme, ctrl)
%BUILDDASHBOARD Overview page: introduction, live status cards, workflow progress.
%   Every value shown here is filled in by AppController.refreshDashboard
%   from the actual application state; nothing is a placeholder number.

h = struct();
h.panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.bg);
h.panel.Layout.Row = 1;
h.panel.Layout.Column = 1;
page = uigridlayout(h.panel, [3 1], 'RowHeight', {148, 118, '1x'}, 'Padding', [0 0 0 0], ...
                    'RowSpacing', theme.gap, 'BackgroundColor', theme.bg);

% ---- Hero --------------------------------------------------------------------------
[hero, heroBody] = uiCard(page, theme, '', [3 3]);
hero.Layout.Row = 1;
heroBody.ColumnWidth = {'1x', 190, 190};
heroBody.RowHeight = {34, 26, '1x'};
t = uiText(heroBody, theme, 'Chest X-Ray Abnormality Detection', 'h1');
t.Layout.Row = 1; t.Layout.Column = 1;
s = uiText(heroBody, theme, 'Classical medical image processing and SVM classification on NIH ChestX-ray14', 'muted');
s.Layout.Row = 2; s.Layout.Column = 1;
d = uiText(heroBody, theme, ['Load a frontal chest radiograph and follow every stage: noise reduction, ' ...
    'contrast enhancement, gamma correction, lung segmentation, morphology, texture features ' ...
    'and a Normal / Abnormal prediction from a trained Support Vector Machine.'], 'caption');
d.Layout.Row = 3; d.Layout.Column = 1;
h.startButton = uiButton(heroBody, theme, 'Start Image Analysis', 'primary', @(~, ~) ctrl.navigate('analysis'));
h.startButton.Layout.Row = 2; h.startButton.Layout.Column = 2;
h.trainButton = uiButton(heroBody, theme, 'Dataset & Training', 'secondary', @(~, ~) ctrl.navigate('training'));
h.trainButton.Layout.Row = 2; h.trainButton.Layout.Column = 3;

% ---- Status cards ------------------------------------------------------------------------
stats = uigridlayout(page, [1 4], 'Padding', [0 0 0 0], 'ColumnSpacing', theme.gap, ...
                     'BackgroundColor', theme.bg);
stats.Layout.Row = 2;
cards = {'dataset', 'Dataset images processed'
         'model',   'Model training status'
         'image',   'Selected image'
         'metrics', 'Last evaluation'};
for k = 1:size(cards, 1)
    [card, body] = uiCard(stats, theme, cards{k, 2}, [2 1]);
    card.Layout.Column = k;
    body.RowHeight = {32, '1x'};
    value = uiText(body, theme, 'Not available', 'h2');
    value.Layout.Row = 1;
    caption = uiText(body, theme, '', 'caption');
    caption.Layout.Row = 2;
    h.cards.(cards{k, 1}) = struct('value', value, 'caption', caption);
end

% ---- Workflow + next steps ----------------------------------------------------------------
bottom = uigridlayout(page, [1 2], 'ColumnWidth', {'1.2x', '1x'}, 'Padding', [0 0 0 0], ...
                      'ColumnSpacing', theme.gap, 'BackgroundColor', theme.bg);
bottom.Layout.Row = 3;

steps = AppController.stepList();
[wfCard, wf] = uiCard(bottom, theme, 'Current image - processing pipeline', [size(steps, 1) 3]);
wfCard.Layout.Column = 1;
wf.ColumnWidth = {18, 170, '1x'};
wf.RowHeight = repmat({24}, 1, size(steps, 1));
h.workflow = struct('dot', {cell(size(steps, 1), 1)}, 'state', {cell(size(steps, 1), 1)});
for k = 1:size(steps, 1)
    dot = uilabel(wf, 'Text', char(9679), 'FontSize', 12, 'FontColor', theme.textFaint, ...
                  'HorizontalAlignment', 'center');
    dot.Layout.Row = k; dot.Layout.Column = 1;
    name = uiText(wf, theme, steps{k, 2}, 'body');
    name.Layout.Row = k; name.Layout.Column = 2;
    state = uiText(wf, theme, 'Pending', 'caption');
    state.Layout.Row = k; state.Layout.Column = 3;
    h.workflow.dot{k} = dot;
    h.workflow.state{k} = state;
end

[nextCard, nb] = uiCard(bottom, theme, 'Getting started', [4 1]);
nextCard.Layout.Column = 2;
nb.RowHeight = {'fit', 'fit', 'fit', '1x'};
h.next = cell(3, 1);
for k = 1:3
    h.next{k} = uiText(nb, theme, '', 'body');
    h.next{k}.Layout.Row = k;
end
note = uiText(nb, theme, ['Accuracy on a held-out test set is reported only after a model has ' ...
    'actually been trained and evaluated. A good accuracy value alone does not establish ' ...
    'clinical usefulness.'], 'caption', 'VerticalAlignment', 'bottom');
note.Layout.Row = 4;
end
