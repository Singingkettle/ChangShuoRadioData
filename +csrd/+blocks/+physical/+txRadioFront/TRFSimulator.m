classdef TRFSimulator < matlab.System
    % TRFSimulator - Advanced Transmitter Radio Front-End Simulator
    % 中文说明：提供 CSRD 生产链路中的 TRFSimulator 实现。
    %
    % This class implements a comprehensive transmitter radio front-end simulation
    % featuring advanced complex exponential frequency translation to replace traditional
    % Digital Up-Converter (DUC) approaches. The simulator models real-world RF
    % impairments and provides receiver-centric frequency allocation for AI/ML
    % optimized signal generation.
    %
    % Key Features:
    %   - Target-rate complex exponential frequency translation (replaces DUC)
    %   - Configurable RF impairments (IQ imbalance, phase noise, nonlinearity)
    %   - Multi-antenna support with identical frequency translation
    %   - Flexible sample rate conversion only when needed
    %   - Power scaling and DC offset modeling
    %   - Receiver-centric target sample rate configuration
    %
    % References / 参考资料:
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
        % Sample rate of the modulator output before receiver-rate resampling.
        % Frequency translation is performed after resampling to TargetSampleRate.
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

        % PhaseNoiseBackend: implementation used for oscillator phase noise.
        % 'FastSpectral' preserves the phase-noise PSD contract without paying
        % the heavy per-shape initialization cost of comm.PhaseNoise on short
        % Monte-Carlo frames. 'MathWorks' is retained for explicit comparison.
        PhaseNoiseBackend char = 'FastSpectral'

        % MemoryLessNonlinearityConfig: Structure defining nonlinearity model
        % Contains fields for power amplifier nonlinearity modeling:
        %   .Method - Nonlinearity model type ('Cubic polynomial', 'Hyperbolic tangent', etc.)
        %   .LinearGain - Linear gain in dB
        %   .TOISpecification - Third-order intercept specification type
        %   Various model-specific parameters (IIP3, OIP3, etc.)
        MemoryLessNonlinearityConfig struct
    end

    properties (GetAccess = public, SetAccess = protected)
        % Read-only handles to the impairment objects wired by setupImpl.
        % Promoted to public read access (set access stays protected) so
        % test harnesses and external consumers can introspect what the
        % factory actually configured (e.g. that IIP3 was written to the
        % IIP3 property and not to OIP3).
        IQImbalance               % Function handle applying iqimbal
        PhaseNoise                % comm.PhaseNoise instance or fast spectral state
        MemoryLessNonlinearity    % comm.MemorylessNonlinearity instance

        % Note: DUC-related properties removed in frequency translation upgrade
        % Legacy properties no longer needed:
        % - InterpolationFactor (replaced by flexible resampling)
        % - DUC (replaced by complex exponential frequency translation)
    end

    properties (Access = private)
        PhaseNoiseSampleRateHz double = NaN
    end

    methods (Access = protected)

        % Note: genDUC method removed - no longer needed with complex exponential approach

        function iqImbalanceHandle = genIqImbalance(obj)
            % genIqImbalance - Generate IQ imbalance function handle
            % 中文说明：genIqImbalance 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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

        function phaseNoiseObject = genPhaseNoise(obj, sampleRateHz)
            % genPhaseNoise - Generate phase noise system object
            % 中文说明：genPhaseNoise 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            if nargin < 2 || isempty(sampleRateHz)
                sampleRateHz = obj.SampleRate;
            end

            backend = char(obj.PhaseNoiseBackend);
            if strcmpi(backend, 'MathWorks')
                phaseNoiseObject = comm.PhaseNoise( ...
                    Level = obj.PhaseNoiseConfig.Level, ...
                    FrequencyOffset = obj.PhaseNoiseConfig.FrequencyOffset, ...
                    SampleRate = sampleRateHz);

                % Configure optional random stream settings for reproducibility
                if isfield(obj.PhaseNoiseConfig, 'RandomStream')

                    if strcmp(obj.PhaseNoiseConfig.RandomStream, 'mt19937ar with seed')
                        phaseNoiseObject.RandomStream = "mt19937ar with seed";
                        phaseNoiseObject.Seed = obj.PhaseNoiseConfig.Seed;
                    end

                end
                return;
            end

            if ~strcmpi(backend, 'FastSpectral')
                error('CSRD:TRF:UnknownPhaseNoiseBackend', ...
                    'PhaseNoiseBackend must be ''FastSpectral'' or ''MathWorks'', got "%s".', ...
                    backend);
            end

            phaseNoiseObject = struct( ...
                'Backend', 'FastSpectral', ...
                'SampleRate', double(sampleRateHz), ...
                'Level', double(obj.PhaseNoiseConfig.Level(:).'), ...
                'FrequencyOffset', double(obj.PhaseNoiseConfig.FrequencyOffset(:).'), ...
                'RandomStream', '', ...
                'Seed', [], ...
                'Stream', []);

            if isfield(obj.PhaseNoiseConfig, 'RandomStream') && ...
                    strcmp(obj.PhaseNoiseConfig.RandomStream, 'mt19937ar with seed')
                if ~isfield(obj.PhaseNoiseConfig, 'Seed') || isempty(obj.PhaseNoiseConfig.Seed)
                    error('CSRD:TRF:MissingPhaseNoiseSeed', ...
                        'PhaseNoiseConfig.Seed is required when RandomStream is mt19937ar with seed.');
                end
                phaseNoiseObject.RandomStream = 'mt19937ar with seed';
                phaseNoiseObject.Seed = double(obj.PhaseNoiseConfig.Seed);
                phaseNoiseObject.Stream = RandStream('mt19937ar', ...
                    'Seed', phaseNoiseObject.Seed);
            end
        end

        function nonlinearityObject = genMemoryLessNonlinearity(obj)
            %GENMEMORYLESSNONLINEARITY Build a comm.MemorylessNonlinearity
            % 中文说明：genMemoryLessNonlinearity 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % System object for the PA stage. The implementation follows
            % the official MATLAB documentation Dependencies table for
            % `comm.MemorylessNonlinearity`: only the property set declared
            % for the chosen Method is written. Unknown Methods fail fast
            % — the v0.4 deep refactor removed the silent "default to
            % Cubic polynomial" fallback.
            %
            % Mirror of csrd.blocks.physical.rxRadioFront.RRFSimulator's
            % genLowerPowerAmplifier so PA and LNA share the same strict
            % build path.

            cfg = obj.MemoryLessNonlinearityConfig;
            if ~isstruct(cfg) || ~isfield(cfg, 'Method')
                error('TRFSimulator:MissingNonlinearityConfig', ...
                    'MemoryLessNonlinearityConfig must contain a Method field.');
            end

            method = cfg.Method;
            switch method
                case 'Cubic polynomial'
                    args = obj.assembleCubicPolynomialArgs(cfg);
                case 'Hyperbolic tangent'
                    args = obj.assembleHyperbolicTangentArgs(cfg);
                case 'Saleh model'
                    args = obj.assembleSalehGhorbaniArgs(cfg, 'Saleh model');
                case 'Ghorbani model'
                    args = obj.assembleSalehGhorbaniArgs(cfg, 'Ghorbani model');
                case 'Modified Rapp model'
                    args = obj.assembleModifiedRappArgs(cfg);
                case 'Lookup table'
                    args = obj.assembleLookupTableArgs(cfg);
                otherwise
                    error('TRFSimulator:UnknownNonlinearityMethod', ...
                        ['Unknown comm.MemorylessNonlinearity Method ' ...
                         '"%s". Supported: Cubic polynomial, Hyperbolic ' ...
                         'tangent, Saleh model, Ghorbani model, Modified ' ...
                         'Rapp model, Lookup table.'], method);
            end

            if ~isfield(cfg, 'ReferenceImpedance') || isempty(cfg.ReferenceImpedance)
                error('TRFSimulator:MissingReferenceImpedance', ...
                    'MemoryLessNonlinearityConfig must contain ReferenceImpedance.');
            end
            args = [args, {'ReferenceImpedance', cfg.ReferenceImpedance}];

            nonlinearityObject = comm.MemorylessNonlinearity(args{:});
        end

        function args = assembleCubicPolynomialArgs(~, cfg)
            % assembleCubicPolynomialArgs - Production declaration in CSRD.
            % 中文说明：assembleCubicPolynomialArgs 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            args = {'Method', 'Cubic polynomial', ...
                'LinearGain', cfg.LinearGain, ...
                'TOISpecification', cfg.TOISpecification};
            switch cfg.TOISpecification
                case 'IIP3',  args = [args, {'IIP3',  cfg.IIP3}];
                case 'OIP3',  args = [args, {'OIP3',  cfg.OIP3}];
                case 'IP1dB', args = [args, {'IP1dB', cfg.IP1dB}];
                case 'OP1dB', args = [args, {'OP1dB', cfg.OP1dB}];
                case 'IPsat', args = [args, {'IPsat', cfg.IPsat}];
                case 'OPsat', args = [args, {'OPsat', cfg.OPsat}];
                otherwise
                    error('TRFSimulator:UnknownTOISpecification', ...
                        'Unknown TOISpecification "%s".', cfg.TOISpecification);
            end
            args = [args, ...
                {'AMPMConversion',  cfg.AMPMConversion, ...
                 'PowerLowerLimit', cfg.PowerLowerLimit, ...
                 'PowerUpperLimit', cfg.PowerUpperLimit}];
        end

        function args = assembleHyperbolicTangentArgs(~, cfg)
            % assembleHyperbolicTangentArgs - Production declaration in CSRD.
            % 中文说明：assembleHyperbolicTangentArgs 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            args = {'Method', 'Hyperbolic tangent', ...
                'LinearGain',      cfg.LinearGain, ...
                'IIP3',            cfg.IIP3, ...
                'AMPMConversion',  cfg.AMPMConversion, ...
                'PowerLowerLimit', cfg.PowerLowerLimit, ...
                'PowerUpperLimit', cfg.PowerUpperLimit};
        end

        function args = assembleSalehGhorbaniArgs(~, cfg, methodName)
            % assembleSalehGhorbaniArgs - Production declaration in CSRD.
            % 中文说明：assembleSalehGhorbaniArgs 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            args = {'Method', methodName, ...
                'InputScaling',  cfg.InputScaling, ...
                'AMAMParameters', cfg.AMAMParameters, ...
                'AMPMParameters', cfg.AMPMParameters, ...
                'OutputScaling',  cfg.OutputScaling};
        end

        function args = assembleModifiedRappArgs(~, cfg)
            % assembleModifiedRappArgs - Production declaration in CSRD.
            % 中文说明：assembleModifiedRappArgs 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            args = {'Method', 'Modified Rapp model', ...
                'LinearGain',            cfg.LinearGain, ...
                'Smoothness',            cfg.Smoothness, ...
                'PhaseGainRadian',       cfg.PhaseGainRadian, ...
                'PhaseSaturation',       cfg.PhaseSaturation, ...
                'PhaseSmoothness',       cfg.PhaseSmoothness, ...
                'OutputSaturationLevel', cfg.OutputSaturationLevel};
        end

        function args = assembleLookupTableArgs(~, cfg)
            % assembleLookupTableArgs - Production declaration in CSRD.
            % 中文说明：assembleLookupTableArgs 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            if ~isfield(cfg, 'Table') || isempty(cfg.Table) || size(cfg.Table, 2) ~= 3
                error('TRFSimulator:InvalidLookupTable', ...
                    ['Lookup table requires an Nx3 [Pin_dBm, Pout_dBm, ' ...
                     'dPhi_deg] matrix; the supplied Table is missing or ' ...
                     'has the wrong shape.']);
            end
            args = {'Method', 'Lookup table', 'Table', cfg.Table};
        end

        function setupImpl(obj, ~)
            % setupImpl - Initialize transmitter radio front-end system components
            % 中文说明：setupImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Sets up all necessary RF impairment models and system objects for
            % the transmitter chain. This method is called automatically when
            % the system object is first used and configures:
            %   - IQ imbalance function handle
            %   - Phase noise system object
            %   - Memoryless nonlinearity system object

            % Initialize RF impairment models
            obj.IQImbalance = obj.genIqImbalance;
            obj.PhaseNoise = obj.genPhaseNoise(obj.SampleRate);
            obj.PhaseNoiseSampleRateHz = obj.SampleRate;
            obj.MemoryLessNonlinearity = obj.genMemoryLessNonlinearity;
        end

        function translatedSignal = frequencyTranslate(obj, inputSignal, targetFrequency, signalSampleRate)
            % frequencyTranslate - Apply complex exponential frequency translation
            % 中文说明：frequencyTranslate 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % 中文说明：resampleToTarget 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            %   Uses rational resampling only when the resolved P/Q reaches
            %   the target rate within the runtime truth tolerance. A failed
            %   conversion is a hard error because the downstream time grid
            %   and annotations are defined at TargetSampleRate.
            %
            % Performance Optimization:
            %   - No resampling when input rate equals target rate
            %   - Efficient rational resampling using resample() function
            %   - Column-wise processing for multi-antenna signals

            if ~isnumeric(inputSampleRate) || ~isscalar(inputSampleRate) || ...
                    ~isfinite(inputSampleRate) || inputSampleRate <= 0
                error('CSRD:TRF:InvalidInputSampleRate', ...
                    'inputSampleRate must be a positive finite scalar.');
            end
            targetSampleRate = obj.TargetSampleRate;
            if ~isnumeric(targetSampleRate) || ~isscalar(targetSampleRate) || ...
                    ~isfinite(targetSampleRate) || targetSampleRate <= 0
                error('CSRD:TRF:InvalidTargetSampleRate', ...
                    'TargetSampleRate must be a positive finite scalar.');
            end

            relRateDelta = abs(inputSampleRate - targetSampleRate) / targetSampleRate;
            if relRateDelta <= 1e-12
                resampledSignal = inputSignal;
            else
                conversionRatio = targetSampleRate / inputSampleRate;
                [upsampleFactor, downsampleFactor] = rat(conversionRatio, 1e-12);
                actualOutputRate = inputSampleRate * upsampleFactor / downsampleFactor;
                rateError = abs(actualOutputRate - targetSampleRate) / targetSampleRate;
                if rateError > 1e-9
                    error('CSRD:TRF:ResampleRatioError', ...
                        ['Resolved resample P/Q=%d/%d gives %.12g Hz vs target ', ...
                         '%.12g Hz (relative error %.3g).'], ...
                        upsampleFactor, downsampleFactor, actualOutputRate, ...
                        targetSampleRate, rateError);
                end

                maxFactor = 50000;
                if upsampleFactor > maxFactor || downsampleFactor > maxFactor
                    error('CSRD:TRF:UnsupportedResampleRatio', ...
                        ['Exact resample ratio %d/%d exceeds the supported ', ...
                         'rational factor limit %d. Use an explicit upstream ', ...
                         'sample-rate plan with a tractable rational ratio.'], ...
                        upsampleFactor, downsampleFactor, maxFactor);
                end

                % MATLAB resample operates along the first dimension for
                % normal matrix inputs, treating columns as independent
                % channels. A 1-by-N short-frame matrix is a special case:
                % resample treats it as one row vector and expands the
                % antenna axis, so preserve the columns explicitly there.
                if size(inputSignal, 1) == 1
                    resampledSignal = resampleOneSampleAntennaMatrix( ...
                        inputSignal, upsampleFactor, downsampleFactor);
                else
                    resampledSignal = resample(inputSignal, ...
                        upsampleFactor, downsampleFactor);
                end

            end

        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Process input signal through complete transmitter RF chain
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Executes the complete transmitter radio front-end processing chain
            % including RF impairments, sample rate conversion, and complex
            % exponential frequency translation. This is the main processing method called
            % when the system object is used as a function.
            %
            % Processing Chain:
            %   1. Apply IQ imbalance to simulate quadrature demodulator imperfections
            %   2. Add DC offset to model transmitter bias and LO leakage
            %   3. Apply phase noise to simulate oscillator phase noise
            %   4. Apply memoryless nonlinearity to model power amplifier characteristics
            %   5. Resample to target sample rate if needed
            %   6. Perform complex exponential frequency translation
            %   7. Apply final power scaling
            %
            % Syntax:
            %   outputSignal = stepImpl(obj, inputSignal)
            %
            % Input Arguments:
            %   inputSignal - Input structure containing:
            %     .Signal - Baseband IQ signal data [samples x antennas]
            %     .FrequencyOffset - Target carrier frequency offset (Hz) [optional]
            %     .SampleRate - Input sample rate (Hz) [optional]
            %
            % Output Arguments:
            %   outputSignal - Output structure containing:
            %     .Signal - Processed RF signal [samples x antennas]
            %     .FrequencyOffset - Applied carrier frequency offset (Hz)
            %     .SampleRate - Output sample rate (Hz)
            %     .Bandwidth - Signal bandwidth (Hz)
            %     .TxPower - Transmission power (dBm)
            %
            % Example:
            %   % Create input signal structure
            %   input.Signal = randn(1024, 2) + 1j*randn(1024, 2);  % 2-antenna signal
            %   input.FrequencyOffset = 2.4e9;  % 2.4 GHz carrier
            %   input.SampleRate = 20e6;         % 20 MHz sample rate
            %
            %   % Process through transmitter
            %   output = trf(input);

            % Direct signal array input - use object properties
            basebandData = inputSignal;
            carrierFreq = obj.CarrierFrequency;
            inputSampleRate = obj.SampleRate;
            traceMeta = struct( ...
                'InputSamples', size(basebandData, 1), ...
                'InputColumns', size(basebandData, 2), ...
                'InputSampleRate', double(inputSampleRate), ...
                'TargetSampleRate', double(obj.TargetSampleRate), ...
                'CarrierFrequency', double(carrierFreq));

            % Step 1: Apply IQ imbalance to simulate quadrature imperfections
            stageStart = tic;
            processedSignal = obj.IQImbalance(basebandData);
            csrd.runtime.performance.trace('event', 'TRF.IQImbalance', ...
                toc(stageStart), traceMeta);

            % Step 2: Add DC offset to model transmitter bias and LO leakage
            stageStart = tic;
            processedSignal = processedSignal + 10 ^ (obj.DCOffset / 10);
            csrd.runtime.performance.trace('event', 'TRF.DCOffset', ...
                toc(stageStart), traceMeta);

            % Step 3: Apply oscillator phase noise on the current baseband grid.
            % 中文说明：PhaseNoise 与当前信号采样网格绑定；不要每帧重建，也不要为了
            % “看起来统一”强行搬到目标采样率，实测会显著增加短帧 setup 成本。
            obj.ensurePhaseNoiseSampleRate(inputSampleRate);
            stageStart = tic;
            processedSignal = obj.applyPhaseNoise(processedSignal);
            phaseMeta = traceMeta;
            phaseMeta.InputSamples = size(processedSignal, 1);
            phaseMeta.InputSampleRate = double(inputSampleRate);
            csrd.runtime.performance.trace('event', 'TRF.PhaseNoise', ...
                toc(stageStart), phaseMeta);

            % Step 4: Apply memoryless nonlinearity to model power amplifier characteristics
            stageStart = tic;
            processedSignal = obj.applyMemorylessNonlinearity(processedSignal);
            csrd.runtime.performance.trace('event', 'TRF.MemorylessNonlinearity', ...
                toc(stageStart), traceMeta);

            % Step 5: Resample to the receiver observation rate.
            % 中文说明：先升采样到接收机观测采样率，避免高频点在调制器低采样率下混叠。
            stageStart = tic;
            resampledSignal = obj.resampleToTarget(processedSignal, inputSampleRate);
            resampleMeta = traceMeta;
            resampleMeta.OutputSamples = size(resampledSignal, 1);
            csrd.runtime.performance.trace('event', 'TRF.ResampleToTarget', ...
                toc(stageStart), resampleMeta);

            % Step 6: Translate on the target-rate grid used by ReceiverView.
            % 中文说明：频移必须在 TargetSampleRate 网格上执行，才能与标注中的频点一致。
            stageStart = tic;
            frequencyTranslatedSignal = obj.frequencyTranslate( ...
                resampledSignal, carrierFreq, obj.TargetSampleRate);
            translateMeta = traceMeta;
            translateMeta.InputSamples = size(resampledSignal, 1);
            csrd.runtime.performance.trace('event', 'TRF.FrequencyTranslate', ...
                toc(stageStart), translateMeta);

            % Step 7: Apply final power scaling to achieve desired transmission power
            stageStart = tic;
            signalDuration = size(frequencyTranslatedSignal, 1) / obj.TargetSampleRate;
            signalPower = mean(abs(frequencyTranslatedSignal(:)) .^ 2);

            % Convert dBm to linear power (Watts) and calculate scaling factor
            targetPowerWatts = 10 ^ (obj.TxPowerDb / 10) / 1000; % Convert dBm to Watts
            if signalPower > eps
                scalingFactor = sqrt(targetPowerWatts / signalPower);
            else
                scalingFactor = 1;
            end
            finalSignal = frequencyTranslatedSignal * scalingFactor;
            powerMeta = traceMeta;
            powerMeta.OutputSamples = size(finalSignal, 1);
            powerMeta.SignalDurationSec = signalDuration;
            csrd.runtime.performance.trace('event', 'TRF.PowerScaling', ...
                toc(stageStart), powerMeta);

            outputSignal = finalSignal;

        end

        function outputSignal = applyPhaseNoise(obj, inputSignal)
            % applyPhaseNoise - Apply configured oscillator phase noise backend.
            if isa(obj.PhaseNoise, 'matlab.System')
                outputSignal = obj.PhaseNoise(inputSignal);
                return;
            end

            outputSignal = obj.applyFastSpectralPhaseNoise(inputSignal);
        end

        function outputSignal = applyMemorylessNonlinearity(obj, inputSignal)
            % applyMemorylessNonlinearity - Apply PA model per antenna column.
            %
            % comm.MemorylessNonlinearity is physically memoryless. Applying it
            % column-by-column is equivalent for independent antenna streams and
            % avoids a MATLAB internal matrix-input path that can throw
            % "left and right sides have a different number of elements" for
            % some Saleh/Ghorbani/Rapp configurations.
            if size(inputSignal, 2) <= 1
                outputSignal = obj.MemoryLessNonlinearity(inputSignal);
                return;
            end

            outputSignal = zeros(size(inputSignal), 'like', inputSignal);
            for col = 1:size(inputSignal, 2)
                outputSignal(:, col) = obj.MemoryLessNonlinearity(inputSignal(:, col));
            end
        end

        function outputSignal = applyFastSpectralPhaseNoise(obj, inputSignal)
            % applyFastSpectralPhaseNoise - Fast PSD-mask phase noise synthesis.
            %
            % MathWorks comm.PhaseNoise models y_k = x_k exp(j phi_k), where
            % phi_k is filtered Gaussian noise following the configured phase
            % noise mask. For CSRD short frames, the official System object can
            % spend minutes priming FIR/cascade filters for each sample-rate and
            % channel shape. This implementation keeps the same exported RF
            % contract by synthesizing phi_k directly in the frequency domain
            % from the dBc/Hz mask, then applying exp(j phi_k).
            numSamples = size(inputSignal, 1);
            numChannels = size(inputSignal, 2);
            if numSamples == 0 || numChannels == 0
                outputSignal = inputSignal;
                return;
            end

            phaseState = obj.PhaseNoise;
            sampleRateHz = double(phaseState.SampleRate);
            levelsDbcHz = double(phaseState.Level(:));
            offsetsHz = double(phaseState.FrequencyOffset(:));
            obj.validateFastPhaseNoiseMask(levelsDbcHz, offsetsHz, sampleRateHz);

            positiveBins = floor(numSamples / 2);
            spectrum = complex(zeros(numSamples, numChannels));

            if positiveBins >= 1
                binIdx = (2:(positiveBins + 1)).';
                freqsHz = (binIdx - 1) * sampleRateHz / numSamples;
                twoSidedPsd = obj.phaseNoiseTwoSidedPsd( ...
                    freqsHz, offsetsHz, levelsDbcHz);
                sigma = sqrt(twoSidedPsd * sampleRateHz * numSamples);
                noiseSpec = obj.randnLikePhaseNoise(numel(binIdx), numChannels);
                spectrum(binIdx, :) = sigma .* noiseSpec;

                mirrorIdx = numSamples - binIdx + 2;
                validMirror = mirrorIdx >= 1 & mirrorIdx <= numSamples & ...
                    mirrorIdx ~= binIdx;
                spectrum(mirrorIdx(validMirror), :) = ...
                    conj(spectrum(binIdx(validMirror), :));
            end

            if mod(numSamples, 2) == 0
                nyquistIdx = numSamples / 2 + 1;
                nyquistFreq = sampleRateHz / 2;
                twoSidedPsd = obj.phaseNoiseTwoSidedPsd( ...
                    nyquistFreq, offsetsHz, levelsDbcHz);
                sigma = sqrt(twoSidedPsd * sampleRateHz * numSamples);
                spectrum(nyquistIdx, :) = sigma .* ...
                    obj.randnLikePhaseNoise(1, numChannels, true);
            end

            phaseRad = real(ifft(spectrum, [], 1));
            outputSignal = inputSignal .* exp(1j * phaseRad);
        end

        function noiseValues = randnLikePhaseNoise(obj, numRows, numCols, realOnly)
            if nargin < 4
                realOnly = false;
            end
            phaseState = obj.PhaseNoise;
            if isstruct(phaseState) && isfield(phaseState, 'Stream') && ...
                    ~isempty(phaseState.Stream)
                if realOnly
                    noiseValues = randn(phaseState.Stream, numRows, numCols);
                else
                    noiseValues = (randn(phaseState.Stream, numRows, numCols) + ...
                        1j * randn(phaseState.Stream, numRows, numCols)) / sqrt(2);
                end
            else
                if realOnly
                    noiseValues = randn(numRows, numCols);
                else
                    noiseValues = (randn(numRows, numCols) + ...
                        1j * randn(numRows, numCols)) / sqrt(2);
                end
            end
        end

        function validateFastPhaseNoiseMask(~, levelsDbcHz, offsetsHz, sampleRateHz)
            if isempty(levelsDbcHz) || isempty(offsetsHz) || ...
                    numel(levelsDbcHz) ~= numel(offsetsHz)
                error('CSRD:TRF:InvalidPhaseNoiseMask', ...
                    'PhaseNoise Level and FrequencyOffset must be nonempty vectors of equal length.');
            end
            if any(~isfinite(levelsDbcHz)) || any(levelsDbcHz >= 0)
                error('CSRD:TRF:InvalidPhaseNoiseLevel', ...
                    'PhaseNoise Level values must be finite negative dBc/Hz values.');
            end
            if any(~isfinite(offsetsHz)) || any(offsetsHz <= 0) || ...
                    any(diff(offsetsHz) <= 0)
                error('CSRD:TRF:InvalidPhaseNoiseOffset', ...
                    'PhaseNoise FrequencyOffset values must be positive and strictly increasing.');
            end
            if sampleRateHz <= 2 * max(offsetsHz)
                error('CSRD:TRF:InvalidPhaseNoiseSampleRate', ...
                    ['PhaseNoise SampleRate %.15g Hz must be greater than ', ...
                     'two times the maximum FrequencyOffset %.15g Hz.'], ...
                    sampleRateHz, max(offsetsHz));
            end
        end

        function twoSidedPsd = phaseNoiseTwoSidedPsd(~, freqsHz, offsetsHz, levelsDbcHz)
            freqsHz = max(double(freqsHz), eps);
            if numel(offsetsHz) == 1
                % Scalar masks use the documented 1/f characteristic that
                % passes through the configured offset/level point.
                levelsAtFreq = levelsDbcHz(1) - ...
                    10 * log10(freqsHz ./ offsetsHz(1));
                twoSidedPsd = 10 .^ (levelsAtFreq ./ 10);
                return;
            end

            levelsAtFreq = interp1(log10(offsetsHz), levelsDbcHz, ...
                log10(freqsHz), 'linear', 'extrap');

            below = freqsHz < offsetsHz(1);
            if any(below)
                % Match the documented low-frequency 1/f^3 behavior below
                % the smallest mask point until the discrete frame resolution.
                levelsAtFreq(below) = levelsDbcHz(1) - ...
                    30 * log10(freqsHz(below) ./ offsetsHz(1));
            end

            above = freqsHz > offsetsHz(end);
            if any(above)
                levelsAtFreq(above) = levelsDbcHz(end);
            end

            % SSB phase noise L(f) relates to phase PSD by
            % S_phi_one_sided(f) ~= 2*10^(L/10). The two-sided PSD used by
            % the FFT synthesis is therefore 10^(L/10) rad^2/Hz.
            twoSidedPsd = 10 .^ (levelsAtFreq ./ 10);
        end

        function ensurePhaseNoiseSampleRate(obj, inputSampleRate)
            % ensurePhaseNoiseSampleRate - Keep phase noise object on active grid.
            % 中文说明：PhaseNoise 的 SampleRate 必须跟当前处理网格一致，且不能每帧重建。
            if isempty(obj.PhaseNoise) || ...
                    ~isfinite(obj.PhaseNoiseSampleRateHz) || ...
                    abs(obj.PhaseNoiseSampleRateHz - inputSampleRate) > ...
                        max(1e-9, 1e-12 * inputSampleRate)
                if ~isempty(obj.PhaseNoise) && isa(obj.PhaseNoise, 'matlab.System') && ...
                        isLocked(obj.PhaseNoise)
                    release(obj.PhaseNoise);
                end
                obj.PhaseNoise = obj.genPhaseNoise(inputSampleRate);
                obj.PhaseNoiseSampleRateHz = inputSampleRate;
            end
        end

    end

    methods

        function obj = TRFSimulator(varargin)
            % TRFSimulator - Constructor for transmitter radio front-end simulator
            % 中文说明：TRFSimulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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

function y = resampleOneSampleAntennaMatrix(x, upsampleFactor, downsampleFactor)
%RESAMPLEONESAMPLEANTENNAMATRIX Preserve antenna columns for 1-sample frames.
% MATLAB resample treats a 1-by-N matrix as one row-vector channel. In this
% edge case, resample each antenna stream independently so the output remains
% samples-by-antennas for downstream channel objects.

    numAntennas = size(x, 2);
    firstColumn = resample(x(:, 1), upsampleFactor, downsampleFactor);
    firstColumn = firstColumn(:);
    y = zeros(numel(firstColumn), numAntennas, 'like', firstColumn);
    y(:, 1) = firstColumn;
    for colIdx = 2:numAntennas
        resampledColumn = resample(x(:, colIdx), ...
            upsampleFactor, downsampleFactor);
        y(:, colIdx) = resampledColumn(:);
    end
end
