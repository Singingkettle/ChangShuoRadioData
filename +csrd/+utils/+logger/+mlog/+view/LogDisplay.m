classdef LogDisplay < matlab.ui.componentcontainer.ComponentContainer
    % Display log messages

    % Copyright 2022 The MathWorks Inc.


    %% Public properties
    properties (AbortSet, Dependent)

        % Name of logger to monitor
        LogName (1,1) string

    end


    properties (AbortSet)

        % Logger to monitor
        Log mlog.Logger {mustBeScalarOrEmpty}

        % Most severe level of messages to display
        UpperDisplayThreshold (1,1) mlog.Level = mlog.Level.NONE

        % Least severe level of messages to display
        LowerDisplayThreshold (1,1) mlog.Level = mlog.Level.INFO

        % Number of messages to display
        MaxDisplay (1,1) uint16 {mustBePositive} = 100

        % Indicates whether to show the timestamp
        ShowTime (1,1) logical = true

        % Indicates whether to show the level
        ShowLevel (1,1) logical = true

    end %properties


    %% Internal Properties
    properties (Transient, NonCopyable, Access = private)

        % The internal grid to manage contents
        Grid matlab.ui.container.GridLayout

        % Text control
        TextArea matlab.ui.control.TextArea

        % Listener to log changes
        LogListener event.listener

    end %properties


    properties (Access = private, UsedInUpdate = true)

        IsDirty (1,1) logical

    end %properties



    %% Protected Methods
    methods (Access = protected)

        function setup(obj)
            % Configure the widget

            % Grid Layout to manage building blocks
            obj.Grid = uigridlayout(obj,[1 1]);
            obj.Grid.Padding = [0 0 0 0];

            obj.TextArea = uitextarea(obj.Grid);
            obj.TextArea.Placeholder = "  (No Messages)  ";
            obj.TextArea.WordWrap = false;
            obj.TextArea.Editable = false;

        end %function


        function update(obj)
            % Update display

            % Get the list of messages
            if ~isempty(obj.Log) && isvalid(obj.Log)
                messages = obj.Log.Messages;
            else
                messages = mlog.Message.empty(0,1);
            end

            % Filter messages by severity
            msgLevels = [messages.Level];
            isKeep = msgLevels >= obj.UpperDisplayThreshold & ...
                msgLevels <= obj.LowerDisplayThreshold;
            messages(~isKeep) = [];

            % Filter to message limit
            if numel(messages) > obj.MaxDisplay
                messages = messages(1:end-obj.MaxDisplay);
            end

            % Prepare message text
            if isempty(messages)
                displayText = "";
            else
                displayText = vertcat(messages.Text);
                if obj.ShowLevel
                    msgLevels = vertcat(messages.Level);
                    displayText = string(msgLevels) + ":   " + displayText;
                end
                if obj.ShowTime
                    msgTimes = vertcat(messages.Time);
                    displayText = string(msgTimes) + "    " + displayText;
                end
            end

            % Update the text display
            obj.TextArea.Value = displayText;
            obj.TextArea.scroll('bottom');

        end %function


        function requestUpdate(obj)
            % Request an update occur at next draw

            obj.IsDirty = true;

        end %function


        function attachListener(obj)
            % Attach listener to log

            if isempty(obj.Log) || ~isvalid(obj.Log)
                obj.LogListener(:) = [];
            else
                obj.LogListener = listener(obj.Log,...
                    "MessageAdded", @(src,evt)requestUpdate(obj));
            end

        end %function

    end %methods


    %% Get/Set Methods
    methods

        function value = get.LogName(obj)
            if isempty(obj.Log) || ~isvalid(obj.Log)
                value = "";
            else
                value = obj.Log.Name;
            end
        end %function


        function set.LogName(obj,value)
            if strlength(value)
                obj.Log = mlog.Logger(value);
            else
                obj.Log(:) = [];
            end
        end %function


        function set.Log(obj,value)
            obj.Log = value;
            obj.attachListener();
        end %function


        function set.UpperDisplayThreshold(obj,value)
            obj.UpperDisplayThreshold = value;
            if obj.LowerDisplayThreshold < obj.UpperDisplayThreshold
                obj.LowerDisplayThreshold = obj.UpperDisplayThreshold;
            end
        end %function


        function set.LowerDisplayThreshold(obj,value)
            obj.LowerDisplayThreshold = value;
            if obj.UpperDisplayThreshold > obj.LowerDisplayThreshold
                obj.UpperDisplayThreshold = obj.LowerDisplayThreshold;
            end
        end %function

    end %methods

end %classdef

%#ok<*MCSUP,*CPROPLC>