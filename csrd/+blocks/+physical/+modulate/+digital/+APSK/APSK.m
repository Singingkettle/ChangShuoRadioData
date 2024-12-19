classdef APSK < blocks.physical.modulate.BaseModulator

    properties (Access = protected)

        filterCoeffs
        ostbc

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            % Perform APSK modulation
            x = apskmod(x, obj.ModulatorOrder, obj.ModulatorConfig.Radii, obj.ModulatorConfig.PhaseOffset);
            x = obj.ostbc(x);

            % Apply pulse shaping filter
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            % Calculate bandwidth
            bw = obw(y, obj.SampleRate);

            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end

        end

    end

    methods

        function filterCoeffs = genFilterCoeffs(obj)

            filterCoeffs = rcosdesign(obj.ModulatorConfig.beta, ...
                obj.ModulatorConfig.span, ...
                obj.SamplePerSymbol);

        end

        function modulatorHandle = genModulatorHandle(obj)

            % Generate default configuration if not provided
            if ~isfield(obj.ModulatorConfig, 'Radii')

                if obj.ModulatorOrder / 4 > 8
                    n = 8;
                else
                    n = obj.ModulatorOrder / 4;
                end

                n = randi([2 n]);

                % Configure modulation parameters
                obj.ModulatorOrder = sort(randomSumAsSpecifiedValue(obj.ModulatorOrder / 4, n, true)) * 4;
                obj.ModulatorConfig.Radii = cumsum((rand(n, 1) * 0.1 + 0.2));
                obj.ModulatorConfig.PhaseOffset = pi ./ obj.ModulatorOrder;
                obj.ModulatorConfig.beta = rand(1);
                obj.ModulatorConfig.span = randi([2, 8]) * 2;
            end

            % Configure OSTBC for multiple antennas
            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            end

            % Set up modulator
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            modulatorHandle = @(x)obj.baseModulator(x);

        end

    end

end

function x = randomSumAsSpecifiedValue(s, n, isInteger)

    lb = 1; % lower bound
    ub = s; % upper bound
    x = randfixedsum(n, 1, s, lb, ub);

    if isInteger
        e = ones(1, n);
        x = round(minL1intlin(speye(n), x, 1:n, [], [], e, s, lb * e, ub * e));
    end

end
