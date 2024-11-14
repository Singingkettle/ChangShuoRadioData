classdef Receive < matlab.System

    properties
        % config for modulate
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e3;
        CenterFrequency (1, 1) {mustBePositive, mustBeReal, mustBeInteger} = 20e3
        SiteConfig
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        Config {mustBeFile} = "../config/_base_/simulate/radiofront/receive.json"

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

        function obj = Receive(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = mlog.Logger("logger");
            obj.cfgs = load_config(obj.Config);

            MasterClockRate = randi((obj.cfgs.MasterClockRateRange(2) - obj.cfgs.MasterClockRateRange(1)) / obj.cfgs.MasterClockRateStep) * obj.cfgs.MasterClockRateStep + obj.cfgs.MasterClockRateRange(1);
            DCOffset = rand(1) * (obj.cfgs.DCOffsetRange(2) - obj.cfgs.DCOffsetRange(1)) + obj.cfgs.DCOffsetRange(1);

            IqImbalanceConfig.A = rand(1) * (obj.cfgs.IqImbalanceConfig.A(2) - obj.cfgs.IqImbalanceConfig.A(1)) + obj.cfgs.IqImbalanceConfig.A(1);
            IqImbalanceConfig.P = rand(1) * (obj.cfgs.IqImbalanceConfig.P(2) - obj.cfgs.IqImbalanceConfig.P(1)) + obj.cfgs.IqImbalanceConfig.P(1);

            ThermalNoiseConfig.NoiseFigure = rand(1)*(obj.cfgs.ThermalNoiseConfig.NoiseFigure(2)-obj.cfgs.ThermalNoiseConfig.NoiseFigure(1))+obj.cfgs.ThermalNoiseConfig.NoiseFigure(1);
            MemoryLessNonlinearityConfig = MemoryLessNonlinearityRandom(obj.cfgs.MemoryLessNonlinearityConfig);
            
            TimeDuration = rand(1)*(obj.cfgs.TimeDurationRange(2)-obj.cfgs.TimeDurationRange(1)) + obj.cfgs.TimeDurationRange(1);
            obj.run = RRFSimulator(MasterClockRate=MasterClockRate, IqImbalanceConfig=IqImbalanceConfig, ...
                                CenterFrequency = obj.CenterFrequency, BandWidth = obj.BandWidth, ...
                                DCOffset=DCOffset, ThermalNoiseConfig=ThermalNoiseConfig, TimeDuration = TimeDuration, ...
                                NumReceiveAntennas=obj.NumReceiveAntennas, MemoryLessNonlinearityConfig=MemoryLessNonlinearityConfig, SiteConfig=obj.SiteConfig);
        end

        function out = stepImpl(obj, x, FrameId, RxId)
            % transmit
            out = obj.run(x);
            obj.logger.info("Receive signals of Frame-Rx %06d:%02d by SimSDR %s", FrameId, RxId, obj.SiteConfig.Name);

        end

    end

end
