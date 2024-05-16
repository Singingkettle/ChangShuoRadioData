classdef Audio < BaseSource

    methods (Access = protected)

        function out = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            num_part = 14;
            SamplePerFrame = obj.SamplePerFrame * num_part;
            audioSrc = dsp.AudioFileReader('audio_mix_441.wav', ...
                'SamplesPerFrame', SamplePerFrame, 'PlayCount', inf);
            audioRC = dsp.SampleRateConverter('Bandwidth', 30e3, ...
                'InputSampleRate', audioSrc.SampleRate, ...
                'OutputSampleRate', obj.SampleRate);
            [~, decimFactor] = getRateChangeFactors(audioRC);
            audioSrc.SamplesPerFrame = ceil(SamplePerFrame / ...
                obj.SampleRate * audioSrc.SampleRate / ...
                decimFactor) * decimFactor;

            x = audioRC(audioSrc());
            partID = randi(num_part);
            y = x((partID-1)*obj.SamplePerFrame+1:partID*obj.SamplePerFrame, 1);

            y = lowpass(y, 15e3, obj.SampleRate, ...
                ImpulseResponse = "fir", Steepness = 0.99999, ...
                StopbandAttenuation=200);

            out.data = y;
            out.TimeDuration = obj.TimeDuration;
            out.SampleRate = obj.SampleRate;
            out.SamplePerFrame = length(y);
            out.SamplePerSymbol = 1;
        end

    end

end
