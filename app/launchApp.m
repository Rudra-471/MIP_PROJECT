function ctrl = launchApp(loadSavedModel)
%LAUNCHAPP Build the dashboard window and return its controller.
%   ctrl = launchApp() creates the uifigure, the sidebar, top bar, footer
%   disclaimer and all pages, connects them to an AppController and loads
%   models/trainedModel.mat when it exists (launchApp(false) skips that,
%   e.g. for automated GUI tests). Use main.m to start the app.
%
%   Layout
%     +-----------+------------------------------------------------+
%     |  sidebar  |  top bar: page title, workflow status, chips   |
%     |  (nav)    +------------------------------------------------+
%     |           |  page (Dashboard / Analysis / Training / ...)  |
%     |           +------------------------------------------------+
%     |           |  medical disclaimer (always visible)           |
%     +-----------+------------------------------------------------+

if nargin < 1
    loadSavedModel = true;
end
theme = uiTheme();
cfg = appConfig();

screen = get(groot, 'ScreenSize');            % fit smaller displays (e.g. 1366 x 768)
width = min(1440, screen(3) - 40);
height = min(900, screen(4) - 90);
fig = uifigure('Name', [cfg.projectName ' - Classical MIP + SVM'], 'Visible', 'off', ...
               'Color', theme.bg, 'Position', [20 40 width height]);
try
    movegui(fig, 'center');
catch
end

root = uigridlayout(fig, [1 2], 'ColumnWidth', {224, '1x'}, 'RowHeight', {'1x'}, ...
                    'Padding', [0 0 0 0], 'ColumnSpacing', 0, 'BackgroundColor', theme.bg);

ctrl = AppController(fig, theme, cfg);

ui = struct();
ui.sidebar = buildSidebar(root, theme, ctrl);

main = uigridlayout(root, [3 1], 'RowHeight', {66, '1x', 34}, 'Padding', [0 0 0 0], ...
                    'RowSpacing', 0, 'BackgroundColor', theme.bg);
main.Layout.Column = 2;
ui.top = buildTopBar(main, theme, ctrl);

pageHost = uigridlayout(main, [1 1], 'Padding', [18 16 18 12], 'BackgroundColor', theme.bg);
pageHost.Layout.Row = 2;
ui.dashboard  = buildDashboard(pageHost, theme, ctrl);
ui.analysis   = buildAnalysisPage(pageHost, theme, ctrl);
ui.training   = buildTrainingPage(pageHost, theme, ctrl);
ui.evaluation = buildEvaluationPage(pageHost, theme, ctrl);
ui.about      = buildAboutPage(pageHost, theme, ctrl);
ui.settings   = buildSettingsPage(pageHost, theme, ctrl);
% All pages share cell (1,1); undo any rows the grid added while they were created
pageHost.RowHeight = {'1x'};
pageHost.ColumnWidth = {'1x'};

footer = uigridlayout(main, [1 1], 'Padding', [18 4 18 6], 'BackgroundColor', theme.sidebar);
footer.Layout.Row = 3;
ui.disclaimer = uilabel(footer, 'Text', ['Medical disclaimer: ' cfg.disclaimer], ...
    'FontName', theme.font, 'FontSize', theme.fontSize.caption, 'FontColor', theme.warning, ...
    'HorizontalAlignment', 'center');

ctrl.attachUI(ui);
ctrl.initialize(loadSavedModel);
fig.Visible = 'on';
end
