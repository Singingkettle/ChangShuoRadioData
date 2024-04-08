classdef RandomSource < BaseSource

    properties
        ModulationOrder {mustBePositive, mustBeReal} = 2
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
    end

    methods

        % function obj = RandomSource(varargin)
        %
        %     setProperties(obj, nargin, varargin);
        %
        % end

    end

    methods (Access = protected)

        function y = stepImpl(obj)

            if isscalar(obj.ModulationOrder)
                y = randi([0, obj.ModulationOrder - 1], ...
                    round(obj.SamplePerFrame / obj.SamplePerSymbol), 1);
            else
                y = randi([0, sum(obj.ModulationOrder) - 1], ...
                    round(obj.SamplePerFrame / obj.SamplePerSymbol), 1);
            end

        end

    end

end
