classdef BaseModulation < matlab.System
    % BaseModulation - Base class for modulators
    %
    %   This class serves as the base class for modulators in the ChangShuoRadioData project.
    %   It provides common properties and methods that are shared among different modulators.
    %
    %   To create a specific modulator, you should create a subclass of BaseModulation and
    %   implement the abstract method genModulationHandle.
    %
    %   Properties:
    %       - ModulationOrder: The modulation order of the modulator (default: 1)
    %       - TimeDuration: The time duration of the modulator in seconds (default: 1)
    %       - SampleRate: The sample rate of the modulator in Hz (default: 200e3)
    %       - ModulationConfig: Configuration parameters for the modulator
    %       - NumTransmitAntennnas: The number of transmit antennas (default: 1)
    %       - IsDigital: Flag indicating whether the modulator is digital (default: true)
    %
    %   Methods:
    %       - BaseModulation: Constructor method for the BaseModulation class
    %       - placeHolder: A placeholder method used in single TransmitAntennna
    %
    %   Abstract Methods:
    %       - genModulationHandle: Abstract method to generate the modulator handle
    %
    %   Protected Methods:
    %       - validateInputsImpl: Validates the inputs to the object
    %       - setupImpl: Performs setup operations for the object
    %       - stepImpl: Performs the main processing step for the object
    %
    %   See also: matlab.System
    
    properties
        ModulationOrder {mustBePositive, mustBeReal} = 1
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        ModulationConfig struct
        NumTransmitAntennnas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennnas, [1, 2, 3, 4])} = 1
        
    end
    
    properties (Access = private)
        modulator % Modulate Handle
        IsDigital = true
    end
    
    methods
        function obj = BaseModulation(varargin)
            % BaseModulation - Constructor method for the BaseModulation class
            %
            %   obj = BaseModulation() creates a BaseModulation object with default property values.
            %
            %   obj = BaseModulation(Name,Value) creates a BaseModulation object with the specified
            %   property values.
            
            setProperties(obj, nargin, varargin{:});
        end
        
        function y = placeHolder(obj, x)
            % placeHolder - A placeholder method for testing purposes
            %
            %   y = placeHolder(obj, x) returns the input x as the output y.
            
            y = x;
        end
    end
    
    methods (Abstract)
        % genModulationHandle - Abstract method to generate the modulator handle
        %
        %   This method should be implemented in the subclass to generate the modulator handle.
        %   The modulator handle is used for modulating the input data.
        %
        %   modulatorHandle = genModulationHandle(obj)
        
    end
    
    methods (Access = protected)
        function validateInputsImpl(~, x)
            % validateInputsImpl - Validates the inputs to the object
            %
            %   This method validates that the input is a struct.
            %
            %   validateInputsImpl(obj, x)
            
            if ~isstruct(x)
                error("Input must be struct");
            end
        end
        
        function setupImpl(obj)
            % setupImpl - Performs setup operations for the object
            %
            %   This method is called before the first call to the stepImpl method.
            %   It initializes the modulator handle.
            %
            %   setupImpl(obj)
            
            obj.modulator = obj.genModulationHandle;
        end
        
        function out = stepImpl(obj, x)
            % stepImpl - Performs the main processing step for the object
            %
            %   This method performs the main processing step for the modulator.
            %   It modulates the input data using the modulator handle and applies
            %   any necessary filtering.
            %
            %   out = stepImpl(obj, x)
            
            [y, bw] = obj.modulator(x.data);
            
            if ~isfield(obj.ModulationConfig, 'base')
                bw = ceil(bw/1000)*1000;
            end
            
            out.data = y;
            out.BandWidth = bw;
            out.SamplePerSymbol = x.SamplePerSymbol;
            out.ModulationOrder = obj.ModulationOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennnas = obj.NumTransmitAntennnas;
            out.ModulationConfig = obj.ModulationConfig;
            
            % The obj.TimeDuration and obj.SampleRate are redefined in
            % OFDM, SCDMA and OTFS
            out.TimeDuration = obj.TimeDuration;
            out.SampleRate = obj.SampleRate;
            out.SamplePerFrame = size(y, 1);
            
        end
        
    end
    
end