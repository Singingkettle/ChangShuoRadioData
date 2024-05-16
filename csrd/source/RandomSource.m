classdef RandomSource < BaseSource

    properties
        ModulationOrder {mustBePositive, mustBeReal} = 2
    end

    methods

        % function obj = RandomSource(varargin)
        %
        %     setProperties(obj, nargin, varargin);
        %
        % end

    end

    methods (Access = protected)

        function out = stepImpl(obj)

            if isscalar(obj.ModulationOrder)
                y = randi([0, obj.ModulationOrder - 1], ...
                    round(obj.SamplePerFrame / obj.SamplePerSymbol), 1);
            else
                y = randi([0, sum(obj.ModulationOrder) - 1], ...
                    round(obj.SamplePerFrame / obj.SamplePerSymbol), 1);
            end
            
            out.data = y;
            out.TimeDuration = obj.TimeDuration;
            out.SampleRate = obj.SampleRate;
            out.SamplePerFrame = length(y);
            out.SamplePerSymbol = 1;

        end

    end

end
