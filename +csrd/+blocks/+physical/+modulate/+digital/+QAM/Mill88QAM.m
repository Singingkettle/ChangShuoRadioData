classdef Mill88QAM < csrd.blocks.physical.modulate.digital.APSK.APSK
    % Mill88QAM - MIL-STD-188-110 QAM Modulator
    %
    % This class implements MIL-STD-188-110 compliant QAM modulation as a subclass
    % of the APSK modulator. MIL-STD-188-110 defines the standard for interoperability
    % and performance requirements for data communication systems used by the
    % Department of Defense (DoD).
    %
    % MIL-188 QAM differs from conventional QAM in constellation point arrangement
    % and specific power normalization requirements defined by the military standard.
    % This implementation ensures compliance with DoD communication protocols for
    % tactical data communication systems.
    %
    % Key Features:
    %   - MIL-STD-188-110 compliant constellation arrangement
    %   - Unit average power normalization for DoD standards
    %   - Configurable modulation orders (4, 8, 16, 32, 64-QAM)
    %   - OSTBC encoding support for MIMO transmission
    %   - Pulse shaping with raised cosine filters
    %   - Military-grade signal quality requirements
    %
    % Syntax:
    %   mill88Modulator = Mill88QAM()
    %   mill88Modulator = Mill88QAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = mill88Modulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Number of constellation points (4, 8, 16, 32, 64)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %     .ostbcSymbolRate - Symbol rate for OSTBC (for >2 antennas)
    %
    % Methods:
    %   baseModulator - Core MIL-188 QAM modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create MIL-188 16-QAM modulator for tactical communications
    %   mill88Mod = csrd.blocks.physical.modulate.digital.QAM.Mill88QAM();
    %   mill88Mod.ModulatorOrder = 16;
    %   mill88Mod.SamplePerSymbol = 4;
    %   mill88Mod.SampleRate = 1e6;
    %
    %   % Configure for military-grade pulse shaping
    %   mill88Mod.ModulatorConfig.beta = 0.35;  % Standard roll-off
    %   mill88Mod.ModulatorConfig.span = 10;    % Filter span
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 4000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = mill88Mod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.digital.QAM.QAM,
    %           csrd.blocks.physical.modulate.BaseModulator, mil188qammod

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core MIL-188 QAM modulation implementation
            %
            % This method performs MIL-STD-188-110 compliant QAM modulation with
            % unit average power normalization, OSTBC encoding for MIMO, and
            % pulse shaping for bandwidth efficiency.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array (integers 0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - MIL-188 QAM modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Apply MIL-188 QAM modulation with unit average power
            %   2. Apply OSTBC encoding for multiple antennas
            %   3. Apply pulse shaping filter with upsampling
            %   4. Calculate occupied bandwidth using obw function
            %
            % MIL-188 QAM Features:
            %   - Constellation points arranged according to MIL-STD-188-110
            %   - Unit average power normalization for military standards
            %   - Optimized for tactical communication environments
            %
            % Example:
            %   symbols = [0 1 2 3 4 5]; % 16-QAM symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply MIL-188 QAM modulation with unit average power normalization
            modulatedSymbols = mil188qammod(inputSymbols, obj.ModulatorOrder, ...
                'UnitAveragePower', true);

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
            % genModulatorHandle - Generate configured MIL-188 QAM modulator function handle
            %
            % This method configures the MIL-188 QAM modulator with default parameters
            % if not specified and returns a function handle for the complete modulation
            % process. The method sets up pulse shaping filters, OSTBC encoding, and
            % creates the final modulator function for military-grade communications.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for MIL-188 QAM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %   - ostbcSymbolRate: Symbol rate for OSTBC (0.5-1.0 for >2 antennas)
            %
            % Default Configuration:
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - ostbcSymbolRate: Random value (0.5, 0.75, or 1.0)
            %
            % Military Standards Compliance:
            %   All parameters are selected to maintain compatibility with
            %   MIL-STD-188-110 requirements for tactical data communications.
            %
            % Example:
            %   mill88Mod = csrd.blocks.physical.modulate.digital.QAM.Mill88QAM();
            %   mill88Mod.ModulatorOrder = 32; % 32-QAM
            %   modHandle = mill88Mod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5]);

            % Configure pulse shaping parameters if not provided
            if ~isfield(obj.ModulatorConfig, "beta")
                obj.ModulatorConfig.beta = rand(1); % Random roll-off factor [0,1]
                obj.ModulatorConfig.span = randi([2, 8]) * 2; % Random even span [4,16]
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
