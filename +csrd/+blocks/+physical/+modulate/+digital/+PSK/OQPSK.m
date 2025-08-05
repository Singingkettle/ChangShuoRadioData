classdef OQPSK < csrd.blocks.physical.modulate.digital.APSK.APSK
    % OQPSK - Offset Quadrature Phase Shift Keying Modulator
    %
    % This class implements Offset Quadrature Phase Shift Keying (OQPSK) modulation
    % as a subclass of the APSK modulator. OQPSK is a variant of QPSK where the
    % quadrature component is delayed by half a symbol period, reducing the peak
    % power variations and envelope fluctuations compared to conventional QPSK.
    %
    % OQPSK (also known as Staggered QPSK) maintains constant envelope properties
    % better than QPSK by ensuring that transitions through zero (180-degree phase
    % changes) are eliminated. This makes it particularly suitable for non-linear
    % amplifiers and satellite communications where amplitude variations must be
    % minimized.
    %
    % Key Features:
    %   - Offset quadrature component by half symbol period
    %   - Reduced envelope variations compared to QPSK
    %   - Constant envelope properties for non-linear amplifiers
    %   - Configurable phase offset and symbol mapping
    %   - OSTBC encoding support for MIMO transmission
    %   - Pulse shaping with raised cosine filters
    %
    % Syntax:
    %   oqpskModulator = OQPSK()
    %   oqpskModulator = OQPSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = oqpskModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Fixed at 4 for OQPSK (quaternary modulation)
    %   SamplePerSymbol - Number of samples per symbol (must be even)
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .SymbolMapping - Symbol mapping ('Binary' or 'Gray')
    %     .PhaseOffset - Phase offset in radians
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Properties (Access = protected):
    %   oqpskModulator - Internal OQPSK modulator object
    %
    % Methods:
    %   baseModulator - Core OQPSK modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create OQPSK modulator with Gray coding
    %   oqpskMod = csrd.blocks.physical.modulate.digital.PSK.OQPSK();
    %   oqpskMod.SamplePerSymbol = 8; % Must be even for OQPSK
    %   oqpskMod.SampleRate = 1e6;
    %
    %   % Configure for Gray coding and specific phase offset
    %   oqpskMod.ModulatorConfig.SymbolMapping = 'Gray';
    %   oqpskMod.ModulatorConfig.PhaseOffset = pi/4;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 2000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = oqpskMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.digital.PSK.PSK,
    %           csrd.blocks.physical.modulate.BaseModulator, comm.OQPSKModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core OQPSK modulation implementation
            %
            % This method performs OQPSK modulation using the configured MATLAB
            % Communications Toolbox OQPSKModulator object, which handles the
            % offset quadrature component timing and pulse shaping automatically.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input bit sequence to be modulated
            %                  Type: logical or binary numeric array
            %
            % Output Arguments:
            %   modulatedSignal - OQPSK modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Apply OQPSK modulation with offset quadrature timing
            %   2. Calculate occupied bandwidth using obw function
            %   3. Handle MIMO bandwidth calculation if multiple antennas
            %
            % OQPSK Characteristics:
            %   The quadrature component is offset by Ts/2 (half symbol period)
            %   relative to the in-phase component, which eliminates 180-degree
            %   phase transitions and reduces envelope variations.
            %
            % Example:
            %   bits = [0 1 1 0 1 0 1 1]; % Binary input
            %   [signal, bw] = obj.baseModulator(bits);

            % Apply OQPSK modulation with offset quadrature timing
            modulatedSignal = obj.baseModulator(inputSymbols);

            % Calculate occupied bandwidth
            bandWidth = obw(modulatedSignal, obj.SampleRate);

            % For MIMO systems, take maximum bandwidth across antennas
            if obj.NumTransmitAntennas > 1
                bandWidth = max(bandWidth);
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured OQPSK modulator function handle
            %
            % This method configures the OQPSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % OQPSK requires even samples per symbol for proper offset timing.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for OQPSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(bits)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - SymbolMapping: Binary or Gray code mapping (random selection)
            %   - PhaseOffset: Phase offset in radians (random 0 to 2π)
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %
            % OQPSK Constraints:
            %   - ModulatorOrder is fixed at 4 (quaternary)
            %   - SamplePerSymbol must be even for proper offset implementation
            %   - Uses root raised cosine pulse shaping by default
            %
            % Default Configuration:
            %   - SymbolMapping: Random 'Binary' or 'Gray'
            %   - PhaseOffset: Random angle [0, 2π]
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %
            % Example:
            %   oqpskMod = csrd.blocks.physical.modulate.digital.PSK.OQPSK();
            %   oqpskMod.SamplePerSymbol = 8; % Even number required
            %   modHandle = oqpskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 1 0 1 0]);

            % Set modulator type flag
            obj.IsDigital = true;

            % OQPSK is inherently quaternary (4-ary) modulation
            obj.ModulatorOrder = 4;

            % Configure OQPSK modulation parameters if not provided
            if ~isfield(obj.ModulatorConfig, "beta")
                % Random symbol mapping (Binary or Gray code)
                obj.ModulatorConfig.SymbolMapping = randsample(["Binary", "Gray"], 1);

                % Random phase offset [0, 2π]
                obj.ModulatorConfig.PhaseOffset = rand(1) * 2 * pi;

                % Random pulse shaping parameters
                obj.ModulatorConfig.beta = rand(1); % Roll-off factor [0,1]
                obj.ModulatorConfig.span = randi([2, 8]) * 2; % Even span [4,16]
            end

            % Generate pulse shaping filter coefficients
            obj.filterCoeffs = obj.genFilterCoeffs;

            % Generate OSTBC encoder for MIMO support
            obj.ostbc = obj.genOSTBC;

            % Ensure SamplePerSymbol is even for proper OQPSK offset implementation
            obj.SamplePerSymbol = obj.SamplePerSymbol - mod(obj.SamplePerSymbol, 2);
            obj.pureModulator = csrd.blocks.physical.modulate.digital.PSK.BaseOQPSK( ...
                PhaseOffset = obj.ModulatorConfig.PhaseOffset, ...
                SymbolMapping = obj.ModulatorConfig.SymbolMapping, ...
                PulseShape = 'Root raised cosine', ...
                RolloffFactor = obj.ModulatorConfig.beta, ...
                FilterSpanInSymbols = obj.ModulatorConfig.span, ...
                SamplesPerSymbol = obj.SamplePerSymbol, ...
                NumTransmitAntennas = obj.NumTransmitAntennas, ...
                ostbc = obj.ostbc);

            modulatorHandle = @(x)obj.baseModulator(x);

        end

    end

end
