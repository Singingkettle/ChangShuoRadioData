classdef Audio < BaseSource

    methods

        function obj = Audio(param)
            obj.timeDuration = param.timeDuration;
            obj.sampleRate = param.sampleRate;
        end

    end

    methods (Access = protected)

        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            audioSrc = dsp.AudioFileReader('audio_mix_441.wav', ...
                'SamplesPerFrame', obj.samplePerFrame, 'PlayCount', inf);
            audioRC = dsp.SampleRateConverter('Bandwidth', 30e3, ...
                'InputSampleRate', audioSrc.SampleRate, ...
                'OutputSampleRate', obj.sampleRate);
            [~, decimFactor] = getRateChangeFactors(audioRC);
            audioSrc.SamplesPerFrame = ceil(obj.samplePerFrame / ...
                obj.sampleRate * audioSrc.SampleRate / ...
                decimFactor) * decimFactor;

            x = audioRC(audioSrc());
            y = x(1:obj.samplePerFrame, 1);
        end

    end

end
