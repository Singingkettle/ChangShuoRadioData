classdef Message < event.EventData & matlab.mixin.CustomDisplay
    % LOGMESSAGE Advanced logging message
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
        Time (1,1) datetime
        
        % The severity level
        Level (1,1) mlog.Level = mlog.Level.ERROR
        
        % The message text
        Text (1,1) string
        
    end %properties
    
    
    
    %% Constructor / Destructor
    methods
        
        function obj = Message()
            % Construct the message
            
            obj.Time = datetime('now','TimeZone','local');
            obj.Time.Format = 'uuuu-MM-dd HH:mm:ss';
            
        end %function
        
    end %methods
    
    
    
    %% Public Methods
    methods
        
        function t = toTable(obj)
            % Convert the object to a table
            
            % Find any invalid handles
            idxValid = isvalid(obj);
            
            % Create row numbering
            rowNames = string(1:numel(obj));
            rowNames(~idxValid) = "<deleted>";
            
            % Create variables
            Time(idxValid,1) = vertcat( obj(idxValid).Time );
            Level(idxValid,1) = vertcat( obj(idxValid).Level );
            Text(idxValid,1) = vertcat( obj(idxValid).Text );
            
            % Make table
            t = table(Time, Level, Text, 'RowNames', rowNames);
            
        end %function
        
        
        function toDialog(obj, fig, title)
            % Send the message to a dialog window in the specified figure
            
            % Check arguments
            arguments
                obj (1,1) mlog.Message
                fig (1,1) matlab.ui.Figure
                title (1,1) string = ""
            end
            
            % Which icon to show?
            iconLevels = [
                mlog.Level.NONE
                mlog.Level.ERROR
                mlog.Level.WARNING
                mlog.Level.INFO
                ];
            if any(obj.Level == iconLevels)
                icon = lower(string(obj.Level));
            elseif obj.Level == mlog.Level.MESSAGE
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
            className = matlab.mixin.CustomDisplay.getClassNameForHeader(obj);
            dimStr = matlab.mixin.CustomDisplay.convertDimensionsToString(obj);
            
            % Display the header
            fprintf('  %s %s with data:\n\n',dimStr,className);
            
            % Show the group list in a table
            disp( obj.toTable() );
            
        end %function
        
    end %methods
    
    
    methods (Access = {?mlog.Message, ?mlog.Logger})
        
        function str = createDisplayMessage(obj)
            % Get the message formatted for display

            % Could potentially replace newline (char 10 or 13?) with an
            % arrow or whitespace to put stack traces on a single line
            % here. char(8629) is ↵.  However, this makes the log harder to
            % read. 
            % Decided to wait on this to have a use case.  It only makes
            % sense if one wanted to import the log as a delimited text
            % format.
            
            str = sprintf("%-8s %s", obj.Level, obj.Text);
            
        end %function
        
        
        function str = createLogFileMessage(obj)
            % Get the message formatted for display
            
            % The default log file message is simply the time plus the
            % standard display message
            str = sprintf('%s %s',...
                string(obj.Time),...
                obj.createDisplayMessage() );
            
        end %function
        
    end %methods
    
    
end % classdef