classdef Receive < matlab.System

    properties
        % config for receive
        Config {mustBeFile} = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', '..', ...
            'config', '_base_', 'simulate', 'radiofront', 'receive.json')
        RxInfos

    end

    properties (Access = private)
        forward
        logger
        cfgs
    end

    methods

        function obj = Receive(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = Log.getInstance();
            obj.cfgs = load_config(obj.Config);

            obj.forward = cell(1, length(obj.RxInfos));

            for RxId = 1:length(obj.RxInfos)
                ReceiverTypes = fieldnames(obj.cfgs.(obj.RxInfos{RxId}.ParentReceiverType));
                ReceiverType = ReceiverTypes{randperm(numel(ReceiverTypes), 1)};

                kwargs = obj.cfgs.(obj.RxInfos{RxId}.ParentReceiverType).(ReceiverType);
                % verify receiver class exists and create instance
                if ~exist(kwargs.handle, 'class')
                    obj.logger.error("Receiver handle %s does not exist.", kwargs.handle);
                    exit(1);
                else

                    if isfield(obj.RxInfos{RxId}, "MasterClockRateRange")
                        MasterClockRateRange = obj.RxInfos{RxId}.MasterClockRateRange;
                    else
                        MasterClockRateRange = kwargs.MasterClockRateRange;
                    end

                    MasterClockRate = MasterClockRateRange(1);
                    DCOffset = rand(1) * (kwargs.DCOffsetRange(2) - kwargs.DCOffsetRange(1)) + kwargs.DCOffsetRange(1);

                    IqImbalanceConfig.A = rand(1) * (kwargs.IqImbalanceConfig.A(2) - kwargs.IqImbalanceConfig.A(1)) + kwargs.IqImbalanceConfig.A(1);
                    IqImbalanceConfig.P = rand(1) * (kwargs.IqImbalanceConfig.P(2) - kwargs.IqImbalanceConfig.P(1)) + kwargs.IqImbalanceConfig.P(1);

                    ThermalNoiseConfig.NoiseTemperature = rand(1) * (kwargs.ThermalNoiseConfig.NoiseTemperature(2) - kwargs.ThermalNoiseConfig.NoiseTemperature(1)) + kwargs.ThermalNoiseConfig.NoiseTemperature(1);
                    MemoryLessNonlinearityConfig = MemoryLessNonlinearityRandom(kwargs.MemoryLessNonlinearityConfig);

                    if isfield(obj.RxInfos{RxId}, "TimeDurationRange")
                        TimeDurationRange = obj.RxInfos{RxId}.TimeDurationRange;
                    else
                        TimeDurationRange = kwargs.TimeDurationRange;
                    end

                    TimeDuration = rand(1) * (TimeDurationRange(2) - TimeDurationRange(1)) + TimeDurationRange(1);

                    % create a function handle from the class name
                    receiverClass = str2func(kwargs.handle);

                    % instantiate the class using the function handle
                    obj.forward{RxId} = receiverClass(MasterClockRate = MasterClockRate, IqImbalanceConfig = IqImbalanceConfig, ...
                        CenterFrequency = obj.RxInfos{RxId}.CenterFrequency, BandWidth = obj.RxInfos{RxId}.BandWidth, ...
                        DCOffset = DCOffset, ThermalNoiseConfig = ThermalNoiseConfig, TimeDuration = TimeDuration, ...
                        NumReceiveAntennas = obj.RxInfos{RxId}.NumReceiveAntennas, MemoryLessNonlinearityConfig = MemoryLessNonlinearityConfig, SiteConfig = obj.RxInfos{RxId}.SiteConfig);
                end

            end

        end

        function out = stepImpl(obj, x, FrameId, RxId)
            % transmit
            out = obj.forward{RxId}(x);
            obj.logger.debug("Receive signals of Frame-Rx %06d:%02d by SimSDR %s", FrameId, RxId, obj.RxInfos{RxId}.SiteConfig.Name);

        end

    end

end
