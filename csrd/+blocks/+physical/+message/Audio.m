classdef Audio < matlab.System

    properties
        AudioFile {mustBeFile} = "../data/audio_mix_441.wav"
    end

    properties (Access = private)
        audioSrc
    end

    methods

        function obj = Audio(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            obj.audioSrc = dsp.AudioFileReader(obj.AudioFile, ...
                'SamplesPerFrame', 1024, 'PlayCount', inf);
        end

        function out = stepImpl(obj, MessageLength, SymbolRate)
            % SymbolRate is an useless var, only used to keep consistent
            % with other message classes' step function
            sample_times = round(MessageLength / 1024);
            y = zeros(1024, samnple_times);

            for i = 1:sample_times
                y(:, i) = obj.audioSrc();
            end

            out.data = y(1:MessageLength);

            out.SymbolRate = obj.audioSrc.SampleRate;
            out.MessageLength = MessageLength;

        end

    end

end
