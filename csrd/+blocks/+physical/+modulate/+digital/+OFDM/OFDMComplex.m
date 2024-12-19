classdef OFDMComplex < blocks.physical.modulate.BaseModulator
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html  关于如何实现对OFDM信号采样的仿真，本质上是一个转换
    % https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m      关于如何实现对OFDM信号采样的仿真
    % https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html  基于这个例子确定OFDM-MIMO的整体流程
    % https://www.mathworks.com/help/comm/ug/ofdm-transmitter-and-receiver.html

    properties (Nontunable)

        % Transmit parameters
        NumTransmitAntennas (1, 1) {mustBePositive, mustBeInteger, mustBeMember(NumTransmitAntennas, [1, 2, 3, 4])} = 1

        % Index corresponding to desired bandwidth
        BandWidthIndex (1, 1) {mustBeReal, mustBePositive} = 1

        % Code rate index corresponding to desired rate
        codeRateIndex (1, 1) {mustBeReal, mustBePositive} = 1

        %
        ModulatorType = 'psk'
        ModulatorOrder (1, 1) {mustBeReal, mustBePositive} = 1

    end

    properties (Access = protected)

        sysParam
        txParam
        txObj

    end

    methods (Access = protected)

        function [sysParam, txParam] = setParameters(obj)
            sysParam = struct();

            % Set transmit-specific parameter structure
            txParam = struct();
            txParam.numTx = obj.NumTransmitAntennas;
            txParam.modType = obj.ModulatorType;
            txParam.modOrder = obj.ModulatorOrder;
            txParam.codeRateIndex = obj.CodeRateIndex;

            sysParam.initState = [1 0 1 1 1 0 1]; % Scrambler/descrambler polynomials
            sysParam.scrMask = [0 0 0 1 0 0 1];

            sysParam.headerIntrlvNColumns = 12; % Number of columns of header interleaver, must divide into 72 evenly
            sysParam.dataIntrlvNColumns = 18; % Number of columns of data interleaver
            sysParam.dataConvK = 7; % Convolutional encoder constraint length for data
            sysParam.dataConvCode = [171 133]; % Convolution polynomials (1/2 rate) for data
            sysParam.headerConvK = 7; % Convolutional encoder constraint length for header
            sysParam.headerConvCode = [171 133]; % Convolution polynomials (1/2 rate) for header

            sysParam.headerCRCPoly = [16 12 5 0]; % header CRC polynomial

            sysParam.CRCPoly = [32 26 23 22 16 12 11 10 8 7 5 4 2 1 0]; % data CRC polynomial
            sysParam.CRCLen = 32; % data CRC length

            % Transmission grid parameters
            sysParam.ssIdx = 1; % Symbol 1 is the sync symbol
            sysParam.rsIdx = 2; % Symbol 2 is the reference symbol
            sysParam.headerIdx = 3; % Symbol 3 is the header symbol

            % Derived parameters from simulation settings
            % The remaining parameters are derived from user selections. Checks are
            % made to ensure that interdependent parameters are compatible with each
            % other.
            [BWParam, codeParam] = OFDMGetTables(obj.BandWidthIndex, obj.CodeRateIndex);
            sysParam.FFTLen = BWParam.FFTLen; % FFT length
            sysParam.CPLen = BWParam.CPLen; % cyclic prefix length
            sysParam.usedSubCarr = BWParam.numSubCarr; % number of active subcarriers
            sysParam.BW = BWParam.BW; % total allocated bandwidth
            sysParam.scs = BWParam.scs; % subcarrier spacing (Hz)
            sysParam.pilotSpacing = BWParam.pilotSpacing;
            codeRate = codeParam.codeRate; % Coding rate
            sysParam.tracebackDepth = codeParam.tracebackDepth; % Traceback depth

            numSubCar = sysParam.usedSubCarr; % Number of subcarriers per symbol
            sysParam.pilotIdx = ((sysParam.FFTLen - sysParam.usedSubCarr) / 2) + ...
                (1:sysParam.pilotSpacing:sysParam.usedSubCarr).';

            % Check if a pilot subcarrier falls on the DC subcarrier; if so, then shift
            % up the rest of the pilots by a subcarrier
            dcIdx = (sysParam.FFTLen / 2) + 1;

            if any(sysParam.pilotIdx == dcIdx)
                sysParam.pilotIdx(floor(length(sysParam.pilotIdx) / 2) + 1:end) = 1 + ...
                    sysParam.pilotIdx(floor(length(sysParam.pilotIdx) / 2) + 1:end);
            end

            % Error checks
            pilotsPerSym = numSubCar / sysParam.pilotSpacing;

            if floor(pilotsPerSym) ~= pilotsPerSym
                error('Number of subcarriers must be evenly divisible by the pilot spacing.');
            end

            sysParam.pilotsPerSym = pilotsPerSym;

            numIntrlvRows = 72 / sysParam.headerIntrlvNColumns;

            if floor(numIntrlvRows) ~= numIntrlvRows
                error('Number of header interleaver rows must divide into number of header subcarriers evenly.');
            end

        end

        function txObj = txInit(obj)
            %txInit Initializes transmitter
            %   This helper function is called once and sets up various transmitter
            %   objects for use in per-frame processing of transport blocks.
            %
            %   txObj = helperOFDMTxInit(sysParam)
            %   sysParam - structure of system parameters
            %   txObj - structure of tx parameters and object handles

            % Copyright 2020-2023 The MathWorks, Inc.

            % Create a tx filter object for baseband filtering
            txFilterCoef = OFDMFrontEndFilter(obj.sysParam);
            txObj.txFilter = dsp.FIRFilter('Numerator', txFilterCoef);

            % Configure PN sequencer for additive scrambler
            txObj.pnSeq = comm.PNSequence(Polynomial = 'x^-7 + x^-3 + 1', ...
                InitialConditionsSource = "Input port", ...
                Mask = obj.sysParam.scrMask, ...
                SamplesPerFrame = obj.sysParam.trBlkSize + obj.sysParam.CRCLen);

            % Initialize CRC parameters
            txObj.crcHeaderGen = crcConfig('Polynomial', obj.sysParam.headerCRCPoly);
            txObj.crcDataGen = crcConfig('Polynomial', obj.sysParam.CRCPoly);

            % Plot frequency response
            if obj.sysParam.enableScopes
                [h, w] = freqz(txFilterCoef, 1, 1024, obj.sysParam.scs * obj.sysParam.FFTLen);
                figure;
                plot(w, 20 * log10(abs(h)));
                grid on;
                title('Tx Filter Frequency Response');
                xlabel('Frequency (Hz)');
                ylabel('Magnitude (dB)');
            end

        end

        function y = baseModulator(obj, x)
            obj.sysParam.numSymPerFrame = round(length(x) / obj.sysParam.usedSubCarr / obj.NumTransmitAntennas);
            numDataOFDMSymbols = obj.sysParam.numSymPerFrame - ...
                length(obj.sysParam.ssIdx) - length(obj.sysParam.rsIdx) - ...
                length(obj.sysParam.headerIdx); % Number of data OFDM symbols

            if numDataOFDMSymbols < 1
                error('Number of symbols per frame must be greater than the number of sync, header, and reference symbols.');
            end

            % Calculate transport block size (trBlkSize) using parameters
            bitsPerModSym = log2(obj.txParam.modOrder); % Bits per modulated symbol
            numSubCar = obj.sysParam.usedSubCarr; % Number of subcarriers per symbol
            pilotsPerSym = numSubCar / obj.sysParam.pilotSpacing; % Number of pilots per symbol
            uncodedPayloadSize = (numSubCar - pilotsPerSym) * numDataOFDMSymbols * bitsPerModSym;
            codedPayloadSize = floor(uncodedPayloadSize / codeParam.codeRateK) * ...
                codeParam.codeRateK;
            obj.sysParam.trBlkPadSize = (uncodedPayloadSize - codedPayloadSize) * obj.NumTransmitAntennas;
            obj.sysParam.trBlkSize = ((codedPayloadSize * codeRate) - obj.sysParam.CRCLen - ...
                (obj.sysParam.dataConvK - 1)) * obj.NumTransmitAntennas;

            ssIdx = obj.sysParam.ssIdx; % sync symbol index
            rsIdx = obj.sysParam.rsIdx; % reference symbol index
            headerIdx = obj.sysParam.headerIdx; % header symbol index
            numCommonChannels = length(ssIdx) + length(rsIdx) + length(headerIdx);

            % Generate OFDM modulate output for each input configuration structure
            fftLen = obj.sysParam.FFTLen; % FFT length
            cpLen = obj.sysParam.CPLen; % CP length
            numSubCar = obj.sysParam.usedSubCarr; % Number of subcarriers per OFDM symbol
            numSymPerFrame = obj.sysParam.numSymPerFrame; % Number of OFDM symbols per frame

            % Initialize transmitter grid
            grid = zeros(numSubCar, numSymPerFrame, obj.NumTransmitAntennas);

            % Derive actual parameters from inputs
            [modType, bitsPerModSym, puncVec, ~] = ...
                getParameters(obj.txParam.modOrder, obj.txParam.codeRateIndex);

            %% Synchronization signal generation
            syncSignal = OFDMSyncSignal();
            syncSignalInd = (numSubCar / 2) - 31 + (1:62);

            % Load synchronization signal on the grid
            grid(syncSignalInd, ssIdx, :) = repmat(syncSignal, [1, 1, obj.NumTransmitAntennas]);

            %% Reference signal generation
            refSignal = OFDMRefSignal(numSubCar);
            refSignalInd = 1:length(refSignal);

            % Load reference signals on the grid
            grid(refSignalInd, rsIdx(1), :) = repmat(refSignal, [1, 1, obj.NumTransmitAntennas]);

            %% Header generation
            % Generate header bits
            % Map FFT length
            nbitsFFTLenIndex = 3;

            switch fftLen
                case 64 % 0 -> 64
                    FFTLenIndexBits = dec2bin(0, nbitsFFTLenIndex) == '1';
                case 128 % 1 -> 128
                    FFTLenIndexBits = dec2bin(1, nbitsFFTLenIndex) == '1';
                case 256 % 2 -> 256
                    FFTLenIndexBits = dec2bin(2, nbitsFFTLenIndex) == '1';
                case 512 % 3 -> 512
                    FFTLenIndexBits = dec2bin(3, nbitsFFTLenIndex) == '1';
                case 1024 % 4 -> 1024
                    FFTLenIndexBits = dec2bin(4, nbitsFFTLenIndex) == '1';
                case 2048 % 5 -> 2048
                    FFTLenIndexBits = dec2bin(5, nbitsFFTLenIndex) == '1';
                case 4096 % 6 -> 4096
                    FFTLenIndexBits = dec2bin(6, nbitsFFTLenIndex) == '1';
            end

            % Map modulation order
            nbitsModTypeIndex = 3;

            switch modType
                case 'BPSK' % 0 -> BPSK
                    modTypeIndexBits = dec2bin(0, nbitsModTypeIndex) == '1';
                case 'QPSK' % 1 -> QPSK
                    modTypeIndexBits = dec2bin(1, nbitsModTypeIndex) == '1';
                case '16QAM' % 2 -> 16-QAM
                    modTypeIndexBits = dec2bin(2, nbitsModTypeIndex) == '1';
                case '64QAM' % 3 -> 64-QAM
                    modTypeIndexBits = dec2bin(3, nbitsModTypeIndex) == '1';
                case '256QAM' % 4 -> 256-QAM
                    modTypeIndexBits = dec2bin(4, nbitsModTypeIndex) == '1';
                case '1024QAM' % 5 -> 1024-QAM
                    modTypeIndexBits = dec2bin(5, nbitsModTypeIndex) == '1';
            end

            reserveBits = zeros(1, 14 - nbitsFFTLenIndex - nbitsCodeRateIndex - nbitsModTypeIndex); % Reserve bits for future use

            % Form header bits
            headerBits = [FFTLenIndexBits, modTypeIndexBits, codeRateIndexBits, reserveBits];
            diagnostics.headerBits = headerBits.';

            % Append CRC bits
            headerCRCOut = reshape(crcGenerate(headerBits', obj.txObj.crcHeaderGen), 1, []);

            % Perform convolutional coding
            headerConvK = obj.sysParam.headerConvK;
            headerConvCode = obj.sysParam.headerConvCode;
            headerConvOut = convenc([headerCRCOut, zeros(1, headerConvK - 1)], ...
                poly2trellis(headerConvK, headerConvCode)); % Terminated Mode

            % Perform Interleaving
            headerIntrlvLen = obj.sysParam.headerIntrlvNColumns;
            headerIntrlvOut = reshape(reshape(headerConvOut, headerIntrlvLen, []).', [], 1);

            % Modulate header using BPSK
            headerSym = pskmod(headerIntrlvOut, 2, InputType = "bit");
            headerSymInd = (numSubCar / 2) - 36 + (1:72);

            % Load header signal on the grid
            grid(headerSymInd, headerIdx, :) = repmat(headerSym, [1, 1, obj.NumTransmitAntennas]);

            %% Pilot generation
            % Number of data/pilots OFDM symbols per frame
            numDataOFDMSymbols = numSymPerFrame - numCommonChannels;
            pilot = helperOFDMPilotSignal(obj.sysParam.pilotsPerSym); % Pilot signal values
            pilot = repmat(pilot, 1, numDataOFDMSymbols); % Pilot symbols per frame
            pilotGap = obj.sysParam.pilotSpacing; % Pilot signal repetition gap in OFDM symbol
            pilotInd = (1:pilotGap:numSubCar).';

            %% Data generation
            % Initialize convolutional encoder parameters
            dataConvK = obj.sysParam.dataConvK;
            dataConvCode = obj.sysParam.dataConvCode;
            % Calculate transport block size
            trBlkSize = obj.sysParam.trBlkSize;

            if (~isfield(obj.txParam, {'txDataBits'})) || ...
                    isempty(obj.txParam.txDataBits)
                % Generate random bits if txDataBits is not a field
                obj.txParam.txDataBits = randi([0 1], trBlkSize, 1);
            else
                % Pad appropriate bits if txDataBits is less than required bits
                if length(obj.txParam.txDataBits) < trBlkSize

                    if isrow(obj.txParam.txDataBits)
                        obj.txParam.txDataBits = ...
                            [obj.txParam.txDataBits zeros(1, trBlkSize - length(obj.txParam.txDataBits))];
                    else
                        obj.txParam.txDataBits = ...
                            [obj.txParam.txDataBits; zeros((trBlkSize - length(obj.txParam.txDataBits)), 1)];
                    end

                end

            end

            diagnostics.dataBits = obj.txParam.txDataBits(1:trBlkSize);

            % Retrieve data to form a transport block
            dataBits = obj.txParam.txDataBits;

            if isrow(dataBits)
                dataBits = dataBits.';
            end

            % Append CRC bits to data bits
            crcData = crcGenerate(dataBits, obj.txObj.crcDataGen);

            % Additively scramble using scramble polynomial
            scrOut = xor(crcData, obj.txObj.pnSeq(obj.sysParam.initState));

            % Perform convolutional coding
            dataEnc = convenc([scrOut; zeros(dataConvK - 1, 1)], ...
                poly2trellis(dataConvK, dataConvCode), puncVec); % Terminated mode
            dataEnc = [dataEnc; zeros(obj.sysParam.trBlkPadSize, 1)]; % append pad to factorize payload length
            dataEnc = reshape(dataEnc, [], numDataOFDMSymbols); % form columns of symbols

            % Perform interleaving and symbol modulation
            modData = zeros(numel(dataEnc) / (numDataOFDMSymbols * bitsPerModSym), numDataOFDMSymbols);

            for i = 1:numDataOFDMSymbols
                % Interleave each symbol
                intrlvOut = OFDMInterleave(dataEnc(:, i), obj.sysParam.dataIntrlvNColumns);
                % Modulate the symbol
                modData(:, i) = qammod(intrlvOut, obj.txParam.modOrder, ...
                    UnitAveragePower = true, InputType = "bit");
            end

            modDataInd = 1:numSubCar;

            % Remove the pilot indices from modData indices
            modDataInd(pilotInd) = [];

            % Load data and pilots on the grid
            grid(pilotInd, (headerIdx + 1:numSymPerFrame)) = pilot;
            grid(modDataInd, (headerIdx + 1:numSymPerFrame)) = modData;

            %% OFDM modulation
            dcIdx = (fftLen / 2) + 1;

            % Generate sync symbol
            nullLen = (fftLen - 62) / 2;
            syncNullInd = [1:nullLen dcIdx fftLen - nullLen + 2:fftLen].';
            ofdmSyncOut = ofdmmod(syncSignal, fftLen, cpLen, syncNullInd);

            % Generate reference symbol
            nullInd = [1:((fftLen - numSubCar) / 2) dcIdx ((fftLen + numSubCar) / 2) + 1 + 1:fftLen].';
            ofdmRefOut = ofdmmod(refSignal, fftLen, cpLen, nullInd);

            % Generate header symbol
            nullLen = (fftLen - 72) / 2;
            headerNullInd = [1:nullLen dcIdx fftLen - nullLen + 2:fftLen].';
            ofdmHeaderOut = ofdmmod(headerSym, fftLen, cpLen, headerNullInd);

            % Generate data symbols with embedded pilot subcarriers
            ofdmDataOut = ofdmmod(modData, fftLen, cpLen, nullInd, obj.sysParam.pilotIdx, pilot);
            ofdmModOut = [ofdmSyncOut; ofdmRefOut; ofdmHeaderOut; ofdmDataOut];

            % Filter OFDM modulate output
            txWaveform = obj.txObj.txFilter(ofdmModOut);

            % Collect diagnostic information
            diagnostics.ofdmModOut = txWaveform.';

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            [obj.txParam, obj.sysParam] = obj.setParameters;
            obj.txObj = obj.txInit;
            obj.IsDigital = true;

        end

    end

end

function [modType, bitsPerModSym, puncVec, codeRate] = getParameters(modOrder, codeRateIndex)
    % Select modulation type and bits per modulated symbol
    switch modOrder
        case 2
            modType = 'BPSK';
            bitsPerModSym = 1;
        case 4
            modType = 'QPSK';
            bitsPerModSym = 2;
        case 16
            modType = '16QAM';
            bitsPerModSym = 4;
        case 64
            modType = '64QAM';
            bitsPerModSym = 6;
        case 256
            modType = '256QAM';
            bitsPerModSym = 8;
        case 1024
            modType = '1024QAM';
            bitsPerModSym = 10;
        otherwise
            modType = 'QPSK';
            bitsPerModSym = 2;
            fprintf('\n Invalid modulation order. By default, QPSK is applied. \n');
    end

    % Select puncture vector and punctured code rate
    switch codeRateIndex
        case 0
            puncVec = [1 1];
            codeRate = 1/2;
        case 1
            puncVec = [1 1 0 1];
            codeRate = 2/3;
        case 2
            puncVec = [1 1 1 0 0 1];
            codeRate = 3/4;
        case 3
            puncVec = [1 1 1 0 0 1 1 0 0 1];
            codeRate = 5/6;
        otherwise
            puncVec = [1 1];
            codeRate = 1/2;
            fprintf('\n Invalid code rate. By default, 1/2 code rate is applied. \n');
    end

end

function intrlvOut = OFDMInterleave(in, dataIntrlvLen)

    lenIn = size(in, 1);
    numIntRows = ceil(lenIn / dataIntrlvLen);
    numInPad = (dataIntrlvLen * numIntRows) - lenIn; % number of padded entries needed to make the input data length factorable
    numFullCols = dataIntrlvLen - numInPad;
    inPad = [in; zeros(numInPad, 1)]; % pad the input data so it is factorable
    temp = reshape(inPad, dataIntrlvLen, []).'; % form interleave matrix
    temp1 = reshape(temp(:, 1:numFullCols), [], 1); % extract out the full rows

    if numInPad ~= 0
        temp2 = reshape(temp(1:numIntRows - 1, numFullCols + 1:end), [], 1); % extract out the partially-filled rows
    else
        temp2 = [];
    end

    intrlvOut = [temp1; temp2]; % concatenate the two rows

end

function firCoeff = OFDMFrontEndFilter(sysParam)
    %OFDMFrontEndFilter() Generates the transceiver front-end filter.
    %
    %   firCoeff = helperOFDMFrontEndFilter(sysParam)
    %   sysParam - system parameters structure
    %   firCoeff - FIR filter coefficients for the specified bandwidth

    % Copyright 2020-2022 The MathWorks, Inc.

    BW = sysParam.BW; % Bandwidth (in Hz) of OFDM signal
    fs = sysParam.scs * sysParam.FFTLen; % Sample rate of OFDM signal

    %% FIR Filtering
    % Equiripple Lowpass filter designed using the |firpm| function.
    % All frequency values are in Hz.
    Fpass = BW / 2; % Passband frequency
    Fstop = fs / 2; % Stopband frequency
    Dpass = 0.00033136495965; % Passband ripple
    Dstop = 0.05; % Stopband ripple
    dens = 20; % Density factor

    % Calculate the order from the parameters using the |firpmord| function.
    [N, Fo, Ao, W] = firpmord([Fpass, Fstop] / (fs / 2), [1 0], [Dpass, Dstop]);

    % Calculate the coefficients using the |firpm| function.
    firCoeff = firpm(N, Fo, Ao, W, {dens});

end

function syncSignal = OFDMSyncSignal()
    %OFDMSyncSignal Generates synchronization signal
    %   This function returns a length-62 complex-valued vector for the
    %   frequency-domain representation of the sync signal.
    %
    %   By default, this function uses a length-62 Zadoff-Chu sequence with
    %   root index 25. Zadoff-Chu is a constant amplitude signal so long as the
    %   length is a prime number, so the sequence is generated with a length of
    %   63 and adjusted for a length of 62.
    %
    %   This sequence can be user-defined as needed (e.g. a maximum length
    %   seqeunce) as long as the sequence is of length 62 to fit the OFDM
    %   simulation.
    %
    %   syncSignal = helperOFDMSyncSignal()
    %   syncSignal - frequency-domain sync signal

    % Copyright 2022 The MathWorks, Inc.

    zcRootIndex = 25;
    seqLen = 62;
    nPart1 = 0:((seqLen / 2) - 1);
    nPart2 = (seqLen / 2):(seqLen - 1);

    ZC = zadoffChuSeq(zcRootIndex, seqLen + 1);
    syncSignal = [ZC(nPart1 + 1); ZC(nPart2 + 2)];

    % Output check
    if length(syncSignal) ~= 62
        error('Sync signal must be of length 62.');
    end

end

function refSignal = OFDMRefSignal(numSubCarr)
    %OFDMRefSignal Generates reference signal.
    %   This function generates a reference signal (refSignal) for the given
    %   number of active subcarriers (numSubCarr). This reference signal is
    %   known to both the transmitter and receiver.
    %
    %   By default, this function uses a BPSK-modulated pseudo random binary
    %   sequence, repeated as necessary to fill the desired subcarriers. The
    %   sequence is designed to be centered around DC. The sequence for the
    %   smallest FFT length is also used for the other larger FFT lengths within
    %   those subcarriers, so that receivers that can only support the minimum
    %   FFT length can use the reference signal to demodulate the header (which
    %   is transmitted at the minimum FFT length to support all receivers
    %   independent of supported bandwidth). The sequence can be less than the
    %   FFT length to accomodate for null carriers within the OFDM symbol.
    %
    %   This sequence can be user-defined as needed.
    %
    %   refSignal = helperOFDMRefSignal(numSubCarr)
    %   numSubCarr - number of subcarriers per symbol
    %   refSignal - frequency-domain reference signal

    % Copyright 2020-2022 The MathWorks, Inc.

    seq1 = [1; 1; -1; -1; ...
                1; 1; -1; 1; ...
                -1; 1; 1; 1; ...
                1; 1; 1; -1; ...
                -1; 1; 1; -1; ...
                1; -1; 1; 1; ...
                1; 1; ];
    seq2 = [1; ...
                -1; -1; 1; 1; ...
                -1; 1; -1; 1; ...
                -1; -1; -1; -1; ...
                -1; 1; 1; -1; ...
                -1; 1; -1; 1; ...
                -1; 1; 1; 1; 1];
    seq = [seq1; seq2];

    rep = floor(numSubCarr / length(seq));
    endSeqLen = (numSubCarr - (rep * length(seq))) / 2;
    refSignal = [seq(end - (endSeqLen - 1):end); repmat(seq, rep, 1); seq(1:endSeqLen)];

    % Output check
    if length(refSignal) > numSubCarr
        error('Reference signal length too long for FFT.');
    end

end
