clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 2;
SamplePerSymbol = 8;


ModulatorConfig.BandwidthTimeProduct = 0.3;
ModulatorConfig.PulseLength = 4;
ModulatorConfig.SymbolPrehistory = 1;
ModulatorConfig.InitialPhaseOffset = 0;

source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = GMSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);