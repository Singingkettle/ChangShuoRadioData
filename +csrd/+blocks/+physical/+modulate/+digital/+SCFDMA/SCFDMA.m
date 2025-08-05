classdef SCFDMA < csrd.blocks.physical.modulate.digital.OFDM.OFDM
    % SCFDMA - Single Carrier Frequency Division Multiple Access Modulator
    %
    % This class implements SC-FDMA (Single Carrier Frequency Division Multiple Access)
    % modulation as a subclass of the OFDM modulator with additional DFT spreading.
    % SC-FDMA combines the low PAPR characteristics of single carrier systems with
    % the multipath resistance and flexible spectrum allocation of OFDM systems.
    %
    % SC-FDMA is widely used in LTE uplink communications due to its superior
    % power efficiency compared to OFDM. The modulation process involves DFT
    % spreading before subcarrier mapping, which reduces the peak-to-average
    % power ratio while maintaining orthogonality between users.
    %
    % Key Features:
    %   - Low peak-to-average power ratio (PAPR) compared to OFDM
    %   - DFT spreading for improved power efficiency
    %   - Flexible subcarrier mapping (localized or distributed)
    %   - Support for multiple access through frequency domain scheduling
    %   - OSTBC encoding support for MIMO transmission
    %   - Configurable base modulation (PSK/QAM)
    %
    % Technical Reference:
    %   SC-FDMA vs OFDM comparison and implementation:
    %   https://www.mathworks.com/help/comm/ug/scfdma-vs-ofdm.html
    %
    % Syntax:
    %   scfdmaModulator = SCFDMA()
    %   scfdmaModulator = SCFDMA('PropertyName', PropertyValue, ...)
    %   modulatedSignal = scfdmaModulator.step(inputData)
    %
    % Properties:
    %   SubcarrierMappingInterval - Interval between mapped subcarriers (default: 1)
    %
    % Properties (Inherited from OFDM):
    %   NumDataSubcarriers - Number of data subcarriers for user allocation
    %   NumSymbols - Number of SC-FDMA symbols per frame
    %   firstStageModulator - Primary modulation stage (PSK/QAM)
    %   secondStageModulator - OFDM modulation stage with CP insertion
    %   ostbc - Orthogonal space-time block coding for MIMO
    %   ModulatorConfig - Configuration structure for SC-FDMA parameters
    %     .scfdma.FFTLength - FFT size for frequency domain processing
    %     .scfdma.CyclicPrefixLength - Cyclic prefix length in samples
    %     .scfdma.Subcarrierspacing - Frequency spacing between subcarriers (Hz)
    %     .scfdma.NumDataSubcarriers - Number of allocated data subcarriers
    %     .scfdma.SubcarrierMappingInterval - Subcarrier mapping interval
    %     .base.mode - Base modulation mode ('psk' or 'qam')
    %     .base.PhaseOffset - Phase offset for PSK modulation
    %     .base.SymbolOrder - Symbol mapping order ('bin' or 'gray')
    %
    % Methods:
    %   baseModulator - Core SC-FDMA modulation with DFT spreading
    %   genSecondStageModulator - Generate OFDM modulator for second stage
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create SC-FDMA modulator for LTE-like uplink communication
    %   scfdmaMod = csrd.blocks.physical.modulate.digital.SCFDMA.SCFDMA();
    %   scfdmaMod.ModulatorOrder = 4; % QPSK base modulation
    %   scfdmaMod.SubcarrierMappingInterval = 1; % Localized mapping
    %
    %   % Configure SC-FDMA parameters
    %   scfdmaMod.ModulatorConfig.scfdma.FFTLength = 512;
    %   scfdmaMod.ModulatorConfig.scfdma.NumDataSubcarriers = 48;
    %   scfdmaMod.ModulatorConfig.base.mode = 'qam';
    %
    %   % Create input data structure
    %   inputData.data = randi([0 1], 2000, 1); % Random bits
    %
    %   % Modulate the signal
    %   modulatedSignal = scfdmaMod.step(inputData);
    %
    % See also: csrd.blocks.physical.modulate.digital.OFDM.OFDM,
    %           csrd.blocks.physical.modulate.BaseModulator, comm.OFDMModulator

    properties (Nontunable)
        % SubcarrierMappingInterval - Spacing between mapped subcarriers
        % Type: positive scalar, Default: 1
        %
        % This parameter determines the subcarrier mapping pattern in the
        % frequency domain. A value of 1 results in localized mapping where
        % subcarriers are allocated contiguously. Higher values create
        % distributed mapping with frequency diversity benefits.
        %
        % Mapping Types:
        %   - 1: Localized mapping (contiguous subcarriers)
        %   - >1: Distributed mapping (interleaved subcarriers)
        SubcarrierMappingInterval (1, 1) {mustBeReal, mustBePositive} = 1
    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            % baseModulator - Core SC-FDMA modulation implementation
            %
            % This method implements the complete SC-FDMA modulation process including
            % base modulation, OSTBC encoding, DFT spreading, subcarrier mapping,
            % and OFDM modulation with cyclic prefix insertion.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, inputSymbols)
            %
            % Input Arguments:
            %   inputSymbols - Input symbol sequence to be modulated
            %                  Type: numeric array
            %
            % Output Arguments:
            %   modulatedSignal - SC-FDMA modulated signal with CP
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth as [lower, upper] bounds in Hz
            %               Type: 1x2 numeric array
            %
            % Processing Steps:
            %   1. Apply base modulation (PSK/QAM) to input symbols
            %   2. Apply OSTBC encoding for MIMO transmission (if applicable)
            %   3. Reshape data for DFT spreading operation
            %   4. Apply DFT spreading to reduce PAPR
            %   5. Perform subcarrier mapping with guard band allocation
            %   6. Apply OFDM modulation with IFFT and cyclic prefix addition
            %   7. Calculate occupied bandwidth from subcarrier allocation
            %
            % DFT Spreading Benefits:
            %   - Reduces peak-to-average power ratio compared to OFDM
            %   - Maintains single carrier characteristics in time domain
            %   - Preserves orthogonality for multiple access
            %
            % Example:
            %   symbols = randi([0 3], 192, 1); % QPSK symbols
            %   [signal, bw] = obj.baseModulator(symbols);

            % Step 1: Apply base modulation (PSK/QAM)
            modulatedSymbols = obj.firstStageModulator(inputSymbols);

            % Step 2: Apply OSTBC encoding for MIMO transmission
            encodedSymbols = obj.ostbc(modulatedSymbols);

            % Step 3: Reshape input data for DFT spreading
            obj.NumSymbols = fix(size(encodedSymbols, 1) / obj.ModulatorConfig.scfdma.NumDataSubcarriers);
            trimmedSymbols = encodedSymbols(1:obj.NumSymbols * obj.ModulatorConfig.scfdma.NumDataSubcarriers, :);
            reshapedSymbols = reshape(trimmedSymbols, [obj.ModulatorConfig.scfdma.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);

            % Step 4: Apply DFT spreading for PAPR reduction
            dftSpreadSymbols = fft(reshapedSymbols(1:obj.ModulatorConfig.scfdma.NumDataSubcarriers, :, :), obj.ModulatorConfig.scfdma.NumDataSubcarriers);

            % Step 5: Subcarrier mapping with guard band allocation
            mappedSymbols = zeros(obj.ModulatorConfig.scfdma.FFTLength, obj.NumSymbols, obj.NumTransmitAntennas, 'like', dftSpreadSymbols);
            leftGuardBandSize = floor((obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers) / 2);
            rightGuardBandSize = obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers - leftGuardBandSize;

            % Map DFT spread symbols to allocated subcarriers
            subcarrierIndices = leftGuardBandSize + 1:obj.ModulatorConfig.scfdma.SubcarrierMappingInterval:leftGuardBandSize + obj.ModulatorConfig.scfdma.NumDataSubcarriers * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval;
            mappedSymbols(subcarrierIndices, :, :) = dftSpreadSymbols;

            % Step 6: Apply OFDM modulation (IFFT + Cyclic Prefix)
            % Release modulator if locked to allow parameter changes
            if isLocked(obj.secondStageModulator)
                release(obj.secondStageModulator);
            end

            % Update OFDM modulator with current symbol count
            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            modulatedSignal = obj.secondStageModulator(mappedSymbols);

            % Step 7: Calculate occupied bandwidth from subcarrier allocation
            bandWidth = zeros(1, 2);
            bandWidth(1) = -obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - leftGuardBandSize);
            bandWidth(2) = obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - rightGuardBandSize);

        end

        function secondStageModulator = genSecondStageModulator(obj)
            % genSecondStageModulator - Generate OFDM modulator for second stage
            %
            % This method creates a Communications Toolbox OFDMModulator object
            % configured for SC-FDMA operation. The OFDM modulator handles IFFT
            % operation and cyclic prefix insertion for the SC-FDMA system.
            %
            % Syntax:
            %   secondStageModulator = genSecondStageModulator(obj)
            %
            % Output Arguments:
            %   secondStageModulator - Configured OFDM modulator object
            %                          Type: comm.OFDMModulator
            %
            % Configuration Parameters:
            %   - FFTLength: SC-FDMA FFT size for frequency domain processing
            %   - NumGuardBandCarriers: No additional guard bands (handled in mapping)
            %   - CyclicPrefixLength: CP length for multipath protection
            %   - NumTransmitAntennas: Number of transmit antennas for MIMO
            %
            % Side Effects:
            %   Updates obj.NumDataSubcarriers and obj.SampleRate based on
            %   SC-FDMA configuration parameters.

            scfdmaParams = obj.ModulatorConfig.scfdma;

            % Create OFDM modulator for SC-FDMA second stage
            secondStageModulator = comm.OFDMModulator( ...
                'FFTLength', scfdmaParams.FFTLength, ...
                'NumGuardBandCarriers', [0; 0], ... % Guard bands handled in subcarrier mapping
                'CyclicPrefixLength', scfdmaParams.CyclicPrefixLength, ...
                'NumTransmitAntennas', obj.NumTransmitAntennas);

            % Update system parameters based on SC-FDMA configuration
            obj.NumDataSubcarriers = (obj.ModulatorConfig.scfdma.NumDataSubcarriers - 1) * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval + 1;
            obj.SampleRate = obj.ModulatorConfig.scfdma.Subcarrierspacing * scfdmaParams.FFTLength;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured SC-FDMA modulator function handle
            %
            % This method configures the SC-FDMA modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % The method sets up base modulation, SC-FDMA parameters, and OSTBC encoding.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for SC-FDMA modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(symbols)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - ostbcSymbolRate: OSTBC symbol rate for >2 antennas
            %   - base.mode: Base modulation mode ('psk' or 'qam')
            %   - base.PhaseOffset: Phase offset for PSK (random 0 to 2π)
            %   - base.SymbolOrder: Symbol ordering ('bin' or 'gray')
            %   - scfdma.FFTLength: SC-FDMA FFT size (random selection)
            %   - scfdma.CyclicPrefixLength: CP length (random 12-32 samples)
            %   - scfdma.Subcarrierspacing: Subcarrier spacing (200 or 400 Hz)
            %   - scfdma.SubcarrierMappingInterval: Mapping interval (1 or 2)
            %   - scfdma.NumDataSubcarriers: Data subcarrier count
            %
            % Default Configuration:
            %   - Random FFT length: [128, 256, 512, 1024, 2048]
            %   - Random CP length: [12, 32] samples
            %   - Random subcarrier spacing: [200, 400] Hz
            %   - Random mapping interval: [1, 2]
            %   - Data subcarriers: minimum 48, maximum based on FFT size
            %
            % Example:
            %   scfdmaMod = csrd.blocks.physical.modulate.digital.SCFDMA.SCFDMA();
            %   scfdmaMod.ModulatorOrder = 16; % 16-QAM base modulation
            %   modHandle = scfdmaMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(randi([0 15], 192, 1));

            % Set modulator type flag
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

            % Generate random SC-FDMA configuration if not provided
            if ~isfield(obj.ModulatorConfig, 'base')

                % Configure base modulation parameters
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);

                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    obj.ModulatorConfig.base.PhaseOffset = rand(1) * 2 * pi;
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end

                % Configure SC-FDMA specific parameters
                obj.ModulatorConfig.scfdma.FFTLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.scfdma.CyclicPrefixLength = randi([12, 32], 1);
                obj.ModulatorConfig.scfdma.Subcarrierspacing = randsample([2, 4], 1) * 1e2; % 200 or 400 Hz
                obj.ModulatorConfig.scfdma.SubcarrierMappingInterval = randi([1, 2], 1);

                % Calculate maximum number of data subcarriers based on FFT size and mapping interval
                maxDataSubcarriers = fix((obj.ModulatorConfig.scfdma.FFTLength - 1) / obj.ModulatorConfig.scfdma.SubcarrierMappingInterval) + 1;

                % Select number of data subcarriers (minimum 48 for reasonable payload)
                obj.ModulatorConfig.scfdma.NumDataSubcarriers = randi([48, maxDataSubcarriers], 1);
            end

            % Initialize base and second stage modulators
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;

            % Create function handle for modulation
            modulatorHandle = @(inputSymbols)obj.baseModulator(inputSymbols);

        end

    end

end
