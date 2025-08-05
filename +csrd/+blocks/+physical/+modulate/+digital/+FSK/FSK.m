classdef FSK < csrd.blocks.physical.modulate.BaseModulator
    % FSK - Frequency Shift Keying Modulator
    %
    % This class implements Frequency Shift Keying (FSK) modulation as a subclass
    % of the BaseModulator. FSK modulation encodes digital information by shifting
    % the carrier frequency between discrete values, with each frequency representing
    % a different digital symbol.
    %
    % FSK is a digital modulation technique that uses frequency variations to
    % represent digital data. The modulation index and frequency separation determine
    % the spectral efficiency and error performance. This implementation supports
    % both continuous-phase and discontinuous-phase FSK modes.
    %
    % Key Features:
    %   - Configurable frequency separation between symbols
    %   - Binary and Gray code symbol mapping
    %   - Continuous and discontinuous phase modes
    %   - Automatic frequency separation optimization
    %   - Single antenna transmission (SISO)
    %
    % Syntax:
    %   fskModulator = FSK()
    %   fskModulator = FSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = fskModulator.step(inputData)
    %
    % Properties:
    %   ModulatorOrder - Number of frequency states (2, 4, 8, 16, etc.)
    %   SamplePerSymbol - Number of samples per symbol
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   ModulatorConfig - Configuration structure for FSK parameters
    %     .FrequencySeparation - Frequency separation between symbols (Hz)
    %     .SymbolOrder - Symbol ordering ('bin' or 'gray')
    %     .PhaseDiscontinuity - Phase continuity mode ('cont' or 'discont')
    %
    % Properties (Access = private):
    %   frequencySeparation - Internal frequency separation value
    %   pureModulator - Function handle for core FSK modulation
    %
    % Methods:
    %   baseModulator - Core FSK modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create 4-FSK modulator
    %   fskMod = csrd.blocks.physical.modulate.digital.FSK.FSK();
    %   fskMod.ModulatorOrder = 4;
    %   fskMod.SamplePerSymbol = 8;
    %   fskMod.SampleRate = 1e6;
    %
    %   % Configure frequency separation
    %   fskMod.ModulatorConfig.FrequencySeparation = 50000; % 50 kHz
    %   fskMod.ModulatorConfig.SymbolOrder = 'gray';
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 2000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = fskMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.BaseModulator, fskmod

    properties (Access = private)
        % frequencySeparation - Frequency separation between symbols in Hz
        % Type: positive scalar
        frequencySeparation

        % pureModulator - Function handle for core FSK modulation
        % Type: function_handle
        pureModulator
    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core FSK modulation implementation
            %
            % This method performs FSK modulation using the configured frequency
            % separation and calculates the occupied bandwidth based on the
            % frequency spacing or actual signal analysis.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array (integers 0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - FSK modulated signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Apply FSK modulation using configured parameters
            %   2. Calculate bandwidth using frequency separation or obw analysis
            %
            % Bandwidth Calculation:
            %   For FSK signals, bandwidth is primarily determined by frequency
            %   separation and can be estimated as: BW ≈ freq_sep * (M-1) + 2*Rs
            %   where M is the modulation order and Rs is the symbol rate.
            %
            % Example:
            %   symbols = [0 1 2 3 0 1]; % 4-FSK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply FSK modulation using pre-configured modulator
            modulatedSignal = obj.pureModulator(inputSymbols);

            % Calculate bandwidth based on frequency separation if available
            if ~isempty(obj.frequencySeparation)
                % Estimate bandwidth using frequency separation and modulation order
                bandWidth = obj.frequencySeparation * obj.ModulatorOrder;
            else
                % Fall back to occupied bandwidth analysis
                bandWidth = obw(modulatedSignal, obj.SampleRate);
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured FSK modulator function handle
            %
            % This method configures the FSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up frequency separation, symbol ordering, and creates
            % the core FSK modulation function.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for FSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - FrequencySeparation: Frequency spacing between symbols (Hz)
            %   - SymbolOrder: Binary or Gray code ordering
            %   - Phase discontinuity mode: Continuous or discontinuous phase
            %
            % Frequency Separation Calculation:
            %   Maximum frequency separation is limited by sample rate and modulation
            %   order. The algorithm selects 40-50% of maximum allowable separation
            %   to ensure adequate spectral containment.
            %
            % Example:
            %   fskMod = csrd.blocks.physical.modulate.digital.FSK.FSK();
            %   fskMod.ModulatorOrder = 8; % 8-FSK
            %   modHandle = fskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5 6 7]);

            % Set modulator type flag
            obj.IsDigital = true;

            % FSK is inherently single-antenna modulation
            obj.NumTransmitAntennas = 1;

            % Calculate maximum allowable frequency separation
            maximumFrequencySeparation = obj.SampleRate / (obj.ModulatorOrder - 1);

            % Select frequency separation as 40-50% of maximum (rounded to 100 Hz)
            obj.frequencySeparation = round((rand(1) * 0.1 + 0.4) * maximumFrequencySeparation / 100) * 100;

            % Configure FSK modulation parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'SymbolOrder')
                obj.ModulatorConfig.FrequencySeparation = obj.frequencySeparation;
                obj.ModulatorConfig.SymbolOrder = randsample(["bin", "gray"], 1);
            end

            % Create FSK modulator function handle with discontinuous phase
            obj.pureModulator = @(inputSymbols)fskmod(inputSymbols, ...
                obj.ModulatorOrder, ...
                obj.ModulatorConfig.FrequencySeparation, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulatorConfig.SymbolOrder);

            % Create main modulator function handle
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);
        end

    end

end
