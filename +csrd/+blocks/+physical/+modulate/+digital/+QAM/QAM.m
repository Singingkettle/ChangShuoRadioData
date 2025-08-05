classdef QAM < csrd.blocks.physical.modulate.digital.APSK.APSK
    % QAM - Quadrature Amplitude Modulation Modulator
    %
    % This class implements Quadrature Amplitude Modulation (QAM) as a subclass
    % of the APSK modulator. QAM modulation combines amplitude and phase modulation
    % by transmitting digital information using discrete amplitude and phase
    % combinations of the carrier signal.
    %
    % QAM is a digital modulation technique that uses both amplitude and phase
    % variations to encode digital data. Common QAM configurations include 4-QAM
    % (QPSK), 16-QAM, 64-QAM, and 256-QAM, with higher orders providing greater
    % spectral efficiency at the cost of noise sensitivity.
    %
    % Key Features:
    %   - Configurable modulation order (4, 16, 64, 256-QAM, etc.)
    %   - Binary and Gray code symbol mapping
    %   - Unit average power normalization
    %   - OSTBC encoding for MIMO transmission
    %   - Pulse shaping with raised cosine filters
    %
    % Syntax:
    %   qamModulator = QAM()
    %   qamModulator = QAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = qamModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Number of constellation points (must be power of 2)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .SymbolOrder - Symbol ordering ('bin' or 'gray')
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Methods:
    %   baseModulator - Core QAM modulation implementation with pulse shaping
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create 16-QAM modulator with Gray coding
    %   qamMod = csrd.blocks.physical.modulate.digital.QAM.QAM();
    %   qamMod.ModulatorOrder = 16;
    %   qamMod.SamplePerSymbol = 4;
    %   qamMod.SampleRate = 1e6;
    %
    %   % Configure for Gray coding
    %   qamMod.ModulatorConfig.SymbolOrder = 'gray';
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 4000, 1); % Random bits (4 bits per symbol)
    %
    %   % Modulate the signal
    %   modulatedSignal = qamMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.BaseModulator, qammod

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core QAM modulation implementation
            %
            % This method performs the complete QAM modulation process including
            % QAM constellation mapping with unit average power, OSTBC encoding
            % for MIMO, and pulse shaping for bandwidth efficiency.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array (integers 0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - QAM modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Apply QAM modulation with unit average power normalization
            %   2. Apply OSTBC encoding for multiple antennas
            %   3. Apply pulse shaping filter with upsampling
            %   4. Calculate occupied bandwidth using obw function
            %
            % Example:
            %   symbols = [0 1 2 3 4 5]; % 16-QAM symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply QAM modulation with unit average power normalization
            modulatedSymbols = qammod(inputSymbols, obj.ModulatorOrder, ...
                obj.ModulatorConfig.SymbolOrder, 'UnitAveragePower', true);

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
            % genModulatorHandle - Generate configured QAM modulator function handle
            %
            % This method configures the QAM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up symbol ordering, pulse shaping filters, OSTBC encoding,
            % and creates the final modulator function.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for QAM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - SymbolOrder: Binary or Gray code ordering (random selection)
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %   - ostbcSymbolRate: Symbol rate for OSTBC (0.5-1.0 for >2 antennas)
            %
            % Default Configuration:
            %   - SymbolOrder: Random 'bin' or 'gray'
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - ostbcSymbolRate: Random value (0.5, 0.75, or 1.0)
            %
            % Example:
            %   qamMod = csrd.blocks.physical.modulate.digital.QAM.QAM();
            %   qamMod.ModulatorOrder = 64; % 64-QAM
            %   modHandle = qamMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5]);

            % Configure QAM modulation parameters if not provided
            if ~isfield(obj.ModulatorConfig, "beta")
                % Random symbol ordering (binary or Gray code)
                obj.ModulatorConfig.SymbolOrder = randsample(["bin", "gray"], 1);

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
