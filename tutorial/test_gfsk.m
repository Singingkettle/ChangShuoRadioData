clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 8;
SamplePerSymbol = 32;


ModulatorConfig.BandwidthTimeProduct = 0.35;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = GFSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);

% Simple test for filter
M = 2; % Modulation order
gfskMod = comm.CPMModulator( ...
    'ModulationOrder',M, ...
    'FrequencyPulse','Gaussian', ...
    'BandwidthTimeProduct',0.5, ...
    'ModulationIndex',1, ...
    'BitInput',false);
gfskDemod = comm.CPMDemodulator( ...
    'ModulationOrder',M, ...
    'FrequencyPulse','Gaussian', ...
    'BandwidthTimeProduct',0.5, ...
    'ModulationIndex',1, ...
    'BitOutput',false);
spf = 10000;        % Symobls per frame


data = randi([0 M-1],spf,1);
const = (-(M-1):2:(M-1))';
data = const((data(:)+1));
modSignal = gfskMod(data);
bw = obw(modSignal, SampleRate);
y = lowpass(modSignal, bw*0.8, SampleRate, ImpulseResponse="fir", Steepness=0.99);
receivedData = gfskDemod(modSignal);
delay = finddelay(data,receivedData);
errorRate = comm.ErrorRate( ...
    ReceiveDelay=delay);
isequal(data(1:end-delay),receivedData(delay+1:end))
errorStats = errorRate(data,receivedData);

receivedData1 = gfskDemod(y);
errorStats1 = errorRate(data,receivedData1);