classdef MSK < csrd.blocks.physical.modulate.digital.FSK.FSK
    % MSK - Minimum Shift Keying Modulator
    %
    % This class implements Minimum Shift Keying (MSK) modulation as a subclass
    % of the FSK modulator. MSK is a special case of Continuous Phase Frequency
    % Shift Keying (CPFSK) with a modulation index of 0.5, providing constant
    % envelope and continuous phase characteristics ideal for efficient power
    % amplification and spectral efficiency.
    %
    % MSK modulation offers excellent spectral properties with no abrupt phase
    % transitions, making it suitable for mobile communications where power
    % efficiency and adjacent channel interference are critical concerns.
    % The continuous phase nature allows the use of non-linear power amplifiers
    % without spectral regrowth.
    %
    % Key Features:
    %   - Constant envelope modulation for efficient amplification
    %   - Continuous phase transitions (no phase discontinuities)
    %   - Excellent spectral efficiency with low sidelobes
    %   - Differential and non-differential encoding support
    %   - Configurable initial phase for synchronization
    %   - Single antenna transmission (inherent to MSK)
    %
    % Technical Specifications:
    %   - Modulation Index: 0.5 (fixed for MSK)
    %   - Phase Continuity: Maintained across symbol transitions
    %   - Spectral Efficiency: Superior to conventional FSK
    %   - Power Efficiency: Constant envelope enables Class C amplifiers
    %
    % Syntax:
    %   mskModulator = MSK()
    %   mskModulator = MSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = mskModulator.step(inputData)
    %
    % Properties (Inherited from FSK):
    %   ModulatorOrder - Fixed at 2 for binary MSK
    %   SamplePerSymbol - Number of samples per symbol for pulse shaping
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas (fixed at 1 for MSK)
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .DataEncode - Encoding type ('diff' for differential, 'nondiff' for standard)
    %     .InitPhase - Initial phase offset in radians [0, π/2, π, 3π/2]
    %
    % Methods:
    %   baseModulator - Core MSK modulation implementation with preprocessing
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create MSK modulator for mobile communications
    %   mskMod = csrd.blocks.physical.modulate.digital.CPM.MSK();
    %   mskMod.SamplePerSymbol = 8;
    %   mskMod.SampleRate = 250000; % 250 kHz sample rate
    %
    %   % Configure for differential encoding
    %   mskMod.ModulatorConfig.DataEncode = 'diff';
    %   mskMod.ModulatorConfig.InitPhase = 0;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 1000, 1); % Random binary data
    %
    %   % Modulate the signal
    %   modulatedSignal = mskMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.FSK.FSK,
    %           csrd.blocks.physical.modulate.digital.CPM.GMSK,
    %           csrd.blocks.physical.modulate.BaseModulator, mskmod

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputBits)
            % baseModulator - Core MSK modulation implementation with preprocessing
            %
            % This method performs MSK modulation with proper data length validation
            % and preprocessing for differential encoding modes. MSK requires even
            % number of bits for non-differential encoding to maintain phase
            % continuity across symbol boundaries.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputBits)
            %
            % Input Arguments:
            %   inputBits - Input binary data to be modulated
            %               Type: binary array (0s and 1s)
            %
            % Output Arguments:
            %   modulatedSignal - MSK modulated signal with constant envelope
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Validate and adjust input data length for encoding mode
            %   2. Apply MSK modulation using configured parameters
            %   3. Calculate occupied bandwidth of the modulated signal
            %
            % Data Length Requirements:
            %   - Non-differential mode: Even number of bits required
            %   - Differential mode: Any number of bits acceptable
            %
            % Example:
            %   inputBits = [1 0 1 1 0 0]; % Binary input
            %   [signal, bw] = obj.baseModulator(inputBits);

            % Get input data dimensions for validation
            [dataLength, numChannels] = size(inputBits);

            % For non-differential encoding, ensure even number of bits
            % This maintains phase continuity in MSK modulation
            if ~strcmpi(obj.ModulatorConfig.DataEncode, 'diff') && mod(dataLength, 2) ~= 0
                % Pad with zeros to make length even
                inputBits = [inputBits; zeros(1, numChannels, 'like', inputBits)];
            end

            % Apply MSK modulation using the configured pure modulator
            modulatedSignal = obj.pureModulator(inputBits);

            % Calculate occupied bandwidth of the modulated signal
            bandWidth = obw(modulatedSignal, obj.SampleRate);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured MSK modulator function handle
            %
            % This method configures the MSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. MSK is inherently digital and single-antenna due to its
            % constant envelope characteristics.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for MSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(bits)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - DataEncode: Encoding mode ('diff' or 'nondiff')
            %   - InitPhase: Initial phase offset (0, π/2, π, or 3π/2)
            %
            % Default Configuration:
            %   - DataEncode: Random selection between 'diff' and 'nondiff'
            %   - InitPhase: Random selection from [0, π/2, π, 3π/2]
            %   - IsDigital: true (digital modulation)
            %   - NumTransmitAntennas: 1 (single antenna for constant envelope)
            %
            % Encoding Modes:
            %   - 'diff': Differential encoding for improved error performance
            %   - 'nondiff': Standard encoding with direct bit mapping
            %
            % Initial Phase Options:
            %   - 0: Default phase reference
            %   - π/2: 90-degree phase offset
            %   - π: 180-degree phase offset
            %   - 3π/2: 270-degree phase offset
            %
            % Example:
            %   mskMod = csrd.blocks.physical.modulate.digital.CPM.MSK();
            %   modHandle = mskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([1 0 1 0 1 1]);

            % Set modulation type flags
            obj.IsDigital = true; % MSK is digital modulation
            obj.NumTransmitAntennas = 1; % Single antenna (constant envelope constraint)

            % Configure MSK parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'DataEncode')
                % Random encoding mode selection
                obj.ModulatorConfig.DataEncode = randsample(["diff", "nondiff"], 1);

                % Random initial phase selection (quadrant phases)
                obj.ModulatorConfig.InitPhase = randi([0, 3]) * pi / 2;
            end

            % Create pure MSK modulator function handle using MATLAB's mskmod
            obj.pureModulator = @(inputBits)mskmod(inputBits, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);

            % Create main modulator function handle
            modulatorHandle = @(inputBits)obj.baseModulator(inputBits);

        end

    end

end
