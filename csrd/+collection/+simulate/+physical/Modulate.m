% Modulate - Signal modulation system class
%
% A MATLAB System object that handles digital signal modulation for multiple
% transmitters with configurable modulation schemes.
%
% Properties:
%   Config          - Path to JSON config file (default: "../config/_base_/simulate/modulate/modulate.json")
%   ModulateInfos   - Cell array of modulation settings per transmitter
%
% Private Properties:
%   forward         - Cell array of modulator objects per transmitter
%   logger          - Logging utility instance
%   cfgs           - Parsed configuration settings
%
% Methods:
%   Modulate(varargin)
%     Constructor that accepts name-value pair arguments
%
%   setupImpl(obj)
%     Initializes the modulation system:
%     - Sets up logging
%     - Loads configuration
%     - Creates modulator instances for each transmitter
%     - Randomly selects modulation schemes and orders
%
%   stepImpl(obj, x, FrameId, TxId, SegmentId)
%     Performs modulation for a single step:
%     - Processes input data based on modulation type
%     - Applies selected modulation scheme
%     - Returns modulated signal with metadata
%
%     Inputs:
%       x         - Input data to modulate
%       FrameId   - Current frame identifier
%       TxId      - Transmitter identifier
%       SegmentId - Segment identifier within frame
%
% Supported Modulation Types:
%   - Single-carrier: Various PSK/QAM schemes
%   - Multi-carrier: OFDM, OTFS, SC-FDMA
%     (with configurable PSK or QAM base modulation)
classdef Modulate < matlab.System

    properties
        % Config - Path to modulation configuration file
        % If not specified, will use default path relative to project root
        Config = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..', ...
            'config', '_base_', 'simulate', 'modulate', 'modulate.json')
        
        % Cell array containing modulation settings for each transmitter
        ModulateInfos
    end

    properties (Access = private)
        % Cell array of modulator objects for each transmitter
        forward
        % Logger instance for tracking operations and errors
        logger
        % Struct containing parsed configuration settings
        cfgs
    end

    methods
        % Constructor accepting name-value pair arguments
        function obj = Modulate(varargin)
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % Initialize logger and load configuration
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            % For each transmitter, configure its modulation settings
            for ModulatorIndex = 1:length(obj.ModulateInfos)
                % Get available modulator types from config
                ModulatorTypes = fieldnames(obj.cfgs.(obj.ModulateInfos{ModulatorIndex}.ParentModulatorType));

                % Randomly select one modulator type
                ModulatorType = ModulatorTypes{randperm(numel(ModulatorTypes), 1)};
                kwargs = obj.cfgs.(obj.ModulateInfos{ModulatorIndex}.ParentModulatorType).(ModulatorType);

                % Verify modulator class exists and create instance
                if ~exist(kwargs.handle, 'class')
                    obj.logger.error("Modulator handle %s does not exist.", kwargs.handle);
                    exit(1);
                else
                    % Special handling for multicarrier modulation schemes
                    if ModulatorType == "OFDM" || ...
                            ModulatorType == "OTFS" || ...
                            ModulatorType == "SCFDMA"
                        % Choose between PSK or QAM as base modulation
                        baseModulatorType = randsample(["psk", "qam"], 1);
                        ModulatorOrders = kwargs.(strcat(upper(baseModulatorType), "Order"));
                        obj.ModulateInfos{ModulatorIndex}.SamplePerSymbol = 1;
                        obj.ModulateInfos{ModulatorIndex}.baseModulatorType = baseModulatorType;
                    else
                        % Get modulation orders for single-carrier schemes
                        ModulatorOrders = kwargs.Order;
                    end

                    % Randomly select modulation order and calculate sample rate
                    ModulatorOrder = ModulatorOrders(randperm(numel(ModulatorOrders), 1));
                    SampleRate = obj.ModulateInfos{ModulatorIndex}.SymbolRate * ...
                        obj.ModulateInfos{ModulatorIndex}.SamplePerSymbol;
                    % Create modulator object directly instead of using eval
                    ModulatorClass = str2func(kwargs.handle);
                    obj.forward{ModulatorIndex} = ModulatorClass( ...
                        'SampleRate', SampleRate, ...
                        'ModulatorOrder', ModulatorOrder, ...
                        'SamplePerSymbol', obj.ModulateInfos{ModulatorIndex}.SamplePerSymbol, ...
                        'NumTransmitAntennas', obj.ModulateInfos{ModulatorIndex}.NumTransmitAntennas);
                end

                % Store modulation parameters for this transmitter
                obj.ModulateInfos{ModulatorIndex}.ModulatorType = ModulatorType;
                obj.ModulateInfos{ModulatorIndex}.ModulatorOrder = ModulatorOrder;
            end

        end

        function out = stepImpl(obj, x, FrameId, ModulatorIndex, SegmentId)
            % Input validation
            validateattributes(x, {'struct'}, {'nonempty'}, 'stepImpl', 'x', 2);
            validateattributes(FrameId, {'numeric'}, {'scalar', 'positive', 'integer'}, 'stepImpl', 'FrameId', 3);
            validateattributes(ModulatorIndex, {'numeric'}, ...
                {'scalar', 'positive', 'integer', '<=', length(obj.ModulateInfos)}, ...
                'stepImpl', 'ModulatorIndex', 4);
            validateattributes(SegmentId, {'numeric'}, {'scalar', 'nonnegative', 'integer'}, 'stepImpl', 'SegmentId', 5);

            % Validate x.data exists and is non-empty
            if ~isfield(x, 'data') || isempty(x.data)
                obj.logger.error('Input x must contain non-empty data field');
                error('Input x must contain non-empty data field');
            end

            % For single-carrier modulation, reduce input data length
            if ~(obj.ModulateInfos{ModulatorIndex}.ModulatorType == "OFDM" || ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType == "OTFS" || ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType == "SCFDMA")
                save_len = fix(length(x.data) / 10);
                x.data = x.data(1:save_len);
            end

            % Perform modulation using the configured modulator
            if obj.ModulateInfos{ModulatorIndex}.ParentModulatorType == "analog"
                obj.forward{ModulatorIndex}.SampleRate = x.SymbolRate;
            end
            out = obj.forward{ModulatorIndex}(x);
            out.ModulatorType = obj.ModulateInfos{ModulatorIndex}.ModulatorType;

            % Log modulation details with appropriate format based on modulator type
            if obj.ModulateInfos{ModulatorIndex}.ModulatorType == "OFDM" || ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType == "OTFS" || ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType == "SCFDMA"
                out.baseModulatorType = obj.ModulateInfos{ModulatorIndex}.baseModulatorType;
                obj.logger.debug("Generate modulated signals of Frame-Tx-Segment " + ...
                    "%06d:%02d:%02d using %d-%s-%s", ...
                    FrameId, ModulatorIndex, SegmentId, ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorOrder, ...
                    obj.ModulateInfos{ModulatorIndex}.baseModulatorType, ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType);
            else
                obj.logger.debug("Generate modulated signals of Frame-Tx-Segment " + ...
                    "%06d:%02d:%02d using %d-%s", ...
                    FrameId, ModulatorIndex, SegmentId, ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorOrder, ...
                    obj.ModulateInfos{ModulatorIndex}.ModulatorType);
            end

        end

    end

end
