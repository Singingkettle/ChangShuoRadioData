classdef PAM < csrd.blocks.physical.modulate.BaseModulator
    % PAM - Pulse Amplitude Modulation Modulator
    %
    % This class implements Pulse Amplitude Modulation (PAM) as a subclass
    % of the BaseModulator. PAM modulation encodes digital information by varying
    % the amplitude of pulse signals at discrete time intervals. PAM forms the
    % basis for many advanced modulation schemes including ASK and QAM.
    %
    % PAM is a single-dimensional digital modulation technique that maps input
    % symbols to different amplitude levels. The modulated symbols are then
    % pulse-shaped using a raised cosine filter for bandwidth efficiency and
    % inter-symbol interference reduction.
    %
    % Key Features:
    %   - Configurable modulation order (2, 4, 8, 16-PAM, etc.)
    %   - Unit average power normalization
    %   - Pulse shaping with raised cosine filters
    %   - Single antenna transmission (SISO)
    %   - Real-valued output signals
    %
    % Syntax:
    %   pamModulator = PAM()
    %   pamModulator = PAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = pamModulator.step(inputData)
    %
    % Properties:
    %   ModulatorOrder - Number of amplitude levels (2, 4, 8, 16, etc.)
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   ModulatorConfig - Configuration structure for PAM parameters
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Properties (Access = protected):
    %   filterCoeffs - Pulse shaping filter coefficients
    %
    % Methods:
    %   baseModulator - Core PAM modulation implementation with pulse shaping
    %   genFilterCoeffs - Generate raised cosine filter coefficients
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create 4-PAM modulator
    %   pamMod = csrd.blocks.physical.modulate.digital.PAM.PAM();
    %   pamMod.ModulatorOrder = 4;
    %   pamMod.SamplePerSymbol = 8;
    %   pamMod.SampleRate = 1e6;
    %
    %   % Configure pulse shaping
    %   pamMod.ModulatorConfig.beta = 0.35; % Roll-off factor
    %   pamMod.ModulatorConfig.span = 10;   % Filter span
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 2000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = pamMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.BaseModulator, pammod, rcosdesign

    properties
        % SamplePerSymbol - Number of samples per symbol for pulse shaping
        % Type: positive real scalar, Default: 2
        % Note: Lower values provide computational efficiency but reduce filtering
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
    end

    properties (Access = protected)
        % filterCoeffs - Pulse shaping filter coefficients
        % Type: numeric array
        filterCoeffs
    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core PAM modulation implementation
            %
            % This method performs the complete PAM modulation process including
            % amplitude normalization for unit power, PAM symbol mapping, and
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
            %   modulatedSignal - PAM modulated and pulse-shaped signal
            %                     Type: real array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Calculate amplitude normalization factor for unit power
            %   2. Apply PAM modulation with amplitude scaling
            %   3. Apply pulse shaping filter with upsampling
            %   4. Calculate occupied bandwidth (doubled for double-sided spectrum)
            %
            % Power Normalization:
            %   PAM constellation is normalized to have unit average power to
            %   ensure consistent signal levels across different modulation orders.
            %
            % Example:
            %   symbols = [0 1 2 3 0 1]; % 4-PAM symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Calculate amplitude normalization factor for unit average power
            amplitudeNormalization = 1 / sqrt(mean(abs(pammod(0:obj.ModulatorOrder - 1, obj.ModulatorOrder)) .^ 2));

            % Apply PAM modulation with amplitude normalization
            modulatedSymbols = amplitudeNormalization * pammod(inputSymbols, obj.ModulatorOrder);

            % Apply pulse shaping with upsampling for bandwidth efficiency
            modulatedSignal = filter(obj.filterCoeffs, 1, upsample(modulatedSymbols, obj.SamplePerSymbol));

            % Calculate occupied bandwidth (doubled for double-sided spectrum)
            bandWidth = obw(modulatedSignal, obj.SampleRate) * 2;

            % For MIMO systems, take maximum bandwidth across antennas
            if obj.NumTransmitAntennas > 1
                bandWidth = max(bandWidth);
            end

        end

    end

    methods

        function filterCoeffs = genFilterCoeffs(obj)
            % genFilterCoeffs - Generate raised cosine filter coefficients
            %
            % This method creates a raised cosine filter for pulse shaping based on
            % the configured roll-off factor, filter span, and samples per symbol.
            % The filter reduces inter-symbol interference and shapes the spectrum.
            %
            % Syntax:
            %   filterCoeffs = genFilterCoeffs(obj)
            %
            % Output Arguments:
            %   filterCoeffs - Filter coefficients for pulse shaping
            %                  Type: numeric array
            %
            % Filter Design:
            %   The raised cosine filter provides optimal trade-off between
            %   time-domain compactness and frequency-domain roll-off.
            %   Beta=0 gives sinc pulse (brick-wall spectrum)
            %   Beta=1 gives maximum smooth roll-off
            %
            % Example:
            %   filterCoeffs = obj.genFilterCoeffs();

            filterCoeffs = rcosdesign(obj.ModulatorConfig.beta, ...
                obj.ModulatorConfig.span, ...
                obj.SamplePerSymbol);

        end

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured PAM modulator function handle
            %
            % This method configures the PAM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up pulse shaping filters and creates the final modulator
            % function for single-antenna transmission.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for PAM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %
            % Default Configuration:
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - NumTransmitAntennas: 1 (PAM is inherently single-antenna)
            %
            % Example:
            %   pamMod = csrd.blocks.physical.modulate.digital.PAM.PAM();
            %   pamMod.ModulatorOrder = 8; % 8-PAM
            %   modHandle = pamMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5 6 7]);

            % Set modulator type flag
            obj.IsDigital = true;

            % PAM is inherently single-antenna modulation
            obj.NumTransmitAntennas = 1;

            % Configure pulse shaping parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'beta')
                obj.ModulatorConfig.beta = rand(1); % Random roll-off factor [0,1]
                obj.ModulatorConfig.span = randi([2, 8]) * 2; % Random even span [4,16]
            end

            % Generate pulse shaping filter coefficients
            obj.filterCoeffs = obj.genFilterCoeffs;

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end
