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
%       3. Creates message generator objects for each transmitter based on MessageType
%       4. Validates that specified message handlers exist
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
classdef Message < matlab.System

    properties
        % Config - Path to message configuration file
        % If not specified, will use default path relative to project root
        Config = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..', ...
            'config', '_base_', 'simulate', 'message', 'message.json')
        
        % MessageInfos - Cell array of message configuration for each transmitter
        MessageInfos
    end

    properties (Access = private)
        forward
        logger
        cfgs
    end

    methods
        function obj = Message(varargin)
            % Message - Constructor for Message class
            % 
            % Syntax:
            %   obj = Message()
            %   obj = Message('Config', configPath, 'MessageInfos', messageInfos)
            %
            % Inputs:
            %   varargin - Name-value pairs for configuration
            
            % Set properties from name-value pairs
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)
        function setupImpl(obj)
            % setupImpl - Initialize the Message object
            
            % Initialize logger
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            % Validate MessageInfos
            if isempty(obj.MessageInfos)
                obj.logger.error("MessageInfos cannot be empty");
                exit(1);
            end

            % Create message generators for each transmitter
            for MessageIndex = 1:length(obj.MessageInfos)
                kwargs = obj.cfgs.(obj.MessageInfos{MessageIndex}.MessageType);

                if ~exist(kwargs.handle, 'class')
                    obj.logger.error("Message handle %s does not exist.", kwargs.handle);
                    exit(1);
                else
                    MessageClass = str2func(kwargs.handle);
                    obj.forward{MessageIndex} = MessageClass();
                end

            end

        end

        function out = stepImpl(obj, FrameId, MessageIndex, SegmentId, MessageLength, SymbolRate)
            % stepImpl - Generate messages based on input parameters
            %
            % Inputs:
            %   FrameId - Frame identifier
            %   MessageIndex - Transmitter identifier
            %   SegmentId - Segment identifier
            %   MessageLength - Length of message to generate
            %   SymbolRate - Symbol rate for transmission
            
            % Input validation
            validateattributes(FrameId, {'numeric'}, {'scalar', 'positive', 'integer'});
            validateattributes(MessageIndex, {'numeric'}, {'scalar', 'positive', 'integer'});
            validateattributes(SegmentId, {'numeric'}, {'scalar', 'positive', 'integer'});
            validateattributes(MessageLength, {'numeric'}, {'scalar', 'positive'});
            validateattributes(SymbolRate, {'numeric'}, {'scalar', 'positive'});

            % Generate messages
            out = obj.forward{MessageIndex}(MessageLength, SymbolRate);
            obj.logger.debug("Generate messages of Frame-Tx-Segment %06d:%02d:%02d using %s", ...
                FrameId, MessageIndex, SegmentId, obj.MessageInfos{MessageIndex}.MessageType);
        end

    end

end
