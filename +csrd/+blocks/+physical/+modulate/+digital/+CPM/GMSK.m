classdef GMSK < csrd.blocks.physical.modulate.digital.FSK.FSK
    % GMSK - Gaussian Minimum Shift Keying Modulator
    %
    % This class implements Gaussian Minimum Shift Keying (GMSK) modulation as a
    % subclass of the FSK modulator. GMSK is a special case of Continuous Phase
    % Frequency Shift Keying (CPFSK) that combines MSK modulation with Gaussian
    % pre-filtering to achieve superior spectral efficiency while maintaining
    % constant envelope and continuous phase properties.
    %
    % GMSK is widely used in mobile communication systems including GSM, where
    % its excellent spectral characteristics and power efficiency make it ideal
    % for cellular applications. The Gaussian filter reduces spectral sidelobes
    % compared to MSK while preserving the constant envelope property essential
    % for efficient RF power amplification.
    %
    % Key Features:
    %   - Constant envelope modulation for efficient power amplification
    %   - Continuous phase with no abrupt transitions
    %   - Superior spectral efficiency compared to MSK and FSK
    %   - Gaussian pre-filtering for reduced spectral sidelobes
    %   - Configurable bandwidth-time (BT) product for performance optimization
    %   - Binary input with symbol memory for continuous phase generation
    %   - Single antenna transmission (constant envelope constraint)
    %
    % Technical Specifications:
    %   - Modulation Index: 0.5 (fixed for GMSK, inherited from MSK)
    %   - Pre-filter: Gaussian with configurable BT product
    %   - Phase Memory: Maintains phase history across symbols
    %   - Spectral Efficiency: Superior to MSK due to Gaussian filtering
    %
    % Syntax:
    %   gmskModulator = GMSK()
    %   gmskModulator = GMSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = gmskModulator.step(inputData)
    %
    % Properties (Inherited from FSK):
    %   ModulatorOrder - Fixed at 2 for binary GMSK
    %   SamplePerSymbol - Number of samples per symbol for oversampling
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas (fixed at 1 for GMSK)
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .BandwidthTimeProduct - Gaussian filter BT product (0.2 to 0.5)
    %     .PulseLength - Gaussian pulse length in symbols (4 to 10)
    %     .SymbolPrehistory - Initial symbol state (-1 or +1)
    %     .InitialPhaseOffset - Initial phase offset in radians [0, 2π]
    %
    % Methods:
    %   genModulatorHandle - Generate configured modulator function handle
    %   baseModulator - Inherited from FSK parent class
    %
    % Example:
    %   % Create GMSK modulator for GSM-like mobile communications
    %   gmskMod = csrd.blocks.physical.modulate.digital.CPM.GMSK();
    %   gmskMod.SamplePerSymbol = 8;
    %   gmskMod.SampleRate = 2.6e6; % GSM sample rate (270.833 kbps * 8)
    %
    %   % Configure for GSM-standard parameters
    %   gmskMod.ModulatorConfig.BandwidthTimeProduct = 0.3; % GSM standard
    %   gmskMod.ModulatorConfig.PulseLength = 4; % Typical for GSM
    %   gmskMod.ModulatorConfig.SymbolPrehistory = 1;
    %   gmskMod.ModulatorConfig.InitialPhaseOffset = 0;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 1000, 1); % Random binary data
    %
    %   % Modulate the signal
    %   modulatedSignal = gmskMod.step(inputData);
    %
    % Standards and Applications:
    %   - GSM (Global System for Mobile Communications)
    %   - DECT (Digital Enhanced Cordless Telecommunications)
    %   - Some satellite communication systems
    %
    % Performance Characteristics:
    %   - Power Spectral Density: Better than MSK due to Gaussian filtering
    %   - Bit Error Rate: Slightly worse than MSK due to ISI from filtering
    %   - Spectral Efficiency: Superior sidelobe suppression
    %   - Implementation Complexity: Moderate (requires Gaussian filtering)
    %
    % See also: csrd.blocks.physical.modulate.digital.CPM.MSK,
    %           csrd.blocks.physical.modulate.digital.CPM.GFSK,
    %           csrd.blocks.physical.modulate.digital.FSK.FSK,
    %           csrd.blocks.physical.modulate.BaseModulator, comm.GMSKModulator

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured GMSK modulator function handle
            %
            % This method configures the GMSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. The method creates a GMSKModulator with Gaussian pre-filtering
            % and configures all necessary parameters for continuous phase modulation.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for GMSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(bits)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - BandwidthTimeProduct: Gaussian filter BT product (0.2 to 0.5)
            %   - PulseLength: Gaussian pulse length in symbols (4 to 10)
            %   - SymbolPrehistory: Initial symbol state (-1 or +1)
            %   - InitialPhaseOffset: Initial phase offset [0, 2π]
            %
            % Default Configuration:
            %   - BandwidthTimeProduct: Random value between 0.2 and 0.5
            %   - PulseLength: Random integer between 4 and 10 symbols
            %   - SymbolPrehistory: Random selection from [-1, +1]
            %   - InitialPhaseOffset: Random angle [0, 2π]
            %   - IsDigital: true (digital modulation)
            %   - NumTransmitAntennas: 1 (single antenna for constant envelope)
            %   - BitInput: true (binary input mode)
            %
            % BT Product Guidelines:
            %   - BT = 0.2: Maximum spectral efficiency, higher ISI
            %   - BT = 0.3: GSM standard (good compromise)
            %   - BT = 0.5: Lower spectral efficiency, minimal ISI
            %
            % Pulse Length Considerations:
            %   - Shorter pulses (4-6): Lower latency, more spectral leakage
            %   - Longer pulses (8-10): Better filtering, higher latency
            %   - GSM uses 4 symbols for practical implementation
            %
            % Symbol Prehistory:
            %   - Determines initial phase state for continuous phase generation
            %   - Must be either -1 or +1 for binary GMSK
            %   - Affects phase continuity at start of transmission
            %
            % Example:
            %   gmskMod = csrd.blocks.physical.modulate.digital.CPM.GMSK();
            %   modHandle = gmskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([1 0 1 0 1 1]);

            % Set modulation type flags
            obj.IsDigital = true; % GMSK is digital modulation
            obj.NumTransmitAntennas = 1; % Single antenna (constant envelope constraint)

            % Configure GMSK parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                % BT product typically ranges from 0.2 to 0.5 for practical applications
                % Lower BT provides better spectral efficiency but introduces more ISI
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1) * 0.3 + 0.2; % Range: [0.2, 0.5]

                % Gaussian pulse length in symbols (affects filter memory and performance)
                obj.ModulatorConfig.PulseLength = randi([4, 10], 1);

                % Initial symbol state for phase continuity (must be ±1 for binary)
                obj.ModulatorConfig.SymbolPrehistory = randsample([-1, 1], 1);

                % Initial phase offset for synchronization flexibility
                obj.ModulatorConfig.InitialPhaseOffset = rand(1) * 2 * pi; % Range: [0, 2π]
            end

            % Create MATLAB Communication Toolbox GMSKModulator
            obj.pureModulator = comm.GMSKModulator( ...
                'BitInput', true, ... % Binary input mode for bit-level processing
                'BandwidthTimeProduct', obj.ModulatorConfig.BandwidthTimeProduct, ...
                'PulseLength', obj.ModulatorConfig.PulseLength, ...
                'SymbolPrehistory', obj.ModulatorConfig.SymbolPrehistory, ...
                'InitialPhaseOffset', obj.ModulatorConfig.InitialPhaseOffset, ...
                'SamplesPerSymbol', obj.SamplePerSymbol);

            % Create function handle for modulation (uses inherited baseModulator from FSK)
            modulatorHandle = @(inputBits)obj.baseModulator(inputBits);

        end

    end

end
