function [txWaveInt, waveinfo] = helperSpecSenseLTESignal(RC,timeShift,TrBlkOff,numSF,outputFs)
%helperSpecSenseLTESignal LTE signal generator
%   [X,INFO] = helperSpecSenseNRSignal(RC,TD,TBO,NSF,FS) generates a
%   downlink LTE signal with reference channel set to RC, time delay of the
%   start of the frame is set to TD in ms, turned off transport blocks are
%   set to TBO, number of subframes set to NSF, and output sample rate set
%   to FS. X contains the generated frame I/Q samples and INFO contains the
%   information on the generated waveform.

%   Copyright 2021 The MathWorks, Inc.

persistent pn
if isempty(pn)
  pn = comm.PNSequence('Polynomial', 'x9+x5+1', 'InitialConditions', [zeros(1, 8) 1]);
end

% for later use
rmcOverride.RC = RC;
rmcOverride.DuplexMode = 'FDD';

rmc = lteRMCDL(rmcOverride);

rmc.TotSubframes = numSF;

if randi([0 1])
  rmc.PDSCH.PRBSet = repmat({(0:3)'},10,1);
  for p=1:10
    rmc.PDSCH.PRBSet{p} = unique([(0:1)'; randi([4 8],randi([0 2]),1)]);
  end
else
  % Turn off some TrBlkSizes
  tbBlk = randi([1 length(rmc.PDSCH.TrBlkSizes)],TrBlkOff,1);
  rmc.PDSCH.TrBlkSizes(tbBlk) = 0;
end

release(pn)
pn.InitialConditions = randi([0 1], 1, 9);
pn.SamplesPerFrame = sum(rmc.PDSCH.TrBlkSizes(1, :));
data = pn();

[txWave,~,rmcOut] = lteRMCDLTool(rmc,data);

% Apply slot shifting
txWave = circshift(txWave,floor(timeShift*1e-3*rmcOut.SamplingRate));

% Interpolate for wideband spectrum monitoring
rate = outputFs / rmcOut.SamplingRate;
num = designMultirateFIR(rate,1);
num = num / sum(num);
interpFilt = dsp.FIRInterpolator(rate, num);
txWaveInt = interpFilt(txWave);
waveinfo.Nfft = rmcOut.Nfft*interpFilt.InterpolationFactor;
waveinfo.SampleRate = rmcOut.SamplingRate*interpFilt.InterpolationFactor;

% Bandwidth
switch RC
  case 'R.2'
    bw = 10e6;
  case 'R.6'
    bw = 5e6;
  case 'R.7'
    bw = 10e6;
  case 'R.8'
    bw = 15e6;
  case 'R.9'
    bw = 20e6;
end

waveinfo.Bandwidth = bw;

end

