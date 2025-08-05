classdef TRFSimulator < matlab.System
    % TRFSimulator - Advanced Transmitter Radio Front-End Simulator
    %
    % This class implements a comprehensive transmitter radio front-end simulation
    % featuring advanced complex exponential frequency translation to replace traditional
    % Digital Up-Converter (DUC) approaches. The simulator models real-world RF
    % impairments and provides receiver-centric frequency allocation for AI/ML
    % optimized signal generation.
    %
    % Key Features:
    %   - Complex exponential frequency translation (replaces DUC)
    %   - Configurable RF impairments (IQ imbalance, phase noise, nonlinearity)
    %   - Multi-antenna support with identical frequency translation
    %   - Flexible sample rate conversion only when needed
    %   - Power scaling and DC offset modeling
    %   - Receiver-centric target sample rate configuration
    %
    % Technical References:
    %   - MATLAB Communications Toolbox QAM with RF Impairments example
    %   - USRP zero-IF design architecture (https://kb.ettus.com/UHD)
    %   - ORACLE paper: "Optimized Radio clAssification through Convolutional neuraL nEtworks"
    %
    % Properties:
    %   TargetSampleRate - Output sample rate set by receiver requirements
    %   DCOffset - DC offset in dB for modeling transmitter imperfections
    %   TxPowerDb - Desired transmission power in dBm
    %   CarrierFrequency - Target carrier frequency for this transmitter
    %   BandWidth - Signal bandwidth in Hz
    %   SampleRate - Input baseband sample rate in Hz
    %   SiteConfig - Site configuration flag for enabling location-based settings
    %   IqImbalanceConfig - Structure defining IQ imbalance parameters
    %   PhaseNoiseConfig - Structure defining phase noise characteristics
    %   MemoryLessNonlinearityConfig - Structure defining nonlinearity model
    %
    % Methods:
    %   TRFSimulator - Constructor with configurable properties
    %   setupImpl - Initialize RF impairment models and system objects
    %   stepImpl - Process input signal through complete transmitter chain
    %   frequencyTranslate - Apply complex exponential frequency translation
    %   resampleToTarget - Resample signal to target sample rate when needed
    %
    % Example Usage:
    %   % Create transmitter with receiver-centric configuration
    %   trf = TRFSimulator('TargetSampleRate', 20e6, ...
    %                      'CarrierFrequency', 2.4e9, ...
    %                      'TxPowerDb', 30);
    %
    %   % Process baseband signal through transmitter chain
    %   txSignal = trf(basebandSignal);
    %
    % Migration from DUC:
    %   The traditional DUC-based approach has been replaced with complex exponential
    %   multiplication for improved spectrum efficiency, reduced computational overhead,
    %   and AI/ML-friendly spectrograms without mirror frequency interference.
    %
    % See also: RRFSimulator, ParameterDrivenPlanner, csrd.blocks.scenario

    properties
        % TargetSampleRate: Target sample rate for output signal (Hz)
        % This replaces MasterClockRate from the traditional DUC-based approach.
        % Set by receiver requirements to define the observable frequency range.
        % Default: 20 MHz for typical wireless communication applications.
        TargetSampleRate (1, 1) {mustBePositive, mustBeReal} = 20e6

        % DCOffset: DC offset in dB for modeling transmitter imperfections
        % Models real-world transmitter DC bias and local oscillator leakage.
        % Negative values represent typical DC offset levels in practical systems.
        % Default: -50 dB (typical for modern RF transceivers)
        DCOffset {mustBeReal} = -50

        % TxPowerDb: Desired transmission power in dBm
        % Sets the final output power level for the transmitted signal.
        % Used for power scaling in the final stage of signal processing.
        % Default: 50 dBm (high power for base station applications)
        TxPowerDb (1, 1) {mustBeReal} = 50

        % CarrierFrequency: Target carrier frequency for this transmitter (Hz)
        % Defines the center frequency for complex exponential frequency translation.
        % Can be positive or negative to support full spectrum utilization.
        % Default: 2.4 GHz (ISM band)
        CarrierFrequency (1, 1) {mustBeReal} = 2.4e9

        % BandWidth: Signal bandwidth in Hz
        % Defines the occupied bandwidth of the transmitted signal.
        % Used for spectrum allocation and interference analysis.
        % Default: 20 MHz (typical for wideband communications)
        BandWidth (1, 1) {mustBeReal} = 20e6

        % SampleRate: Input baseband sample rate in Hz
        % Sample rate of the input baseband signal before frequency translation.
        % Used for time vector generation in frequency translation.
        % Default: 20 MHz (matching target sample rate for no resampling)
        SampleRate (1, 1) {mustBeReal} = 20e6

        % SiteConfig: Site configuration flag for location-based settings
        % When true, enables site-specific configuration for antenna positioning,
        % propagation modeling, and location-aware parameter adjustment.
        % Default: false (generic transmitter configuration)
        SiteConfig = false

        % IqImbalanceConfig: Structure defining IQ imbalance parameters
        % Contains fields for amplitude and phase imbalance modeling:
        %   .A - Amplitude imbalance in dB
        %   .P - Phase imbalance in degrees
        % Models real-world quadrature demodulator imperfections
        IqImbalanceConfig struct

        % PhaseNoiseConfig: Structure defining phase noise characteristics
        % Contains fields for oscillator phase noise modeling:
        %   .Level - Phase noise level in dBc/Hz
        %   .FrequencyOffset - Frequency offset for phase noise measurement
        %   .RandomStream - Random stream configuration for reproducibility
        %   .Seed - Random seed when using seeded random stream
        PhaseNoiseConfig struct

        % MemoryLessNonlinearityConfig: Structure defining nonlinearity model
        % Contains fields for power amplifier nonlinearity modeling:
        %   .Method - Nonlinearity model type ('Cubic polynomial', 'Hyperbolic tangent', etc.)
        %   .LinearGain - Linear gain in dB
        %   .TOISpecification - Third-order intercept specification type
        %   Various model-specific parameters (IIP3, OIP3, etc.)
        MemoryLessNonlinearityConfig struct
    end

    properties (Access = protected)
        % IQImbalance: Function handle for IQ imbalance simulation
        % Generated during setup to apply configured amplitude and phase imbalance
        IQImbalance

        % PhaseNoise: System object for phase noise simulation
        % Communications Toolbox phase noise object configured during setup
        PhaseNoise

        % MemoryLessNonlinearity: System object for nonlinearity simulation
        % Communications Toolbox memoryless nonlinearity object for PA modeling
        MemoryLessNonlinearity

        % Note: DUC-related properties removed in frequency translation upgrade
        % Legacy properties no longer needed:
        % - InterpolationFactor (replaced by flexible resampling)
        % - DUC (replaced by complex exponential frequency translation)
    end

    methods (Access = protected)

        % Note: genDUC method removed - no longer needed with complex exponential approach

        function iqImbalanceHandle = genIqImbalance(obj)
            % genIqImbalance - Generate IQ imbalance function handle
            %
            % Creates a function handle that applies amplitude and phase imbalance
            % to simulate real-world quadrature demodulator imperfections. The
            % imbalance parameters are specified in the IqImbalanceConfig structure.
            %
            % Returns:
            %   iqImbalanceHandle - Function handle that applies amplitude and phase imbalance
            %                      using configured parameters from IqImbalanceConfig
            %
            % Configuration Required:
            %   obj.IqImbalanceConfig.A - Amplitude imbalance in dB
            %   obj.IqImbalanceConfig.P - Phase imbalance in degrees
            %
            % Example:
            %   % Configure IQ imbalance
            %   trf.IqImbalanceConfig.A = 0.5;  % 0.5 dB amplitude imbalance
            %   trf.IqImbalanceConfig.P = 2.0;  % 2.0 degree phase imbalance
            %
            % See also: iqimbal (Communications Toolbox)

            iqImbalanceHandle = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
        end

        function phaseNoiseObject = genPhaseNoise(obj)
            % genPhaseNoise - Generate phase noise system object
            %
            % Creates and configures a Communications Toolbox phase noise system object
            % to model oscillator phase noise in the transmitter. The phase noise
            % characteristics are specified in the PhaseNoiseConfig structure.
            %
            % Returns:
            %   phaseNoiseObject - Configured comm.PhaseNoise system object
            %
            % Configuration Required:
            %   obj.PhaseNoiseConfig.Level - Phase noise level in dBc/Hz
            %   obj.PhaseNoiseConfig.FrequencyOffset - Frequency offset array
            %
            % Optional Configuration:
            %   obj.PhaseNoiseConfig.RandomStream - Random stream type
            %   obj.PhaseNoiseConfig.Seed - Random seed for reproducibility
            %
            % Example:
            %   % Configure phase noise
            %   trf.PhaseNoiseConfig.Level = [-80, -90, -100];
            %   trf.PhaseNoiseConfig.FrequencyOffset = [1e3, 10e3, 100e3];
            %
            % See also: comm.PhaseNoise (Communications Toolbox)

            % https://www.mathworks.com/help/comm/ref/comm.phasenoise-system-object.html
            phaseNoiseObject = comm.PhaseNoise( ...
                Level = obj.PhaseNoiseConfig.Level, ...
                FrequencyOffset = obj.PhaseNoiseConfig.FrequencyOffset, ...
                SampleRate = obj.TargetSampleRate); % Use target sample rate

            % Configure optional random stream settings for reproducibility
            if isfield(obj.PhaseNoiseConfig, 'RandomStream')

                if strcmp(obj.PhaseNoiseConfig.RandomStream, 'mt19936ar with seed')
                    phaseNoiseObject.RandomStream = "mt19937ar with seed";
                    phaseNoiseObject.Seed = obj.PhaseNoiseConfig.Seed;
                end

            end

        end

        function nonlinearityObject = genMemoryLessNonlinearity(obj)
            % genMemoryLessNonlinearity - Generate memoryless nonlinearity system object
            %
            % Creates and configures a Communications Toolbox memoryless nonlinearity
            % system object to model power amplifier characteristics. Supports multiple
            % nonlinearity models including cubic polynomial, hyperbolic tangent,
            % Saleh model, Ghorbani model, modified Rapp model, and lookup table.
            %
            % Returns:
            %   nonlinearityObject - Configured comm.MemorylessNonlinearity system object
            %
            % Supported Models:
            %   - 'Cubic polynomial': Third-order intercept point modeling
            %   - 'Hyperbolic tangent': Soft saturation characteristics
            %   - 'Saleh model': Traveling wave tube amplifier model
            %   - 'Ghorbani model': Solid state power amplifier model
            %   - 'Modified Rapp model': Generalized amplifier model
            %   - 'Lookup table': Custom amplifier characteristics
            %
            % Configuration Required:
            %   obj.MemoryLessNonlinearityConfig.Method - Nonlinearity model type
            %   Model-specific parameters as defined in configuration structure
            %
            % See also: comm.MemorylessNonlinearity (Communications Toolbox)

            % Generate nonlinearity models based on configured method
            if strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                nonlinearityObject = comm.MemorylessNonlinearity( ...
                    Method = 'Cubic polynomial', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification = obj.MemoryLessNonlinearityConfig.TOISpecification);

                % Configure third-order intercept specification
                if strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IIP3')
                    nonlinearityObject.OIP3 = obj.MemoryLessNonlinearityConfig.IIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OIP3')
                    nonlinearityObject.OIP3 = obj.MemoryLessNonlinearityConfig.OIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IP1dB')
                    nonlinearityObject.IP1dB = obj.MemoryLessNonlinearityConfig.IP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OP1dB')
                    nonlinearityObject.OP1dB = obj.MemoryLessNonlinearityConfig.OP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IPsat')
                    nonlinearityObject.IPsat = obj.MemoryLessNonlinearityConfig.IPsat;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OPsat')
                    nonlinearityObject.OPsat = obj.MemoryLessNonlinearityConfig.OPsat;
                end

                % Configure AM-PM conversion and power limits
                nonlinearityObject.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                nonlinearityObject.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                nonlinearityObject.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Hyperbolic tangent')
                nonlinearityObject = comm.MemorylessNonlinearity( ...
                    Method = 'Hyperbolic tangent', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);
                nonlinearityObject.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                nonlinearityObject.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                nonlinearityObject.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Saleh model') || strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Ghorbani model')
                nonlinearityObject = comm.MemorylessNonlinearity( ...
                    Method = obj.MemoryLessNonlinearityConfig.Method, ...
                    InputScaling = obj.MemoryLessNonlinearityConfig.InputScaling, ...
                    AMAMParameters = obj.MemoryLessNonlinearityConfig.AMAMParameters, ...
                    AMPMParameters = obj.MemoryLessNonlinearityConfig.AMPMParameters, ...
                    OutputScaling = obj.MemoryLessNonlinearityConfig.OutputScaling);

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Modified Rapp model')
                nonlinearityObject = comm.MemorylessNonlinearity( ...
                    Method = 'Modified Rapp model', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    Smoothness = obj.MemoryLessNonlinearityConfig.Smoothness, ...
                    PhaseGainRadian = obj.MemoryLessNonlinearityConfig.PhaseGainRadian, ...
                    PhaseSaturation = obj.MemoryLessNonlinearityConfig.PhaseSaturation, ...
                    PhaseSmoothness = obj.MemoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel = obj.MemoryLessNonlinearityConfig.OutputSaturationLevel);

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Lookup table')
                nonlinearityObject = comm.MemorylessNonlinearity( ...
                    Method = 'Look table', ...
                    Table = obj.MemoryLessNonlinearityConfig.Table);
            end

            % Set reference impedance for power calculations
            nonlinearityObject.ReferenceImpedance = obj.MemoryLessNonlinearityConfig.ReferenceImpedance;
        end

        function setupImpl(obj)
            % setupImpl - Initialize transmitter radio front-end system components
            %
            % Sets up all necessary RF impairment models and system objects for
            % the transmitter chain. This method is called automatically when
            % the system object is first used and configures:
            %   - IQ imbalance function handle
            %   - Phase noise system object
            %   - Memoryless nonlinearity system object
            %
            % Note: DUC initialization has been removed in favor of the new
            % complex exponential frequency translation approach.

            % Initialize RF impairment models
            obj.IQImbalance = obj.genIqImbalance;
            obj.PhaseNoise = obj.genPhaseNoise;
            obj.MemoryLessNonlinearity = obj.genMemoryLessNonlinearity;

            % Legacy DUC initialization removed:
            % obj.DUC = obj.genDUC;  % No longer needed
        end

        function translatedSignal = frequencyTranslate(obj, inputSignal, targetFrequency, signalSampleRate)
            % frequencyTranslate - Apply complex exponential frequency translation
            %
            % Performs frequency translation using complex exponential multiplication
            % to replace traditional DUC interpolation. This approach provides clean
            % frequency translation without mirror signals, improved computational
            % efficiency, and AI/ML-friendly spectrograms.
            %
            % Syntax:
            %   translatedSignal = frequencyTranslate(obj, inputSignal, targetFrequency, signalSampleRate)
            %
            % Input Arguments:
            %   inputSignal - Input baseband signal [samples x antennas]
            %   targetFrequency - Target frequency for translation in Hz
            %   signalSampleRate - Sample rate of the input signal in Hz
            %
            % Output Arguments:
            %   translatedSignal - Frequency-translated signal [samples x antennas]
            %
            % Mathematical Operation:
            %   translatedSignal = inputSignal .* exp(1j * 2 * π * targetFrequency * t)
            %   where t is the time vector based on sample rate
            %
            % Multi-Antenna Support:
            %   For multi-antenna signals, the same frequency translation is applied
            %   to all antenna elements, maintaining phase relationships between antennas.
            %
            % Advantages over DUC:
            %   - No interpolation artifacts or mirror frequencies
            %   - Direct mathematical operation without filter design
            %   - Support for negative frequency offsets
            %   - Reduced computational complexity
            %   - Clean time-frequency representations for AI/ML applications

            numSamples = size(inputSignal, 1);
            numAntennas = size(inputSignal, 2);

            % Create time vector based on signal sample rate
            timeVector = (0:numSamples - 1)' / signalSampleRate;

            % Generate complex exponential for frequency translation
            % The same frequency translation is applied to all antennas
            frequencyShiftExponential = exp(1j * 2 * pi * targetFrequency * timeVector);

            % Apply frequency shift to all antenna elements
            if numAntennas == 1
                % Single antenna case - direct multiplication
                translatedSignal = inputSignal .* frequencyShiftExponential;
            else
                % Multi-antenna case - replicate frequency shift for all antennas
                frequencyShiftMatrix = repmat(frequencyShiftExponential, 1, numAntennas);
                translatedSignal = inputSignal .* frequencyShiftMatrix;
            end

        end

        function resampledSignal = resampleToTarget(obj, inputSignal, inputSampleRate)
            % resampleToTarget - Resample signal to target sample rate when needed
            %
            % Performs sample rate conversion to match the target sample rate only
            % when necessary. If the input sample rate already matches the target,
            % no resampling is performed to avoid unnecessary processing.
            %
            % Syntax:
            %   resampledSignal = resampleToTarget(obj, inputSignal, inputSampleRate)
            %
            % Input Arguments:
            %   inputSignal - Input signal to be resampled [samples x antennas]
            %   inputSampleRate - Current sample rate of the input signal in Hz
            %
            % Output Arguments:
            %   resampledSignal - Signal resampled to target sample rate [samples x antennas]
            %
            % Resampling Method:
            %   Uses rational resampling with optimized P/Q ratio calculation
            %   for efficient sample rate conversion. Multi-antenna signals
            %   are resampled column-wise to maintain antenna relationships.
            %
            % Performance Optimization:
            %   - No resampling when input rate equals target rate
            %   - Efficient rational resampling using resample() function
            %   - Column-wise processing for multi-antenna signals

            if inputSampleRate == obj.TargetSampleRate
                % No resampling needed - return input signal unchanged
                resampledSignal = inputSignal;
            else
                % Calculate rational resampling factors with high precision
                [upsampleFactor, downsampleFactor] = rat(obj.TargetSampleRate / inputSampleRate, 1e-6);

                if size(inputSignal, 2) == 1
                    % Single antenna - direct resampling
                    resampledSignal = resample(inputSignal, upsampleFactor, downsampleFactor);
                else
                    % Multi-antenna - resample each antenna column separately
                    numAntennas = size(inputSignal, 2);
                    outputLength = ceil(size(inputSignal, 1) * upsampleFactor / downsampleFactor);
                    resampledSignal = zeros(outputLength, numAntennas);

                    for antennaIdx = 1:numAntennas
                        resampledSignal(:, antennaIdx) = resample(inputSignal(:, antennaIdx), upsampleFactor, downsampleFactor);
                    end

                end

            end

        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Process input signal through complete transmitter RF chain
            %
            % Executes the complete transmitter radio front-end processing chain
            % including RF impairments, complex exponential frequency translation,
            % and sample rate conversion. This is the main processing method called
            % when the system object is used as a function.
            %
            % Processing Chain:
            %   1. Apply IQ imbalance to simulate quadrature demodulator imperfections
            %   2. Add DC offset to model transmitter bias and LO leakage
            %   3. Apply phase noise to simulate oscillator phase noise
            %   4. Apply memoryless nonlinearity to model power amplifier characteristics
            %   5. Perform complex exponential frequency translation
            %   6. Resample to target sample rate if needed
            %   7. Apply final power scaling
            %
            % Syntax:
            %   outputSignal = stepImpl(obj, inputSignal)
            %
            % Input Arguments:
            %   inputSignal - Input structure containing:
            %     .data - Baseband signal data [samples x antennas]
            %     .carrierFrequency - Target carrier frequency (Hz) [optional]
            %     .sampleRate - Input sample rate (Hz) [optional]
            %
            % Output Arguments:
            %   outputSignal - Output structure containing:
            %     .data - Processed RF signal [samples x antennas]
            %     .carrierFrequency - Applied carrier frequency (Hz)
            %     .sampleRate - Output sample rate (Hz)
            %     .bandwidth - Signal bandwidth (Hz)
            %     .txPower - Transmission power (dBm)
            %
            % Example:
            %   % Create input signal structure
            %   input.data = randn(1024, 2) + 1j*randn(1024, 2);  % 2-antenna signal
            %   input.carrierFrequency = 2.4e9;  % 2.4 GHz carrier
            %   input.sampleRate = 20e6;         % 20 MHz sample rate
            %
            %   % Process through transmitter
            %   output = trf(input);

            % Extract input parameters with defaults
            if isstruct(inputSignal)
                basebandData = inputSignal.data;
                carrierFreq = inputSignal.carrierFrequency;
                inputSampleRate = inputSignal.sampleRate;
            else
                % Direct signal input - use object properties
                basebandData = inputSignal;
                carrierFreq = obj.CarrierFrequency;
                inputSampleRate = obj.SampleRate;
            end

            % Step 1: Apply IQ imbalance to simulate quadrature imperfections
            processedSignal = obj.IQImbalance(basebandData);

            % Step 2: Add DC offset to model transmitter bias and LO leakage
            processedSignal = processedSignal + 10 ^ (obj.DCOffset / 10);

            % Step 3: Apply phase noise to simulate oscillator imperfections
            release(obj.PhaseNoise);
            processedSignal = obj.PhaseNoise(processedSignal);

            % Step 4: Apply memoryless nonlinearity to model power amplifier characteristics
            processedSignal = obj.MemoryLessNonlinearity(processedSignal);

            % Step 5: Perform complex exponential frequency translation
            frequencyTranslatedSignal = obj.frequencyTranslate(processedSignal, carrierFreq, inputSampleRate);

            % Step 6: Resample to target sample rate if needed
            resampledSignal = obj.resampleToTarget(frequencyTranslatedSignal, inputSampleRate);

            % Step 7: Apply final power scaling to achieve desired transmission power
            signalDuration = size(resampledSignal, 1) / obj.TargetSampleRate;
            signalPower = sum(abs(resampledSignal(:, 1)) .^ 2) / size(resampledSignal, 1);

            % Convert dBm to linear power (Watts) and calculate scaling factor
            targetPowerWatts = 10 ^ (obj.TxPowerDb / 10) / 1000; % Convert dBm to Watts
            scalingFactor = sqrt(targetPowerWatts / (signalPower * signalDuration)) * sqrt(signalDuration);
            finalSignal = resampledSignal * scalingFactor;

            % Create output structure with processed signal and metadata
            if isstruct(inputSignal)
                % Return structure with same format as input
                outputSignal = inputSignal;
                outputSignal.data = finalSignal;
                outputSignal.carrierFrequency = carrierFreq;
                outputSignal.sampleRate = obj.TargetSampleRate;
                outputSignal.bandwidth = obj.BandWidth;
                outputSignal.txPower = obj.TxPowerDb;
                outputSignal.samplePerFrame = size(finalSignal, 1);
                outputSignal.timeDuration = outputSignal.samplePerFrame / outputSignal.sampleRate;
                outputSignal.sdrMode = "Complex Exponential Frequency Translation";

                % Include RF impairment configuration for reference
                outputSignal.rfImpairments.dcOffset = obj.DCOffset;
                outputSignal.rfImpairments.iqImbalanceConfig = obj.IqImbalanceConfig;
                outputSignal.rfImpairments.phaseNoiseConfig = obj.PhaseNoiseConfig;
                outputSignal.rfImpairments.nonlinearityConfig = obj.MemoryLessNonlinearityConfig;
                outputSignal.rfImpairments.siteConfig = obj.SiteConfig;
            else
                % Return direct signal for simple input
                outputSignal = finalSignal;
            end

        end

    end

    methods

        function obj = TRFSimulator(varargin)
            % TRFSimulator - Constructor for transmitter radio front-end simulator
            %
            % Creates a new TRFSimulator instance with configurable properties.
            % The constructor accepts name-value pairs for setting object properties
            % including target sample rate, carrier frequency, power settings, and
            % RF impairment configurations.
            %
            % Syntax:
            %   obj = TRFSimulator()
            %   obj = TRFSimulator('PropertyName', PropertyValue, ...)
            %
            % Input Arguments:
            %   varargin - Name-value pairs for setting object properties
            %     'TargetSampleRate' - Output sample rate in Hz (default: 20e6)
            %     'CarrierFrequency' - Carrier frequency in Hz (default: 2.4e9)
            %     'TxPowerDb' - Transmission power in dBm (default: 50)
            %     'BandWidth' - Signal bandwidth in Hz (default: 20e6)
            %     'DCOffset' - DC offset in dB (default: -50)
            %     'IqImbalanceConfig' - IQ imbalance configuration structure
            %     'PhaseNoiseConfig' - Phase noise configuration structure
            %     'MemoryLessNonlinearityConfig' - Nonlinearity configuration structure
            %
            % Output Arguments:
            %   obj - TRFSimulator instance ready for signal processing
            %
            % Example:
            %   % Create transmitter with custom configuration
            %   trf = TRFSimulator('TargetSampleRate', 40e6, ...
            %                      'CarrierFrequency', 5.8e9, ...
            %                      'TxPowerDb', 30);
            %
            %   % Configure IQ imbalance
            %   trf.IqImbalanceConfig.A = 0.5;  % 0.5 dB amplitude imbalance
            %   trf.IqImbalanceConfig.P = 2.0;  % 2.0 degree phase imbalance
            %
            % See also: setupImpl, stepImpl, frequencyTranslate

            setProperties(obj, nargin, varargin{:});
        end

    end

end
