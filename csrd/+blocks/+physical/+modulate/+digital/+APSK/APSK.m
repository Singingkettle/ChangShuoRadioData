classdef APSK < blocks.physical.modulate.BaseModulator
    % APSK - Amplitude and Phase Shift Keying Modulator
    %
    % This class implements APSK (Amplitude and Phase Shift Keying) modulation
    % with configurable parameters including multiple rings, phase offsets,
    % and pulse shaping. It supports MIMO transmission through OSTBC.
    %
    % Properties (Access = protected):
    %   filterCoeffs - Pulse shaping filter coefficients
    %   ostbc - Orthogonal Space-Time Block Coding object
    %
    % Methods:
    %   baseModulator - Core APSK modulation implementation
    %   genFilterCoeffs - Generates pulse shaping filter coefficients
    %   genModulatorHandle - Configures and returns the modulator function handle
    %
    % ModulatorConfig Parameters:
    %   Radii - Vector of ring radii for constellation points
    %   PhaseOffset - Phase offset for each ring (in radians)
    %   beta - Roll-off factor for pulse shaping (0 to 1)
    %   span - Filter span in symbols
    %   ostbcSymbolRate - Symbol rate for OSTBC (when NumTransmitAntennas > 2)
    %
    % Example:
    %   mod = APSK;
    %   mod.ModulatorOrder = 16; % 16-APSK
    %   mod.SamplePerSymbol = 4;
    %   y = mod.step(x);

    properties (Access = protected)

        filterCoeffs
        ostbc

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % baseModulator - Implements APSK modulation with pulse shaping
            %
            % Syntax:
            %   [y, bw] = baseModulator(obj, x)
            %
            % Inputs:
            %   x - Input symbols to modulate
            %
            % Outputs:
            %   y - Modulated and filtered signal
            %   bw - Occupied bandwidth of the signal
            %
            % The function performs these steps:
            % 1. APSK modulation using configured constellation
            % 2. OSTBC encoding for MIMO transmission
            % 3. Pulse shaping using raised cosine filter
            % 4. Bandwidth calculation

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
            % genFilterCoeffs - Generates raised cosine filter coefficients
            %
            % Syntax:
            %   filterCoeffs = genFilterCoeffs(obj)
            %
            % Returns:
            %   filterCoeffs - Filter coefficients for pulse shaping
            %
            % Uses ModulatorConfig.beta for roll-off factor and
            % ModulatorConfig.span for filter length

            filterCoeffs = rcosdesign(obj.ModulatorConfig.beta, ...
                obj.ModulatorConfig.span, ...
                obj.SamplePerSymbol);

        end

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Configures and returns modulator function
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Returns:
            %   modulatorHandle - Function handle for modulation
            %
            % If ModulatorConfig is not provided, generates random
            % configuration with reasonable defaults:
            % - Constellation size based on ModulatorOrder
            % - Random ring radii with increasing values
            % - Phase offsets proportional to ModulatorOrder
            % - Random roll-off factor and filter span

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
    % randomSumAsSpecifiedValue - Generates random values summing to specified total
    %
    % Syntax:
    %   x = randomSumAsSpecifiedValue(s, n, isInteger)
    %
    % Inputs:
    %   s - Target sum
    %   n - Number of values to generate
    %   isInteger - Boolean flag for integer output
    %
    % Returns:
    %   x - Vector of n random values summing to s

    lb = 1; % lower bound
    ub = s; % upper bound
    x = randfixedsum(n, 1, s, lb, ub);

    if isInteger
        e = ones(1, n);
        x = round(minL1intlin(speye(n), x, 1:n, [], [], e, s, lb * e, ub * e));
    end

end
