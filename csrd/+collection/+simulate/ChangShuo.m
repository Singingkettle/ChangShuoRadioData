classdef ChangShuo < matlab.System

    properties

        NumMaxTx (1, 1) {mustBePositive, mustBeReal} = 8
        NumMaxTransmitTimes {mustBePositive, mustBeInteger} = 4
        NumTransmitAntennasRange (2, 1) {mustBePositive, mustBeReal} = [1, 4]

        NumMaxRx (1, 1) {mustBePositive, mustBeReal} = 8
        NumReceiveAntennasRange (2, 1) {mustBePositive, mustBeReal} = [1; 4]

        ADRatio (1, 1) {mustBePositive, mustBeReal, mustBeLessThanOrEqual(ADRatio, 100)} = 10
        SymbolRateRange (2, 1) {mustBePositive, mustBeReal} = [30e3; 100e3]
        SymbolRateStep (1, 1) {mustBePositive, mustBeInteger} = 1e3
        MessageLengthRange (2, 1) {mustBePositive, mustBeInteger} = [1, 2]
        SamplePerSymbolRange (2, 1) {mustBePositive, mustBeInteger} = [2, 8]

        Message
        Modulate
        Event
        Transmit
        Channel
        Receive
    end

    properties (Access = private)

        logger

    end

    methods

        function obj = ChangShuo(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            obj.logger = Log.getInstance();

        end

        function out = stepImpl(obj, FrameId)

            txs = cell(1, randi([1, obj.NumMaxTx]));

            if isempty(txs)
                out = [];
                return;
            else
                MessageInfos = cell(1, length(txs));
                ModulateInfos = cell(1, length(txs));
                TxInfos = cell(1, length(txs));

                for TxId = 1:length(txs)

                    if randi(100) <= obj.ADRatio
                        ParentModulatorType = "analog";
                        MessageType = "Audio";
                    else
                        ParentModulatorType = "digital";
                        MessageType = "RandomBit";
                    end

                    SymbolRate = randi((obj.SymbolRateRange(2) - obj.SymbolRateRange(1)) / obj.SymbolRateStep) * obj.SymbolRateStep + obj.SymbolRateRange(1);
                    SamplePerSymbol = randsample(obj.SamplePerSymbolRange(1):obj.SamplePerSymbolRange(2), 1);
                    if randi(100) <= 50
                        NumTransmitAntennas = 1;
                    else
                        NumTransmitAntennas = randsample(obj.NumTransmitAntennasRange(1):obj.NumTransmitAntennasRange(2), 1);
                    end
                    TxSiteConfig.owner = "ShuoChang";
                    TxSiteConfig.location = "Beijing";
                    currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
                    TxSiteConfig.Name = sprintf('Tx_%s_%s_%s', TxSiteConfig.owner, TxSiteConfig.location, currentTime);

                    MessageInfos{TxId}.MessageType = MessageType;
                    ModulateInfos{TxId}.ParentModulatorType = ParentModulatorType;
                    ModulateInfos{TxId}.SymbolRate = SymbolRate;
                    ModulateInfos{TxId}.SamplePerSymbol = SamplePerSymbol;
                    ModulateInfos{TxId}.NumTransmitAntennas = NumTransmitAntennas;
                    TxInfos{TxId}.ParentTransmitterType = "Simulator";
                    TxInfos{TxId}.NumTransmitAntennas = NumTransmitAntennas;
                    TxInfos{TxId}.SiteConfig = TxSiteConfig;

                end

                % Init handles of message
                obj.logger.debug("Init messgae handle by using %s in the %dth Frame.", obj.Message.handle, FrameId);
                runMessage = eval(sprintf("%s(Config=obj.Message.Config, MessageInfos=MessageInfos)", obj.Message.handle));

                % Init handles of modulate
                obj.logger.debug("Init modulate handle by using %s in the %dth Frame.", obj.Modulate.handle, FrameId);
                runModulate = eval(sprintf("%s(Config=obj.Modulate.Config, ModulateInfos=ModulateInfos)", obj.Modulate.handle));

                for TxId = 1:length(txs)

                    if ModulateInfos{TxId}.ParentModulatorType == "digital"
                        NumTransmitTimes = randi(obj.NumMaxTransmitTimes, 1);
                    else
                        % For analog modulation, only one transmission is allowed to save the simulation time for a frame
                        NumTransmitTimes = 1;
                    end

                    ys = cell(1, NumTransmitTimes);

                    for SegmentId = 1:NumTransmitTimes
                        MessageLength = randi(round((obj.MessageLengthRange(2) - obj.MessageLengthRange(1)) / 100), 1) * 100 + obj.MessageLengthRange(1);
                        x = runMessage(FrameId, TxId, SegmentId, MessageLength, SymbolRate);
                        ys{SegmentId} = runModulate(x, FrameId, TxId, SegmentId);
                    end

                    txs{TxId} = ys;
                end

                EventInfos = cell(1, 1);
                EventInfos{1}.ParentEventType = "Wireless";
                % Init handles of event
                obj.logger.debug("Init event handle by using %s in the %dth Frame.", obj.Event.handle, FrameId);
                runEvent = eval(sprintf("%s(Config=obj.Event.Config, EventInfos=EventInfos)", obj.Event.handle));

                [txs, Infos, MasterClockRateRange, BandWidthRange] = runEvent(FrameId, 1, txs);

                for TxId = 1:length(txs)
                    TxInfos{TxId}.MasterClockRateRange = MasterClockRateRange;
                    TxInfos{TxId}.CarrierFrequency = Infos{TxId}.CarrierFrequency;
                    TxInfos{TxId}.BandWidth = Infos{TxId}.BandWidth;
                    TxInfos{TxId}.SampleRate = Infos{TxId}.SampleRate;
                end

                % Init handles of transmit
                obj.logger.debug("Init transmit handle by using %s in the %dth Frame.", obj.Transmit.handle, FrameId);
                runTransmit = eval(sprintf("%s(Config=obj.Transmit.Config, TxInfos=TxInfos)", obj.Transmit.handle));

                for TxId = 1:length(txs)

                    for SegmentId = 1:length(txs{TxId})
                        txs{TxId}{SegmentId} = runTransmit(txs{TxId}{SegmentId}, FrameId, TxId, SegmentId);
                    end

                end

                %
                RxInfos = cell(1, randi([1, obj.NumMaxRx]));

                for RxId = 1:length(RxInfos)
                    NumReceiveAntennas = randsample(obj.NumReceiveAntennasRange(1):obj.NumReceiveAntennasRange(2), 1);
                    RxSiteConfig.owner = "ShuoChang";
                    RxSiteConfig.location = "Beijing";
                    currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
                    RxSiteConfig.Name = sprintf('Rx_%s_%s_%s', RxSiteConfig.owner, RxSiteConfig.location, currentTime);
                    RxInfos{RxId}.SiteConfig = RxSiteConfig;
                    RxInfos{RxId}.ParentReceiverType = "Simulator";
                    RxInfos{RxId}.NumReceiveAntennas = NumReceiveAntennas;
                    RxInfos{RxId}.MasterClockRateRange = [0, 0];
                    RxInfos{RxId}.BandWidth = BandWidthRange(2) - BandWidthRange(1);
                    RxInfos{RxId}.CenterFrequency = round((BandWidthRange(2) + BandWidthRange(1)) / 2);
                end

                ChannelInfos = cell(length(TxInfos), length(RxInfos));

                for TxId = 1:length(TxInfos)

                    for RxId = 1:length(RxInfos)
                        ChannelInfos{TxId, RxId}.ParentChannelType = "Simulate";
                        ChannelInfos{TxId, RxId}.CarrierFrequency = txs{TxId}{1}.CarrierFrequency;
                        ChannelInfos{TxId, RxId}.NumTransmitAntennas = txs{TxId}{1}.NumTransmitAntennas;
                        ChannelInfos{TxId, RxId}.NumReceiveAntennas = RxInfos{RxId}.NumReceiveAntennas;

                        if txs{TxId}{1}.SampleRate > RxInfos{RxId}.MasterClockRateRange(1)
                            RxInfos{RxId}.MasterClockRateRange = [txs{TxId}{1}.SampleRate, txs{TxId}{1}.SampleRate * 2];
                        end

                    end

                end

                % Init handles of channel
                obj.logger.debug("Init channel handle by using %s in the %dth Frame.", obj.Channel.handle, FrameId);
                runChannel = eval(sprintf("%s(Config=obj.Channel.Config, ChannelInfos=ChannelInfos)", obj.Channel.handle));

                % Init handles of receive
                obj.logger.debug("Init receive handle by using %s in the %dth Frame.", obj.Receive.handle, FrameId);
                runReceive = eval(sprintf("%s(Config=obj.Receive.Config, RxInfos=RxInfos)", obj.Receive.handle));

                out = cell(1, randi([1, length(RxInfos)]));

                for RxId = 1:length(RxInfos)
                    chs = txs;

                    for TxId = 1:length(txs)

                        for SegmentId = 1:length(txs{TxId})
                            chs{TxId}{SegmentId} = runChannel(txs{TxId}{SegmentId}, FrameId, RxId, TxId, SegmentId);
                        end

                    end

                    out{RxId} = runReceive(chs, FrameId, RxId);
                end

            end

        end

    end

end
