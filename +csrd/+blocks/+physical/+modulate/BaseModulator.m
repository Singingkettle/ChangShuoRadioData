classdef BaseModulator < matlab.System
    % BaseModulator - Base class for modulators in the ChangShuoRadioData project
    %
    % Description:
    %   This class implements the base functionality for all modulator types,
    %   supporting both digital and analog modulation schemes with MIMO capabilities.
    %
    % Usage:
    %   This is an abstract base class. Create a concrete subclass by implementing
    %   the genModulatorHandle method.
    %
    % Example:
    %   % Create a custom modulator
    %   myMod = MyModulator('ModulatorOrder', 4, 'SampleRate', 1e6);
    %   output = myMod.step(input);
    %
    % Properties:
    %   ModulatorOrder       - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
    %   SampleRate          - Sampling rate in Hz
    %   ModulatorConfig     - Configuration struct for modulator-specific settings
    %   NumTransmitAntennas - Number of transmit antennas (1-4)
    %   SamplePerSymbol     - Samples per symbol (for digital modulation)
    %
    % Protected Properties:
    %   modulator  - Handle to the modulation function
    %   IsDigital - Flag indicating digital/analog modulation type
    %
    % References:
    %   - MathWorks matlab.System documentation:
    %     https://www.mathworks.com/help/matlab/ref/matlab.system-class.html
    %   - MathWorks comm.OSTBCEncoder documentation:
    %     https://www.mathworks.com/help/comm/ref/comm.ostbcencoder-system-object.html
    %
    % See also: matlab.System, comm.OSTBCEncoder

    properties
        % ModulatorOrder - Modulation order (e.g., 2 for BPSK, 4 for QPSK)
        % Type: positive real number, Default: 1
        ModulatorOrder {mustBePositive, mustBeReal} = 1

        % SampleRate - Sampling rate in Hz
        % Type: positive real scalar, Default: 200e3
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e3

        % ModulatorConfig - Configuration struct for modulator-specific settings
        % Type: struct, Default: empty struct
        ModulatorConfig struct = struct()

        % NumTransmitAntennas - Number of transmit antennas
        % Type: positive integer in range [1,4], Default: 1
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennas, [1, 2, 3, 4])} = 1

        % SamplePerSymbol - Samples per symbol (for digital modulation)
        % For analog modulation, this is just a placeholder
        % Type: positive real scalar, Default: 1
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 1

        % TargetBandwidth - The scenario's allocated channel width (Hz),
        % pushed by ModulationFactory from the placement config. Digital
        % modulators shape to their symbol rate and may ignore it; ANALOG
        % modulators REQUIRE it -- their message low-pass limit is a family
        % ratio of the allocation (see analogMessageBandwidthLimitHz), which
        % is the coupling that keeps an analog emission inside its planned
        % channel. NaN = not provided.
        % Type: real scalar, Default: NaN
        TargetBandwidth (1, 1) {mustBeReal} = NaN
    end

    properties (Access = protected)
        % modulator - Handle to the modulation function
        modulator

        % IsDigital - Flag indicating digital/analog modulation type
        % Type: logical, Default: true
        IsDigital = true
    end

    methods

        function obj = BaseModulator(varargin)
            % BaseModulator - Constructor method for the BaseModulator class
            %
            % Inputs:
            %   varargin - Name-value pairs for object properties
            %
            % Returns:
            %   obj - Initialized BaseModulator object

            setProperties(obj, nargin, varargin{:});
        end

        function ostbc = genOSTBC(obj)
            % genOSTBC - Generate Orthogonal Space-Time Block Coding encoder
            %
            % Returns:
            %   ostbc - Function handle to OSTBC encoder

            if obj.NumTransmitAntennas > 1

                if obj.NumTransmitAntennas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end

                ostbc = @(x)genOSTBCWithX(ostbc, x);
            else
                ostbc = @(x)obj.placeHolder(x);
            end

        end

        function y = placeHolder(obj, x)
            % placeHolder - A placeholder method for single antenna systems
            %
            % Inputs:
            %   x - Input data
            %
            % Returns:
            %   y - Same as input (no transformation)

            y = x;
        end

    end

    methods (Abstract)
        % genModulatorHandle - Abstract method to generate the modulate handle
        %
        % Returns:
        %   modulatorHandle - Function handle for modulation operation

        modulatorHandle = genModulatorHandle(obj)

    end

    methods (Access = protected)

        function msg = prepareAnalogMessage(obj, x)
            % prepareAnalogMessage - condition a message for analog modulation.
            % Inputs: x - the step input struct; x.data is the raw message and
            %         x.MessageSampleRate its NATIVE sample rate (Hz) as
            %         declared by the message source (e.g. 44.1 kHz audio).
            % Outputs: msg - column message on obj.SampleRate's grid,
            %          band-limited to the family limit, DC-free, normalized.
            %
            % Four steps, each fixing a measured defect class:
            %   1. RESAMPLE native rate -> obj.SampleRate. Reinterpreting the
            %      samples at the modulator rate rescales the message spectrum
            %      by SampleRate/nativeRate and decouples it from the channel.
            %   2. LOW-PASS to the family's share of TargetBandwidth (see
            %      analogMessageBandwidthLimitHz) so the modulated emission
            %      fits its allocation. Audio content is NOT guaranteed to --
            %      a 19 kHz message on a 12.5 kHz FM channel is wider than the
            %      whole channel.
            %   3. REMOVE DC. FM integrates the message (cumsum), so a DC
            %      component becomes a linear phase ramp = a constant carrier
            %      offset that corrupts the measured CenterFrequencyHz.
            %   4. NORMALIZE (per-family 'peak' or 'power', see
            %      analogMessageNormalization) so the drawn modulation indices
            %      (FM deviation, PM phase deviation, AM depth) mean what the
            %      annotation says they mean.
            if ~isfield(x, 'MessageSampleRate') || ...
                    ~isnumeric(x.MessageSampleRate) || ...
                    ~isscalar(x.MessageSampleRate) || ...
                    ~isfinite(x.MessageSampleRate) || x.MessageSampleRate <= 0
                error('CSRD:Modulation:MissingMessageSampleRate', ...
                    ['Analog modulator %s requires x.MessageSampleRate (the ', ...
                     'message''s native sample rate in Hz). Without it the ', ...
                     'samples get reinterpreted on the modulator grid and ', ...
                     'the message bandwidth decouples from the allocation.'], ...
                    class(obj));
            end
            if ~isfinite(obj.TargetBandwidth) || obj.TargetBandwidth <= 0
                error('CSRD:Modulation:MissingTargetBandwidth', ...
                    ['Analog modulator %s requires TargetBandwidth (the ', ...
                     'allocated channel width) to bound its message spectrum.'], ...
                    class(obj));
            end

            msg = double(real(x.data(:)));
            nativeRate = double(x.MessageSampleRate);
            plannedLength = numel(msg);

            % 1. Native grid -> modulator grid, PRESERVING the planned sample
            % count. The pipeline sizes the message buffer so that
            % length/SampleRate spans the planned burst; resampling changes
            % the count (44.1 kHz audio on a 256 kHz grid is 5.8x more
            % samples for the same clip time), so the resampled message is
            % tiled or truncated back to the planned length. Tiling repeats
            % the clip -- the same looping semantics the audio source itself
            % uses (dsp.AudioFileReader PlayCount = inf) -- and the seam
            % energy is handled by the band-limit below.
            if abs(nativeRate - obj.SampleRate) > 1e-6 * obj.SampleRate
                % Rational approximation with a BOUNDED p*q: the planner's
                % snap-spacing rates are irrational-looking doubles (e.g.
                % 638977.63578... Hz), and a tight rat() tolerance returns
                % integer factors whose product overflows upfirdn's 2^31
                % limit. Loosen the tolerance decade by decade until the
                % factors are tractable -- a <=0.1% rate error only shifts
                % the message content scale imperceptibly, and allocation
                % compliance is enforced AFTER this step by the bin zeroing
                % on the true modulator grid.
                ratio = obj.SampleRate / nativeRate;
                tol = 1e-8 * ratio;
                [p, q] = rat(ratio, tol);
                while p * q > 2 ^ 24
                    tol = tol * 10;
                    [p, q] = rat(ratio, tol);
                end
                msg = resample(msg, p, q);
                if numel(msg) < plannedLength
                    msg = repmat(msg, ceil(plannedLength / numel(msg)), 1);
                end
                msg = msg(1:plannedLength);
            end

            % 2. Band-limit to the family's share of the allocation, by
            % zeroing the out-of-band FFT bins of the finite message buffer.
            % The family limit is an ITU 99%-power bound on the MEASURED
            % message OBW, and an FIR transition band leaks enough energy to
            % break it (measured on a white-noise message: the 99% edge sat
            % at 1.4-1.75x the passband edge even at Steepness 0.95, pushing
            % the DSB emission past its allocation). Bin zeroing IS the
            % contract -- "the message contains no content beyond the limit"
            % -- exactly, for any buffer length, with no filter transient.
            limitHz = min(obj.analogMessageBandwidthLimitHz(), ...
                0.45 * obj.SampleRate);
            n = numel(msg);
            binHz = min((0:n - 1)', n - (0:n - 1)') * (obj.SampleRate / n);
            spec = fft(msg);
            spec(binHz > limitHz) = 0;
            msg = real(ifft(spec));

            % 3. DC-free.
            msg = msg - mean(msg);

            % 4. Level normalization (guarding an all-zero message).
            switch obj.analogMessageNormalization()
                case 'peak'
                    scale = max(abs(msg));
                otherwise % 'power'
                    scale = sqrt(mean(msg .^ 2));
            end
            if scale > 0
                msg = msg / scale;
            end
        end

        function limitHz = analogMessageBandwidthLimitHz(obj) %#ok<STOUT> -- always throws; analog subclasses must override
            % analogMessageBandwidthLimitHz - family share of the allocation.
            % Inputs: obj - the modulator (TargetBandwidth must be set).
            % Outputs: limitHz - one-sided message bandwidth limit in Hz.
            %
            % Every ANALOG family must declare how much of the allocated
            % channel its message may occupy (DSB doubles the message, SSB
            % transmits it once, FM expands it by Carson's rule...). There is
            % no honest default, so the base class refuses.
            error('CSRD:Modulation:MissingAnalogBandwidthLimit', ...
                ['%s is analog but does not override ', ...
                 'analogMessageBandwidthLimitHz.'], class(obj));
        end

        function mode = analogMessageNormalization(~)
            % analogMessageNormalization - message level convention.
            % Inputs: none used.
            % Outputs: mode - 'peak' (|m| <= 1: families whose drawn index
            %          multiplies the message: FM deviation, PM phase, AM
            %          depth) or 'power' (unit RMS: linear suppressed-carrier
            %          families where the TRF's unit-power-baseband DC
            %          convention matters more than an index).
            mode = 'peak';
        end

        function validateInputsImpl(~, x)
            % validateInputsImpl - Validates the inputs to the object
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Inputs:
            %   x - Input to validate, must be a struct

            if ~isstruct(x)
                error("Input must be struct");
            end

        end

        function setupImpl(obj)
            % setupImpl - Performs setup operations for the object
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Sets up OSTBC symbol rate and initializes the modulator handle

            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            else
                obj.ModulatorConfig.ostbcSymbolRate = 1;
            end

            obj.modulator = obj.genModulatorHandle;
        end

        function out = stepImpl(obj, x)
            % stepImpl - Main modulation processing step
            %
            % Inputs:
            %   x - Struct containing:
            %     - data: Input data to be modulated (bit array)
            %     - SymbolRate: Symbol rate (optional)
            %     - messageLength: Length of message (optional)
            %
            % Returns:
            %   out - Struct containing:
            %     - Signal: Modulated IQ signal
            %     - Bandwidth: Signal bandwidth [min max] in Hz
            %     - SamplePerSymbol: Samples per symbol
            %     - ModulatorOrder: Modulation order
            %     - IsDigital: Digital/analog flag
            %     - NumTransmitAntennas: Number of TX antennas
            %     - ModulatorConfig: Configuration parameters
            %     - SampleRate: Sample rate (Hz)
            %     - TimeDuration: Signal duration (s)
            %     - SamplePerFrame: Total samples in frame

            if sum(obj.ModulatorOrder) ~= 1
                n = log2(sum(obj.ModulatorOrder)); % Number of bits per symbol
            else
                n = 1;
            end

            % Ensure the length of the data is a multiple of n bits.
            dataLength = size(x.data, 1);
            remainder = mod(dataLength, n);

            if remainder ~= 0
                x.data = x.data(1:end - remainder, :); % Discard the final bits
            end

            % When the modulator is multi-carrier, enforce its minimum payload.
            if isfield(obj.ModulatorConfig, 'base')

                if isfield(obj.ModulatorConfig, 'ofdm')
                    min_num_bits = obj.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'scfdma')
                    min_num_bits = obj.ModulatorConfig.scfdma.NumDataSubcarriers * n * 2;
                elseif isfield(obj.ModulatorConfig, 'otfs')
                    min_num_bits = obj.ModulatorConfig.otfs.DelayLength * n * 2;
                else
                    min_num_bits = 0;
                end

                if length(x.data) < min_num_bits
                    % Repeat and truncate input data to the required length.
                    repeated_data = repmat(x.data, ceil(min_num_bits / length(x.data)), 1);
                    x.data = repeated_data(1:min_num_bits, :);
                    % Random permutation by row.
                    x.data = x.data(randperm(size(x.data, 1)), :);
                end

            end

            % Convert bits to integer symbols before discrete modulation.
            if obj.ModulatorOrder > 1
                % bit2int needs an integer number of bits per symbol, i.e. a
                % power-of-two order. Fail fast with an actionable message
                % instead of the cryptic bit2int "N must be a positive integer"
                % error a layer down.
                if mod(n, 1) ~= 0
                    error('CSRD:Modulation:NonPowerOfTwoOrder', ...
                        'Digital ModulatorOrder must be a power of two (got %g).', ...
                        sum(obj.ModulatorOrder));
                end
                x.data = bit2int(x.data, n);
            end

            % Analog modulators consume a continuous MESSAGE, not a payload:
            % it must arrive on the modulator's own sample grid, band-limited
            % to the family's share of the allocated channel, DC-free and
            % level-normalized. Skipping this is the defect that decoupled
            % every analog family from its allocation (audio samples recorded
            % at 44.1 kHz were reinterpreted at the modulator rate, so the
            % message bandwidth scaled with SampleRate instead of the channel:
            % DSBAM read 3.9x its allocation on clean output).
            if ~obj.IsDigital
                x.data = obj.prepareAnalogMessage(x);
            end

            [y, bw] = obj.modulator(x.data);

            if isscalar(bw)
                bw = [-bw / 2, bw / 2];
            end

            if ~isfield(obj.ModulatorConfig, 'base')
                bw(1) = fix(bw(1));
                bw(2) = fix(bw(2));
            end

            out.Signal = y;
            out.Bandwidth = bw;

            if isfield(obj.ModulatorConfig, 'base')
                out.SamplePerSymbol = 1;
            else
                out.SamplePerSymbol = obj.SamplePerSymbol;
            end

            out.ModulatorOrder = obj.ModulatorOrder;
            out.IsDigital = obj.IsDigital;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
            out.ModulatorConfig = obj.ModulatorConfig;

            % The obj.SampleRate may be redefined by OFDM, SC-FDMA and OTFS.
            out.SampleRate = obj.SampleRate;
            out.TimeDuration = size(y, 1) / obj.SampleRate;
            out.SamplePerFrame = size(y, 1);

        end

    end

