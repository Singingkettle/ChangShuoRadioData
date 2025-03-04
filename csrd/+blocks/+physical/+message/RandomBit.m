classdef RandomBit < matlab.System
    % RandomBit - Random Binary Message Generator
    %
    % This class generates random binary messages (0s and 1s) for use in
    % digital communication simulations. Each bit is generated with equal
    % probability.
    %
    % Methods:
    %   RandomBit - Constructor for random bit generator
    %   stepImpl - Generates random binary sequence
    %
    % Example:
    %   msgGen = RandomBit();
    %   out = msgGen.step(1000, 1e6);
    %   % out contains:
    %   %   - data: Random binary sequence [1000x1]
    %   %   - SymbolRate: Input symbol rate
    %   %   - messageLength: Length of generated sequence
    
    methods
        function obj = RandomBit(varargin)
            % RandomBit - Constructor for random bit generator
            %
            % Syntax:
            %   obj = RandomBit()
            %   obj = RandomBit('PropertyName', PropertyValue, ...)
            %
            % The constructor currently accepts no properties but maintains
            % the varargin interface for future extensibility
            
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function out = stepImpl(obj, messageLength, SymbolRate)
            % stepImpl - Generate random binary sequence
            %
            % Syntax:
            %   out = stepImpl(obj, messageLength, SymbolRate)
            %
            % Inputs:
            %   messageLength - Length of desired binary sequence
            %   SymbolRate - Symbol rate for the message
            %
            % Outputs:
            %   out - Structure containing:
            %       data - Random binary sequence [messageLength x 1]
            %       SymbolRate - Input symbol rate (unchanged)
            %       messageLength - Length of generated sequence
            
            % Generate random binary sequence
            out.data = randi([0, 1], messageLength, 1);

            % Set output parameters
            out.SymbolRate = SymbolRate;
            out.messageLength = messageLength;
        end
    end
end
