classdef Channel < matlab.System

    properties
        % config for modulate
        Config {mustBeFile} = "../config/_base_/simulate/channel/channel.json"
        ChannelInfos
    end

    properties (Access = private)
        forward
        logger
        cfgs
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
            obj.cfgs = load_config(obj.Config);

            if isempty(obj.ChannelInfos)
                obj.logger.error("ChannelInfos cannot be empty");
                exit(1);
            end

            TxNum = size(obj.ChannelInfos, 1);
            RxNum = size(obj.ChannelInfos, 2);
            obj.forward = cell(TxNum, RxNum);
            obj.FadingDistribution = cell(TxNum, RxNum);

            for TxIndex = 1:TxNum

                for RxIndex = 1:RxNum
                    current_channel = fieldnames(obj.cfgs.(obj.ChannelInfos{TxIndex, RxIndex}.ParentChannelType));
                    current_channel = current_channel{randperm(numel(current_channel), 1)};
                    kwargs = obj.cfgs.(obj.ChannelInfos{TxIndex, RxIndex}.ParentChannelType).(current_channel);

                    if ~exist(kwargs.handle, 'class')
                        obj.logger.error("Channel handle %s does not exist.", kwargs.handle);
                        exit(1);
                    else

                        delay_num = randi(kwargs.MaxPaths, 1);
                        PathDelays = zeros(1, delay_num + 1);
                        PathDelays(1) = 0;

                        if randi(100) <= kwargs.MaxDistance.Ratio
                            % indoor
                            Distance = randi(kwargs.MaxDistance.Indoor, 1); % m
                            PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 10);
                        else
                            % outdoor
                            Distance = randi(kwargs.MaxDistance.Outdoor, 1) * 1000; % m
                            PathDelays(2:end) = 10 .^ (sort(randi(3, 1, delay_num)) - 8);
                        end

                        % The dB values in a vector of average path gains often decay roughly linearly as a function of delay, but the specific delay profile depends on the propagation environment.
                        AveragePathGains = linspace(0, -10, delay_num + 1); % Example: decay from 0 dB to -20 dB

                        % 28m/s is the max speed about car in 100Km/s
                        % 1m/s is the 1.5m/s
                        Speed = rand(1) * (kwargs.SpeedRange(2) - kwargs.SpeedRange(1)) + kwargs.SpeedRange(1);
                        MaximumDopplerShift = obj.ChannelInfos{TxIndex, RxIndex}.CarrierFrequency * Speed / 3/10 ^ 8;

                        % https://www.mathworks.com/help/comm/ug/fading-channels.html
                        if randi(100) <= kwargs.Fading.Ratio
                            KFactor = rand(1) * kwargs.MaxKFactor + 1;
                            obj.FadingDistribution{TxIndex, RxIndex} = "Rician";
                        else
                            KFactor = 0;
                            obj.FadingDistribution{TxIndex, RxIndex} = "Rayleigh";
                        end

                        channelClass = str2func(kwargs.handle);
                        obj.forward{TxIndex, RxIndex} = channelClass(PathDelays = PathDelays, AveragePathGains = AveragePathGains, ...
                            MaximumDopplerShift = MaximumDopplerShift, KFactor = KFactor, Distance = Distance, ...
                            FadingTechnique = "Sum of sinusoids", InitialTimeSource = "Input port", ...
                            NumTransmitAntennas = obj.ChannelInfos{TxIndex, RxIndex}.NumTransmitAntennas, NumReceiveAntennas = obj.ChannelInfos{TxIndex, RxIndex}.NumReceiveAntennas, ...
                            FadingDistribution = obj.FadingDistribution{TxIndex, RxIndex});

                    end

                end

            end

        end

        function out = stepImpl(obj, x, FrameId, RxId, TxId, SegmentId)
            % channel
            out = obj.forward{TxId, RxId}(x);
            obj.logger.info("Pass Channel of Frame-Rx-Tx-Segment %06d:%02d:%02d:%02d by %d*%d-%s-MIMO", FrameId, RxId, TxId, SegmentId, obj.ChannelInfos{TxId, RxId}.NumTransmitAntennas, obj.ChannelInfos{TxId, RxId}.NumReceiveAntennas, obj.FadingDistribution{TxId, RxId});

        end

    end

end
