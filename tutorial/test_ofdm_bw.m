% 
M = 64;      % Modulation order for 16QAM
nfft  = 1024; % Number of data carriers
numSubCar = 500;
cplen = 16;  % Cyclic prefix length
nSym  = 12;   % Number of symbols per RE
nt    = 1;   % Number of transmit antennas
dataIn = randi([0 M-1],numSubCar,nSym,nt);

dcIdx = (nfft/2)+1;
nullInd = [1:((nfft-numSubCar)/2) dcIdx ((nfft+numSubCar)/2)+1+1:nfft].';
qamSig = qammod(dataIn,M,'UnitAveragePower',true);
ofdmMod = comm.OFDMModulator( ...
    FFTLength=nfft, ...
    NumGuardBandCarriers=[((nfft-numSubCar)/2); 524-1-((nfft-numSubCar)/2)],...
    NumSymbols=nSym, ...
    InsertDCNull=true);

y = ofdmMod(qamSig);


y1 = otfsmod(qamSig, nfft, cplen, nullInd);


src = dsp.SampleRateConverter(Bandwidth= 20e3, InputSampleRate=20e3, OutputSampleRate=40e3);
FsIn = src.InputSampleRate;
FsOut = src.OutputSampleRate;

hsa = spectrumAnalyzer('SampleRate',FsIn,...
    'Method','welch','YLimits',[-40 40]);
hsa(y1)

sOut = src(y1);

hsb = spectrumAnalyzer('SampleRate',FsOut,...
    'Method','welch','YLimits',[-40 40]);
hsb(sOut)
release(hsb)


src = dsp.SampleRateConverter;

