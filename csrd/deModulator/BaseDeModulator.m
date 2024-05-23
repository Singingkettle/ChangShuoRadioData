classdef BaseDeModulator < matlab.System
    % https://www.mathworks.com/help/comm/ug/design-a-deep-neural-network-with-simulated-data-to-detect-wlan-router-impersonation.html
    
    properties
        
        ModulationOrder {mustBePositive, mustBeReal} = 1
        
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        
        % Modulate parameters
        ModulatorConfig struct
        
        % Transmit parameters
        NumTransmitAntennnas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennnas, [1, 2, 3, 4])} = 1
        
        % Digital Sign
        IsDigital (1, 1) logical = true
        
    end
    
    properties (Access = private)
        % Modulate Handle
        modulator
    end
    
    methods
        
        function obj = BaseModulator(varargin)
            
            setProperties(obj, nargin, varargin{:});
            
        end
        
        function y = placeHolder(obj, x)
            y = x;
        end
        
    end
    
    methods (Abstract)
        % In the sub class, this method should be defined
        modulatorHandle = genModulatorHandle(obj)
        
    end
    
    methods (Access = protected)
        
        % Validate the inputs to the object
        function validateInputsImpl(~, x)
            
            if ~isstruct(x)
                error("Input must be struct");
            end
            
        end
        
        function setupImpl(obj)
            obj.modulator = obj.genModulatorHandle;
        end
        
        function out = stepImpl(obj, x)
            
            [y, bw] = obj.modulator(x.data);
            % filter the high frequnecy component, and the max(bw) stands
            % for only saving the max bw in the multiTX scene.
            y = lowpass(y, bw/2, obj.SampleRate, ...
                ImpulseResponse = "fir", ...
                Steepness = 0.99999, StopbandAttenuation=200);
            
            out.data = y;
            out.BandWidth = bw;
            out.SamplePerSymbol = x.SamplePerSymbol;
            out.ModulationOrder = obj.ModulationOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennnas = obj.NumTransmitAntennnas;
            out.ModulatorConfig = obj.ModulatorConfig;
            out.ModulationOrder = obj.ModulationOrder;
            
            % The obj.TimeDuration and obj.SampleRate are redefined in
            % OFDM, SCDMA and OTFS
            out.TimeDuration = obj.TimeDuration;
            out.SampleRate = obj.SampleRate;
            out.SamplePerFrame = size(y, 1);
            
        end
        
    end
    
end
