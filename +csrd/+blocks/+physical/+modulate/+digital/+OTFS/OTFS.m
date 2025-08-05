classdef OTFS < csrd.blocks.physical.modulate.BaseModulator
    % OTFS - Orthogonal Time Frequency Space Modulator
    %
    % This class implements Orthogonal Time Frequency Space (OTFS) modulation
    % as a subclass of the BaseModulator. OTFS is a novel modulation technique
    % that operates in the delay-Doppler domain, providing excellent performance
    % in high-mobility scenarios where traditional OFDM systems suffer from
    % Doppler spread and time-varying channel conditions.
    %
    % OTFS modulation transforms information from the time-frequency domain to
    % the delay-Doppler domain using symplectic finite Fourier transforms (SFFT).
    % This approach provides robust performance against time-varying channels
    % and is particularly suited for vehicular communications, high-speed rail,
    % and aerospace applications where Doppler effects are significant.
    %
    % Key Features:
    %   - Delay-Doppler domain signal processing for mobility robustness
    %   - Two-stage modulation: constellation mapping + OTFS transformation
    %   - Configurable padding schemes (CP, ZP, RZP, RCP, NONE)
    %   - MIMO transmission support with OSTBC encoding
    %   - Flexible delay-Doppler grid configuration
    %   - Superior performance in high-mobility environments
    %
    % Technical Specifications:
    %   - Domain: Delay-Doppler (DD) representation
    %   - Grid Size: DelayLength × NumSymbols
    %   - Transforms: ISFFT (Inverse Symplectic FFT) + FFT operations
    %   - Padding: Multiple schemes for different channel conditions
    %   - MIMO: OSTBC support for multiple antennas
    %
    % Syntax:
    %   otfsModulator = OTFS()
    %   otfsModulator = OTFS('PropertyName', PropertyValue, ...)
    %   modulatedSignal = otfsModulator.step(inputData)
    %
    % Properties:
    %   ModulatorOrder - Constellation size for first-stage modulation
    %   SamplePerSymbol - Samples per symbol (inherited but not directly used)
    %   SampleRate - Calculated from DelayLength and subcarrier spacing
    %   NumTransmitAntennas - Number of transmit antennas for MIMO
    %   ModulatorConfig - Configuration structure for OTFS parameters
    %     .base - First-stage modulation configuration
    %       .mode - Modulation type ('psk' or 'qam')
    %       .PhaseOffset - Phase offset for PSK (radians)
    %       .SymbolOrder - Symbol ordering ('bin' or 'gray')
    %     .otfs - OTFS-specific configuration
    %       .DelayLength - Number of delay bins (M parameter)
    %       .Subcarrierspacing - Subcarrier spacing in Hz
    %       .padType - Padding scheme ('CP', 'ZP', 'RZP', 'RCP', 'NONE')
    %       .padLen - Padding length in samples
    %
    % Protected Properties:
    %   firstStageModulator - Function handle for constellation mapping
    %   ostbc - OSTBC encoder for MIMO transmission
    %   secondStageModulator - Function handle for OTFS transformation
    %   NumSymbols - Number of Doppler bins (N parameter)
    %
    % Methods:
    %   baseModulator - Core OTFS modulation implementation
    %   genFirstStageModulator - Create constellation mapping function
    %   genSecondStageModulator - Create OTFS transformation function
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create OTFS modulator for high-mobility vehicular communication
    %   otfsMod = csrd.blocks.physical.modulate.digital.OTFS.OTFS();
    %   otfsMod.ModulatorOrder = 16; % 16-QAM
    %   otfsMod.NumTransmitAntennas = 2; % 2x2 MIMO
    %
    %   % Configure OTFS parameters
    %   otfsMod.ModulatorConfig.base.mode = 'qam';
    %   otfsMod.ModulatorConfig.otfs.DelayLength = 512; % M = 512 delay bins
    %   otfsMod.ModulatorConfig.otfs.Subcarrierspacing = 15000; % 15 kHz
    %   otfsMod.ModulatorConfig.otfs.padType = 'CP'; % Cyclic prefix
    %   otfsMod.ModulatorConfig.otfs.padLen = 16; % CP length
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 8192, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = otfsMod.step(inputData);
    %
    % Applications:
    %   - Vehicle-to-everything (V2X) communications
    %   - High-speed rail communication systems
    %   - Satellite communications with mobile terminals
    %   - Aerospace and UAV data links
    %   - Maritime mobile communications
    %
    % References:
    %   - MATLAB OTFS Modulation Documentation:
    %     https://www.mathworks.com/help/comm/ug/otfs-modulation.html
    %   - Hadani et al., "Orthogonal Time Frequency Space Modulation"
    %   - IEEE publications on OTFS theory and applications
    %
    % See also: csrd.blocks.physical.modulate.digital.OFDM.OFDM,
    %           csrd.blocks.physical.modulate.BaseModulator, otfsmod

    properties (Access = protected)
        % firstStageModulator - Function handle for constellation mapping
        % Type: function_handle
        firstStageModulator

        % ostbc - OSTBC encoder for MIMO transmission
        % Type: function_handle
        ostbc

        % secondStageModulator - Function handle for OTFS transformation
        % Type: function_handle
        secondStageModulator

        % NumSymbols - Number of Doppler bins in the delay-Doppler grid
        % Type: positive integer
        NumSymbols
    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core OTFS modulation implementation
            %
            % This method performs the complete OTFS modulation process including
            % first-stage constellation mapping, OSTBC encoding for MIMO, data
            % arrangement in delay-Doppler grid, and OTFS transformation to
            % time-frequency domain.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: integer array (0 to ModulatorOrder-1)
            %
            % Output Arguments:
            %   modulatedSignal - OTFS modulated signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Apply first-stage constellation mapping (PSK/QAM)
            %   2. Apply OSTBC encoding for MIMO transmission
            %   3. Arrange data in delay-Doppler grid (DelayLength × NumSymbols)
            %   4. Apply OTFS transformation (ISFFT + FFT operations)
            %   5. Calculate bandwidth based on delay-Doppler grid parameters
            %
            % Delay-Doppler Grid Formation:
            %   The input data is reshaped into a 3D array with dimensions:
            %   [DelayLength, NumSymbols, NumTransmitAntennas]
            %   This represents the delay-Doppler domain representation.
            %
            % Bandwidth Calculation:
            %   OTFS bandwidth is primarily determined by the delay-Doppler grid:
            %   BW ≈ (DelayLength - margin) × SubcarrierSpacing
            %   A margin (8 samples) is applied to ensure proper signal containment.
            %
            % Example:
            %   symbols = randi([0 15], 2048, 1); % 16-QAM symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Apply first-stage constellation mapping (PSK or QAM)
            modulatedSymbols = obj.firstStageModulator(inputSymbols);

            % Apply OSTBC encoding for MIMO transmission
            encodedSymbols = obj.ostbc(modulatedSymbols);

            % Calculate number of complete delay-Doppler symbols
            obj.NumSymbols = fix(size(encodedSymbols, 1) / obj.ModulatorConfig.otfs.DelayLength);

            % Truncate data to fit complete delay-Doppler grid
            gridData = encodedSymbols(1:obj.NumSymbols * obj.ModulatorConfig.otfs.DelayLength, :);

            % Reshape data into delay-Doppler grid: [DelayLength, NumSymbols, NumTxAntennas]
            delayDopplerGrid = reshape(gridData, ...
                [obj.ModulatorConfig.otfs.DelayLength, obj.NumSymbols, obj.NumTransmitAntennas]);

            % Apply OTFS transformation (delay-Doppler to time-frequency)
            modulatedSignal = obj.secondStageModulator(delayDopplerGrid);

            % Calculate OTFS signal bandwidth
            % Apply margin (8 samples) to ensure proper spectral containment
            % This empirical margin prevents warnings during sample rate conversion
            bandWidth = (obj.ModulatorConfig.otfs.DelayLength - 8) * ...
                obj.ModulatorConfig.otfs.Subcarrierspacing;

        end

        function firstStageModulator = genFirstStageModulator(obj)
            % genFirstStageModulator - Generate constellation mapping function
            %
            % This method creates a function handle for the first-stage modulation
            % (constellation mapping) based on the configured modulation type.
            % Supports PSK and QAM modulation schemes.
            %
            % Syntax:
            %   firstStageModulator = genFirstStageModulator(obj)
            %
            % Output Arguments:
            %   firstStageModulator - Function handle for constellation mapping
            %                         Type: function_handle
            %
            % Supported Modulation Types:
            %   - PSK: Phase Shift Keying with configurable phase offset and symbol ordering
            %   - QAM: Quadrature Amplitude Modulation with unit average power
            %
            % Configuration:
            %   The method uses ModulatorConfig.base.mode to determine the type
            %   and applies appropriate parameters for each modulation scheme.

            if contains(lower(obj.ModulatorConfig.base.mode), 'psk')
                % PSK modulation with phase offset and symbol ordering
                firstStageModulator = @(inputSymbols)pskmod(inputSymbols, ...
                    obj.ModulatorOrder, ...
                    obj.ModulatorConfig.base.PhaseOffset, ...
                    obj.ModulatorConfig.base.SymbolOrder);
            elseif contains(lower(obj.ModulatorConfig.base.mode), 'qam')
                % QAM modulation with unit average power normalization
                firstStageModulator = @(inputSymbols)qammod(inputSymbols, ...
                    obj.ModulatorOrder, ...
                    'UnitAveragePower', true);
            else
                error('ChangShuoRadioData:OTFS:UnsupportedModulation', ...
                    'Modulation type ''%s'' not implemented for OTFS first stage. Use ''psk'' or ''qam''.', ...
                    obj.ModulatorConfig.base.mode);
            end

        end

        function secondStageModulator = genSecondStageModulator(obj)
            % genSecondStageModulator - Generate OTFS transformation function
            %
            % This method creates a function handle for the OTFS transformation
            % that converts delay-Doppler domain signals to time-frequency domain.
            % Also updates the sample rate based on OTFS grid parameters.
            %
            % Syntax:
            %   secondStageModulator = genSecondStageModulator(obj)
            %
            % Output Arguments:
            %   secondStageModulator - Function handle for OTFS transformation
            %                          Type: function_handle
            %
            % OTFS Transformation:
            %   The transformation includes:
            %   1. Inverse symplectic FFT (ISFFT) operations
            %   2. FFT operations for time-frequency conversion
            %   3. Padding/prefix insertion based on configuration
            %
            % Sample Rate Calculation:
            %   Sample rate is determined by the delay-Doppler grid:
            %   Fs = DelayLength × SubcarrierSpacing

            % Extract OTFS configuration parameters
            otfsParams = obj.ModulatorConfig.otfs;

            % Create OTFS modulator function handle
            secondStageModulator = @(delayDopplerGrid)otfsmod(delayDopplerGrid, ...
                obj.NumTransmitAntennas, ...
                otfsParams.padLen, ...
                otfsParams.padType);

            % Update sample rate based on OTFS grid parameters
            obj.SampleRate = obj.ModulatorConfig.otfs.DelayLength * ...
                obj.ModulatorConfig.otfs.Subcarrierspacing;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured OTFS modulator function handle
            %
            % This method configures the OTFS modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up two-stage modulation, MIMO encoding, and OTFS parameters.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for OTFS modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - First-stage modulation type (PSK or QAM)
            %   - OTFS delay-Doppler grid parameters
            %   - Padding scheme and length
            %   - OSTBC symbol rate for multiple antennas
            %
            % Default Configuration:
            %   - Modulation: Random PSK or QAM
            %   - DelayLength: Random from [128, 256, 512, 1024, 2048]
            %   - SubcarrierSpacing: Random from [200, 400] Hz
            %   - Padding: Random from ['CP', 'ZP', 'RZP', 'RCP', 'NONE']
            %   - Padding length: Random from [12, 32] samples
            %
            % OTFS Grid Guidelines:
            %   - Larger DelayLength: Better delay resolution, higher complexity
            %   - Smaller DelayLength: Lower complexity, reduced delay resolution
            %   - SubcarrierSpacing: Determines bandwidth and Doppler resolution
            %
            % Padding Scheme Selection:
            %   - CP (Cyclic Prefix): Best for frequency-selective channels
            %   - ZP (Zero Padding): Simpler implementation, lower efficiency
            %   - RZP (Reduced Zero Padding): Compromise solution
            %   - RCP (Reduced Cyclic Prefix): Modified CP approach
            %   - NONE: No padding, maximum efficiency
            %
            % Example:
            %   otfsMod = csrd.blocks.physical.modulate.digital.OTFS.OTFS();
            %   otfsMod.ModulatorOrder = 64; % 64-QAM
            %   modHandle = otfsMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(dataSymbols);

            % Set modulation type flag
            obj.IsDigital = true;

            % Configure OSTBC symbol rate for multiple antennas (>2)
            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    % Random selection: 0.5, 0.75, or 1.0
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            end

            % Generate OSTBC encoder for MIMO support
            obj.ostbc = obj.genOSTBC;

            % Configure OTFS parameters if not provided
            if ~isfield(obj.ModulatorConfig, "base")
                % First-stage modulation configuration
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);

                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    % PSK-specific parameters
                    obj.ModulatorConfig.base.PhaseOffset = rand(1) * 2 * pi; % [0, 2π]
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end

                % OTFS-specific configuration
                obj.ModulatorConfig.otfs.padType = randsample(["CP", "ZP", "RZP", "RCP", "NONE"], 1);
                obj.ModulatorConfig.otfs.padLen = randi([12, 32], 1); % Padding length
                obj.ModulatorConfig.otfs.DelayLength = randsample([128, 256, 512, 1024, 2048], 1); % M parameter
                obj.ModulatorConfig.otfs.Subcarrierspacing = randsample([2, 4], 1) * 1e2; % [200, 400] Hz
            end

            % Generate first and second stage modulators
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end

