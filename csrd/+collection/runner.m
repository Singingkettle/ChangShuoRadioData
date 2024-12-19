classdef runner < matlab.System

    properties
        handle
        NumFrames
        Seed
        LogLevel
        Data
        Physical
    end

    properties (Access = private)
        % The configuration file
        run
        logger
    end

    methods

        function obj = runner(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function obj = setupImpl(obj)
            % Load the configuration file
            simEngine = sprintf("%s( " + ...
                "NumMaxTx=obj.Physical.NumMaxTx, " + ...
                "NumMaxRx=obj.Physical.NumMaxRx, " + ...
                "NumMaxTransmitTimes=obj.Physical.NumMaxTransmitTimes, " + ...
                "NumTransmitAntennasRange=obj.Physical.NumTransmitAntennasRange, " + ...
                "NumReceiveAntennasRange=obj.Physical.NumReceiveAntennasRange, " + ...
                "ADRatio=obj.Physical.ADRatio, " + ...
                "SymbolRateRange=obj.Physical.SymbolRateRange, " + ...
                "SymbolRateStep=obj.Physical.SymbolRateStep, " + ...
                "SamplePerSymbolRange=obj.Physical.SamplePerSymbolRange, " + ...
                "MessageLengthRange=obj.Physical.MessageLengthRange, " + ...
                "Message=obj.Physical.Message, " + ...
                "Event=obj.Physical.Event, " + ...
                "Modulate=obj.Physical.Modulate, " + ...
                "Transmit=obj.Physical.Transmit, " + ...
                "Channel=obj.Physical.Channel, " + ...
                "Receive=obj.Physical.Receive)", obj.Physical.handle);
            obj.run = eval(simEngine);

            % Init the obj.logger
            obj.logger = mlog.Logger("logger");
            obj.logger.FileThreshold = obj.LogLevel;
            obj.logger.CommandWindowThreshold = obj.LogLevel;
            obj.logger.MessageReceivedEventThreshold = "MESSAGE";
            obj.logger.LogFolder = obj.Data.SaveFolder;
            obj.logger.RotationPeriod = "day";

            obj.logger.info("Start Radion Data Collection by using %s.", obj.Physical.handle);
            % Set the number of frames
            obj.logger.info("The total number of frames: %d.", obj.NumFrames);
            % Set the seed
            rng(obj.Seed);
            obj.logger.info("Random seed set to %d.", obj.Seed);
        end

        function out = stepImpl(obj)
            % modulate
            out = cell(1, obj.NumFrames);

            for FrameId = 1:obj.NumFrames
                out{FrameId} = obj.run(FrameId);
            end

        end

    end

end
