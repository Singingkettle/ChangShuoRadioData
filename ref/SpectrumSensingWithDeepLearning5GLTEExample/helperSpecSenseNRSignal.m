function [txWaveInt, dlWaveInfo] = helperSpecSenseNRSignal(scs,chBW,SSBPeriod,timeShift,numSF,outputFs)
%helperSpecSenseNRSignal 5G NR signal generator
%   [X,INFO] = helperSpecSenseNRSignal(SCS,BW,TSSB,TD,NSF,FS) generates a
%   downlink 5G NR signal with subcarrier spacing set to SCS kHz, channel
%   bandwidth set to BW MHz, SSB period set to TSSB ms, time delay of the
%   start of the frame is set to TD in ms, number of subframes set to NSF,
%   and output sample rate set to FS. X contains the generated frame I/Q
%   samples and INFO contains the information on the generated waveform.
%
%   See also nrWaveformGenerator.

%   Copyright 2021 The MathWorks, Inc.

% Create configuration object
startGrid = 3;
cfgDL = specSenseNRConfig(chBW,scs,startGrid,SSBPeriod,numSF);

% Generate waveform
[txWave,dlWaveInfo] = nrWaveformGenerator(cfgDL);

sr = dlWaveInfo.ResourceGrids.Info.SampleRate;
dlWaveInfo.Bandwidth = chBW*1e6;

% Time shift
txWave = circshift(txWave,floor(timeShift*1e-3*sr));

% Interpolate
rate = outputFs / sr;
num = designMultirateFIR(rate,1);
num = num / sum(num);
interpFilt = dsp.FIRInterpolator(rate, num);
txWaveInt = interpFilt(txWave);
dlWaveInfo.ResourceGrids.Info.SampleRate = sr*interpFilt.InterpolationFactor;
end

function cfgDL = specSenseNRConfig(chBW,scs,startGrid,SSBPeriod,numSF)
%specSenseNRConfig 5G NR downlink configuration
%   CFG = specSenseNRConfig(BW,SCS,TSG,TSSB,NSF) generates a downlink
%   5G NR configuration with subcarrier spacing set to SCS kHz, channel
%   bandwidth set to BW MHz, SSB period set to TSSB ms, starting grid set
%   to TSG, number of subframes set to NSF.

if nargin == 0
  chBW = 20;
  scs = 15;
  startGrid = 3;
  SSBPeriod = 40;
  numSF = 40;
end

if scs == 15
  blockPattern = 'Case A';
else % 30
  blockPattern = 'Case B';
end

gridSize = FR1GridSize(chBW,scs);
[PRBs, slots] = assignREs(gridSize);


try
%% Generate Downlink Waveform
% Downlink configuration:
cfgDL = nrDLCarrierConfig;
cfgDL.Label = 'Carrier1';
cfgDL.FrequencyRange = 'FR1';
cfgDL.ChannelBandwidth = chBW;
cfgDL.NCellID = 1;
cfgDL.NumSubframes = numSF;
cfgDL.WindowingPercent = 0;
cfgDL.SampleRate = [];
cfgDL.CarrierFrequency = 0;

%% SCS specific carriers
scscarrier = nrSCSCarrierConfig;
scscarrier.SubcarrierSpacing = scs;
scscarrier.NSizeGrid = gridSize;
scscarrier.NStartGrid = startGrid;

cfgDL.SCSCarriers = {scscarrier};

%% Bandwidth Parts
bwp = nrWavegenBWPConfig;
bwp.BandwidthPartID = 1;
bwp.Label = 'BWP1';
bwp.SubcarrierSpacing = scs;
bwp.CyclicPrefix = 'normal';
bwp.NSizeBWP = gridSize;
bwp.NStartBWP = 3;

cfgDL.BandwidthParts = {bwp};

%% Synchronization Signals Burst
if rand > 0.5
  len = 4;
else
  len = 8;
end
ssburst = nrWavegenSSBurstConfig;
ssburst.BlockPattern = blockPattern;
ssburst.TransmittedBlocks = randi([0 1],1,len);
ssburst.Period = SSBPeriod;
ssburst.NCRBSSB = [];
ssburst.KSSB = 0;
ssburst.DataSource = 'MIB';
ssburst.DMRSTypeAPosition = 2;
ssburst.CellBarred = false;
ssburst.IntraFreqReselection = false;
ssburst.PDCCHConfigSIB1 = 0;
ssburst.SubcarrierSpacingCommon = scs;
ssburst.Enable = true;
ssburst.Power = 0;

cfgDL.SSBurst = ssburst;

