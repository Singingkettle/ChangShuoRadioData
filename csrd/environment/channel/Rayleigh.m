classdef Rayleigh < BaseChannel

    properties (Nontunable)
        %PathDelays Discrete path delays (s)
        %   Specify the delays of the discrete paths in seconds as a double
        %   precision, real, scalar or row vector. When PathDelays is a scalar,
        %   the channel is frequency-flat; When PathDelays is a vector, the
        %   channel is frequency-selective. The default is 0.
        PathDelays = 0
        %AveragePathGains Average path gains (dB)
        %   Specify the average gains of the discrete paths in dB as a double
        %   precision, real, scalar or row vector. AveragePathGains must have
        %   the same size as PathDelays. The default is 0.
        AveragePathGains = 0
        %MaximumDopplerShift Maximum Doppler shift (Hz)
        %   Specify the maximum Doppler shift for the path(s) of the channel in
        %   Hz as a double precision, real, nonnegative scalar. It applies to
        %   all the paths of the channel. When MaximumDopplerShift is 0, the
        %   channel is static for the entire input and you can use the reset
        %   method to generate a new channel realization. The
        %   MaximumDopplerShift must be smaller than SampleRate/10 for each
        %   path. The default is 0.
        MaximumDopplerShift = 0

    end

    methods (Access=protected)

        function setupImpl(obj)
            obj.MultipathChannel = comm.RayleighChannel( ...
                SampleRate = obj.SampleRate, ...
                PathDelays = obj.PathDelays, ...
                AveragePathGains = obj.AveragePathGains, ...
                MaximumDopplerShift = obj.MaximumDopplerShift);
        end

        function out = addMultipathFading(obj, in)
            %addMultipathFading Add Rician multipath fading
            %   Y=addMultipathFading(CH,X) adds Rician multipath fading effects
            %   to input, X, based on PathDelays, AveragePathGains, and
            %   MaximumDopplerShift settings. Channel path gains are regenerated
            %   for each frame, which provides independent path gain values for
            %   each frame.

            % Pass input through the new channel
            out = obj.MultipathChannel(in);
        end
        
        function out = stepImpl(obj, x)
            % Add channel impairments
            release(obj.MultipathChannel);
            obj.MultipathChannel.SampleRate = x.SampleRate;
            y = obj.addMultipathFading(x.data);
            % y = obj.PathLoss(y);
            
            out = x;
            out.data = y;
            out.Distance = obj.Distance;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.PathDelays = obj.PathDelays;
            out.AveragePathGains = obj.AveragePathGains;
            out.MaximumDopplerShift = obj.MaximumDopplerShift;
            out.mode = 'SISO';
          
        end


        function resetImpl(obj)
            reset(obj.MultipathChannel);
        end

        function s = infoImpl(obj)

            if isempty(obj.MultipathChannel)
                setupImpl(obj);
            end

            % Get channel delay from fading channel object delay
            mpInfo = info(obj.MultipathChannel);

            s = struct( ...
                'mode', obj.mode, ...
                'FadingDistribution', 'Rayleigh', ...
                'NumTransmitAntennas', obj.NumTransmitAntennas, ...
                'NumReceiveAntennas', obj.NumReceiveAntennas, ...
                'ChannelDelay', mpInfo.ChannelFilterDelay);
        end

    end

end
