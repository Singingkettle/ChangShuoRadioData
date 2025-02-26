% Message Class
%
% This class defines a Message object that inherits from the matlab.System class.
% It is used to generate different types of messages based on configuration settings.
%
% Properties:
%   Config (string):
%       Path to the JSON configuration file that defines message generation parameters
%   MessageInfos (cell array):
%       Contains information about different message types for each transmitter
%
% Private Properties:
%   genMessage (cell array):
%       Stores message generator objects for each transmitter
%   logger (object):
%       Logging utility object for tracking operations
%   cfgs (struct):
%       Loaded configuration settings from the Config file
%
% Methods:
%   Message(varargin):
%       Constructor that initializes the object with optional name-value pairs
%
%   setupImpl(obj):
%       Protected method that:
%       1. Initializes the logger
%       2. Loads configuration from the specified JSON file
%       3. Creates event generator objects for each transmitter based on EventType
%       4. Validates that specified event handlers exist
%
%   stepImpl(obj, FrameId, MessageIndex, SegmentId, MessageLength, SymbolRate):
%       Protected method that generates messages with the following parameters:
%       - FrameId: Identifier for the current frame
%       - MessageIndex: Transmitter identifier
%       - SegmentId: Segment identifier within the frame
%       - MessageLength: Length of message to generate
%       - SymbolRate: Rate at which symbols are transmitted
%       Returns: Generated message based on the specified parameters
%
% Usage Example:
%   messageObj = Message('Config', 'path/to/config.json');
%   output = messageObj(1, 1, 1, 1000, 1e6);
classdef Event < matlab.System

    properties
        Config {mustBeFile} = "../config/_base_/simulate/event/event.json"
        EventInfos
    end

    properties (Access = private)
        forward
        logger
        cfgs
    end

    methods

        function obj = Event(varargin)
            % Constructor
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % Initialize logger and load configurations
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            % Validate EventInfos
            if isempty(obj.EventInfos)
                obj.logger.error("EventInfos cannot be empty");
                exit(1);
            end

            % Create message generators for each transmitter
            for EventIndex = 1:length(obj.EventInfos)
                % Get available event types from config
                EventTypes = fieldnames(obj.cfgs.(obj.EventInfos{EventIndex}.ParentEventType));

                % Randomly select one event type
                EventType = EventTypes{randperm(numel(EventTypes), 1)};
                obj.EventInfos{EventIndex}.EventType = EventType;
                kwargs = obj.cfgs.(obj.EventInfos{EventIndex}.ParentEventType).(EventType);

                % Verify event class exists and create instance
                if ~exist(kwargs.handle, 'class')
                    obj.logger.error("Event handle %s does not exist.", kwargs.handle);
                    exit(1);
                else
                    eventHandle = kwargs.handle; % Store handle before removing it
                    kwargs = rmfield(kwargs, "handle");
                    % Convert struct to name-value pairs
                    fields = fieldnames(kwargs);
                    nvPairs = cell(1, 2 * length(fields));
                    idx = 1;

                    for i = 1:length(fields)
                        nvPairs{idx} = fields{i};
                        value = kwargs.(fields{i});

                        if isscalar(value) || islogical(value)
                            nvPairs{idx + 1} = value;
                        elseif ismatrix(value)
                            nvPairs{idx + 1} = value;
                        else
                            nvPairs{idx + 1} = char(value);
                        end

                        idx = idx + 2;
                    end

                    obj.forward{EventIndex} = feval(eventHandle, nvPairs{:}); % Use stored handle
                end

            end

        end

        function [out, TxInfos, TxMasterClockRateRange, BandWidthRange] = stepImpl(obj, FrameId, EventIndex, txs)
            % Input validation
            validateattributes(FrameId, {'numeric'}, {'scalar', 'positive', 'integer'});

            % Generate messages
            [out, TxInfos, TxMasterClockRateRange, BandWidthRange] = obj.forward{EventIndex}(txs);
            obj.logger.debug("Generate event of Frame %06d using %s-%s", FrameId, obj.EventInfos{EventIndex}.ParentEventType, obj.EventInfos{EventIndex}.EventType);
        end

    end

end
