classdef Logger < handle & matlab.mixin.SetGetExactNames & ...
        matlab.mixin.Heterogeneous & matlab.mixin.CustomDisplay
    %LOGGER Advanced logging tool for MATLAB
    %   This class provides configurable logging capabilites for MATLAB
    %   applications.
    %
    %   Logger provides for singleton logger instances given a
    %   unique name of the application. This means that you can get an
    %   instance of the same logger from multiple places in code without
    %   needing to pass around the object handle!
    %
    %   This logger can be configured to write to a file, to the command
    %   window, and to external listeners. Each of these can be
    %   individually configured with a minimum severity of the log message
    %   that should be written.
    %
    %   Please see advancedLogger\GettingStarted.mlx for usage examples.

    %   Copyright 2018-2024 The MathWorks Inc.



    %% Events
    events (NotifyAccess = protected)

        % This event is triggered for each message added, regardless of level
        MessageAdded

        % The externally-accessible event that is triggered when a new
        % message is received. Listen to this event to implement custom log
        % notifications beyond the typical file and command window options.
        MessageReceived

    end %events


    %% Properties
    properties (AbortSet)

        % Name of this logger (each unique name has a singleton logger)
        Name (1,1) string = "Advanced Logger for MATLAB"

        % Location to store log files
        LogFolder (1,1) string = strip(tempdir,'right',filesep)

        % Full path for log file
        LogFile (1,1) string

        % Period of when to rotate to a new log file ("none" produces a single file)
        RotationPeriod (1,1) mlog.RotationPeriod = mlog.RotationPeriod.none

        % Level of messages to save to the log file
        FileThreshold (1,1) mlog.Level = mlog.Level.INFO

        % Level of messages to display in the command window
        CommandWindowThreshold (1,1) mlog.Level = mlog.Level.WARNING

        % Level of messages to trigger MessageReceived event notification
        MessageReceivedEventThreshold (1,1) mlog.Level = mlog.Level.MESSAGE

        % Number of messages to retain
        BufferSize (1,1) uint32 {mustBePositive} = 1000

    end %properties



    %% Read-Only Properties

    properties (Dependent, SetObservable, SetAccess = protected)

        % Log message history
        Messages (:,1) mlog.Message

    end %properties


    properties (Dependent, SetAccess = protected)
        % Most recent log message
        LastMessage (:,1) mlog.Message

        % Messages in table format for display purposes
        MessageTable table

    end %properties


    properties (Transient, SetAccess = private)

        % Next log rotation time
        NextRotation datetime = NaT("TimeZone","local")

    end %properties



    %% Internal Properties
    properties (Access = protected)

        % Circular buffer of log messages
        MessageBuffer (:,1) mlog.Message = repmat(mlog.Message, 1000, 1)

        % Index of last message in buffer
        BufferIndex (1,1) double = 0

        % Indicates whether the buffer has wrapped around
        BufferIsWrapped (1,1) logical = false

        % Message type constructor
        MessageConstructor (1,1) function_handle = @mlog.Message

    end %properties


    properties (Transient, Hidden, SetAccess = private)

        % File identifier for the log file
        FileID (1,1) double = -1

    end %properties



    %% Methods implemented in separate files

    methods
        varargout = write(obj, varargin)
        clearLog(obj)
        openLogFile(obj)
    end

    methods (Access = protected)
        msg = constructMessage(obj, argA, argB, varargin)
        addMessage(obj, msgObj)
        writeToCommandWindow(obj, msgObj)
        writeToLogFile(obj, msgObj)
        tf = isLevelLogged(obj, level)
    end

    methods (Static, Access = protected)
        msgText = convertExceptionText(mExceptionObj)
    end

    methods (Sealed, Access = private)
        updateBufferSize(obj, newSize)
        updateMessageClass(obj)
        fopenLogFile(obj, permission)
        fcloseLogFile(obj)
    end



    %% Constructor / Destructor
    methods

        function obj = Logger(name, pathName)
            % Construct the logger

            % Define input arguments
            arguments
                name (1,1) string = "Advanced_Logger_for_MATLAB"
                pathName (1,1) string = "" %File or folder path
            end

            % Logger is a singleton by Name. Only a single logger for each
            % name is stored in memory. If the name is a repeat, this
            % method will return the existing logger. Otherwise, it keeps
            % the new one.
            obj = getSingletonLogger(obj,name);

            % Was a folder or file name provided?
            if isfolder(pathName)
                obj.LogFolder = pathName;
            elseif strlength(pathName)
                obj.LogFile = pathName;
            end

        end %function


        function delete(obj)
            % Destruct the Logger

            % If a log file was open, close it
            obj.fcloseLogFile();

        end %function

    end %methods


    methods (Sealed, Access = private)

        function obj = getSingletonLogger(obj,name)
            % Get a singleton logger

            % Define input arguments
            arguments
                obj (1,1) mlog.Logger
                name (1,1) string = "Advanced_Logger_for_MATLAB"
            end

            % Track a singleton logger for each unique name
            persistent AllLoggers
            if isempty(AllLoggers)
                AllLoggers = mlog.Logger.empty(0);
            end
            AllLoggers(~isvalid(AllLoggers)) = [];

            % Is there a match?
            allNames = string([AllLoggers.Name]);
            isMatch = matches(allNames, name);
            if any(isMatch)
                % Yes it exists - return the stored logger

                idx = find(isMatch, 1);
                obj = AllLoggers(idx);

            else
                % No it does not exist - use the newly instantiated object
                % and set the file name

                % Add this logger to the persistent list
                obj.Name = name;
                AllLoggers(end+1) = obj;

            end %if any(isMatch)

        end %function

    end %private methods



    %% Display Customization
    methods (Access = protected)

        function propgrp = getPropertyGroups(obj)
            % Customize property display in command window

            if ~isscalar(obj)

                % Skip customization if nonscalar
                propgrp = obj.getPropertyGroups@matlab.mixin.CustomDisplay();

            else

                % Start with all properties
                p = properties(obj);

                % Rotation Group
                isMatch = contains(p, "Rotation");
                pR = p(isMatch);
                p(isMatch) = [];


                % Threshold group
                isMatch = contains(p, "Threshold");
                pT = p(isMatch);
                p(isMatch) = [];

                % Messages group
                pM = ["BufferSize","Messages","LastMessage","MessageTable"];
                isMatch = matches(p, pM);
                p(isMatch) = [];

                % Create property groups
                propgrp = [
                    matlab.mixin.util.PropertyGroup(p)
                    matlab.mixin.util.PropertyGroup(pR,"Log File Rotation:")
                    matlab.mixin.util.PropertyGroup(pT,"Log Level Thresholds:")
                    matlab.mixin.util.PropertyGroup(pM,"Messages:")
                    ];

            end %if ~isscalar(obj)

        end %function


        function displayScalarObject(obj)

            % Start with default display
            obj.displayScalarObject@matlab.mixin.CustomDisplay();

            % Display the recent messages
            msgTable = obj.MessageTable;
            if ~isempty(msgTable)
                fprintf('  Recent Messages:\n\n');
                disp( tail(msgTable,6) );
            end

        end %function

    end %methods



    %% Customize save/load
    methods (Static)

        function obj = loadobj(s)

            if isstruct(s)
                warning("mlog:loadobjFailed",...
                    "Unable to load saved logger. Creating a new instance.");
                obj = mlog.Logger(s.Name, s.LogFile);
            else
                obj = s;
            end

        end %function

    end %methods


    %% Get/Set Methods
    methods

        function value = get.Messages(obj)
            % Get the ordered messages from the circular buffer
            if obj.BufferIsWrapped
                value = circshift(obj.MessageBuffer, -obj.BufferIndex);
            else
                value = obj.MessageBuffer(1:obj.BufferIndex, 1);
            end
        end %function


        function value = get.MessageTable(obj)
            % Get a timetable of messages
            value = obj.Messages.toTable();
        end %function


        function value = get.LastMessage(obj)
            % Get the most recent message
            if obj.BufferIndex > 0
                value = obj.MessageBuffer(obj.BufferIndex);
            else
                value = obj.MessageBuffer([],1);
            end
        end %function


        function set.Name(obj,value)
            obj.Name = value;
            obj.fcloseLogFile();
        end %function


        function set.LogFolder(obj,value)
            % Remove trailing filesep
            obj.LogFolder = strip(value,'right',filesep);
            obj.fcloseLogFile();
        end %function


        function set.LogFile(obj,value)
            obj.LogFile = value;
            obj.fcloseLogFile();
        end %function


        function set.BufferSize(obj,value)
            obj.updateBufferSize(value);
            obj.BufferSize = value;
        end %function


        function set.MessageConstructor(obj,value)
            obj.MessageConstructor = value;
            obj.updateMessageClass();
        end %function

    end %methods

end %classdef

