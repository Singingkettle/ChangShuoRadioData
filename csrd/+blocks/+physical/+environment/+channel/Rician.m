classdef Rician < BaseChannel
    
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
        %KFactor K-factors
        %   Specify the K factor of a Rician fading channel as a double
        %   precision, real, positive scalar. The first discrete path is a
        %   Rician fading process with a Rician K-factor of KFactor and the
        %   remaining discrete paths are independent Rayleigh fading processes.
        %   The default is 3.
        KFactor = 3
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
            obj.MultipathChannel = comm.RicianChannel( ...
                SampleRate = obj.SampleRate, ...
                PathDelays = obj.PathDelays, ...
                AveragePathGains = obj.AveragePathGains, ...
                KFactor = obj.KFactor, ...
                MaximumDopplerShift = obj.MaximumDopplerShift);
        end
        
        function out = stepImpl(obj, x)
            x.data = x.data/10^(obj.PathLoss/20);
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
            out.KFactor = obj.KFactor;
            out.MaximumDopplerShift = obj.MaximumDopplerShift;
            out.mode = 'SISO';
            
        end
        
        function s = infoImpl(obj)
            
            if isempty(obj.MultipathChannel)
                setupImpl(obj);
            end
            
            % Get channel delay from fading channel object delay
            mpInfo = info(obj.MultipathChannel);
            
            s = struct( ...
                'mode', obj.mode, ...
                'FadingDistribution', 'Rician', ...
                'NumTransmitAntennas', obj.NumTransmitAntennas, ...
                'NumReceiveAntennas', obj.NumReceiveAntennas, ...
                'ChannelDelay', mpInfo.ChannelFilterDelay);
        end
        
    end
    
end
