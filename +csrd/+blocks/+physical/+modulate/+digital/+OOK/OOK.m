classdef OOK < csrd.blocks.physical.modulate.digital.APSK.APSK
    % OOK - On-Off Keying Modulator
    %
    % This class implements On-Off Keying (OOK) modulation as a subclass of the
    % APSK modulator. OOK is the simplest form of amplitude-shift keying (ASK)
    % where digital data is transmitted by switching a carrier signal on and off.
    %
    % OOK modulation represents digital bits using two states: carrier ON (bit 1)
    % and carrier OFF (bit 0). This makes it the most basic form of digital
    % modulation, often used in infrared communication, wireless sensor networks,
    % and simple RF applications due to its implementation simplicity.
    %
    % Key Features:
    %   - Binary modulation (2 states: ON/OFF)
    %   - Fixed modulation order of 2
    %   - Pulse shaping with raised cosine filters
    %   - Single antenna transmission (SISO)
    %   - High noise immunity for simple detection
    %
    % Syntax:
    %   ookModulator = OOK()
    %   ookModulator = OOK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = ookModulator.step(inputData)
    %
    % Properties (Inherited from APSK):
    %   ModulatorOrder - Fixed at 2 for binary OOK
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Fixed at 1 (single antenna)
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .beta - Roll-off factor for pulse shaping (0 to 1)
    %     .span - Filter span in symbols
    %
    % Methods:
    %   baseModulator - Core OOK modulation implementation with pulse shaping
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create OOK modulator
    %   ookMod = csrd.blocks.physical.modulate.digital.OOK.OOK();
    %   ookMod.SamplePerSymbol = 8;
    %   ookMod.SampleRate = 1e6;
    %
    %   % Configure pulse shaping
    %   ookMod.ModulatorConfig.beta = 0.5;  % Roll-off factor
    %   ookMod.ModulatorConfig.span = 10;   % Filter span
    %
    %   % Create input data structure (binary data)
    %   inputData.data = randi([0 1], 1000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = ookMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.APSK.APSK,
    %           csrd.blocks.physical.modulate.digital.ASK.ASK,
    %           csrd.blocks.physical.modulate.BaseModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core OOK modulation implementation
            %
            % This method performs OOK modulation by directly applying pulse shaping
            % to the binary input symbols. Unlike other modulation schemes, OOK
            % does not require constellation mapping as the symbols directly
            % represent the ON/OFF states.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Binary input symbol sequence (0s and 1s)
            %                  Type: numeric array (values 0 or 1)
            %
            % Output Arguments:
            %   modulatedSignal - OOK modulated and pulse-shaped signal
            %                     Type: real array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Apply pulse shaping filter with upsampling to binary symbols
            %   2. Calculate occupied bandwidth (doubled for double-sided spectrum)
            %
            % Note:
            %   OOK modulation is implemented by direct pulse shaping without
            %   constellation mapping, as the binary symbols already represent
            %   the desired amplitude states (0 = OFF, 1 = ON).
            %
            % Example:
            %   symbols = [0 1 0 1 1 0]; % Binary OOK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply pulse shaping with upsampling directly to binary symbols
            % In OOK, 0 represents carrier OFF and 1 represents carrier ON
            modulatedSignal = filter(obj.filterCoeffs, 1, upsample(inputSymbols, obj.SamplePerSymbol));

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
            % genModulatorHandle - Generate configured OOK modulator function handle
            %
            % This method configures the OOK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % OOK is inherently binary (modulation order 2) and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for OOK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - beta: Roll-off factor for raised cosine filter (random 0 to 1)
            %   - span: Filter span in symbols (random even number 4-16)
            %   - ModulatorOrder: Fixed at 2 for binary OOK
            %   - NumTransmitAntennas: Fixed at 1 (single antenna)
            %
            % Default Configuration:
            %   - beta: Random value between 0 and 1
            %   - span: Random even integer between 4 and 16
            %   - Digital modulation flag: true
            %
            % Example:
            %   ookMod = csrd.blocks.physical.modulate.digital.OOK.OOK();
            %   modHandle = ookMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 0 1 1 0]);

            % Set modulator type flag
            obj.IsDigital = true;

            % OOK is inherently single-antenna and binary modulation
            obj.NumTransmitAntennas = 1;
            obj.ModulatorOrder = 2; % Fixed binary modulation

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
