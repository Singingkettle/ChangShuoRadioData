classdef AWGNChannel < matlab.System
    % AWGNChannel - Additive White Gaussian Noise Channel Model
    %
    % This class implements an Additive White Gaussian Noise (AWGN) channel model
    % as a MATLAB System object. AWGN is the most fundamental channel model in
    % communication systems, representing thermal noise in electronic circuits
    % and various random disturbances in the transmission medium.
    %
    % The AWGN channel adds complex-valued white Gaussian noise to the input signal
    % with a specified signal-to-noise ratio (SNR). This model is widely used for
    % initial system analysis, performance benchmarking, and as a baseline for
    % more complex channel models in wireless communication systems.
    %
    % Key Features:
    %   - Configurable SNR in decibels for flexible noise control
    %   - Repeatable noise generation with seed-based random streams
    %   - Complex-valued noise generation for baseband signals
    %   - Proper variance scaling for accurate SNR implementation
    %   - MATLAB System object interface for streaming applications
    %   - Thread-safe random number generation
    %
    % Technical Specifications:
    %   - Noise Model: Complex Additive White Gaussian Noise (CAWGN)
    %   - SNR Range: Configurable from -∞ to +∞ dB
    %   - Noise Statistics: Zero mean, configurable variance
    %   - Random Generator: Mersenne Twister (mt19937ar)
    %   - Precision: Double precision floating point
    %
    % Syntax:
    %   awgnChannel = AWGNChannel()
    %   awgnChannel = AWGNChannel('PropertyName', PropertyValue, ...)
    %   noisySignal = awgnChannel(cleanSignal)
    %
    % Properties:
    %   SNRdB - Signal-to-noise ratio in decibels
    %           Type: real scalar, Default: 10 dB
    %           Range: [-Inf, Inf] dB
    %           Note: Higher values mean less noise, lower values mean more noise
    %
    %   Seed - Random number generator seed for reproducibility
    %          Type: integer scalar, Default: 73
    %          Range: [0, 2^32-1]
    %          Note: Same seed produces identical noise sequences
    %
    % Private Properties:
    %   pRandomStream - Internal random number stream object
    %
    % Methods:
    %   step - Process input signal through AWGN channel
    %   reset - Reset internal random number generator state
    %   release - Release system resources
    %
    % Example:
    %   % Create AWGN channel for communication system simulation
    %   awgnCh = csrd.blocks.physical.channel.AWGNChannel();
    %   awgnCh.SNRdB = 15; % 15 dB SNR
    %   awgnCh.Seed = 42;  % Reproducible noise
    %
    %   % Generate test signal (QPSK constellation)
    %   numBits = 1000;
    %   txData = randi([0 3], numBits, 1);
    %   cleanSignal = pskmod(txData, 4, pi/4);
    %
    %   % Add AWGN noise
    %   noisySignal = awgnCh(cleanSignal);
    %
    %   % Calculate actual SNR for verification
    %   signalPower = mean(abs(cleanSignal).^2);
    %   noisePower = mean(abs(noisySignal - cleanSignal).^2);
    %   actualSNR = 10*log10(signalPower / noisePower);
    %   fprintf('Configured SNR: %.1f dB, Actual SNR: %.1f dB\n', ...
    %           awgnCh.SNRdB, actualSNR);
    %
    % Applications:
    %   - Digital communication system performance analysis
    %   - Bit error rate (BER) vs SNR curve generation
    %   - Algorithm robustness testing under noise conditions
    %   - Baseline comparison for advanced channel models
    %   - Monte Carlo simulation for statistical analysis
    %   - Educational demonstrations of noise effects
    %
    % SNR Configuration Guidelines:
    %   - High SNR (>20 dB): Low noise, good signal quality
    %   - Medium SNR (0-20 dB): Moderate noise, typical operating conditions
    %   - Low SNR (<0 dB): High noise, challenging conditions
    %   - Very Low SNR (<-10 dB): Extreme noise, stress testing
    %
    % Noise Variance Calculation:
    %   The noise variance is calculated based on signal power and SNR:
    %   σ² = P_signal / (10^(SNR_dB/10))
    %   where P_signal is the average power of the input signal
    %
    % Complex Noise Generation:
    %   For complex signals, noise is generated as:
    %   n(t) = n_I(t) + j*n_Q(t)
    %   where n_I and n_Q are independent Gaussian random variables
    %   with variance σ²/2 each, ensuring total noise variance = σ²
    %
    % See also: comm.AWGNChannel, awgn, randn, RandStream

    properties
        % SNRdB - Signal-to-noise ratio in decibels
        % Type: real scalar, Default: 10 dB
        %
        % This property specifies the signal-to-noise ratio in decibels.
        % The SNR is defined as the ratio of signal power to noise power:
        % SNR(dB) = 10*log10(P_signal / P_noise)
        %
        % Configuration Guidelines:
        %   - Positive values: Signal stronger than noise (good conditions)
        %   - Zero: Signal and noise have equal power
        %   - Negative values: Noise stronger than signal (challenging conditions)
        %
        % Typical Values:
        %   - 30 dB: Excellent quality (BER ≈ 10^-6 for QPSK)
        %   - 20 dB: Very good quality (BER ≈ 10^-4 for QPSK)
        %   - 10 dB: Good quality (BER ≈ 10^-2 for QPSK)
        %   - 0 dB: Poor quality (BER ≈ 10^-1 for QPSK)
        SNRdB (1, 1) {mustBeNumeric, mustBeReal, mustBeFinite} = 10

        % Seed - Random number generator seed for reproducibility
        % Type: non-negative integer, Default: 73
        %
        % This property controls the initial seed for the random number
        % generator used to produce noise samples. Using the same seed
        % ensures reproducible results across multiple simulations.
        %
        % Seed Selection Guidelines:
        %   - Use fixed seeds for debugging and reproducible results
        %   - Use different seeds for independent simulation runs
        %   - Use rng('shuffle') for time-based random seeds
        %
        % Valid Range: [0, 2^32-1] (32-bit unsigned integer)
        Seed (1, 1) {mustBeNumeric, mustBeReal, mustBeInteger, mustBeNonnegative} = 73
    end

    properties (Access = private)
        % pRandomStream - Internal random number stream object
        % Type: RandStream object
        %
        % This private property maintains the random number generator state
        % for consistent and reproducible noise generation. The stream is
        % initialized during setup and reset as needed.
        pRandomStream
    end

    methods

        function obj = AWGNChannel(varargin)
            % AWGNChannel - Constructor for AWGN channel model
            %
            % This constructor creates an AWGNChannel object with optional
            % property-value pairs for initial configuration.
            %
            % Syntax:
            %   obj = AWGNChannel()
            %   obj = AWGNChannel('PropertyName', PropertyValue, ...)
            %
            % Input Arguments (Name-Value Pairs):
            %   'SNRdB' - Signal-to-noise ratio in dB (default: 10)
            %   'Seed' - Random number generator seed (default: 73)
            %
            % Example:
            %   % Create channel with 20 dB SNR and custom seed
            %   ch = AWGNChannel('SNRdB', 20, 'Seed', 12345);

            % Set properties from name-value pairs
            setProperties(obj, nargin, varargin{:});

        end

    end

    methods (Access = protected)

        function setupImpl(obj, ~)
            % setupImpl - Initialize the AWGN channel system object
            %
            % This method is called automatically when the System object is
            % first used. It initializes the random number stream with the
            % specified seed for reproducible noise generation.
            %
            % Syntax:
            %   setupImpl(obj, inputSignal)
            %
            % Input Arguments:
            %   inputSignal - First input signal (used for initialization)
            %
            % Implementation Details:
            %   - Creates Mersenne Twister random stream with specified seed
            %   - Ensures thread-safe random number generation
            %   - Prepares internal state for noise generation

            % Initialize random stream with Mersenne Twister algorithm
            % mt19937ar provides excellent statistical properties and long period
            obj.pRandomStream = RandStream('mt19937ar', 'Seed', obj.Seed);

        end

        function noisySignal = stepImpl(obj, inputSignal)
            % stepImpl - Add AWGN to input signal
            %
            % This method implements the core AWGN channel functionality by
            % calculating appropriate noise variance based on signal power and
            % SNR, then adding complex Gaussian noise to the input signal.
            %
            % Syntax:
            %   noisySignal = stepImpl(obj, inputSignal)
            %
            % Input Arguments:
            %   inputSignal - Clean input signal to be corrupted with noise
            %                 Type: complex array
            %
            % Output Arguments:
            %   noisySignal - Input signal with added AWGN
            %                 Type: complex array (same size as input)
            %
            % Processing Steps:
            %   1. Calculate average signal power from input samples
            %   2. Compute noise variance based on SNR configuration
            %   3. Generate complex Gaussian noise with proper scaling
            %   4. Add noise to input signal preserving signal statistics
            %
            % Noise Variance Formula:
            %   σ² = P_signal / (10^(SNR_dB/10))
            %   where P_signal = E[|x(n)|²] is the average signal power
            %
            % Complex Noise Model:
            %   n(t) = (σ/√2) × (n_I(t) + j×n_Q(t))
            %   where n_I and n_Q are independent N(0,1) random variables

            % Validate input signal
            if isempty(inputSignal)
                noisySignal = inputSignal;
                return;
            end

            % Calculate average signal power (assuming complex baseband signal)
            % For complex signals: P = E[|x|²] = E[x_real² + x_imag²]
            signalPower = mean(abs(inputSignal(:)) .^ 2);

            % Handle zero-power signals (e.g., all-zero inputs)
            if signalPower == 0
                % For zero-power signals, use unit noise variance
                noiseVariance = 1;
                warning('ChangShuoRadioData:AWGNChannel:ZeroSignalPower', ...
                'Input signal has zero power. Using unit noise variance.');
            else
                % Calculate noise variance from SNR specification
                % SNR_linear = 10^(SNR_dB/10) = P_signal / P_noise
                % Therefore: P_noise = P_signal / SNR_linear
                snrLinear = 10 ^ (obj.SNRdB / 10);
                noiseVariance = signalPower / snrLinear;
            end

            % Generate complex white Gaussian noise
            % For complex noise Z = X + jY where X,Y ~ N(0, σ²/2):
            % - Var(X) = σ²/2, Var(Y) = σ²/2
            % - Var(Z) = Var(X) + Var(Y) = σ²
            % - X and Y are independent Gaussian random variables
            noiseStdDev = sqrt(noiseVariance / 2);

            realNoise = noiseStdDev * randn(obj.pRandomStream, size(inputSignal));
            imagNoise = noiseStdDev * randn(obj.pRandomStream, size(inputSignal));
            complexNoise = complex(realNoise, imagNoise);

            % Add noise to input signal
            noisySignal = inputSignal + complexNoise;

        end

        function resetImpl(obj)
            % resetImpl - Reset the random number generator state
            %
            % This method resets the internal random number stream to its
            % initial state, ensuring reproducible noise sequences when
            % the same seed is used.
            %
            % Syntax:
            %   resetImpl(obj)
            %
            % Usage:
            %   Typically called automatically by the System object framework
            %   or manually via reset(obj) for reproducible simulations.

            % Reset random stream to initial state for reproducibility
            if ~isempty(obj.pRandomStream)
                reset(obj.pRandomStream);
            end

        end

        function s = saveObjectImpl(obj)
            % saveObjectImpl - Save the System object state
            %
            % This method saves the current state of the AWGNChannel object,
            % including the random number generator state for proper restoration.
            %
            % Syntax:
            %   s = saveObjectImpl(obj)
            %
            % Output Arguments:
            %   s - Structure containing object state information

            % Save parent class state
            s = saveObjectImpl@matlab.System(obj);

            % Save random stream state if object is locked (actively used)
            if isLocked(obj)
                s.pRandomStream = obj.pRandomStream;
            end

        end

        function loadObjectImpl(obj, s, wasLocked)
            % loadObjectImpl - Load the System object state
            %
            % This method restores the AWGNChannel object state from a
            % previously saved structure, including random generator state.
            %
            % Syntax:
            %   loadObjectImpl(obj, s, wasLocked)
            %
            % Input Arguments:
            %   s - Structure containing saved object state
            %   wasLocked - Boolean indicating if object was locked when saved

            % Restore random stream state if object was previously locked
            if wasLocked && isfield(s, 'pRandomStream')
                obj.pRandomStream = s.pRandomStream;
            end

            % Load parent class state
            loadObjectImpl@matlab.System(obj, s, wasLocked);

        end

    end

end
