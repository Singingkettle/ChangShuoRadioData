classdef MIMO < blocks.physical.environment.channel.BaseChannel
    % MIMO - Multiple-Input Multiple-Output Channel Model
    %
    % This class implements a MIMO channel model with configurable fading,
    % path delays, and Doppler effects. It supports both Rayleigh and Rician
    % fading distributions.
    %
    % Properties (Nontunable):
    %   FadingDistribution - Type of fading ('Rayleigh' or 'Rician')
    %   PathDelays - Discrete path delays in seconds
    %   AveragePathGains - Average path gains in dB
    %   KFactor - Rician K-factor (only used for Rician fading)
    %   MaximumDopplerShift - Maximum Doppler shift in Hz
    %   FadingTechnique - Method for generating fading ('Sum of sinusoids')
    %   InitialTimeSource - Source of initial time ('Input port')
    %
    % Methods:
    %   setupImpl - Initializes the MIMO channel object
    %   stepImpl - Processes input signal through the channel
    %   infoImpl - Returns channel configuration information
    %
    % Example:
    %   ch = MIMO('NumTransmitAntennas', 2, ...
    %             'NumReceiveAntennas', 2, ...
    %             'FadingDistribution', 'Rayleigh');
    %   out = ch.step(in);

    properties (Nontunable)
        FadingDistribution = 'Rayleigh'
        % FadingDistribution - Type of fading distribution
        % Specify as 'Rayleigh' or 'Rician'. Default: 'Rayleigh'
        
        PathDelays = 0
        % PathDelays - Discrete path delays (s)
        % Specify delays as a scalar (frequency-flat) or row vector 
        % (frequency-selective). Default: 0
        
        AveragePathGains = 0
        % AveragePathGains - Average path gains (dB)
        % Specify gains as a scalar or row vector matching PathDelays size.
        % Default: 0
        
        KFactor = 3
        % KFactor - Rician K-factor
        % Specify as a positive scalar. Only used for Rician fading.
        % First path uses this K-factor, remaining paths are Rayleigh.
        % Default: 3
        
        MaximumDopplerShift = 0
        % MaximumDopplerShift - Maximum Doppler shift (Hz)
        % Specify as a nonnegative scalar < SampleRate/10.
        % Applies to all paths. When 0, channel is static.
        % Default: 0
        
        FadingTechnique = "Sum of sinusoids"
        % FadingTechnique - Method for generating fading
        % Currently supports "Sum of sinusoids" only
        
        InitialTimeSource = "Input port"
        % InitialTimeSource - Source of initial time
        % Specifies how initial time is determined
    end

    methods (Access = protected)
        function setupImpl(obj)
            % setupImpl - Initialize the MIMO channel object
            %
            % Creates a comm.MIMOChannel object with specified parameters
            % Different configurations for Rayleigh and Rician fading

            if strcmp(obj.FadingDistribution, 'Rayleigh')
                obj.MultipathChannel = comm.MIMOChannel( ...
                    SampleRate = obj.SampleRate, ...
                    PathDelays = obj.PathDelays, ...
                    AveragePathGains = obj.AveragePathGains, ...
                    MaximumDopplerShift = obj.MaximumDopplerShift, ...
                    SpatialCorrelationSpecification = 'None', ...
                    FadingDistribution = 'Rayleigh', ...
                    FadingTechnique = obj.FadingTechnique, ...
                    InitialTimeSource = obj.InitialTimeSource, ...
                    NumTransmitAntennas = obj.NumTransmitAntennas, ...
                    NumReceiveAntennas = obj.NumReceiveAntennas);
            else
                obj.MultipathChannel = comm.MIMOChannel( ...
                    SampleRate = obj.SampleRate, ...
                    PathDelays = obj.PathDelays, ...
                    AveragePathGains = obj.AveragePathGains, ...
                    KFactor = obj.KFactor, ...
                    MaximumDopplerShift = obj.MaximumDopplerShift, ...
                    SpatialCorrelationSpecification = 'None', ...
                    FadingDistribution = 'Rician', ...
                    FadingTechnique = obj.FadingTechnique, ...
                    InitialTimeSource = obj.InitialTimeSource, ...
                    NumTransmitAntennas = obj.NumTransmitAntennas, ...
                    NumReceiveAntennas = obj.NumReceiveAntennas);
            end
        end

        function out = stepImpl(obj, x)
            % stepImpl - Process input signal through the channel
            %
            % Syntax:
            %   out = stepImpl(obj, x)
            %
            % Inputs:
            %   x - Input signal structure with fields:
            %       data - Signal data
            %       SampleRate - Sampling rate
            %       StartTime - Signal start time
            %
            % Outputs:
            %   out - Output structure with added channel effects
            
            % Apply path loss
            x.data = x.data / 10 ^ (obj.PathLoss / 20);
            
            % Add channel impairments
            release(obj.MultipathChannel);
            obj.MultipathChannel.SampleRate = x.SampleRate;
            y = obj.addMultipathFading(x.data, x.StartTime);

            % Prepare output structure
            out = x;
            out.data = y;
            out.PathDelays = obj.PathDelays;
            out.AveragePathGains = obj.AveragePathGains;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.FadingDistribution = obj.FadingDistribution;

            if strcmp(obj.FadingDistribution, 'Rician')
                out.KFactor = obj.KFactor;
            end

            out.MaximumDopplerShift = obj.MaximumDopplerShift;
            out.mode = obj.mode;
        end

        function s = infoImpl(obj)
            % infoImpl - Return channel configuration information
            %
            % Returns structure with fields:
            %   mode - Channel mode (SISO/MIMO/MISO/SIMO)
            %   FadingDistribution - Type of fading
            %   NumTransmitAntennas - Number of transmit antennas
            %   NumReceiveAntennas - Number of receive antennas

            if isempty(obj.MultipathChannel)
                setupImpl(obj);
            end

            s = struct( ...
                'mode', obj.mode, ...
                'FadingDistribution', obj.FadingDistribution, ...
                'NumTransmitAntennas', obj.NumTransmitAntennas, ...
                'NumReceiveAntennas', obj.NumReceiveAntennas);
        end
    end
end
