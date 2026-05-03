classdef Message < event.EventData & matlab.mixin.CustomDisplay
    % LOGMESSAGE Advanced logging message
    % 中文说明：提供 CSRD 生产链路中的 Message 实现。
    %   This class implements a log message
    %
    %   See demoLogger.mlx for usage examples:
    %
    %     >> edit demoLogger.mlx

    %   Copyright 2018-2022 The MathWorks Inc.

    %#ok<*PROP>

    %% Properties
    properties

        % Time of the message
        Time (1, 1) datetime

        % The severity level
        Level (1, 1) csrd.runtime.logger.mlog.Level = csrd.runtime.logger.mlog.Level.ERROR

        % The message text
        Text (1, 1) string

        % Caller information (function:line)
        Caller (1, 1) string = ""

    end %properties

    %% Constructor / Destructor
    methods

        function obj = Message()
            % Construct the message
            % 中文说明：Message 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            obj.Time = datetime('now', 'TimeZone', 'local');
            obj.Time.Format = 'MM/dd HH:mm:ss'; % mmengine style timestamp

        end %function

    end %methods

    %% Public Methods
    methods

        function t = toTable(obj)
            % Convert the object to a table
            % 中文说明：toTable 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            % Find any invalid handles
            idxValid = isvalid(obj);

            % Create row numbering
            rowNames = string(1:numel(obj));
            rowNames(~idxValid) = "<deleted>";

            % Create variables
            Time(idxValid, 1) = vertcat(obj(idxValid).Time);
            Level(idxValid, 1) = vertcat(obj(idxValid).Level);
            Text(idxValid, 1) = vertcat(obj(idxValid).Text);

            % Make table
            t = table(Time, Level, Text, 'RowNames', rowNames);

        end %function

        function toDialog(obj, fig, title)
            % Send the message to a dialog window in the specified figure
            % 中文说明：toDialog 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            % Check arguments
            arguments
                obj (1, 1) csrd.runtime.logger.mlog.Message
                fig (1, 1) matlab.ui.Figure
                title (1, 1) string = ""
            end

            % Which icon to show?
            iconLevels = [
                          csrd.runtime.logger.mlog.Level.NONE
                          csrd.runtime.logger.mlog.Level.ERROR
                          csrd.runtime.logger.mlog.Level.WARNING
                          csrd.runtime.logger.mlog.Level.INFO
                          ];

            if any(obj.Level == iconLevels)
                icon = lower(string(obj.Level));
            elseif obj.Level == csrd.runtime.logger.mlog.Level.MESSAGE
                icon = "message";
            else
                icon = "";
            end

            % Launch the dialog
            uialert(fig, obj.Text, title, "Icon", icon);

        end %function

    end %methods

    %% Protected Methods
    methods (Access = protected)

        function displayNonScalarObject(obj)

            % Format text to display
            % 中文说明：displayNonScalarObject 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            className = matlab.mixin.CustomDisplay.getClassNameForHeader(obj);
            dimStr = matlab.mixin.CustomDisplay.convertDimensionsToString(obj);

            % Display the header
            fprintf('  %s %s with data:\n\n', dimStr, className);

            % Show the group list in a table
            disp(obj.toTable());

        end %function

    end %methods

    methods (Access = {?csrd.runtime.logger.mlog.Message, ?csrd.runtime.logger.mlog.Logger})

        function str = createDisplayMessage(obj, loggerName)
            % Get the message formatted for display (mmengine style for console)
            % 中文说明：createDisplayMessage 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Timestamp - LoggerName - Level - [Caller] Message
            arguments
                obj csrd.runtime.logger.mlog.Message
                loggerName (1, 1) string = "DefaultLogger"
            end

            if strlength(obj.Caller) > 0
                str = sprintf('%s - %s - %-8s [%s] %s', ...
                    string(obj.Time), ...
                    loggerName, ...
                    obj.Level, ...
                    obj.Caller, ...
                    obj.Text);
            else
                str = sprintf('%s - %s - %-8s %s', ...
                    string(obj.Time), ...
                    loggerName, ...
                    obj.Level, ...
                    obj.Text);
            end

        end %function

        function str = createLogFileMessage(obj, loggerName)
            % Get the message formatted for log file (mmengine style)
            % 中文说明：createLogFileMessage 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Timestamp - LoggerName - Level - [Caller] Message
            arguments
                obj csrd.runtime.logger.mlog.Message
                loggerName (1, 1) string = "DefaultLogger"
            end

            if strlength(obj.Caller) > 0
                str = sprintf('%s - %s - %-8s [%s] %s', ...
                    string(obj.Time), ...
                    loggerName, ...
                    obj.Level, ...
                    obj.Caller, ...
                    obj.Text);
            else
                str = sprintf('%s - %s - %-8s %s', ...
                    string(obj.Time), ...
                    loggerName, ...
                    obj.Level, ...
                    obj.Text);
            end

        end %function

    end %methods

end % classdef
