classdef Audio < matlab.System
    % Audio - Audio Message Generator for Radio Communication Simulation
    %
    % This class reads audio files and generates message samples for analog
    % modulation (FM/PM/AM variants). Analog modulators require a continuous
    % real-valued baseband; this block supplies it from real audio recordings.
    %
    % A pool of audio clips lives under the AudioDirectory. One clip is chosen
    % deterministically per use: when Seed is set the selection is a pure
    % function of the seed, so a fixed scenario/emitter seed always reproduces
    % the same audio. The planner derives the seed per emitter so different
    % transmitters carry different program material while runs stay replayable.
    %
    % Properties:
    %   AudioFile      - Explicit audio file path. Used only when AudioDirectory
    %                    holds no readable clip (backward-compatible default).
    %   AudioDirectory - Folder scanned for *.wav clips (the selection pool).
    %   Seed           - Non-negative integer selection seed, or [] for the
    %                    global random stream (reproducible under scenario rng).
    %
    % Methods:
    %   Audio    - Constructor that accepts name-value pair arguments
    %   setupImpl - Resolves the clip pool, selects one clip, opens the reader
    %   stepImpl  - Generates audio samples for the requested message length
    %
    % Example:
    %   audioMsg = Audio('Seed', 12345);
    %   out = audioMsg.step(1000, 44100);
    %   % out.data holds the audio samples for the selected clip.

    properties
        % AudioFile - Explicit fallback audio file path.
        % Must be a valid file path. Default is the legacy bundled clip.
        AudioFile {mustBeFile} = fullfile(fileparts(mfilename('fullpath')), "audio_mix_441.wav")

        % AudioDirectory - Folder of *.wav clips used as the selection pool.
        % Default is the bundled public-domain clip set next to this class.
        AudioDirectory {mustBeTextScalar} = fullfile(fileparts(mfilename('fullpath')), "audio")

        % Seed - Non-negative integer selection seed, or [] for global stream.
        Seed (:, :) {mustBeInteger, mustBeNonnegative} = []
    end

    properties (Access = private)
        audioSrc % Audio file reader object
        selectedFile % Resolved audio file actually opened
    end

    methods

        function obj = Audio(varargin)
            % Audio - Constructor for Audio message generator
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Syntax:
            %   obj = Audio()
            %   obj = Audio('PropertyName', PropertyValue, ...)
            %
            % Optional Parameters:
            %   AudioFile, AudioDirectory, Seed

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % setupImpl - Resolve the clip pool, select a clip, open the reader
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Selection is deterministic given Seed: idx = mod(Seed, N) + 1
            % over the sorted clip list, so runs replay identically. When Seed
            % is empty the global random stream is used (still reproducible
            % under the scenario-level rng seed).

            clipList = obj.resolveClipList();
            numClips = numel(clipList);
            if numClips == 0
                error('CSRD:Message:NoAudioClips', ...
                    ['Audio message source found no readable clip. Checked ', ...
                     'AudioDirectory "%s" and AudioFile "%s".'], ...
                    char(string(obj.AudioDirectory)), char(string(obj.AudioFile)));
            end

            if isempty(obj.Seed)
                idx = randi(numClips);
            else
                idx = mod(double(obj.Seed), numClips) + 1;
            end
            obj.selectedFile = clipList{idx};

            obj.audioSrc = dsp.AudioFileReader(obj.selectedFile, ...
                'SamplesPerFrame', 1024, 'PlayCount', inf);
        end

        function out = stepImpl(obj, MessageLength, SymbolRate)
            % stepImpl - Generate audio message samples
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Syntax:
            %   out = stepImpl(obj, MessageLength, SymbolRate)
            %
            % Inputs:
            %   MessageLength - Requested message length in samples
            %   SymbolRate - Unused (kept for interface consistency)
            %
            % Outputs:
            %   out - Structure containing:
            %       data - Audio samples [1 x MessageLength]
            %       SymbolRate - Audio sample rate from source file
            %       MessageLength - Actual message length
            %       AudioFile - Path of the selected clip (provenance)

            % Read enough audio in blocks of 1024 to cover MessageLength.
            sample_times = ceil(MessageLength / 1024);
            y = zeros(1024, sample_times);

            for i = 1:sample_times
                block = obj.audioSrc();
                % Audio assets may be stereo/multichannel; the message stream
                % is a single baseband channel, so mix down to mono. Without
                % this a stereo clip returns [1024 x 2] and the [1024 x 1]
                % column assignment below would error.
                if size(block, 2) > 1
                    block = mean(block, 2);
                end
                y(:, i) = block;
            end

            out.data = y(1:MessageLength)';
            out.SymbolRate = obj.audioSrc.SampleRate;
            out.MessageLength = MessageLength;
            out.AudioFile = obj.selectedFile;
        end

        function resetImpl(obj)
            % resetImpl - Reset the audio reader to the start of the clip.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if ~isempty(obj.audioSrc)
                reset(obj.audioSrc);
            end
        end

        function releaseImpl(obj)
            % releaseImpl - Release the underlying audio reader resource.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if ~isempty(obj.audioSrc)
                release(obj.audioSrc);
            end
        end

    end

    methods (Access = private)

        function clipList = resolveClipList(obj)
            % resolveClipList - Build the sorted pool of candidate clips.
            % Inputs: see signature arguments and local validation.
            % Outputs: sorted cell array of absolute file paths.
            clipList = {};
            dirPath = char(string(obj.AudioDirectory));
            if ~isempty(dirPath) && isfolder(dirPath)
                entries = dir(fullfile(dirPath, '*.wav'));
                names = sort({entries.name});
                for k = 1:numel(names)
                    clipList{end + 1} = fullfile(dirPath, names{k}); %#ok<AGROW>
                end
            end
            if isempty(clipList)
                filePath = char(string(obj.AudioFile));
                if ~isempty(filePath) && isfile(filePath)
                    clipList = {filePath};
                end
            end
        end

    end

end
