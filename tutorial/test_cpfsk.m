clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 4;
SamplePerSymbol = 8;


ModulatorConfig.ModulationIndex = 0.5;
ModulatorConfig.InitialPhaseOffset = 0;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = CPFSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);


% Simple test for filter
M = 8; % Modulation order
cpfskMod = comm.CPFSKModulator(M, ...
    BitInput=false, SamplesPerSymbol=32);
awgnChan = comm.AWGNChannel( ...
    NoiseMethod='Signal to noise ratio (SNR)', ...
    SNR=0);
cpfskDemod = comm.CPFSKDemodulator(M, ...
    BitOutput=false, SamplesPerSymbol=32);
spf = 10000;        % Symobls per frame

delay = cpfskDemod.TracebackDepth;
errorRate = comm.ErrorRate( ...
    ReceiveDelay=delay);
data = randi([0 M-1],spf,1);
const = (-(M-1):2:(M-1))';
data = const(data(:)+1);
modSignal = cpfskMod(data);
bw = obw(modSignal, SampleRate);
y = lowpass(modSignal, bw*0.9, SampleRate, ImpulseResponse="fir", Steepness=0.99);
receivedData = cpfskDemod(modSignal);
errorStats = errorRate(data,receivedData);

receivedData1 = cpfskDemod(y);
errorStats1 = errorRate(data,receivedData1);