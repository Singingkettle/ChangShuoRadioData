classdef GFSK < csrd.blocks.physical.modulate.BaseModulator
    % GFSK - Gaussian Frequency Shift Keying Modulator
    %
    % This class implements Gaussian Frequency Shift Keying (GFSK) modulation
    % as a subclass of the BaseModulator. GFSK is a form of Continuous Phase
    % Modulation (CPM) that uses a Gaussian pulse shape for the frequency
    % modulation, providing excellent spectral efficiency and smooth phase
    % transitions for digital communications.
    %
    % GFSK combines the benefits of FSK with improved spectral characteristics
    % through Gaussian filtering. The Gaussian pulse shaping reduces spectral
    % sidelobes while maintaining constant envelope properties, making it ideal
    % for battery-powered devices and applications requiring efficient spectrum
    % utilization. GFSK is widely used in Bluetooth, GSM, and other wireless
    % communication standards.
    %
    % Key Features:
    %   - Continuous phase modulation with Gaussian pulse shaping
    %   - Constant envelope for efficient power amplification
    %   - Excellent spectral efficiency with reduced sidelobes
    %   - Configurable bandwidth-time (BT) product for performance tuning
    %   - Support for M-ary modulation (binary and higher order)
    %   - Single antenna transmission (constant envelope constraint)
    %
    % Technical Specifications:
    %   - Modulation Index: 1.0 (configurable through ModulationIndex)
    %   - Pulse Shape: Gaussian frequency pulse
    %   - Phase Continuity: Maintained across all symbol transitions
    %   - BT Product: Typically 0.2 to 0.5 for practical applications
    %
    % Syntax:
    %   gfskModulator = GFSK()
    %   gfskModulator = GFSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = gfskModulator.step(inputData)
    %
    % Properties:
    %   ModulatorOrder - Number of frequency levels (2 for binary, higher for M-ary)
    %   SamplePerSymbol - Number of samples per symbol for oversampling
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas (fixed at 1 for GFSK)
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .BandwidthTimeProduct - Gaussian filter BT product (0.2 to 0.5)
    %
    % Protected Properties:
    %   pureModulator - MATLAB Communication Toolbox CPMModulator object
    %   constellationMap - Symbol mapping for M-ary modulation
    %
    % Methods:
    %   baseModulator - Core GFSK modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create binary GFSK modulator for Bluetooth-like applications
    %   gfskMod = csrd.blocks.physical.modulate.digital.CPM.GFSK();
    %   gfskMod.ModulatorOrder = 2; % Binary GFSK
    %   gfskMod.SamplePerSymbol = 8;
    %   gfskMod.SampleRate = 2e6; % 2 MHz sample rate
    %
    %   % Configure Gaussian filter characteristics
    %   gfskMod.ModulatorConfig.BandwidthTimeProduct = 0.3;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 1000, 1); % Random binary data
    %
    %   % Modulate the signal
    %   modulatedSignal = gfskMod.step(inputData);
    %
    % References:
    %   - MATLAB Communications Toolbox CPM Documentation:
    %     https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    %   - Deep Learning Modulation Classification:
    %     https://www.mathworks.com/help/deeplearning/ug/modulation-classification-with-deep-learning.html
    %   - Bluetooth Core Specification for GFSK implementation details
    %
    % See also: csrd.blocks.physical.modulate.digital.CPM.MSK,
    %           csrd.blocks.physical.modulate.digital.CPM.GMSK,
    %           csrd.blocks.physical.modulate.BaseModulator, comm.CPMModulator

    properties (Access = protected)
        % pureModulator - MATLAB Communication Toolbox CPMModulator object
        % Type: comm.CPMModulator
        pureModulator

        % constellationMap - Symbol mapping for M-ary GFSK modulation
        % Type: numeric column vector
        constellationMap
    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core GFSK modulation implementation
            %
            % This method performs GFSK modulation using the MATLAB Communication
            % Toolbox CPMModulator with Gaussian frequency pulse shaping. The method
            % maps input symbols to the appropriate constellation points and applies
            % continuous phase modulation.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: integer array (0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - GFSK modulated signal with constant envelope
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Map symbols to constellation points using constellationMap
            %   2. Apply GFSK modulation using CPMModulator
            %   3. Calculate occupied bandwidth of the modulated signal
            %
            % Symbol Mapping:
            %   For M-ary GFSK, symbols are mapped to frequency levels:
            %   - Binary (M=2): [−1, +1]
            %   - 4-ary (M=4): [−3, −1, +1, +3]
            %   - General M-ary: [−(M−1), ..., −1, +1, ..., +(M−1)]
            %
            % Example:
            %   inputSymbols = [0 1 0 1]; % Binary symbols
            %   [signal, bw] = obj.baseModulator(inputSymbols);

            % Map input symbols to constellation points for M-ary modulation
            % Add 1 to convert 0-based indexing to 1-based for MATLAB
            mappedSymbols = obj.constellationMap(inputSymbols(:) + 1);

            % Apply GFSK modulation using the configured CPM modulator
            modulatedSignal = obj.pureModulator(mappedSymbols);

            % Calculate occupied bandwidth of the modulated signal
            bandWidth = obw(modulatedSignal, obj.SampleRate);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured GFSK modulator function handle
            %
            % This method configures the GFSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. The method creates a CPMModulator with Gaussian frequency
            % pulse and configures the constellation mapping for M-ary operation.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for GFSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - BandwidthTimeProduct: Gaussian filter BT product (0.2 to 0.5)
            %
            % Default Configuration:
            %   - BandwidthTimeProduct: Random value between 0.2 and 0.5
            %   - ModulationIndex: 1.0 (standard for GFSK)
            %   - FrequencyPulse: "Gaussian" (defining characteristic of GFSK)
            %   - IsDigital: true (digital modulation)
            %   - NumTransmitAntennas: 1 (single antenna for constant envelope)
            %
            % BT Product Guidelines:
            %   - BT = 0.2: Higher spectral efficiency, more intersymbol interference
            %   - BT = 0.3: Bluetooth standard (good compromise)
            %   - BT = 0.5: Less spectral efficient but lower ISI
            %
            % Constellation Mapping:
            %   Creates symmetric M-ary constellation:
            %   - Points: [−(M−1), −(M−3), ..., −1, +1, ..., +(M−3), +(M−1)]
            %   - Spacing: 2 units between adjacent levels
            %   - Zero-centered for balanced frequency deviation
            %
            % Example:
            %   gfskMod = csrd.blocks.physical.modulate.digital.CPM.GFSK();
            %   gfskMod.ModulatorOrder = 4; % 4-ary GFSK
            %   modHandle = gfskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 0 1]);

            % Set modulation type flags
            obj.IsDigital = true; % GFSK is digital modulation
            obj.NumTransmitAntennas = 1; % Single antenna (constant envelope constraint)

            % Create symmetric M-ary constellation mapping
            % For M-ary GFSK: [−(M−1), −(M−3), ..., −1, +1, ..., +(M−3), +(M−1)]
            obj.constellationMap = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';

            % Configure Gaussian filter bandwidth-time product if not provided
            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                % BT product typically ranges from 0.2 to 0.5 for practical applications
                % - BT = 0.2: More spectral efficient but higher ISI
                % - BT = 0.3: Bluetooth standard (good compromise)
                % - BT = 0.5: Less spectral efficient but lower ISI
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1) * 0.3 + 0.2; % Range: [0.2, 0.5]
            end

            % Create MATLAB Communication Toolbox CPMModulator for GFSK
            obj.pureModulator = comm.CPMModulator( ...
                'ModulationOrder', obj.ModulatorOrder, ...
                'FrequencyPulse', "Gaussian", ...
                'ModulationIndex', 1, ... % Standard modulation index for GFSK
                'BandwidthTimeProduct', obj.ModulatorConfig.BandwidthTimeProduct, ...
                'SamplesPerSymbol', obj.SamplePerSymbol);

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end
