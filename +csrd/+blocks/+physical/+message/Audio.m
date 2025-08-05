classdef Audio < matlab.System
    % Audio - Audio Message Generator for Radio Communication Simulation
    %
    % This class reads audio files and generates message samples for use in
    % radio communication simulations. It supports continuous audio playback
    % with configurable scaling.
    %
    % Properties:
    %   AudioFile - Path to input audio file (default: "../data/audio_mix_441.wav")
    %
    % Private Properties:
    %   audioSrc - Audio file reader object
    %
    % Methods:
    %   Audio - Constructor that accepts name-value pair arguments
    %   setupImpl - Initializes audio file reader
    %   stepImpl - Generates audio samples based on requested length
    %
    % Example:
    %   audioMsg = Audio('AudioFile', 'myaudio.wav', 'scale', 10);
    %   out = audioMsg.step(1000, 44100);
    %   % out contains:
    %   %   - data: Audio samples
    %   %   - SymbolRate: Audio sample rate
    %   %   - MessageLength: Actual message length

    properties
        % AudioFile - Path to input audio file
        % Must be a valid file path. Default is relative to this file.
        AudioFile {mustBeFile} = fullfile(fileparts(mfilename('fullpath')), "audio_mix_441.wav")
    end

    properties (Access = private)
        audioSrc % Audio file reader object
    end

    methods

        function obj = Audio(varargin)
            % Audio - Constructor for Audio message generator
            %
            % Syntax:
            %   obj = Audio()
            %   obj = Audio('PropertyName', PropertyValue, ...)
            %
            % Optional Parameters:
            %   AudioFile - Path to input audio file
            %   scale - Message length scaling factor

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % setupImpl - Initialize the audio file reader
            %
            % Creates a dsp.AudioFileReader object configured for:
            % - 1024 samples per frame
            % - Infinite playback count (loops when reaching end)

            obj.audioSrc = dsp.AudioFileReader(obj.AudioFile, ...
                'SamplesPerFrame', 1024, 'PlayCount', inf);
        end

        function out = stepImpl(obj, MessageLength, SymbolRate)
            % stepImpl - Generate audio message samples
            %
            % Syntax:
            %   out = stepImpl(obj, MessageLength, SymbolRate)
            %
            % Inputs:
            %   MessageLength - Requested base message length
            %   SymbolRate - Unused (kept for interface consistency)
            %
            % Outputs:
            %   out - Structure containing:
            %       data - Audio samples [MessageLength * scale x 1]
            %       SymbolRate - Audio sample rate from source file
            %       MessageLength - Actual message length after scaling

            % Scale the requested message length
            sample_times = ceil(MessageLength / 1024);
            y = zeros(1024, sample_times);

            % Read audio samples in blocks of 1024
            for i = 1:sample_times
                y(:, i) = obj.audioSrc();
            end

            % Prepare output structure
            out.data = y(1:MessageLength)';
            out.SymbolRate = obj.audioSrc.SampleRate;
            out.MessageLength = MessageLength;
        end

    end

end