function [modulatedSignal, isfftOutput] = otfsmod(delayDopplerGrid, numTransmitAntennas, paddingLength, varargin)
    % otfsmod - OTFS Modulation Function
    %
    % This function performs OTFS modulation by transforming delay-Doppler domain
    % data to time-frequency domain using inverse symplectic FFT operations and
    % applying the specified padding scheme.
    %
    % Syntax:
    %   [modulatedSignal, isfftOutput] = otfsmod(delayDopplerGrid, numTx, padLen)
    %   [modulatedSignal, isfftOutput] = otfsmod(delayDopplerGrid, numTx, padLen, padType)
    %
    % Input Arguments:
    %   delayDopplerGrid - Input delay-Doppler domain data
    %                      Type: 3D complex array [M, N, numTx]
    %   numTransmitAntennas - Number of transmit antennas
    %                         Type: positive integer
    %   paddingLength - Length of padding/prefix in samples
    %                   Type: positive integer
    %   padType - Padding scheme (optional, default: 'CP')
    %             Type: string ('CP', 'ZP', 'RZP', 'RCP', 'NONE')
    %
    % Output Arguments:
    %   modulatedSignal - Time-domain OTFS signal with padding
    %                     Type: complex array [samples, numTx]
    %   isfftOutput - Intermediate time-frequency grid output
    %                 Type: complex array [M, N, numTx]
    %
    % Padding Schemes:
    %   - 'CP': Cyclic Prefix before each OTFS column (OFDM-like)
    %   - 'ZP': Zero Padding after each OTFS column
    %   - 'RZP': Reduced Zero Padding (serialize then append zeros)
    %   - 'RCP': Reduced Cyclic Prefix (serialize then prepend CP)
    %   - 'NONE': No padding applied
    %
    % OTFS Transformation Process:
    %   1. Inverse Zak transform (inverse symplectic FFT)
    %   2. FFT to produce time-frequency grid
    %   3. Apply padding scheme
    %   4. Serialize for transmission

    % Get delay-Doppler grid dimensions
    delayBins = size(delayDopplerGrid, 1); % M parameter

    % Set default padding type if not specified
    if isempty(varargin)
        paddingType = 'CP';
    else
        paddingType = varargin{1};
    end

    % Step 1: Inverse Zak transform (Inverse Symplectic FFT)
    % This transforms from delay-Doppler domain to intermediate domain
    timeFrequencyGrid = pagetranspose(ifft(pagetranspose(delayDopplerGrid))) / delayBins;

    % Step 2: FFT to produce the time-frequency grid output
    isfftOutput = fft(timeFrequencyGrid);

    % Step 3: Apply padding scheme and serialize
    switch paddingType
        case 'CP'
            % Cyclic Prefix: Add CP before each OTFS column (similar to OFDM)
            cyclicPrefix = timeFrequencyGrid(end - paddingLength + 1:end, :, 1:numTransmitAntennas);
            paddedSignal = [cyclicPrefix; timeFrequencyGrid];
            modulatedSignal = reshape(paddedSignal, [], numTransmitAntennas); % Serialize

        case 'ZP'
            % Zero Padding: Add zeros after each OTFS column
            dopplerBins = size(delayDopplerGrid, 2); % N parameter
            zeroPadding = zeros(paddingLength, dopplerBins, numTransmitAntennas);
            paddedSignal = [timeFrequencyGrid; zeroPadding];
            modulatedSignal = reshape(paddedSignal, [], numTransmitAntennas); % Serialize

        case 'RZP'
            % Reduced Zero Padding: Serialize first, then append zeros
            modulatedSignal = reshape(timeFrequencyGrid, [], numTransmitAntennas); % Serialize
            zeroPadding = zeros(paddingLength, numTransmitAntennas);
            modulatedSignal = [modulatedSignal; zeroPadding]; % Append zeros

        case 'RCP'
            % Reduced Cyclic Prefix: Serialize first, then prepend CP
            modulatedSignal = reshape(timeFrequencyGrid, [], numTransmitAntennas); % Serialize
            cyclicPrefix = modulatedSignal(end - paddingLength + 1:end, 1:numTransmitAntennas);
            modulatedSignal = [cyclicPrefix; modulatedSignal]; % Prepend CP

        case 'NONE'
            % No padding: Direct serialization
            modulatedSignal = reshape(timeFrequencyGrid, [], numTransmitAntennas);

        otherwise
            error('ChangShuoRadioData:OTFS:InvalidPaddingType', ...
                'Invalid padding type ''%s''. Valid options: ''CP'', ''ZP'', ''RZP'', ''RCP'', ''NONE''.', ...
                paddingType);
    end

end
