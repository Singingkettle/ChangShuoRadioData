% Message Class
%
% This class defines a Message object that inherits from the matlab.System class.
% It is used to handle the modulation of signals based on the configuration provided.
%
% Properties:
%
%   Radio (double):
%       A positive real number less than or equal to 100. Default is 10.
%       Determines the probability of selecting an analog modulator.
%
%   ConfigFile (string):
%       A file path to the configuration file. Default is '../config/_base_/simulate/modulator/modulate.json'.
%
%   DigitalSymbolRateRange (double array):
%       A positive real array specifying the range of digital symbol rates. Default is [1e3, 1e6].
%
%   DigitalSymbolRateStep (double):
%       A positive real number specifying the step size for digital symbol rates. Default is 1e3.
%
% Properties (Access = private):
%
%   run (object):
%       An object that handles the modulation process.
%
% Methods:
%
%   Message(varargin):
%       Constructor method that sets the properties of the object.
%
%   setupImpl(obj):
%       Protected method that loads the configuration file and initializes the modulator based on the Radio property.
%
%   stepImpl(obj, x):
%       Protected method that performs the modulation on the input signal x and returns the modulated signal y.
classdef Message < matlab.System

    properties
        AudioFile {mustBeFile} = "../data/audio_mix_441.wav"
    end

    properties (Access = private)
        runAudio
        runRandomBit
        logger
    end

    methods

        function obj = Message(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.logger = mlog.Logger("logger");
            obj.runAudio = Audio(AudioFile = obj.AudioFile);
            obj.runRandomBit = RandomBit();
        end

        function out = stepImpl(obj, FrameId, TxId, SegmentId, ParentModulatorType, MessageLength, SymbolRate)
            % modulate
            switch ParentModulatorType
                case "analog"
                    runMessage = obj.runAudio;
                    MessageType = "Audio";
                case "digital"
                    runMessage = obj.runRandomBit;
                    MessageType = "RandomBit";
                otherwise
                    obj.logger.error("ParentModulatorType %s is not supported.", ParentModulatorType);
                    exit(1);
            end

            out = runMessage(MessageLength, SymbolRate);
            obj.logger.info("Generate messages of Frame-Tx-Segment %06d:%02d:%02d using %s", FrameId, TxId, SegmentId, MessageType);
        end

    end

end
