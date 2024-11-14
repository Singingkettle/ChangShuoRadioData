classdef Transmit < matlab.System

    properties
        % config for modulate
        SiteConfig
        MasterClockRateRange (2, 1) {mustBePositive, mustBeReal} = [100e4; 150e4]
        Config {mustBeFile} = "../config/_base_/simulate/radiofront/transmit.json"

    end

    properties (Access = private)
        run
        logger
        cfgs
        ModulatorType
        baseModulatorType
        ModulatorOrder
    end

    methods

        function obj = Transmit(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = mlog.Logger("logger");
            obj.cfgs = load_config(obj.Config);

            MasterClockRate = randi((obj.MasterClockRateRange(2) - obj.MasterClockRateRange(1)) / obj.cfgs.MasterClockRateStep) * obj.cfgs.MasterClockRateStep + obj.MasterClockRateRange(1);
            DCOffset = rand(1) * (obj.cfgs.DCOffsetRange(2) - obj.cfgs.DCOffsetRange(1)) + obj.cfgs.DCOffsetRange(1);

            IqImbalanceConfig.A = rand(1) * (obj.cfgs.IqImbalanceConfig.A(2) - obj.cfgs.IqImbalanceConfig.A(1)) + obj.cfgs.IqImbalanceConfig.A(1);
            IqImbalanceConfig.P = rand(1) * (obj.cfgs.IqImbalanceConfig.P(2) - obj.cfgs.IqImbalanceConfig.P(1)) + obj.cfgs.IqImbalanceConfig.P(1);

            PhaseNoiseConfig.Level = randi(obj.cfgs.PhaseNoiseConfig.Level(2) - obj.cfgs.PhaseNoiseConfig.Level(1)) + obj.cfgs.PhaseNoiseConfig.Level(1);
            PhaseNoiseConfig.FrequencyOffset = randi(obj.cfgs.PhaseNoiseConfig.FrequencyOffset(2) - obj.cfgs.PhaseNoiseConfig.FrequencyOffset(1)) + obj.cfgs.PhaseNoiseConfig.FrequencyOffset(1);
            MemoryLessNonlinearityConfig = MemoryLessNonlinearityRandom(obj.cfgs.MemoryLessNonlinearityConfig);

            obj.run = TRFSimulator(MasterClockRate = MasterClockRate, IqImbalanceConfig = IqImbalanceConfig, ...
                DCOffset = DCOffset, PhaseNoiseConfig = PhaseNoiseConfig, ...
                MemoryLessNonlinearityConfig = MemoryLessNonlinearityConfig, TxSiteConfig = obj.SiteConfig);
        end

        function out = stepImpl(obj, x, FrameId, TxId, SegmentId)
            % transmit
            out = obj.run(x);
            obj.logger.info("Transmit signals of Frame-Tx-Segment %06d:%02d:%02d by SimSDR %s", FrameId, TxId, SegmentId, obj.SiteConfig.Name);

        end

    end

end
