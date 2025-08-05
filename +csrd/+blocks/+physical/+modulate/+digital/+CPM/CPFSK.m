classdef CPFSK < csrd.blocks.physical.modulate.digital.CPM.GFSK
    % CPFSK - Continuous Phase Frequency Shift Keying Modulator
    %
    % This class implements Continuous Phase Frequency Shift Keying (CPFSK)
    % modulation as a subclass of the GFSK modulator. CPFSK is a digital
    % modulation technique that uses a finite number of frequencies to
    % represent digital data while maintaining continuous phase transitions
    % between symbols, providing excellent spectral efficiency and constant
    % envelope characteristics.
    %
    % CPFSK is the general form of frequency shift keying with continuous phase,
    % where MSK and GMSK are special cases. This implementation supports M-ary
    % modulation with configurable modulation index and phase characteristics,
    % making it suitable for various digital communication applications requiring
    % spectral efficiency and power amplifier linearity.
    %
    % Key Features:
    %   - M-ary frequency shift keying with continuous phase transitions
    %   - Constant envelope modulation for efficient power amplification
    %   - Configurable modulation index for bandwidth and performance control
    %   - No phase discontinuities across symbol boundaries
    %   - Superior spectral efficiency compared to conventional FSK
    %   - Support for higher-order modulation (M > 2)
    %   - Single antenna transmission (constant envelope constraint)
    %
    % Technical Specifications:
    %   - Modulation Order: M ≥ 2 (binary and higher-order supported)
    %   - Modulation Index: Configurable (typically 0.5 to 1.0)
    %   - Phase Continuity: Maintained across all symbol transitions
    %   - Frequency Separation: Determined by modulation index
    %   - Spectral Efficiency: Increases with modulation order
    %
    % Syntax:
    %   cpfskModulator = CPFSK()
    %   cpfskModulator = CPFSK('PropertyName', PropertyValue, ...)
    %   modulatedSignal = cpfskModulator.step(inputData)
    %
    % Properties (Inherited from GFSK):
    %   ModulatorOrder - Number of frequency levels (M ≥ 2)
    %   SamplePerSymbol - Number of samples per symbol for oversampling
    %   SampleRate - Sample rate of the modulated signal in Hz
    %   NumTransmitAntennas - Number of transmit antennas (fixed at 1)
    %   ModulatorConfig - Configuration structure for modulator parameters
    %     .ModulationIndex - Frequency deviation parameter (0.5 to 1.0)
    %     .InitialPhaseOffset - Initial phase offset in radians [0, 2π]
    %
    % Protected Properties (Inherited):
    %   pureModulator - MATLAB Communication Toolbox CPFSKModulator object
    %   constellationMap - Symbol mapping for M-ary modulation
    %
    % Methods:
    %   genModulatorHandle - Generate configured modulator function handle
    %   baseModulator - Inherited from GFSK parent class
    %
    % Example:
    %   % Create 4-ary CPFSK modulator for satellite communications
    %   cpfskMod = csrd.blocks.physical.modulate.digital.CPM.CPFSK();
    %   cpfskMod.ModulatorOrder = 4; % 4-ary CPFSK
    %   cpfskMod.SamplePerSymbol = 8;
    %   cpfskMod.SampleRate = 1e6; % 1 MHz sample rate
    %
    %   % Configure modulation parameters
    %   cpfskMod.ModulatorConfig.ModulationIndex = 0.7;
    %   cpfskMod.ModulatorConfig.InitialPhaseOffset = 0;
    %
    %   % Create input data structure
    %   inputData.data = randi([0 3], 500, 1); % Random 4-ary symbols
    %
    %   % Modulate the signal
    %   modulatedSignal = cpfskMod.step(inputData);
    %
    % Modulation Index Guidelines:
    %   - h = 0.5: Minimum bandwidth (MSK case for binary)
    %   - h = 0.7: Good compromise between bandwidth and performance
    %   - h = 1.0: Orthogonal frequencies, easier demodulation
    %   - Higher h: Wider bandwidth but better error performance
    %
    % Performance vs. Complexity Trade-offs:
    %   - Lower ModulationOrder: Simpler implementation, lower data rate
    %   - Higher ModulationOrder: Higher data rate, more complex detection
    %   - Lower ModulationIndex: Narrower bandwidth, more ISI
    %   - Higher ModulationIndex: Wider bandwidth, less ISI
    %
    % References:
    %   - MATLAB Communications Toolbox CPM Documentation:
    %     https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    %   - CPFSK Implementation Details:
    %     https://blog.csdn.net/Insomnia_X/article/details/126333301
    %   - Digital Communications by John G. Proakis (Chapter on CPM)
    %
    % See also: csrd.blocks.physical.modulate.digital.CPM.GFSK,
    %           csrd.blocks.physical.modulate.digital.CPM.MSK,
    %           csrd.blocks.physical.modulate.digital.CPM.GMSK,
    %           csrd.blocks.physical.modulate.BaseModulator, comm.CPFSKModulator

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured CPFSK modulator function handle
            %
            % This method configures the CPFSK modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. The method validates the modulation order and creates a
            % CPFSKModulator with the specified configuration parameters.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for CPFSK modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - ModulationIndex: Frequency deviation parameter (0.5 to 1.0)
            %   - InitialPhaseOffset: Initial phase offset [0, 2π]
            %
            % Input Validation:
            %   - ModulatorOrder must be ≥ 2 for meaningful CPFSK operation
            %   - MSK (M=2, h=0.5) and GMSK are special cases handled separately
            %
            % Default Configuration:
            %   - ModulationIndex: Random value between 0.5 and 1.0
            %   - InitialPhaseOffset: Random angle [0, 2π]
            %   - IsDigital: true (digital modulation)
            %   - NumTransmitAntennas: 1 (single antenna for constant envelope)
            %
            % Modulation Index Selection:
            %   - h = 0.5: Minimum shift keying (MSK) for binary case
            %   - h = 0.68: Optimal for some applications (partial response)
            %   - h = 1.0: Orthogonal frequencies (easier demodulation)
            %   - Random selection provides variety for testing/simulation
            %
            % Frequency Spacing:
            %   The frequency separation between adjacent symbols is:
            %   Δf = h × R_s / 2, where R_s is the symbol rate
            %
            % Error Handling:
            %   Throws error if ModulatorOrder < 2, as lower orders don't
            %   provide meaningful CPFSK operation compared to specialized
            %   implementations (MSK, GMSK).
            %
            % Example:
            %   cpfskMod = csrd.blocks.physical.modulate.digital.CPM.CPFSK();
            %   cpfskMod.ModulatorOrder = 8; % 8-ary CPFSK
            %   modHandle = cpfskMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle([0 1 2 3 4 5 6 7]);

            % Validate modulation order for meaningful CPFSK operation
            if obj.ModulatorOrder < 2
                error('ChangShuoRadioData:CPFSK:InvalidModulationOrder', ...
                    'Modulation order must be greater than or equal to 2. ' + ...
                'For binary cases, consider using MSK or GMSK specialized implementations.');
            end

            % Set modulation type flags
            obj.IsDigital = true; % CPFSK is digital modulation
            obj.NumTransmitAntennas = 1; % Single antenna (constant envelope constraint)

            % Create symmetric M-ary constellation mapping (inherited from GFSK)
            % For M-ary CPFSK: [−(M−1), −(M−3), ..., −1, +1, ..., +(M−3), +(M−1)]
            obj.constellationMap = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';

            % Configure CPFSK parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'ModulationIndex')
                % Modulation index typically ranges from 0.5 to 1.0
                % h = 0.5: Minimum bandwidth (MSK for binary)
                % h = 1.0: Orthogonal frequencies, easier demodulation
                obj.ModulatorConfig.ModulationIndex = 0.5 + rand(1) * 0.5; % Range: [0.5, 1.0]

                % Initial phase offset for synchronization and testing variety
                obj.ModulatorConfig.InitialPhaseOffset = rand(1) * 2 * pi; % Range: [0, 2π]
            end

            % Create MATLAB Communication Toolbox CPFSKModulator
            obj.pureModulator = comm.CPFSKModulator( ...
                'ModulationOrder', obj.ModulatorOrder, ...
                'ModulationIndex', obj.ModulatorConfig.ModulationIndex, ...
                'InitialPhaseOffset', obj.ModulatorConfig.InitialPhaseOffset, ...
                'SamplesPerSymbol', obj.SamplePerSymbol);

            % Create function handle for modulation (uses inherited baseModulator from GFSK)
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end
