classdef ChangShuo < matlab.System

    properties
        NumMaxTx (1, 1) {mustBePositive, mustBeReal} = 8
        NumMaxRx (1, 1) {mustBePositive, mustBeReal} = 8
        NumMaxTransmitTimes {mustBePositive, mustBeInteger} = 4
        NumTransmitAntennasRange (2, 1) {mustBePositive, mustBeReal} = [1, 4]
        NumReceiveAntennasRange (2, 1) {mustBePositive, mustBeReal} = [1; 4]
        ADRatio (1, 1) {mustBePositive, mustBeReal, mustBeLessThanOrEqual(ADRatio, 100)} = 10
        SymbolRateRange (2, 1) {mustBePositive, mustBeReal} = [30e3; 100e3]
        SymbolRateStep (1, 1) {mustBePositive, mustBeInteger} = 1e3
        MessageLengthRange (2, 1) {mustBePositive, mustBeInteger} = [1, 2]
        SamplePerSymbolRange (2, 1) {mustBePositive, mustBeInteger} = [2, 8]

        %
        TxMasterClockRateRange (2, 1) {mustBePositive, mustBeReal} = [100e4, 150e4]

        Message
        Modulate
        Behavior
        Transmit
        Channel
        Receive
    end

    properties (Access = private)

        logger
        runMessage
        runModulate
        runBehavior
        runTransmit
        runChannel
        runReceive

    end

    methods

        function obj = ChangShuo(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            obj.logger = mlog.Logger("logger");

            obj.logger.info("Init messgae handle by using %s.", obj.Message.handle);
            hMessage = sprintf("%s(AudioFile=obj.Message.AudioFile)", obj.Message.handle);
            obj.runMessage = eval(hMessage);

            obj.logger.info("Init modulate handle by using %s.", obj.Modulate.handle);
            obj.runModulate = obj.Modulate.handle;

            obj.logger.info("Init behavior handle by using %s.", obj.Behavior.handle);
            hBehavior = sprintf("%s(IsOverlap=obj.Behavior.IsOverlap, FrequencyOverlapRadioRange=obj.Behavior.FrequencyOverlapRadioRange)", obj.Behavior.handle);
            obj.runBehavior = eval(hBehavior);

            obj.logger.info("Init transmit handle by using %s.", obj.Transmit.handle);
            obj.runTransmit = obj.Transmit.handle;

            obj.logger.info("Init channel handle by using %s.", obj.Channel.handle);
            obj.runChannel = obj.Channel.handle;
            
            obj.logger.info("Init receive handle by using %s.", obj.Receive.handle);
            obj.runReceive = obj.Receive.handle;

        end

        function out = stepImpl(obj, FrameId)

            txs = cell(1, randi([1, obj.NumMaxTx]));
            % the same transimitter will be used to emit wireless signals using different modulation types
            isSuccess = false;

            while ~isSuccess

                for TxId = 1:length(txs)

                    if randi(100) <= obj.ADRatio
                        ParentModulatorType = "analog";
                    else
                        ParentModulatorType = "digital";
                    end

                    SymbolRate = randi((obj.SymbolRateRange(2) - obj.SymbolRateRange(1)) / obj.SymbolRateStep) * obj.SymbolRateStep + obj.SymbolRateRange(1);
                    SamplePerSymbol = randsample(obj.SamplePerSymbolRange(1):obj.SamplePerSymbolRange(2), 1);
                    NumTransmitAntennas = randsample(obj.NumTransmitAntennasRange(1):obj.NumTransmitAntennasRange(2), 1);
                    obj.runModulate = eval(sprintf("%s(Config=obj.Modulate.Config, SymbolRate=SymbolRate, SamplePerSymbol=SamplePerSymbol, NumTransmitAntennas=NumTransmitAntennas, ParentModulatorType=ParentModulatorType)", obj.Modulate.handle));

                    NumTransmitTimes = randi(obj.NumMaxTransmitTimes, 1);
                    ys = cell(1, NumTransmitTimes);

                    for SegmentId = 1:NumTransmitTimes
                        MessageLength = randi(round((obj.MessageLengthRange(2) - obj.MessageLengthRange(1)) / 100), 1) * 100 + obj.MessageLengthRange(1);
                        x = obj.runMessage(FrameId, TxId, SegmentId, ParentModulatorType, MessageLength, SymbolRate);
                        ys{SegmentId} = obj.runModulate(x, FrameId, TxId, SegmentId);
                    end

                    txs{TxId} = ys;
                end

                [txs, bound] = obj.runBehavior(txs, obj.TxMasterClockRateRange);

                if ~isempty(txs)
                    isSuccess = true;
                else
                    txs = cell(1, randi([1, obj.NumMaxTx]));
                end

            end

            for TxId = 1:length(txs)
                TxSiteConfig.owner = "ShuoChang";
                TxSiteConfig.location = "Beijing";
                currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
                TxSiteConfig.Name = sprintf('Tx_%s_%s_%s', TxSiteConfig.owner, TxSiteConfig.location, currentTime);
                obj.runTransmit = eval(sprintf("%s(Config=obj.Transmit.Config, SiteConfig=TxSiteConfig, MasterClockRateRange=obj.TxMasterClockRateRange)", obj.Transmit.handle));

                for SegmentId = 1:length(txs{TxId})
                    txs{TxId}{SegmentId} = obj.runTransmit(txs{TxId}{SegmentId}, FrameId, TxId, SegmentId);
                end

            end

            out = cell(1, randi([1, obj.NumMaxRx]));

            for RxId = 1:length(out)
                NumReceiveAntennas = randi(obj.NumReceiveAntennasRange(2) - obj.NumReceiveAntennasRange(1)) + obj.NumReceiveAntennasRange(1);
                RxSiteConfig.owner = "ShuoChang";
                RxSiteConfig.location = "Beijing";
                currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
                RxSiteConfig.Name = sprintf('Tx_%s_%s_%s', RxSiteConfig.owner, RxSiteConfig.location, currentTime);

                chs = txs;
                for TxId = 1:length(txs)
                    obj.runChannel = eval(sprintf("%s(MaxPaths=obj.Channel.MaxPaths, " + ...
                        "CarrierFrequency=txs{TxId}{1}.CarrierFrequency, " + ...
                        "MaxDistance=obj.Channel.MaxDistance, " + ...
                        "SpeedRange=obj.Channel.SpeedRange, " + ...
                        "MaxKFactor=obj.Channel.MaxKFactor, " + ...
                        "Fading=obj.Channel.Fading, " + ...
                        "NumTransmitAntennas=txs{TxId}{1}.NumTransmitAntennas, " + ...
                        "NumReceiveAntennas=NumReceiveAntennas)", obj.Channel.handle));

                    for SegmentId = 1:length(txs{TxId})
                        chs{TxId}{SegmentId} = obj.runChannel(txs{TxId}{SegmentId}, FrameId, RxId, TxId, SegmentId);
                    end

                end
                
                CenterFrequency = (bound.right + bound.left) / 2;
                BandWidth = (bound.right - bound.left) + 1000;
                obj.runReceive = eval(sprintf("%s(" + ...
                    "Config=obj.Receive.Config, SiteConfig=RxSiteConfig, " + ...
                    "NumReceiveAntennas=NumReceiveAntennas, " + ...
                    "CenterFrequency=CenterFrequency, " + ...
                    "BandWidth=BandWidth)", obj.Receive.handle));
                out{RxId} = obj.runReceive(chs, FrameId, RxId);
            end

        end

    end

end
