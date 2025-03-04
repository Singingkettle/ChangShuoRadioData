classdef BaseChannel < matlab.System
    % BaseChannel - Base class for wireless channel models
    %
    % This class provides fundamental channel modeling capabilities including
    % path loss, atmospheric conditions, and antenna configurations for wireless
    % communication systems.
    %
    % Properties (Nontunable):
    %   CarrierFrequency - Carrier frequency in Hz (default: 200MHz)
    %   SampleRate - Sample rate in Hz (default: 200kHz)
    %   Distance - Propagation distance in meters (default: 1)
    %   atmosCond - Atmospheric conditions ('FreeSpace', 'Fog', 'Gas', 'Rain')
    %   NumTransmitAntennas - Number of transmit antennas (default: 1)
    %   NumReceiveAntennas - Number of receive antennas (default: 1)
    %
    % Protected Properties:
    %   WaveLength - Signal wavelength calculated from carrier frequency
    %   PathLoss - Path loss value based on distance and conditions
    %   mode - Channel mode (SISO/MIMO/MISO/SIMO)
    %   MultipathChannel - Multipath channel model instance
    %
    % Methods:
    %   BaseChannel - Constructor for channel model
    %   genPathLoss - Calculates path loss based on conditions
    %   addMultipathFading - Applies Rician multipath fading
    %   resetImpl - Resets the multipath channel state
    %
    % Example:
    %   ch = BaseChannel('CarrierFrequency', 900e6, ...
    %                    'Distance', 2, ...
    %                    'atmosCond', 'FreeSpace');
    
    properties (Nontunable)
        CarrierFrequency (1, 1) {mustBePositive, mustBeReal} = 200e6
        
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        % SampleRate - Input signal sample rate in Hz
        % Specify as a positive real scalar. Default: 200 kHz
        
        Distance (1, 1) {mustBePositive, mustBeReal} = 1
        % Distance - Propagation distance in meters
        % Specify as a positive real scalar. Default: 1m
        
        atmosCond {mustBeText} = 'FreeSpace'
        % atmosCond - Atmospheric conditions for path loss calculation
        % Specify as one of: 'FreeSpace', 'Fog', 'Gas', 'Rain'
        
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        % NumTransmitAntennas - Number of transmit antennas
        % Specify as a positive integer. Default: 1 (SISO/SIMO)
        
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        % NumReceiveAntennas - Number of receive antennas
        % Specify as a positive integer. Default: 1 (SISO/MISO)
    end
    
    properties (Access=protected)
        WaveLength   % Signal wavelength (m)
        PathLoss    % Total path loss (dB)
        mode        % Channel configuration mode
        MultipathChannel  % Multipath channel model object
    end
    
    methods (Access=protected)
        function PathLoss = genPathLoss(obj)
            % genPathLoss - Calculate total path loss including atmospheric effects
            %
            % Returns:
            %   PathLoss - Total path loss in dB
            %
            % The method calculates path loss based on:
            % 1. Free space path loss
            % 2. Additional loss based on atmospheric conditions:
            %    - Fog: Up to 18km with liquid water density 0.05 g/m³
            %    - Gas: Up to 100km with standard atmospheric pressure
            %    - Rain: Up to 2km with 3mm/h rain rate
            
            % Calculate free space path loss
            freeSpacePL = fspl(obj.Distance*1000, obj.WaveLength);
            
            T = 15; % Temperature in degree C
            switch obj.atmosCond % Get path loss in dB
                case 'Fog'   % Fog
                    den = .05; % Liquid water density in g/m^3
                    % Approximate maximum 18km for fog/cloud
                    PathLoss = freeSpacePL + ...
                        fogpl( min(obj.Distance, 18)*1000, obj.CarrierFrequency, T, den);
                case 'FreeSpace'   % Free space
                    PathLoss = freeSpacePL;
                case 'Gas'   % Gas
                    P = 101.325e3; % Dry air pressure in Pa
                    den = 7.5;     % Water vapor density in g/m^3
                    % Approximate maximum 100km for atmospheric gases
                    PathLoss = freeSpacePL + ...
                        gaspl( min(obj.Distance, 100)*1000, obj.CarrierFrequency, T, P, den);
                otherwise   % Rain
                    RR = 3; % Rain rate in mm/h
                    % Approximate maximum 2km for rain
                    PathLoss = freeSpacePL + ...
                        rainpl(min(obj.Distance, 2)*1000, obj.CarrierFrequency, RR);
            end
        end
        
        function out = addMultipathFading(obj, in, startTime)
            % addMultipathFading - Add Rician multipath fading effects
            %
            % Syntax:
            %   out = addMultipathFading(obj, in, startTime)
            %
            % Inputs:
            %   in - Input signal
            %   startTime - Start time for fading process
            %
            % Outputs:
            %   out - Signal with multipath fading effects
            %
            % The method applies Rician fading based on:
            % - Path delays
            % - Average path gains
            % - K-factor
            % - Maximum Doppler shift
            % Channel path gains are regenerated for each frame
            
            % Get new path gains
            reset(obj.MultipathChannel)
            % Pass input through the new channel
            out = obj.MultipathChannel(in, startTime);
        end
        
        function resetImpl(obj)
            % resetImpl - Reset the multipath channel state
            reset(obj.MultipathChannel);
        end
    end
    
    methods
        function obj = BaseChannel(varargin)
            % BaseChannel - Constructor for channel model
            %
            % Syntax:
            %   obj = BaseChannel()
            %   obj = BaseChannel('PropertyName', PropertyValue, ...)
            %
            % Optional Parameters:
            %   All properties can be set as name-value pairs
            
            % Set properties from name-value pairs
            setProperties(obj, nargin, varargin{:});
            
            % Determine channel mode based on antenna configuration
            if obj.NumTransmitAntennas == 1 && obj.NumReceiveAntennas == 1
                obj.mode = 'SISO';
            elseif obj.NumTransmitAntennas > 1 && obj.NumReceiveAntennas > 1
                obj.mode = 'MIMO';
            elseif obj.NumTransmitAntennas > 1 && obj.NumReceiveAntennas == 1
                obj.mode = 'MISO';
            else
                obj.mode = 'SIMO';
            end
            
            % Calculate wavelength and path loss
            lightSpeed = physconst('light');
            obj.WaveLength = lightSpeed/(obj.CarrierFrequency);
            obj.PathLoss = obj.genPathLoss;
        end
    end
end
