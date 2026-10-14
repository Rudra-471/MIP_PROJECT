function h = buildSidebar(parent, theme, ctrl)
%BUILDSIDEBAR Logo block, navigation items and a short disclaimer.
%   Each navigation item is a 1 x 2 grid: a thin accent bar (visible for the
%   active page) and a left-aligned button. AppController.navigate updates
%   the active state.

pages = AppController.pageList();
n = size(pages, 1);
grid = uigridlayout(parent, [n + 4, 1], 'Padding', [0 18 0 14], 'RowSpacing', 2, ...
                    'BackgroundColor', theme.sidebar);
grid.Layout.Column = 1;
grid.RowHeight = [{64, 14}, repmat({40}, 1, n), {'1x', 'fit'}];

% ---- Logo treatment ------------------------------------------------------------
logo = uigridlayout(grid, [2 2], 'ColumnWidth', {40, '1x'}, 'RowHeight', {'1x', '1x'}, ...
                    'Padding', [18 6 12 6], 'ColumnSpacing', 10, 'RowSpacing', 0, ...
                    'BackgroundColor', theme.sidebar);
logo.Layout.Row = 1;
badge = uilabel(logo, 'Text', 'CX', 'FontName', theme.font, 'FontSize', 15, 'FontWeight', 'bold', ...
    'FontColor', theme.onAccent, 'BackgroundColor', theme.accent, 'HorizontalAlignment', 'center');
badge.Layout.Row = [1 2];
badge.Layout.Column = 1;
name = uilabel(logo, 'Text', 'CXR Lab', 'FontName', theme.font, 'FontSize', 17, ...
    'FontWeight', 'bold', 'FontColor', theme.text, 'VerticalAlignment', 'bottom');
name.Layout.Row = 1;
name.Layout.Column = 2;
tag = uilabel(logo, 'Text', 'Abnormality Detection', 'FontName', theme.font, ...
    'FontSize', theme.fontSize.caption, 'FontColor', theme.textMuted, 'VerticalAlignment', 'top');
tag.Layout.Row = 2;
tag.Layout.Column = 2;

section = uilabel(grid, 'Text', '   NAVIGATION', 'FontName', theme.font, 'FontSize', 10, ...
    'FontWeight', 'bold', 'FontColor', theme.textFaint);
section.Layout.Row = 2;

% ---- Navigation items --------------------------------------------------------------
h = struct();
h.navBars = cell(n, 1);
h.navButtons = cell(n, 1);
for k = 1:n
    item = uigridlayout(grid, [1 2], 'ColumnWidth', {4, '1x'}, 'Padding', [0 0 10 0], ...
                        'ColumnSpacing', 10, 'BackgroundColor', theme.sidebar);
    item.Layout.Row = k + 2;
    bar = uilabel(item, 'Text', '', 'BackgroundColor', theme.sidebar);
    bar.Layout.Column = 1;
    key = pages{k, 1};
    btn = uibutton(item, 'push', 'Text', ['  ' pages{k, 2}], 'HorizontalAlignment', 'left', ...
        'BackgroundColor', theme.sidebar, 'FontColor', theme.textMuted, 'FontName', theme.font, ...
        'FontSize', theme.fontSize.body, 'ButtonPushedFcn', @(~, ~) ctrl.navigate(key));
    btn.Layout.Column = 2;
    h.navBars{k} = bar;
    h.navButtons{k} = btn;
end

note = uilabel(grid, 'Text', sprintf(['Classical image processing + SVM.\nEducational and research ' ...
    'use only - not a medical diagnosis.']), 'FontName', theme.font, 'FontSize', 10, ...
    'FontColor', theme.textFaint, 'WordWrap', 'on');
note.Layout.Row = n + 4;
end
