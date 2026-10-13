function [panel, body, titleLabel] = uiCard(parent, theme, titleText, bodySize, subtitle)
%UICARD Flat dashboard card: borderless panel + title row + body grid.
%   [panel, body, titleLabel] = uiCard(parent, theme, titleText, bodySize)
%   bodySize = [rows cols] of the returned body grid (default [1 1]).
%   Pass titleText = '' for a card without a title row. The optional
%   subtitle is shown right-aligned in the title row (muted).

if nargin < 4 || isempty(bodySize)
    bodySize = [1 1];
end
if nargin < 5
    subtitle = '';
end
panel = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', theme.card, 'Title', '');
outer = uigridlayout(panel, [2 1], 'Padding', [14 12 14 12], 'RowSpacing', 8, ...
                     'BackgroundColor', theme.card);
if isempty(titleText)
    outer.RowHeight = {0, '1x'};
    titleLabel = [];
else
    outer.RowHeight = {22, '1x'};
    head = uigridlayout(outer, [1 2], 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
                        'BackgroundColor', theme.card, 'ColumnWidth', {'1x', 'fit'});
    head.Layout.Row = 1;
    titleLabel = uilabel(head, 'Text', upper(titleText), 'FontName', theme.font, ...
        'FontSize', theme.fontSize.caption, 'FontWeight', 'bold', 'FontColor', theme.textMuted);
    titleLabel.Layout.Column = 1;
    if ~isempty(subtitle)
        sub = uilabel(head, 'Text', subtitle, 'FontName', theme.font, 'FontSize', theme.fontSize.caption, ...
            'FontColor', theme.textFaint, 'HorizontalAlignment', 'right');
        sub.Layout.Column = 2;
    end
end
body = uigridlayout(outer, bodySize, 'Padding', [0 0 0 0], 'RowSpacing', 8, ...
                    'ColumnSpacing', 10, 'BackgroundColor', theme.card);
body.Layout.Row = 2;
end
