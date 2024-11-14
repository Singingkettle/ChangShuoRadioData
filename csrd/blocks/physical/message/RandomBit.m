classdef RandomBit < matlab.System
    
    methods

        function obj = RandomBit(varargin)

            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function out = stepImpl(obj, messageLength, SymbolRate)

            out.data = randi([0, 1], messageLength, 1);

            out.SymbolRate = SymbolRate;
            out.messageLength = messageLength;

        end

    end

end
