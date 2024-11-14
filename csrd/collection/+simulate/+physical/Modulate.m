classdef Modulate < matlab.System

    properties
        % config for modulate
        Config {mustBeFile} = "../config/_base_/simulate/modulate/modulate.json"
        SymbolRate (1, 1) {mustBePositive, mustBeReal} = 1e3
        SamplePerSymbol (1, 1) {mustBePositive, mustBeInteger} = 2
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger} = 1
        ParentModulatorType {mustBeMember(ParentModulatorType, ["analog", "digital"])} = "digital"
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

        function obj = Modulate(varargin)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = mlog.Logger("logger");
            obj.cfgs = load_config(obj.Config);

            % Load the configuration file
            ModulatorTypes = fieldnames(obj.cfgs.(obj.ParentModulatorType));
            obj.ModulatorType = randsample(ModulatorTypes, 1);
            obj.ModulatorType = obj.ModulatorType{1};

            if obj.ModulatorType == "OFDM" || obj.ModulatorType == "OTFS" || obj.ModulatorType == "SCFDMA"
                obj.baseModulatorType = randsample(["psk", "qam"], 1);
                ModulatorOrders = obj.cfgs.(obj.ParentModulatorType).(obj.ModulatorType).(upper(obj.baseModulatorType));
                obj.SamplePerSymbol = 1;
            else
                ModulatorOrders = obj.cfgs.(obj.ParentModulatorType).(obj.ModulatorType);
            end

            obj.ModulatorOrder = ModulatorOrders(randperm(numel(ModulatorOrders), 1));
            SampleRate = obj.SymbolRate * obj.SamplePerSymbol;
            modulate = sprintf("%s(SampleRate=SampleRate, ModulatorOrder=obj.ModulatorOrder, SamplePerSymbol=obj.SamplePerSymbol, NumTransmitAntennas=obj.NumTransmitAntennas)", obj.ModulatorType);
            obj.run = eval(modulate);
        end

        function out = stepImpl(obj, x, FrameId, TxId, SegmentId)
            % modulate
            if ~(obj.ModulatorType == "OFDM" || obj.ModulatorType == "OTFS" || obj.ModulatorType == "SCFDMA")
                save_len = fix(length(x.data) / 10);
                x.data = x.data(1:save_len);
            end
            out = obj.run(x);
            out.ModulatorType = obj.ModulatorType;

            if obj.ModulatorType == "OFDM" || obj.ModulatorType == "OTFS" || obj.ModulatorType == "SCFDMA"
                out.baseModulatorType = obj.baseModulatorType;
                obj.logger.info("Generate modulated signals of Frame-Tx-Segment %06d:%02d:%02d using %d-%s-%s", FrameId, TxId, SegmentId, obj.ModulatorOrder, obj.baseModulatorType, obj.ModulatorType);
            else
                obj.logger.info("Generate modulated signals of Frame-Tx-Segment %06d:%02d:%02d using %d-%s", FrameId, TxId, SegmentId, obj.ModulatorOrder, obj.ModulatorType);
            end

        end

    end

end
