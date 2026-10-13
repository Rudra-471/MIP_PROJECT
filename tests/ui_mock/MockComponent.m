classdef MockComponent < handle
    %MOCKCOMPONENT Headless stand-in for MATLAB UI components (TEST USE ONLY).
    %   Used by tests/testGui.m under GNU Octave, which has no uifigure. It
    %   stores any property that is set and returns [] for unset ones, so
    %   the controller and page-builder logic can run without a display.
    properties
        P
    end
    methods
        function obj = MockComponent(kind, varargin)
            obj.P = struct('Type', kind, 'Layout', struct('Row', [], 'Column', []), ...
                           'Visible', 'on', 'Enable', 'on', 'Children', []);
            args = varargin;
            if ~isempty(args) && isa(args{1}, 'MockComponent')
                obj.P.Parent = args{1};
                args(1) = [];
            end
            if mod(numel(args), 2) == 1 && ischar(args{1})
                obj.P.Style = args{1};      % uibutton('push') / uieditfield('numeric')
                args(1) = [];
            elseif mod(numel(args), 2) == 1 && isnumeric(args{1})
                obj.P.GridSize = args{1};   % uigridlayout(parent, [rows cols])
                args(1) = [];
            end
            for k = 1:2:numel(args)
                obj.P.(args{k}) = args{k + 1};
            end
            global MOCK_UI_REGISTRY %#ok<GVMIS>
            MOCK_UI_REGISTRY{end + 1} = obj;   % lets tests inspect the whole layout
            obj.P.Id = numel(MOCK_UI_REGISTRY);
        end
        function varargout = subsref(obj, s)
            if strcmp(s(1).type, '.') && ~strcmp(s(1).subs, 'P')
                if isfield(obj.P, s(1).subs)
                    v = obj.P.(s(1).subs);
                else
                    v = [];
                end
                if numel(s) > 1
                    v = subsref(v, s(2:end));
                end
                varargout = {v};
            else
                varargout = {builtin('subsref', obj, s)};
            end
        end
        function obj = subsasgn(obj, s, val)
            if strcmp(s(1).type, '.') && ~strcmp(s(1).subs, 'P')
                if numel(s) == 1
                    obj.P.(s(1).subs) = val;
                else
                    cur = [];
                    if isfield(obj.P, s(1).subs)
                        cur = obj.P.(s(1).subs);
                    end
                    obj.P.(s(1).subs) = subsasgn(cur, s(2:end), val);
                end
            else
                obj = builtin('subsasgn', obj, s, val);
            end
        end
        function close(obj)
            obj.P.Closed = true;
        end
        function press(obj)
            % Simulate a click: call ButtonPushedFcn like MATLAB would
            fcn = obj.P.ButtonPushedFcn;
            fcn(obj, []);
        end
        function change(obj, value)
            % Simulate a user changing a value component
            obj.P.Value = value;
            if isfield(obj.P, 'ValueChangedFcn') && ~isempty(obj.P.ValueChangedFcn)
                fcn = obj.P.ValueChangedFcn;
                fcn(obj, struct('Value', value));
            end
        end
    end
end
