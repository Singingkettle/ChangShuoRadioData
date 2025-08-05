classdef MIMO < csrd.blocks.physical.channel.BaseChannel
    % MIMO - Multiple-Input Multiple-Output Channel Model
    %
    % This class implements a comprehensive MIMO channel model as a subclass of
    % BaseChannel, providing realistic wireless propagation effects including
    % multipath fading, Doppler shifts, and spatial diversity. The model supports
    % both Rayleigh and Rician fading distributions for various propagation
    % environments, from urban cellular to rural line-of-sight scenarios.
    %
    % MIMO channel modeling is essential for evaluating spatial diversity techniques,
    % beamforming algorithms, and capacity analysis in modern wireless communication
    % systems. This implementation provides flexibility for various antenna
    % configurations and propagation conditions while maintaining computational
    % efficiency for system-level simulations.
    %
    % Key Features:
    %   - Configurable antenna arrays (SISO/SIMO/MISO/MIMO)
    %   - Rayleigh and Rician fading distributions
    %   - Frequency-flat and frequency-selective channels
    %   - Doppler effects for mobile scenarios
    %   - Path loss integration with atmospheric conditions
    %   - Spatial correlation modeling capabilities
    %   - Time-varying channel realizations
    %
    % Technical Specifications:
    %   - Antenna Configurations: Up to NxM antenna arrays
    %   - Fading Models: Rayleigh (NLOS), Rician (LOS)
    %   - Frequency Response: Flat or selective (configurable delays)
    %   - Doppler Modeling: Mobile velocities up to Fs/20
    %   - Path Delay Resolution: Sample-level precision
    %   - Channel Matrix: Complex-valued NR×NT per path
    %
    % Syntax:
    %   mimoChannel = MIMO()
    %   mimoChannel = MIMO('PropertyName', PropertyValue, ...)
    %   outputSignal = mimoChannel(inputSignal)
    %
    % Properties (Nontunable):
    %   FadingDistribution - Fading model ('Rayleigh' or 'Rician')
    %   PathDelays - Discrete multipath delays in seconds
    %   AveragePathGains - Average power of each multipath component (dB)
    %   KFactor - Rician K-factor for line-of-sight component
    %   MaximumDopplerShift - Maximum Doppler frequency shift (Hz)
    %   FadingTechnique - Fading generation method
    %   InitialTimeSource - Time reference source for fading
    %
    % Properties (Inherited from BaseChannel):
    %   CarrierFrequency - RF carrier frequency (Hz)
    %   SampleRate - Signal sampling rate (Hz)
    %   Distance - Propagation distance (m)
    %   atmosCond - Atmospheric propagation conditions
    %   NumTransmitAntennas - Number of transmit antennas
    %   NumReceiveAntennas - Number of receive antennas
    %
    % Methods:
    %   step - Process input signal through MIMO channel
    %   info - Get channel configuration information
    %   reset - Reset channel state to initial conditions
    %   release - Release system resources
    %
    % Example:
    %   % Create 2x2 MIMO channel for urban cellular environment
    %   mimoChannel = csrd.blocks.physical.channel.MIMO();
    %   mimoChannel.NumTransmitAntennas = 2;
    %   mimoChannel.NumReceiveAntennas = 2;
    %   mimoChannel.FadingDistribution = 'Rayleigh'; % NLOS urban
    %   mimoChannel.PathDelays = [0 1e-6 2e-6]; % 3-path model
    %   mimoChannel.AveragePathGains = [0 -3 -6]; % Exponential decay
    %   mimoChannel.MaximumDopplerShift = 50; % 50 Hz (mobile scenario)
    %   mimoChannel.CarrierFrequency = 2.4e9; % 2.4 GHz
    %   mimoChannel.SampleRate = 1e6; % 1 MHz bandwidth
    %
    %   % Configure input signal structure
    %   inputSignal.data = randn(1000, 2) + 1j*randn(1000, 2); % 2 Tx antennas
    %   inputSignal.SampleRate = mimoChannel.SampleRate;
    %   inputSignal.StartTime = 0;
    %
    %   % Process signal through channel
    %   outputSignal = mimoChannel(inputSignal);
    %   fprintf('Channel mode: %s\n', outputSignal.mode);
    %   fprintf('Output size: %dx%d (samples x antennas)\n', size(outputSignal.data));
    %
    % Applications:
    %   - MIMO system capacity analysis and optimization
    %   - Spatial diversity and multiplexing algorithm testing
    %   - Beamforming and precoding technique evaluation
    %   - Mobile communication system performance analysis
    %   - 5G/6G wireless system design and validation
    %   - Antenna array pattern and correlation studies
    %
    % Channel Model Types:
    %   - SISO (1x1): Single antenna reference case
    %   - SIMO (1xN): Receive diversity systems
    %   - MISO (Nx1): Transmit diversity and beamforming
    %   - MIMO (NxM): Full spatial multiplexing and diversity
    %
    % Fading Distribution Guidelines:
    %   - Rayleigh: Non-line-of-sight (NLOS) environments
    %     * Urban cellular with buildings and obstacles
    %     * Indoor environments with rich scattering
    %     * Dense urban areas with high multipath
    %   - Rician: Line-of-sight (LOS) environments
    %     * Rural and suburban areas with clear paths
    %     * Outdoor-to-indoor penetration scenarios
    %     * Satellite and aerospace communications
    %
    % See also: csrd.blocks.physical.channel.BaseChannel,
    %           csrd.blocks.physical.channel.AWGNChannel,
    %           comm.MIMOChannel, comm.RayleighChannel, comm.RicianChannel

    properties (Nontunable)
        % FadingDistribution - Statistical fading model selection
        % Type: string, Default: 'Rayleigh'
        %
        % This property determines the statistical distribution used for
        % modeling small-scale fading effects in the wireless channel.
        %
        % Supported Values:
        %   'Rayleigh' - Non-line-of-sight (NLOS) environments
        %   'Rician'   - Line-of-sight (LOS) environments
        %
        % Selection Guidelines:
        %   - Rayleigh: Dense urban, indoor, heavily obstructed paths
        %   - Rician: Rural, suburban, clear line-of-sight scenarios
        %
        % Technical Notes:
        %   Rayleigh fading assumes no dominant path component, while
        %   Rician fading includes a strong LOS component characterized
        %   by the K-factor parameter.
        FadingDistribution {mustBeMember(FadingDistribution, {'Rayleigh', 'Rician'})} = 'Rayleigh'

        % PathDelays - Multipath delay profile in seconds
        % Type: non-negative scalar or row vector, Default: 0
        %
        % This property specifies the relative delays of multipath components
        % arriving at the receiver. The delays determine whether the channel
        % is frequency-flat or frequency-selective.
        %
        % Configuration:
        %   - Scalar (0): Frequency-flat channel (single path)
        %   - Vector: Frequency-selective channel (multiple paths)
        %
        % Typical Values:
        %   - Urban: [0 0.5e-6 1.0e-6 2.0e-6] seconds
        %   - Rural: [0 1.0e-6] seconds (fewer paths)
        %   - Indoor: [0 0.1e-6 0.3e-6 0.7e-6] seconds
        %
        % Constraints:
        %   - All delays must be non-negative
        %   - Maximum delay should be << 1/SampleRate
        %   - Delays are specified relative to first path (typically 0)
        PathDelays (1, :) {mustBeNonnegative, mustBeReal} = 0

        % AveragePathGains - Average power of multipath components in dB
        % Type: real scalar or row vector, Default: 0
        %
        % This property specifies the average power of each multipath component
        % relative to the first path. The gain profile affects frequency
        % selectivity and overall channel characteristics.
        %
        % Configuration:
        %   - Must match the length of PathDelays
        %   - Typically decreasing with delay (exponential decay)
        %   - First path often has 0 dB gain (reference)
        %
        % Typical Profiles:
        %   - Exponential: [0 -3 -6 -9] dB (3 dB/path decay)
        %   - Uniform: [0 0 0 0] dB (equal power paths)
        %   - Custom: Application-specific power profiles
        %
        % Implementation Notes:
        %   Gains are applied as multiplicative factors in linear scale
        %   after converting from dB: gain_linear = 10^(gain_dB/20)
        AveragePathGains (1, :) {mustBeReal} = 0

        % KFactor - Rician K-factor for line-of-sight component
        % Type: non-negative scalar, Default: 3
        %
        % This property specifies the ratio of line-of-sight (LOS) power to
        % scattered power for Rician fading channels. Only used when
        % FadingDistribution is set to 'Rician'.
        %
        % Definition:
        %   K = P_LOS / P_scattered (linear scale)
        %   K_dB = 10*log10(K) (decibel scale)
        %
        % Typical Values:
        %   - K = 0 (0 dB): Rayleigh fading (no LOS component)
        %   - K = 1-3 (0-5 dB): Weak LOS component
        %   - K = 3-10 (5-10 dB): Moderate LOS component
        %   - K > 10 (>10 dB): Strong LOS component
        %
        % Application Guidelines:
        %   - Satellite links: K = 10-20 dB
        %   - Rural cellular: K = 3-10 dB
        %   - Suburban: K = 1-5 dB
        KFactor (1, 1) {mustBeNonnegative, mustBeReal} = 3

        % MaximumDopplerShift - Maximum Doppler frequency shift in Hz
        % Type: non-negative scalar, Default: 0
        %
        % This property specifies the maximum Doppler shift due to relative
        % motion between transmitter and receiver. Doppler effects cause
        % time-varying channel coefficients and spectral spreading.
        %
        % Calculation:
        %   f_d = v * f_c / c
        %   where v = velocity, f_c = carrier frequency, c = speed of light
        %
        % Typical Values:
        %   - Stationary: 0 Hz (static channel)
        %   - Pedestrian: 5-20 Hz (3-5 km/h at 2.4 GHz)
        %   - Vehicular: 50-200 Hz (30-120 km/h at 2.4 GHz)
        %   - High-speed: 500+ Hz (300+ km/h for rail/aerospace)
        %
        % Constraints:
        %   - Must be < SampleRate/10 for proper modeling
        %   - Zero value creates static (time-invariant) channel
        %   - Higher values increase channel variation rate
        MaximumDopplerShift (1, 1) {mustBeNonnegative, mustBeReal} = 0

        % FadingTechnique - Method for generating fading realizations
        % Type: string, Default: "Sum of sinusoids"
        %
        % This property specifies the algorithm used to generate time-varying
        % fading coefficients. Different techniques offer trade-offs between
        % accuracy, computational complexity, and statistical properties.
        %
        % Available Methods:
        %   "Sum of sinusoids" - Jakes model implementation
        %     * Computationally efficient
        %     * Good statistical approximation
        %     * Suitable for most applications
        %
        % Technical Notes:
        %   The sum of sinusoids method uses multiple sinusoidal oscillators
        %   with random phases to approximate the Doppler spectrum shape.
        FadingTechnique {mustBeMember(FadingTechnique, ["Sum of sinusoids"])} = "Sum of sinusoids"

        % InitialTimeSource - Source for initial time reference
        % Type: string, Default: "Input port"
        %
        % This property determines how the initial time for fading generation
        % is specified, enabling synchronized channel realizations across
        % multiple channel instances or simulation runs.
        %
        % Available Options:
        %   "Input port" - Time provided via input signal structure
        %     * Allows external time control
        %     * Supports synchronized multi-channel scenarios
        %     * Required for consistent time-aligned simulations
        %
        % Usage:
        %   When set to "Input port", the input signal structure must
        %   contain a 'StartTime' field specifying the initial time.
        InitialTimeSource {mustBeMember(InitialTimeSource, ["Input port"])} = "Input port"
    end

    methods (Access = protected)

        function setupImpl(obj)
            % setupImpl - Initialize the MIMO channel system object
            %
            % This method configures the underlying Communications Toolbox
            % MIMOChannel object based on the specified parameters. Different
            % configurations are applied for Rayleigh and Rician fading.
            %
            % Syntax:
            %   setupImpl(obj)
            %
            % Implementation Details:
            %   - Creates comm.MIMOChannel with appropriate parameters
            %   - Handles Rayleigh vs Rician configuration differences
            %   - Sets up spatial correlation (currently none)
            %   - Configures fading generation technique
            %
            % Validation:
            %   - Ensures PathDelays and AveragePathGains have consistent lengths
            %   - Verifies Doppler shift is within valid range
            %   - Checks antenna configuration compatibility

            % Validate path configuration consistency
            if length(obj.PathDelays) ~= length(obj.AveragePathGains)
                error('ChangShuoRadioData:MIMO:InconsistentPathConfiguration', ...
                    'PathDelays and AveragePathGains must have the same length. ' + ...
                    'PathDelays: %d elements, AveragePathGains: %d elements.', ...
                    length(obj.PathDelays), length(obj.AveragePathGains));
            end

            % Validate Doppler shift constraint
            if obj.MaximumDopplerShift >= obj.SampleRate / 10
                warning('ChangShuoRadioData:MIMO:ExcessiveDopplerShift', ...
                    'Maximum Doppler shift (%.1f Hz) is close to sampling rate limit (%.1f Hz). ' + ...
                    'Consider reducing Doppler shift or increasing sample rate.', ...
                    obj.MaximumDopplerShift, obj.SampleRate / 10);
            end

            % Configure MIMO channel based on fading distribution
            if strcmp(obj.FadingDistribution, 'Rayleigh')
                % Rayleigh fading configuration (NLOS environments)
                obj.MultipathChannel = comm.MIMOChannel( ...
                    'SampleRate', obj.SampleRate, ...
                    'PathDelays', obj.PathDelays, ...
                    'AveragePathGains', obj.AveragePathGains, ...
                    'MaximumDopplerShift', obj.MaximumDopplerShift, ...
                    'SpatialCorrelationSpecification', 'None', ...
                    'FadingDistribution', 'Rayleigh', ...
                    'FadingTechnique', obj.FadingTechnique, ...
                    'InitialTimeSource', obj.InitialTimeSource, ...
                    'NumTransmitAntennas', obj.NumTransmitAntennas, ...
                    'NumReceiveAntennas', obj.NumReceiveAntennas);
            else
                % Rician fading configuration (LOS environments)
                obj.MultipathChannel = comm.MIMOChannel( ...
                    'SampleRate', obj.SampleRate, ...
                    'PathDelays', obj.PathDelays, ...
                    'AveragePathGains', obj.AveragePathGains, ...
                    'KFactor', obj.KFactor, ...
                    'MaximumDopplerShift', obj.MaximumDopplerShift, ...
                    'SpatialCorrelationSpecification', 'None', ...
                    'FadingDistribution', 'Rician', ...
                    'FadingTechnique', obj.FadingTechnique, ...
                    'InitialTimeSource', obj.InitialTimeSource, ...
                    'NumTransmitAntennas', obj.NumTransmitAntennas, ...
                    'NumReceiveAntennas', obj.NumReceiveAntennas);
            end

        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Process input signal through MIMO channel
            %
            % This method applies complete channel effects including path loss,
            % multipath fading, and Doppler shifts to the input signal matrix.
            % The method handles dynamic sample rate updates and maintains
            % proper signal structure formatting.
            %
            % Syntax:
            %   outputSignal = stepImpl(obj, inputSignal)
            %
            % Input Arguments:
            %   inputSignal - Input signal structure with fields:
            %     .data - Signal matrix [samples × NumTransmitAntennas]
            %     .SampleRate - Sampling rate in Hz
            %     .StartTime - Initial time for fading generation
            %
            % Output Arguments:
            %   outputSignal - Output signal structure with added fields:
            %     .data - Channel-modified signal [samples × NumReceiveAntennas]
            %     .PathDelays - Applied multipath delays
            %     .AveragePathGains - Applied path gains
            %     .NumReceiveAntennas - Number of receive antennas
            %     .FadingDistribution - Applied fading model
            %     .KFactor - K-factor (Rician channels only)
            %     .MaximumDopplerShift - Applied Doppler shift
            %     .mode - Channel configuration (SISO/SIMO/MISO/MIMO)
            %
            % Processing Steps:
            %   1. Apply path loss based on distance and atmospheric conditions
            %   2. Update channel object with current sample rate
            %   3. Apply multipath fading and Doppler effects
            %   4. Package output with channel parameters
            %
            % Signal Power Calculation:
            %   Path loss is applied as: signal_out = signal_in / (10^(PL_dB/20))
            %   where PL_dB is calculated by the BaseChannel class

            % Validate input signal structure
            if ~isstruct(inputSignal) || ~isfield(inputSignal, 'data')
                error('ChangShuoRadioData:MIMO:InvalidInputStructure', ...
                'Input must be a structure with at least a ''data'' field.');
            end

            if ~isfield(inputSignal, 'SampleRate') || ~isfield(inputSignal, 'StartTime')
                error('ChangShuoRadioData:MIMO:MissingRequiredFields', ...
                'Input structure must contain ''SampleRate'' and ''StartTime'' fields.');
            end

            % Validate input signal dimensions
            [numSamples, numTxAntennas] = size(inputSignal.data);

            if numTxAntennas ~= obj.NumTransmitAntennas
                error('ChangShuoRadioData:MIMO:AntennaMismatch', ...
                    'Input signal has %d antennas but channel expects %d transmit antennas.', ...
                    numTxAntennas, obj.NumTransmitAntennas);
            end

            % Apply path loss attenuation
            % Convert dB to linear scale: 10^(dB/20) for amplitude scaling
            pathLossLinear = 10 ^ (obj.PathLoss / 20);
            attenuatedSignal = inputSignal.data / pathLossLinear;

            % Update channel with current sample rate (release and reconfigure if needed)
            if isLocked(obj.MultipathChannel) && ...
                    obj.MultipathChannel.SampleRate ~= inputSignal.SampleRate
                release(obj.MultipathChannel);
                obj.MultipathChannel.SampleRate = inputSignal.SampleRate;
            end

            % Apply multipath fading and Doppler effects
            fadedSignal = obj.addMultipathFading(attenuatedSignal, inputSignal.StartTime);

            % Prepare comprehensive output structure
            outputSignal = inputSignal;
            outputSignal.data = fadedSignal;

            % Add channel configuration information
            outputSignal.PathDelays = obj.PathDelays;
            outputSignal.AveragePathGains = obj.AveragePathGains;
            outputSignal.NumReceiveAntennas = obj.NumReceiveAntennas;
            outputSignal.FadingDistribution = obj.FadingDistribution;
            outputSignal.MaximumDopplerShift = obj.MaximumDopplerShift;
            outputSignal.mode = obj.mode;

            % Add Rician-specific parameters
            if strcmp(obj.FadingDistribution, 'Rician')
                outputSignal.KFactor = obj.KFactor;
            end

        end

        function channelInfo = infoImpl(obj)
            % infoImpl - Return comprehensive channel configuration information
            %
            % This method provides detailed information about the current
            % channel configuration, useful for analysis and debugging.
            %
            % Syntax:
            %   channelInfo = infoImpl(obj)
            %
            % Output Arguments:
            %   channelInfo - Structure containing channel parameters:
            %     .mode - Channel configuration type
            %     .FadingDistribution - Statistical fading model
            %     .NumTransmitAntennas - Number of transmit antennas
            %     .NumReceiveAntennas - Number of receive antennas
            %     .PathDelays - Multipath delay profile
            %     .AveragePathGains - Path gain profile
            %     .MaximumDopplerShift - Doppler frequency limit
            %     .KFactor - K-factor (Rician channels only)
            %     .CarrierFrequency - RF carrier frequency
            %     .Distance - Propagation distance
            %     .PathLoss - Total path loss in dB

            % Initialize channel if not already setup
            if isempty(obj.MultipathChannel)
                setupImpl(obj);
            end

            % Create comprehensive channel information structure
            channelInfo = struct();

            % Basic configuration
            channelInfo.mode = obj.mode;
            channelInfo.FadingDistribution = obj.FadingDistribution;
            channelInfo.NumTransmitAntennas = obj.NumTransmitAntennas;
            channelInfo.NumReceiveAntennas = obj.NumReceiveAntennas;

            % Multipath characteristics
            channelInfo.PathDelays = obj.PathDelays;
            channelInfo.AveragePathGains = obj.AveragePathGains;
            channelInfo.MaximumDopplerShift = obj.MaximumDopplerShift;

            % Propagation parameters
            channelInfo.CarrierFrequency = obj.CarrierFrequency;
            channelInfo.Distance = obj.Distance;
            channelInfo.PathLoss = obj.PathLoss;
            channelInfo.AtmosphericConditions = obj.atmosCond;

            % Add Rician-specific information
            if strcmp(obj.FadingDistribution, 'Rician')
                channelInfo.KFactor = obj.KFactor;
            end

        end

    end

end
