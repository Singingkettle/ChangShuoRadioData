classdef Audio < BaseSource

    methods (Access = protected)

        function y = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            audioSrc = dsp.AudioFileReader('audio_mix_441.wav', ...
                'SamplesPerFrame', obj.SamplePerFrame, 'PlayCount', inf);
            audioRC = dsp.SampleRateConverter('Bandwidth', 30e3, ...
                'InputSampleRate', audioSrc.SampleRate, ...
                'OutputSampleRate', obj.SampleRate);
            [~, decimFactor] = getRateChangeFactors(audioRC);
            audioSrc.SamplesPerFrame = ceil(obj.SamplePerFrame / ...
                obj.SampleRate * audioSrc.SampleRate / ...
                decimFactor) * decimFactor;

            x = audioRC(audioSrc());
            y = x(1:obj.SamplePerFrame, 1);
        end

    end

end
