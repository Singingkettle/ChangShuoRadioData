classdef ASK < csrd.blocks.physical.modulate.digital.APSK.APSK
    % ASK - Amplitude Shift Keying Modulator
    %
    % This class implements Amplitude Shift Keying (ASK) modulation as a subclass
    % of the APSK modulator. ASK modulation varies the amplitude of the carrier
    % signal to represent digital information while maintaining constant phase.
    %
    % ASK is a form of amplitude modulation that represents digital data as
    % variations in the amplitude of a carrier wave. This implementation uses
    % PAM (Pulse Amplitude Modulation) as the underlying modulation technique
    % with configurable pulse shaping for bandwidth efficiency.
    %
    % Syntax:
    %   askModulator = ASK()
    %   askModulator = ASK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = askModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - The order of modulation (2^n for n bits per symbol)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for modulator parameters
    %
    % Methods:
    %   baseModulator - Core ASK modulation implementation with pulse shaping
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create ASK modulator with 4-ASK (2 bits per symbol)
    %   askMod = csrd.blocks.physical.modulate.digital.ASK.ASK();
    %   askMod.ModulatorOrder = 4;
    %   askMod.SamplePerSymbol = 8;
    %   askMod.SampleRate = 1e6;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 1000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = askMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.BaseModulator
    %
    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core ASK modulation implementation
            %
            % This method performs the complete ASK modulation process including
            % amplitude normalization, PAM modulation, OSTBC encoding for MIMO,
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
            %   modulatedSignal - ASK modulated and pulse-shaped signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar or vector (for MIMO)
            %
            % Processing Steps:
            %   1. Calculate amplitude normalization factor for unit power
            %   2. Apply PAM modulation with amplitude scaling
            %   3. Apply OSTBC encoding for multiple antennas
            %   4. Apply pulse shaping filter with upsampling
            %   5. Calculate occupied bandwidth using obw function
            %
            % Example:
            %   symbols = [0 1 2 3 0 1]; % 4-ASK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Calculate amplitude normalization factor for unit average power
            amplitudeNormalization = 1 / sqrt(mean(abs(pammod(0:obj.ModulatorOrder - 1, obj.ModulatorOrder)) .^ 2));

            % Apply PAM modulation with amplitude normalization
            modulatedSymbols = amplitudeNormalization * pammod(inputSymbols, obj.ModulatorOrder);

            % Apply OSTBC encoding for MIMO transmission
            encodedSymbols = obj.ostbc(modulatedSymbols);

            % Apply pulse shaping with upsampling for bandwidth efficiency
            modulatedSignal = filter(obj.filterCoeffs, 1, upsample(encodedSymbols, obj.SamplePerSymbol));

            % Calculate occupied bandwidth (doubled for double-sided spectrum)
            bandWidth = obw(modulatedSignal, obj.SampleRate) * 2;

            % For MIMO systems, take maximum bandwidth across antennas
            if obj.NumTransmitAntennas > 1
                bandWidth = max(bandWidth);
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured ASK modulator function handle
            %
            % This method configures the ASK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up pulse shaping filters, OSTBC encoding, and creates
            % the final modulator function.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for ASK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - beta: Roll-off factor for raised cosine filter (0 to 1)
            %   - span: Filter span in symbols (even number, 4-16)
            %   - ostbcSymbolRate: Symbol rate for OSTBC (0.5-1.0 for >2 antennas)
            %
            % Default Configuration:
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - ostbcSymbolRate: Random value (0.5, 0.75, or 1.0)
            %
            % Example:
            %   askMod = csrd.blocks.physical.modulate.digital.ASK.ASK();
            %   askMod.ModulatorOrder = 4;
            %   modHandle = askMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3]);

            % Configure pulse shaping parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'beta')
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
