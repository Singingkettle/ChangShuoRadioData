classdef Channel < matlab.System

    properties
        % config for modulate
        MaxPaths (1, 1) {mustBePositive, mustBeInteger} = 3
        CarrierFrequency (1, 1) {mustBePositive, mustBeReal} = 2.4e9
        MaxDistance
        SpeedRange (2, 1) {mustBePositive, mustBeReal} = [1.5, 28]
        MaxKFactor (1, 1) {mustBePositive, mustBeInteger} = 9
        Fading
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeGreaterThanOrEqual(NumTransmitAntennas, 1)} = 1
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeGreaterThanOrEqual(NumReceiveAntennas, 1)} = 1

    end

    properties (Access = private)
        run
        logger
        FadingDistribution
    end

    methods

        function obj = Channel(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = mlog.Logger("logger");

            delay_num = randi(obj.MaxPaths, 1);
            PathDelays = zeros(1, delay_num + 1);
            PathDelays(1) = 0;

            if randi(100) <= obj.MaxDistance.Ratio
                % indoor
                Distance = randi(obj.MaxDistance.Indoor, 1); % m
                PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 10);
            else
                % outdoor
                Distance = randi(obj.MaxDistance.Outdoor, 1) * 1000; % m
                PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 8);
            end

            % The dB values in a vector of average path gains often decay roughly linearly as a function of delay, but the specific delay profile depends on the propagation environment.
            AveragePathGains = linspace(0, -10, delay_num + 1); % Example: decay from 0 dB to -20 dB

            % 28m/s is the max speed about car in 100Km/s
            % 1m/s is the 1.5m/s
            Speed = rand(1) * (obj.SpeedRange(2) - obj.SpeedRange(1)) + obj.SpeedRange(1);
            MaximumDopplerShift = obj.CarrierFrequency * Speed / 3/10 ^ 8;

            % https://www.mathworks.com/help/comm/ug/fading-channels.html
            if randi(100) <= obj.Fading.Ratio
                KFactor = rand(1) * obj.MaxKFactor + 1;
                obj.FadingDistribution = "Rician";
            else
                KFactor = 0;
                obj.FadingDistribution = "Rayleigh";
            end

            current_channel = "MIMO";
            % 根据字符串选择不同的类
            switch current_channel
                case "MIMO"
                    obj.run = MIMO(PathDelays = PathDelays, AveragePathGains = AveragePathGains, ...
                        MaximumDopplerShift = MaximumDopplerShift, KFactor = KFactor, Distance = Distance, ...
                        FadingTechnique = "Sum of sinusoids", InitialTimeSource = "Input port", ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, NumReceiveAntennas = obj.NumReceiveAntennas, ...
                        FadingDistribution = obj.FadingDistribution);
                otherwise
                    error('Unknown channel type');
            end

        end

        function out = stepImpl(obj, x, FrameId, RxId, TxId, SegmentId)
            % transmit
            out = obj.run(x);
            obj.logger.info("Pass Channel of Frame-Rx-Tx-Segment %06d:%02d:%02d:%02d by %d*%d-%s-MIMO", FrameId, RxId, TxId, SegmentId, obj.NumTransmitAntennas, obj.NumReceiveAntennas, obj.FadingDistribution);

        end

    end

end