function y = otfsmod(x,nfft,cplen,varargin)
%OFDMMOD OFDM modulate the frequency-domain input signal
%
%   Y = OFDMMOD(X,NFFT,CPLEN) performs OFDM modulation on the input X and
%   outputs the result in Y. Specify X as an NFFT-by-Nsym-by-Nt array of
%   real or complex values. NFFT is the FFT size, specified as a scalar.
%   Nsym is the number of OFDM symbols and Nt is the number of transmit
%   antennas. CPLEN is the cyclic prefix length, specified as a scalar or
%   row vector of integers. When CPLEN is specified as a scalar, its value
%   must be in the range 0 and NFFT, both inclusive. When CPLEN is
%   specified as a vector, its length must equal Nsym and each value be
%   non-negative.
%       Y is the complex OFDM modulated output signal of size
%   ((NFFT+CPLEN)*Nsym)-by-Nt, if CPLEN is a scalar or of size
%   (NFFT*Nsym+sum(CPLEN))-by-Nt, if CPLEN is a row vector.
%
%   Y = OFDMMOD(X,NFFT,CPLEN,NULLIDX) accepts a column vector of FFT
%   indices, NULLIDX, indicating the null carrier locations from 1 to NFFT.
%   For this syntax, the number of rows in the input X must be
%   NFFT-length(NULLIDX), to allow for nulls to be inserted at the
%   locations indicated by NULLIDX. NULLIDX can be used to account for both
%   guard bands and DC subcarriers. The DC subcarrier is the center of the
%   frequency band and has an index value of (NFFT/2+1) if NFFT is even or
%   (NFFT+1)/2 if NFFT is odd.
%
%   Y = OFDMMOD(X,NFFT,CPLEN,NULLIDX,PILOTIDX,PILOTS) also accepts a column
%   vector of FFT indices, PILOTIDX and associated PILOTS values. PILOTIDX
%   indicates the pilot carrier locations from 1 to NFFT. For this syntax,
%   the number of rows in the input X must be
%   NFFT-length(NULLIDX)-length(PILOTIDX), to also allow for pilots to be
%   inserted at the locations indicated by PILOTIDX. PILOTS is the pilot
%   subcarrier signal, specified as a Np-by-Nsym-by-Nt array, where Np must
%   equal length(PILOTIDX). The pilot subcarrier locations are assumed to
%   be the same across each OFDM symbol and transmit antenna.
%
%   Y = OFDMMOD(X,NFFT,CPLEN,...,Name,Value) specifies an additional
%   name-value pair argument described below:
%
%   'OversamplingFactor' A positive, real scalar that specifies the
%                        oversampling factor for an upsampled output
%                        signal. The factor must satisfy the constraints
%                        that OversamplingFactor >= 1.0, and
%                        OversamplingFactor*NFFT and
%                        OversamplingFactor*CPLEN are both integers.
%                        The default value is 1.
%
%   Class Support
%   -------------
%   Input signals, X and PILOTS, can be numeric arrays, dlarrays, or gpuArrays
%   of underlyingType double or single. Both X and Pilots must be of the same
%   underlyingType. NFFT, CPLEN, NULLIDX, and PILOTSIDX must be numeric of class
%   double. Y is a dlarray if either X or PILOTS are dlarrays. Y
%   is a gpuArray if either X or PILOTS are gpuArrays. If both X and PILOTS are
%   numeric arrays of class double or single, Y is numeric of same class.
%
%   Notes
%   -----
%   1. X can be an array of up to four dimensions specified as
%      NFFT-by-Nsym-by-Nt-by-Nb array, where Nb is the number of batch
%      observations in deep learning workflows.
%   2. PILOTS can be an array of up to four dimensions specified as
%      Np-by-Nsym-by-Nt-by-Nb array, where Nb is the number of batch
%      observations in deep learning workflows.
%   3. If X is a 4-D array and PILOTS is a 3-D array, PILOTS are assumed to
%      be the same across all batch observations.
%
%   % Example: OFDM modulate a fully packed input over 2 transmit antennas
%
%     nfft  = 128;
%     cplen = 16;
%     nSym  = 5;
%     nt    = 2;
%     dataIn = randn(nfft,nSym,nt,"like",1i);
%
%     y1 = ofdmmod(dataIn,nfft,cplen);
%
%   % Example: OFDM modulate data input with nulls and pilots packing
%
%     nfft     = 64;
%     cplen    = 16;
%     nSym     = 10;
%     nullIdx  = [1:6 33 64-4:64]';
%     pilotIdx = [12 26 40 54]';
%     numDataCarrs = nfft-length(nullIdx)-length(pilotIdx);
%     dataIn = randn(numDataCarrs,nSym,"like",1i);
%     pilots = repmat(pskmod((0:3).',4),1,nSym);
%
%     y2 = ofdmmod(dataIn,nfft,cplen,nullIdx,pilotIdx,pilots);
%
%   % Example: OFDM modulate with upsampling and nulls
%
%     osf = 3;
%     nfft = 256;
%     cplen = 16;
%     nullIdx  = [1:6 nfft/2+1 nfft-5:nfft]';
%     numDataCarrs = nfft-length(nullIdx);
%     dataIn = randn(numDataCarrs,1,"like",1i);
%
%     y3 = ofdmmod(dataIn,nfft,cplen,nullIdx,OversamplingFactor=osf);
%
%   See also ofdmdemod, comm.OFDMModulator.

%   Copyright 2017-2023 The MathWorks, Inc.

%#codegen

narginchk(3,8);

% parse, validate inputs, set up processing
[prmStr,dataIdx] = setup(x,nfft,cplen,varargin{:});

fftLen = prmStr.FFTLength;
numSym = prmStr.NumSymbols;
numTx  = prmStr.NumTransmitAntennas;
numBatchObs = prmStr.NumBatchObs;

if isempty(prmStr.Pilots)
    typeIn = cast(1i, "like", x);
else
    % If X is gpuArray & Pilots is dlarray or vice versa, Y is dlarray holding gpuArray
    typeIn = cast(1i, "like", prmStr.Pilots(1)+x(1));
end

% Pack input data into grid
fullGrid = zeros(fftLen,numSym,numTx,numBatchObs,"like",typeIn);

id = floor(length(dataIdx)/2);
dataIdx(1:id, :) = dataIdx(1:id, :) - dataIdx(1) + 1;
dataIdx(id+1:end, :) = dataIdx(id+1:end, :) + fftLen - dataIdx(end);
fullGrid(dataIdx,1:numSym,1:numTx,1:numBatchObs) = x(:,1:numSym,1:numTx,1:numBatchObs);

% Pack input pilots into grid, if specified and non-empty
if ~isempty(prmStr.PilotIndices) && ~isempty(prmStr.Pilots)
    if size(prmStr.Pilots,4) == numBatchObs
        fullGrid(prmStr.PilotIndices,1:numSym,1:numTx,1:numBatchObs) = ...
            prmStr.Pilots(:,1:numSym,1:numTx,1:numBatchObs);
    else
        fullGrid(prmStr.PilotIndices,1:numSym,1:numTx,1:numBatchObs) = ...
        repmat(prmStr.Pilots(:,1:numSym,1:numTx),[1,1,1,numBatchObs]);
    end
end

M = size(fullGrid, 1);
fullGrid = pagetranspose(ifft(pagetranspose(fullGrid)));
fullGrid = fft(fullGrid);
% call internal fcn to compute output
y = comm.internal.ofdm.modulate(fullGrid,prmStr);

end

function [prmStr,pDataIdx] = setup(x,nfft,cplen,varargin)
% Parse inputs and set up parameters

    % Validate data input
    validateattributes(x, {'double','single'}, ...
        {'nonempty','finite'}, '', 'X');

    [numST,numSym,numTx,numBatchObs] = size(x,1:4);

    fullSz = size(x);

    % Validate input size
    coder.internal.errorIf( ~(numel(size(x))<=4 || all(fullSz(5:end)==1)), ...
        'comm:OFDM:InvalidXInputSize',numST,numSym,numTx,numBatchObs);

    % Formatted dlarrays are unsupported
    coder.internal.errorIf( isa(x, 'dlarray') && ~isempty(dims(x)), ...
        'comm:OFDM:InvalidDlarrayFormat');

    % Check nfft - scalar, positive integer > 8.
    validateattributes(nfft, {'numeric'}, ...
        {'real','scalar','integer','nonempty','finite','>=',8}, ...
        '', 'NFFT');

    % Check cplen - scalar in range [0 nfft], or vector of length numSym
    validateattributes(cplen, {'numeric'}, ...
        {'real','row','integer','nonnegative','nonempty','finite'}, ...
        '', 'CPLEN');
    if isscalar(cplen)
        coder.internal.errorIf( cplen>nfft, ...
            'comm:OFDM:InvalidCyclicPrefixfcn');
    else
        coder.internal.errorIf( (length(cplen) ~= numSym) , ...
            'comm:OFDM:InvalidCyclicPrefixVectorfcn');
    end

    % Parse optional parameters and name-value arguments
    % Avoid using inputParser for faster processing
    hasNVPair = false;
    if isempty(varargin)      % ofdmmod(x,nfft,cplen)

        NullIndices   = [];
        hasPilots     = false;
        PilotIndices  = [];
        Pilots        = [];
        OversamplingFactor = 1;

    elseif length(varargin)==1
        % ofdmmod(x,nfft,cplen,nullIdx) OR
        % ofdmmod(x,nfft,cplen,'OversamplingFactor') without argument error

        if isnumeric(varargin{1})
            NullIndices   = varargin{1};
            hasPilots     = false;
            PilotIndices  = [];
            Pilots        = [];
            OversamplingFactor = 1;
        else
            coder.internal.errorIf(true, 'comm:OFDM:InvalidOversamplingFactorSyntax');
        end

    elseif length(varargin)==2

        % ofdmmod(x,nfft,cplen,'OversamplingFactor',OversamplingFactor) OR
        % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx) without PILOTS argument error
        % ofdmmod(x,nfft,cplen,nullIdx,'OversamplingFactor') without argument error

        if ~isnumeric(varargin{1})
            NullIndices   = [];
            hasPilots     = false;
            PilotIndices  = [];
            Pilots        = [];
            hasNVPair = true;
            nvInd = 1;
        else
            if isnumeric(varargin{2})
                coder.internal.errorIf(true, 'comm:OFDM:InvalidPilotSyntax');
            else
                coder.internal.errorIf(true, 'comm:OFDM:InvalidOversamplingFactorSyntax');
            end
        end

    elseif length(varargin)==3

        % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx,pilots) OR
        % ofdmmod(x,nfft,cplen,nullIdx,'OversamplingFactor',OversamplingFactor)

        if isnumeric(varargin{2})
            % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx,pilots)
            NullIndices  = varargin{1};
            hasPilots    = true;
            PilotIndices = varargin{2};
            Pilots       = varargin{3};
            OversamplingFactor = 1;
            coder.internal.errorIf( ~strcmp(underlyingType(x),underlyingType(Pilots)) , ...
                'comm:OFDM:InvalidInputTypes');
        else
            % ofdmmod(x,nfft,cplen,nullIdx,'OversamplingFactor',OversamplingFactor)
            NullIndices  = varargin{1};
            hasPilots    = false;
            PilotIndices = [];
            Pilots       = [];
            hasNVPair = true;
            nvInd = 2;
        end

    elseif length(varargin)==4

        % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx,'OversamplingFactor',OversamplingFactor) without PILOTS argument error
        % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx,pilots,'OversamplingFactor') without argument error

        if ~isnumeric(varargin{3})
            coder.internal.errorIf(true, 'comm:OFDM:InvalidPilotSyntax');
        else
            coder.internal.errorIf(true, 'comm:OFDM:InvalidOversamplingFactorSyntax');
        end

    elseif length(varargin)==5 % ofdmmod(x,nfft,cplen,nullIdx,pilotIdx,pilots,'OversamplingFactor',OversamplingFactor)
        NullIndices  = varargin{1};
        hasPilots    = true;
        PilotIndices = varargin{2};
        Pilots       = varargin{3};
        hasNVPair = true;
        nvInd = 4;
    end

    % Parse Name-Value pair
    if hasNVPair
        defaults = struct('OversamplingFactor', 1);
        res = comm.internal.utilities.nvParser(defaults, varargin{nvInd:end});
        OversamplingFactor = res.OversamplingFactor;

        % Check validity of oversampling factor
        validateattributes(OversamplingFactor, {'numeric'}, ...
            {'real','scalar','nonempty','finite','>=',1}, ...
            '', 'OversamplingFactor');
        OversamplingFactor = double(OversamplingFactor);
    end

    % Populate prmStr as a sticky struct for codegen performance
    prmStr = coder.internal.constantPreservingStruct( ...
        'FFTLength',nfft, ...
        'CyclicPrefixLength',cplen, ...
        'NumSymbols',numSym, ...
        'NumTransmitAntennas',numTx, ...
        'NumBatchObs',numBatchObs, ...
        'NullIndices',NullIndices, ...
        'hasPilots', hasPilots, ...
        'PilotIndices', PilotIndices, ...
        'Pilots', Pilots, ...
        'OversamplingFactor',OversamplingFactor);

    if hasNVPair
         comm.internal.ofdm.validatePrms('OversamplingFactor',prmStr);
    end

    % Throw error if pilot indices are specified but pilot values are empty
    if ~isempty(prmStr.PilotIndices) && isempty(prmStr.Pilots)
        coder.internal.errorIf(true, 'comm:OFDM:InvalidPilotSyntax');
    end
    
    % Check for proper input type if PilotIndices and Pilots are not empty
    if ~isempty(prmStr.PilotIndices) && ~isempty(prmStr.Pilots)
        hasPilots = true;
        coder.internal.errorIf( ~strcmp(underlyingType(x),underlyingType(prmStr.Pilots)) , ...
            'comm:OFDM:InvalidInputTypes');
    else
        hasPilots = false;
    end

    % Calculate the DataIndices
    if ~isempty(prmStr.NullIndices)
        checkNulls(prmStr,numST,hasPilots);

        dataIdx = zeros(nfft-length(prmStr.NullIndices),1);
        dataIdx(:) = double(setdiff((1:nfft)',prmStr.NullIndices));
    else % no nulls
        if hasPilots
            numPilots = length(prmStr.PilotIndices); % may not have been specified
            coder.internal.errorIf( (numST+numPilots) ~= prmStr.FFTLength, ...
                'comm:OFDM:InvalidPacking');
        else
            coder.internal.errorIf( numST ~= prmStr.FFTLength, ...
                'comm:OFDM:InvalidBasicInputSize');
        end

        dataIdx = double((1:nfft)');
    end
    
    if hasPilots
        checkPilots(prmStr,numSym,numTx,numBatchObs);

        pDataIdx = coder.nullcopy(zeros(nfft-length(prmStr.NullIndices) ...
            -length(prmStr.PilotIndices),1));
        pDataIdx(:) = double(setdiff(dataIdx,prmStr.PilotIndices));
    else
        pDataIdx = dataIdx;
    end

end

function checkNulls(prmStr,numST,hasPilots)
%   Check for:
%       NullIdx: unique, column, range [1:nfft]

    comm.internal.ofdm.validatePrms('NullIdx',prmStr);

    numNulls = length(prmStr.NullIndices);
    if hasPilots
        numPilots = length(prmStr.PilotIndices); % may not have been specified
    else
        numPilots = 0;
    end
    
    coder.internal.errorIf( (numST+numNulls+numPilots) ~= prmStr.FFTLength, ...
        'comm:OFDM:InvalidPacking');

end

function checkPilots(prmStr,numSym,numTx,numBatchObs)
%   Check for:
%       PilotIdx: unique, column, length = size(pilots,1) = np
%           range [1:floor(nfft/2) floor(nfft/2)+2:nfft]
%       Pilots: double, 2d or 3D of size [np-by-Nsym-by-Nt] or
%               4D of size [np-by-Nsym-by-Nt-by-Nb]

    comm.internal.ofdm.validatePrms('PilotIdx',prmStr);

    % Formatted dlarrays are unsupported
    coder.internal.errorIf(isa(prmStr.Pilots, 'dlarray') && ~isempty(dims(prmStr.Pilots)), ...
        'comm:OFDM:InvalidDlarrayFormat');
    
    numPilots = length(prmStr.PilotIndices);
    
    [np,pSym,pNt,pNb] = size(prmStr.Pilots);
    if numBatchObs == 1
        coder.internal.errorIf( (np~=numPilots || pSym~=numSym || pNt~=numTx || pNb~=1), ...
            'comm:OFDM:InvalidNumPilots', numPilots, numSym, numTx);
    else
        coder.internal.errorIf( (np~=numPilots || pSym~=numSym || pNt~=numTx || (pNb~=1 && pNb~=numBatchObs)), ...
            'comm:OFDM:InvalidNumPilots4D', numPilots, numSym, numTx, numBatchObs);
    end        

end

% [EOF]
