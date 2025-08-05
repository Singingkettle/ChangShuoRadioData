classdef PSK < csrd.blocks.physical.modulate.digital.APSK.APSK
    % PSK - Phase Shift Keying Modulator
    %
    % This class implements Phase Shift Keying (PSK) modulation as a subclass
    % of the APSK modulator. PSK modulation encodes digital information by
    % varying the phase of the carrier signal while maintaining constant
    % amplitude and frequency.
    %
    % PSK is a digital modulation technique that uses a finite number of
    % distinct phase states to represent digital data. This implementation
    % supports both standard PSK and differential PSK (DPSK) modes with
    % configurable phase offset, symbol ordering, and pulse shaping.
    %
    % Key Features:
    %   - Standard PSK and Differential PSK (DPSK) support
    %   - Configurable phase offset and symbol ordering
    %   - Binary and Gray code symbol mapping
    %   - OSTBC encoding for MIMO transmission
    %   - Pulse shaping with raised cosine filters
    %
    % Technical Reference:
    %   OSTBC and PRC relationship: https://publik.tuwien.ac.at/files/pub-et_8438.pdf
    %
    % Syntax:
    %   pskModulator = PSK()
    %   pskModulator = PSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = pskModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Number of constellation points (2^n for n bits per symbol)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .Differential - Enable differential PSK mode (logical)
    %     .SymbolOrder - Symbol ordering ('bin' or 'gray')
    %     .PhaseOffset - Phase offset in radians
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Methods:
    %   baseModulator - Core PSK modulation implementation with pulse shaping
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create QPSK modulator (4-PSK)
    %   pskMod = csrd.blocks.physical.modulate.digital.PSK.PSK();
    %   pskMod.ModulatorOrder = 4;
    %   pskMod.SamplePerSymbol = 8;
    %   pskMod.SampleRate = 1e6;
    %
    %   % Configure for differential mode with Gray coding
    %   pskMod.ModulatorConfig.Differential = true;
    %   pskMod.ModulatorConfig.SymbolOrder = 'gray';
    %   pskMod.ModulatorConfig.PhaseOffset = pi/4;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 2000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = pskMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.BaseModulator, pskmod, dpskmod

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core PSK modulation implementation
            %
            % This method performs the complete PSK modulation process including
            % standard or differential PSK modulation, OSTBC encoding for MIMO,
            % and pulse shaping for bandwidth efficiency.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array (integers 0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - PSK modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Apply PSK or DPSK modulation based on configuration
            %   2. Apply OSTBC encoding for multiple antennas
            %   3. Apply pulse shaping filter with upsampling
            %   4. Calculate occupied bandwidth using obw function
            %
            % Modulation Types:
            %   - Standard PSK: Uses pskmod function with phase offset
            %   - Differential PSK: Uses dpskmod function for differential encoding
            %
            % Example:
            %   symbols = [0 1 2 3 0 1]; % QPSK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply PSK modulation (standard or differential)
            if obj.ModulatorConfig.Differential
                % Differential PSK modulation for better phase noise tolerance
                modulatedSymbols = dpskmod(inputSymbols, obj.ModulatorOrder, ...
                    obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            else
                % Standard PSK modulation
                modulatedSymbols = pskmod(inputSymbols, obj.ModulatorOrder, ...
                    obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            end

            % Apply OSTBC encoding for MIMO transmission
            encodedSymbols = obj.ostbc(modulatedSymbols);

            % Apply pulse shaping with upsampling for bandwidth efficiency
            modulatedSignal = filter(obj.filterCoeffs, 1, upsample(encodedSymbols, obj.SamplePerSymbol));

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
            % genModulatorHandle - Generate configured PSK modulator function handle
            %
            % This method configures the PSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up modulation parameters, pulse shaping filters, OSTBC
            % encoding, and creates the final modulator function.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for PSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - Differential: Enable/disable differential PSK (random selection)
            %   - SymbolOrder: Binary or Gray code ordering (random selection)
            %   - PhaseOffset: Phase offset in radians (random 0 to 2π)
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %   - ostbcSymbolRate: Symbol rate for OSTBC (0.5-1.0 for >2 antennas)
            %
            % Default Configuration:
            %   - Differential: Random true/false
            %   - SymbolOrder: Random 'bin' or 'gray'
            %   - PhaseOffset: Random angle [0, 2π]
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - ostbcSymbolRate: Random value (0.5, 0.75, or 1.0)
            %
            % Example:
            %   pskMod = csrd.blocks.physical.modulate.digital.PSK.PSK();
            %   pskMod.ModulatorOrder = 8; % 8-PSK
            %   modHandle = pskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5 6 7]);

            % Configure PSK modulation parameters if not provided
            if ~isfield(obj.ModulatorConfig, "beta")
                % Random differential mode selection
                obj.ModulatorConfig.Differential = randsample([true, false], 1);

                % Random symbol ordering (binary or Gray code)
                obj.ModulatorConfig.SymbolOrder = randsample(["bin", "gray"], 1);

                % Random phase offset [0, 2π]
                obj.ModulatorConfig.PhaseOffset = rand(1) * 2 * pi;

                % Random pulse shaping parameters
                obj.ModulatorConfig.beta = rand(1); % Roll-off factor [0,1]
                obj.ModulatorConfig.span = randi([2, 8]) * 2; % Even span [4,16]
            end

            % Configure OSTBC symbol rate for multiple antennas (>2)
            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    % Random selection: 0.5, 0.75, or 1.0
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            end

            % Set modulator type flag
            obj.IsDigital = true;

            % Generate pulse shaping filter coefficients
            obj.filterCoeffs = obj.genFilterCoeffs;

            % Generate OSTBC encoder for MIMO support
            obj.ostbc = obj.genOSTBC;

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end
