classdef BaseModulator < matlab.System
    % BaseModulator - Base class for modulators
    %
    %   This class serves as the base class for modulators in the ChangShuoRadioData project.
    %   It provides common properties and methods that are shared among different modulators.
    %
    %   To create a specific modulator, you should create a subclass of BaseModulator and
    %   implement the abstract method genModulatorHandle.
    %
    %   Properties:
    %       - ModulatorOrder: The modulation order of the modulator (default: 1)
    %       - SampleRate: The sample rate of the modulator in Hz (default: 200e3)
    %       - ModulatorConfig: Configuration parameters for the modulator
    %       - NumTransmitAntennas: The number of transmit antennas (default: 1)
    %       - IsDigital: Flag indicating whether the modulator is digital (default: true)
    %
    %   Methods:
    %       - BaseModulator: Constructor method for the BaseModulator class
    %       - placeHolder: A placeholder method used in single TransmitAntennna
    %
    %   Abstract Methods:
    %       - genModulatorHandle: Abstract method to generate the modulator handle
    %
    %   Protected Methods:
    %       - validateInputsImpl: Validates the inputs to the object
    %       - setupImpl: Performs setup operations for the object
    %       - stepImpl: Performs the main processing step for the object
    %
    %   See also: matlab.System
    
    properties
        ModulatorOrder {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3
        ModulatorConfig struct = struct()
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennas, [1, 2, 3, 4])} = 1
        % For analog modulation, the SamplePerSymbol is just a placeholder
        % var without use
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 1
    end
    
    properties (Access = protected)
        modulator % Modulate Handle
        IsDigital = true
    end
    
    methods
        function obj = BaseModulator(varargin)
            % BaseModulator - Constructor method for the BaseModulator class
            %
            %   obj = BaseModulator() creates a BaseModulator object with default property values.
            %
            %   obj = BaseModulator(Name,Value) creates a BaseModulator object with the specified
            %   property values.
            
            setProperties(obj, nargin, varargin{:});
        end
        
        function ostbc = genOSTBC(obj)
            
            if obj.NumTransmitAntennas > 1
                
                if obj.NumTransmitAntennas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end
                ostbc = @(x)genOSTBCWithX(ostbc, x);
            else
                ostbc = @(x)obj.placeHolder(x);
            end
            
        end
        
        function y = placeHolder(obj, x)
            % placeHolder - A placeholder method for testing purposes
            %
            %   y = placeHolder(obj, x) returns the input x as the output y.
            
            y = x;
        end
    end
    
    methods (Abstract)
        % genModulatorHandle - Abstract method to generate the modulator handle
        %
        %   This method should be implemented in the subclass to generate the modulator handle.
        %   The modulator handle is used for modulating the input data.
        %
        modulatorHandle = genModulatorHandle(obj)
        
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
            if obj.NumTransmitAntennas > 2
                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1])*0.25+0.5;
                end
            else
                obj.ModulatorConfig.ostbcSymbolRate = 1;
            end
            obj.modulator = obj.genModulatorHandle;
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
            
            if isscalar(bw)
                bw = [-bw/2, bw/2];
            end
            if ~isfield(obj.ModulatorConfig, 'base')
                bw(1) = fix(bw(1));
                bw(2) = fix(bw(2));
            end
            
            out.data = y;
            out.BandWidth = bw;
            if isfield(obj.ModulatorConfig, 'base')
                out.SamplePerSymbol = 1;
            else
                out.SamplePerSymbol = x.SamplePerSymbol;
            end
            out.ModulatorOrder = obj.ModulatorOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
            out.ModulatorConfig = obj.ModulatorConfig;
            
            % The obj.SampleRate are redefined in
            % OFDM, SCDMA and OTFS
            out.SampleRate = obj.SampleRate;
            out.TimeDuration = size(y, 1) / obj.SampleRate;
            out.SamplePerFrame = size(y, 1);
            
        end
        
    end
    
end


function y = genOSTBCWithX(ostbc, x)

rr = floor(ostbc.SymbolRate * 8);
valid_len = floor(size(x, 1) / rr);
valid_len = valid_len * rr;
y = ostbc(x(1:valid_len, :));

end