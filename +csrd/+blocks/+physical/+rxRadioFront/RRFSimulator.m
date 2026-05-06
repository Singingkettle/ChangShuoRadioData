classdef RRFSimulator < matlab.System
    % RRFSimulator: Radio Receiver Front-end Simulator
    % 中文说明：提供 CSRD 生产链路中的 RRFSimulator 实现。
    %
    % Models the receiver-side RF chain that is currently implemented.
    % Today the actively connected stages, in order, are:
    %   1. Low-noise amplifier nonlinearity (comm.MemorylessNonlinearity)
    %   2. Thermal noise (comm.ThermalNoise)
    %   3. IQ imbalance (iqimbal)
    %   4. ADC sample-rate offset in ppm (comm.SampleRateOffset)
    %
    % Stages historically declared but never wired (phase noise, AGC,
    % bandpass filter, Doppler frequency shifter) have been removed from
    % this class so that the documented capabilities match the runtime
    % behaviour. Re-enable them only after they are integrated into
    % stepImpl with proper validation.

    properties
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0 % Start time of simulation in seconds
        DecimationFactor (1, 1) {mustBePositive, mustBeReal} = 1 % Decimation factor
        NumAntennas (1, 1) {mustBePositive, mustBeReal} = 1 % Number of receive antennas (canonical name; matches RxInfo.NumAntennas)
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e6 % Receiver bandwidth in Hz (updated default)
        CenterFrequency (1, 1) {mustBeReal, mustBeInteger} = 0 % Center frequency in Hz (now allows 0 for baseband-centric)
        SampleRateOffset (1, 1) {mustBeReal} = 0 % ADC clock offset in parts per million (ppm)
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1 % Total simulation duration in seconds
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 20e6 % Master clock rate in Hz (updated default)
        DCOffset {mustBeReal} = -50 % DC offset in dB

        UseReceiverCentricMode (1, 1) logical = true % Use new frequency allocation approach

        SiteConfig struct % Configuration for receiver site parameters
        IqImbalanceConfig struct % Configuration for IQ imbalance parameters
        MemoryLessNonlinearityConfig struct % Configuration for nonlinearity parameters
        ThermalNoiseConfig struct % Configuration for thermal noise parameters
    end

    properties (GetAccess = public, SetAccess = protected)
        % Read-only handles to the actually-connected impairment objects.
        LowerPowerAmplifier % comm.MemorylessNonlinearity instance
        ThermalNoise        % comm.ThermalNoise instance
        IQImbalance         % function handle applying iqimbal
        SampleShifter       % comm.SampleRateOffset instance
        SampleRateOffsetInfo struct = struct()
    end

    properties (Access = private)
        ThermalNoiseSampleRateHz double = NaN
        ThermalNoiseTemperatureK double = NaN
        SampleShifterOffsetPpm double = NaN
    end

    methods (Access = private)

        function IQImbalance = genIqImbalance(obj)
            % Generates IQ imbalance function handle
            % 中文说明：genIqImbalance 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Returns:
            %   IQImbalance: Function handle that applies amplitude (A) and phase (P) imbalance
            %                to the input signal using the iqimbal function
            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
        end

        function LowerNoiseAmplifier = genLowerPowerAmplifier(obj)
            %GENLOWERPOWERAMPLIFIER Build a comm.MemorylessNonlinearity
            % 中文说明：genLowerPowerAmplifier 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % System object for the LNA stage. The implementation follows
            % the official MATLAB documentation Dependencies table for
            % `comm.MemorylessNonlinearity`: each Method only has its
            % declared properties set, in one shot via name=value, so the
            % System object never sees off-Method writes. Unknown Methods
            % fail fast — the v0.4 deep refactor removed the silent
            % "default to Cubic polynomial" fallback.

            cfg = obj.MemoryLessNonlinearityConfig;
            if ~isstruct(cfg) || ~isfield(cfg, 'Method')
                error('RRFSimulator:MissingNonlinearityConfig', ...
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
                    error('RRFSimulator:UnknownNonlinearityMethod', ...
                        ['Unknown comm.MemorylessNonlinearity Method ' ...
                         '"%s". Supported: Cubic polynomial, Hyperbolic ' ...
                         'tangent, Saleh model, Ghorbani model, Modified ' ...
                         'Rapp model, Lookup table.'], method);
            end

            if ~isfield(cfg, 'ReferenceImpedance') || isempty(cfg.ReferenceImpedance)
                error('RRFSimulator:MissingReferenceImpedance', ...
                    'MemoryLessNonlinearityConfig must contain ReferenceImpedance.');
            end
            args = [args, {'ReferenceImpedance', cfg.ReferenceImpedance}];

            LowerNoiseAmplifier = comm.MemorylessNonlinearity(args{:});
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
                    error('RRFSimulator:UnknownTOISpecification', ...
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
                error('RRFSimulator:InvalidLookupTable', ...
                    ['Lookup table requires an Nx3 [Pin_dBm, Pout_dBm, ' ...
                     'dPhi_deg] matrix; the supplied Table is missing or ' ...
                     'has the wrong shape.']);
            end
            args = {'Method', 'Lookup table', 'Table', cfg.Table};
        end

        function ThermalNoise = genThermalNoise(obj)
            % Generates thermal noise object with specified parameters
            % 中文说明：genThermalNoise 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Returns:
            %   ThermalNoise: Configured thermal noise generator object
            ThermalNoise = comm.ThermalNoise( ...
                NoiseMethod = "Noise temperature", ...
                NoiseTemperature = obj.ThermalNoiseConfig.NoiseTemperature, ...
                SampleRate = obj.MasterClockRate);
        end

        function SampleShifter = genSampleShifter(obj)
            % Generates the ADC sample-rate-offset object.
            % 中文说明：genSampleShifter 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Offset is in ppm (parts per million); 0 ppm is a no-op
            % (identity) and therefore safe to instantiate unconditionally.
            SampleShifter = comm.SampleRateOffset( ...
                Offset = obj.SampleRateOffset);
        end

        function ensureThermalNoiseObject(obj)
            noiseTemperature = obj.ThermalNoiseConfig.NoiseTemperature;
            needsObject = isempty(obj.ThermalNoise) || ...
                ~isa(obj.ThermalNoise, 'comm.ThermalNoise') || ...
                obj.ThermalNoiseSampleRateHz ~= obj.MasterClockRate || ...
                obj.ThermalNoiseTemperatureK ~= noiseTemperature;

            if ~needsObject
                return;
            end

            if isa(obj.ThermalNoise, 'matlab.System') && isLocked(obj.ThermalNoise)
                release(obj.ThermalNoise);
            end
            obj.ThermalNoise = obj.genThermalNoise();
            obj.ThermalNoiseSampleRateHz = obj.MasterClockRate;
            obj.ThermalNoiseTemperatureK = noiseTemperature;
        end

        function ensureSampleShifterObject(obj)
            offsetPpm = double(obj.SampleRateOffset);
            if offsetPpm == 0
                if isa(obj.SampleShifter, 'matlab.System') && isLocked(obj.SampleShifter)
                    release(obj.SampleShifter);
                end
                obj.SampleShifter = [];
                obj.SampleShifterOffsetPpm = 0;
                return;
            end

            needsObject = isempty(obj.SampleShifter) || ...
                ~isa(obj.SampleShifter, 'comm.SampleRateOffset') || ...
                obj.SampleShifterOffsetPpm ~= offsetPpm;
            if ~needsObject
                return;
            end

            if isa(obj.SampleShifter, 'matlab.System') && isLocked(obj.SampleShifter)
                release(obj.SampleShifter);
            end
            obj.SampleShifter = obj.genSampleShifter();
            obj.SampleShifterOffsetPpm = offsetPpm;
        end

    end

    methods

        function obj = RRFSimulator(varargin)
            % Constructor for RRFSimulator
            % 中文说明：RRFSimulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % Args:
            %   varargin: Name-value pairs for setting object properties
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj, ~)
            % setupImpl - Production declaration in CSRD.
            % 中文说明：setupImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier;
            obj.IQImbalance = obj.genIqImbalance;
            obj.ensureThermalNoiseObject();
            obj.ensureSampleShifterObject();
        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Apply receiver RF impairments to a pre-combined signal.
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Signal combination is performed upstream in
            % processReceiverProcessing. The active impairment chain is:
            %   1. LNA nonlinearity (comm.MemorylessNonlinearity)
            %   2. Thermal noise   (comm.ThermalNoise)
            %   3. IQ imbalance    (iqimbal)
            %   4. ADC sample-rate offset (comm.SampleRateOffset, ppm)
            %
            % comm.SampleRateOffset is constructed only for non-zero ppm.
            % The 0 ppm path is an exact identity fast path; non-zero
            % offsets may change the output length by one sample (Farrow
            % filter) and are recorded in SampleRateOffsetInfo.
            %
            % Args:
            %   inputSignal: Pre-combined numeric signal array [samples x antennas]
            % Returns:
            %   outputSignal: Signal array after the impairment chain.

            x = obj.LowerPowerAmplifier(inputSignal);

            obj.ensureThermalNoiseObject();
            xAwgn = obj.ThermalNoise(x);

            xIq = obj.IQImbalance(xAwgn);

            obj.ensureSampleShifterObject();
            if obj.SampleRateOffset == 0
                outputSignal = xIq;
                action = 'identity';
                applied = false;
            else
                outputSignal = obj.SampleShifter(xIq);
                action = 'sample-rate-offset';
                applied = true;
            end
            obj.SampleRateOffsetInfo = struct( ...
                'Applied', applied, ...
                'OffsetPpm', double(obj.SampleRateOffset), ...
                'InputSamples', size(xIq, 1), ...
                'OutputSamples', size(outputSignal, 1), ...
                'Action', action);
        end

    end

end