end

function y = genOSTBCWithX(ostbc, x)
    % genOSTBCWithX - Apply OSTBC encoding to input data
    %
    % Inputs:
    %   ostbc - OSTBC encoder object with properties:
    %     - SymbolRate: Rate of the OSTBC encoder (fraction)
    %   x - Input data matrix to be encoded
    %
    % Returns:
    %   y - OSTBC encoded data matrix

    % The OSTBC input length must be a multiple of the encoder's symbols per
    % block, which is NOT floor(SymbolRate*8). That formula is only
    % coincidentally correct for the rate-1/2 codes: the 2-antenna (Alamouti)
    % encoder defaults to SymbolRate 3/4 and needs only even-length input
    % (2 symbols/block), and the rate-3/4 codes need multiples of 3. The old
    % formula used 6 for both, silently dropping up to 5 trailing payload
    % symbols before encoding.
    if ostbc.NumTransmitAntennas == 2
        rr = 2;                         % Alamouti: even-length input
    elseif abs(ostbc.SymbolRate - 0.5) < 1e-9
        rr = 4;                         % rate-1/2 OSTBC: 4 symbols per block
    else
        rr = 3;                         % rate-3/4 OSTBC: 3 symbols per block
    end
    valid_len = floor(size(x, 1) / rr) * rr;
    y = ostbc(x(1:valid_len, :));

end