%% CORESET and Search Space Configuration
maxCORESETRB = floor(gridSize / 6);
% CORESET 1
coreset1 = nrCORESETConfig;
coreset1.CORESETID = 0;
coreset1.Label = 'CORESET0';
coreset1.FrequencyResources = ones(1,maxCORESETRB); % Use the full band
coreset1.Duration = 2;
coreset1.CCEREGMapping = 'interleaved';
coreset1.REGBundleSize = 6;
coreset1.InterleaverSize = 2;
coreset1.ShiftIndex = 0;

cfgDL.CORESET = {coreset1};

% Search Spaces
searchspace = nrSearchSpaceConfig;
searchspace.SearchSpaceID = 1;
searchspace.Label = 'SearchSpace1';
searchspace.CORESETID = 0;
searchspace.SearchSpaceType = 'ue';
searchspace.StartSymbolWithinSlot = 0;
searchspace.SlotPeriodAndOffset = [1 0];
searchspace.Duration = 1;
searchspace.NumCandidates = [8 8 4 2 1];

%% PDCCH Instances Configuration
pdcch = nrWavegenPDCCHConfig;
pdcch.Enable = true;
pdcch.Label = 'PDCCH1';
pdcch.Power = 0;
pdcch.BandwidthPartID = 1;
pdcch.SearchSpaceID = 1;
fr = sum(coreset1.FrequencyResources)*coreset1.Duration;
pdcch.AggregationLevel = min(8,2^(floor(log2(fr))));

% Update num candidates based on aggregation level
aggregationLevels = [1 2 4 8 16];
searchspace.NumCandidates(aggregationLevels > pdcch.AggregationLevel) = 0;
cfgDL.SearchSpaces = {searchspace};

pdcch.AllocatedCandidate = 1;
pdcch.SlotAllocation = 0;
pdcch.Period = 1;
pdcch.Coding = true;
pdcch.DataBlockSize = 20;
pdcch.DataSource = 'PN9-ITU';
pdcch.RNTI = 1;
pdcch.DMRSScramblingID = 2;
pdcch.DMRSPower = 0;

cfgDL.PDCCH = {pdcch};

%% PDSCH Instances Configuration
% PDSCH 1
pdsch1 = nrWavegenPDSCHConfig;
pdsch1.Enable = true;
pdsch1.Label = 'PDSCH1';
pdsch1.Power = 0;
pdsch1.BandwidthPartID = 1;
pdsch1.Modulation = 'QPSK';
pdsch1.NumLayers = 1;
pdsch1.MappingType = 'A';
pdsch1.ReservedCORESET = [];
pdsch1.SymbolAllocation = [0 14];
pdsch1.SlotAllocation = slots;
pdsch1.Period = 20;
pdsch1.PRBSet = PRBs; %0:130;
pdsch1.VRBToPRBInterleaving = false;
pdsch1.VRBBundleSize = 2;
pdsch1.NID = 1;
pdsch1.RNTI = 1;
pdsch1.Coding = true;
pdsch1.TargetCodeRate = 0.513671875;
pdsch1.TBScaling = 1;
pdsch1.XOverhead = 0;
pdsch1.RVSequence = [0 2 3 1];
pdsch1.DataSource = 'PN9-ITU';
pdsch1.DMRSPower = 0;
pdsch1.EnablePTRS = false;
pdsch1.PTRSPower = 0;

% PDSCH Reserved PRB
pdsch1ReservedPRB = nrPDSCHReservedConfig;
pdsch1ReservedPRB.PRBSet = [];
pdsch1ReservedPRB.SymbolSet = [];
pdsch1ReservedPRB.Period = [];

pdsch1.ReservedPRB = {pdsch1ReservedPRB};

% PDSCH DM-RS
pdsch1DMRS = nrPDSCHDMRSConfig;
pdsch1DMRS.DMRSConfigurationType = 1;
pdsch1DMRS.DMRSReferencePoint = 'CRB0';
pdsch1DMRS.DMRSTypeAPosition = 3;%pdsch1.SymbolAllocation(1);
pdsch1DMRS.DMRSAdditionalPosition = 0;
pdsch1DMRS.DMRSLength = 1;
pdsch1DMRS.CustomSymbolSet = [];
pdsch1DMRS.DMRSPortSet = [];
pdsch1DMRS.NIDNSCID = [];
pdsch1DMRS.NSCID = 0;
pdsch1DMRS.NumCDMGroupsWithoutData = 2;

pdsch1.DMRS = pdsch1DMRS;

% PDSCH PT-RS
pdsch1PTRS = nrPDSCHPTRSConfig;
pdsch1PTRS.TimeDensity = 1;
pdsch1PTRS.FrequencyDensity = 2;
pdsch1PTRS.REOffset = '00';
pdsch1PTRS.PTRSPortSet = [];

