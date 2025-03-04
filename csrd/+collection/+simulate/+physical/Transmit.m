classdef Transmit < matlab.System

    properties
        % config for modulate
        Config {mustBeFile} = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..', ...
            'config', '_base_', 'simulate', 'radiofront', 'transmit.json')
        TxInfos

    end

    properties (Access = private)
        forward
        logger
        cfgs
    end

    methods

        function obj = Transmit(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            obj.forward = cell(1, length(obj.TxInfos));

            for TxId = 1:length(obj.TxInfos)
                TransmitterTypes = fieldnames(obj.cfgs.(obj.TxInfos{TxId}.ParentTransmitterType));
                TransmitterType = TransmitterTypes{randperm(numel(TransmitterTypes), 1)};

                kwargs = obj.cfgs.(obj.TxInfos{TxId}.ParentTransmitterType).(TransmitterType);
                % Verify transmitter class exists and create instance
                if ~exist(kwargs.handle, 'class')
                    obj.logger.error("Transmitter handle %s does not exist.", kwargs.handle);
                    exit(1);
                else

                    if isfield(obj.TxInfos{TxId}, "MasterClockRateRange")
                        MasterClockRateRange = obj.TxInfos{TxId}.MasterClockRateRange;
                    else
                        MasterClockRateRange = kwargs.MasterClockRateRange;
                    end

                    MasterClockRate = randi(fix((MasterClockRateRange(2) - MasterClockRateRange(1)) / kwargs.MasterClockRateStep)) * kwargs.MasterClockRateStep + MasterClockRateRange(1);
                    DCOffset = rand(1) * (kwargs.DCOffsetRange(2) - kwargs.DCOffsetRange(1)) + kwargs.DCOffsetRange(1);
                    IqImbalanceConfig.A = rand(1) * (kwargs.IqImbalanceConfig.A(2) - kwargs.IqImbalanceConfig.A(1)) + kwargs.IqImbalanceConfig.A(1);
                    IqImbalanceConfig.P = rand(1) * (kwargs.IqImbalanceConfig.P(2) - kwargs.IqImbalanceConfig.P(1)) + kwargs.IqImbalanceConfig.P(1);

                    PhaseNoiseConfig.Level = randi(kwargs.PhaseNoiseConfig.Level(2) - kwargs.PhaseNoiseConfig.Level(1)) + kwargs.PhaseNoiseConfig.Level(1);
                    PhaseNoiseConfig.FrequencyOffset = randi(kwargs.PhaseNoiseConfig.FrequencyOffset(2) - kwargs.PhaseNoiseConfig.FrequencyOffset(1)) + kwargs.PhaseNoiseConfig.FrequencyOffset(1);
                    MemoryLessNonlinearityConfig = MemoryLessNonlinearityRandom(kwargs.MemoryLessNonlinearityConfig);

                    CarrierFrequency = obj.TxInfos{TxId}.CarrierFrequency;
                    BandWidth = obj.TxInfos{TxId}.BandWidth;
                    SampleRate = obj.TxInfos{TxId}.SampleRate;

                    % Create a function handle from the class name
                    transmitterClass = str2func(kwargs.handle);

                    % Instantiate the class using the function handle
                    obj.forward{TxId} = transmitterClass('MasterClockRate', MasterClockRate, ...
                        'IqImbalanceConfig', IqImbalanceConfig, 'DCOffset', DCOffset, ...
                        'PhaseNoiseConfig', PhaseNoiseConfig, ...
                        'MemoryLessNonlinearityConfig', MemoryLessNonlinearityConfig, ...
                        'SiteConfig', obj.TxInfos{TxId}.SiteConfig, ...
                        'CarrierFrequency', CarrierFrequency, ...
                        'BandWidth', BandWidth, ...
                        'SampleRate', SampleRate);
                end

            end

        end

        function out = stepImpl(obj, x, FrameId, TxId, SegmentId)
            % transmit
            out = obj.forward{TxId}(x);
            obj.logger.debug("Transmit signals of Frame-Tx-Segment %06d:%02d:%02d by SimSDR %s", FrameId, TxId, SegmentId, obj.TxInfos{TxId}.SiteConfig.Name);

        end

    end

end
