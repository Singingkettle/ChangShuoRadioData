classdef BaseChannel < matlab.System
    
    properties (Nontunable)
        
        CarrierFrequency (1, 1) {mustBePositive, mustBeReal} = 200e6
        %SampleRate Sample rate (Hz)
        %   Specify the sample rate of the input signal in Hz as a double
        %   precision, real, positive scalar. The default is 1 Hz.
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        
        Distance (1, 1) {mustBePositive, mustBeReal} = 1
        atmosCond {mustBeText} = 'FreeSpace'
        
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        
    end
    
    properties (Access=protected)
        WaveLength
        PathLoss
        mode
        MultipathChannel
    end
    
    methods (Access=protected)
        function PathLoss =genPathLoss(obj)
            
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
        
    end
    
    methods
        
        function obj = BaseChannel(varargin)
            
            setProperties(obj, nargin, varargin{:});
            
            if obj.NumTransmitAntennas == 1 && obj.NumReceiveAntennas == 1
                obj.mode = 'SISO';
            elseif obj.NumTransmitAntennas > 1 && obj.NumReceiveAntennas > 1
                obj.mode = 'MIMO';
            elseif obj.NumTransmitAntennas > 1 && obj.NumReceiveAntennas == 1
                obj.mode = 'MISO';
            else
                obj.mode = 'SIMO';
            end
            
            lightSpeed = physconst('light');
            obj.WaveLength = lightSpeed/(obj.CarrierFrequency);
            obj.PathLoss = obj.genPathLoss;
            
        end
        
    end
    
end