pdsch1.PTRS = pdsch1PTRS;

cfgDL.PDSCH = {pdsch1};

%% CSI-RS Instances Configuration
csirs = nrWavegenCSIRSConfig;
csirs.Enable = false;
csirs.Label = 'CSIRS1';
csirs.Power = 0;
csirs.BandwidthPartID = 1;
csirs.CSIRSType = 'nzp';
csirs.CSIRSPeriod = 'on';
csirs.RowNumber = 3;
csirs.Density = 'one';
csirs.SymbolLocations = 0;
csirs.SubcarrierLocations = 0;
csirs.NumRB = 52;
csirs.RBOffset = 0;
csirs.NID = 0;

cfgDL.CSIRS = {csirs};
catch ME
  save localVariables
  rethrow(ME)
end
end

function gridSize = FR1GridSize(chBW,scs)
    % TS 38.104 Table 5.3.2-1:   Transmission bandwidth configuration NRB for FR1
    % TS 38.101-1 Table 5.3.2-1: Maximum transmission bandwidth configuration NRB (FR1)
    % NRB, for BW and SCS
    colIdx = [5   10 15 20  25  30  40  50  60  70  80  90  100] == chBW;
    rowIdx = [15 30 60] == scs;
    % BW MHz    5   10 15 20  25  30  40  50  60  70  80  90  100
    nrbtable = [25  52 79 106 133 160 216 270 NaN NaN NaN NaN NaN;     % 15 kHz
                11  24 38 51  65  78  106 133 162 189 217 245 273;     % 30 kHz
                NaN 11 18 24  31  38  51  65  79  93  107 121 135];    % 60 kHz
     
    gridSize = nrbtable(rowIdx,colIdx);
end

function [PRBs, slots] = assignREs(gridSize)

maxNumSlots = 8;
numSlotGroups = randi(3);
fillRatio = rand()*0.7+0.1; % Random fill ratio between 10% and 80%
numSlots = randFixSum(numSlotGroups,max(numSlotGroups,round(maxNumSlots*fillRatio)));

numRBGroups = randi(3);
fillRatio = rand()*0.5+0.2; % Random fill ratio between 20% and 70%
numRBs = randFixSum(numRBGroups,max(numRBGroups,round(gridSize*fillRatio)));

PRBLimits = zeros(1,numRBGroups*2);
startRB = 0;
for p=1:numRBGroups
  if gridSize - sum(numRBs(p:end)) - startRB > 0
    startRB = startRB + randi(gridSize - sum(numRBs(p:end)) - startRB);
    PRBLimits(2*p-1) = startRB;
    PRBLimits(2*p) = PRBLimits(2*p-1)+numRBs(p);
    startRB = PRBLimits(2*p);
  elseif gridSize - sum(numRBs(p:end)) - startRB == 0
    startRB = startRB + 1;
    PRBLimits(2*p-1) = startRB;
    PRBLimits(2*p) = min(gridSize-1, startRB+numRBs(p));
    startRB = PRBLimits(2*p);
  end
end
PRBLimits(PRBLimits >= gridSize) = gridSize - 1;
PRBs = "[";
for p=1:numRBGroups
  PRBs = PRBs + PRBLimits(2*p-1) + ":" + PRBLimits(2*p) + " ";
end
PRBs = PRBs + "]";
PRBs = unique(eval(PRBs));

slotLimits = zeros(1,numSlotGroups*2);
startSlot = 2;
for p=1:numSlotGroups
  if 8 - sum(numSlots(p:end)) - startSlot > 0
    startSlot = startSlot + randi(8 - sum(numSlots(p:end)) - startSlot);
    slotLimits(2*p-1) = startSlot;
    slotLimits(2*p) = slotLimits(2*p-1)+numSlots(p);
    startSlot = slotLimits(2*p);
  elseif 8 - sum(numSlots(p:end)) - startSlot == 0
    startSlot = startSlot + 1;
    slotLimits(2*p-1) = startSlot;
    slotLimits(2*p) = min(10, startSlot+numSlots(p));
    startSlot = slotLimits(2*p);
  end
end
slotLimits(slotLimits==0) = [];
slots = "[";
for p=1:2:numel(slotLimits)
  slots = slots + slotLimits(p) + ":" + slotLimits(p+1) + " ";
end
slots = slots + "]";
slots = unique(eval(slots));

function x = randFixSum(n,s)
m=1:s;
a=m(sort(randperm(s,n)));
x=diff(a);
x(end+1)=s-sum(x);
end
end
