clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 16;
SamplePerSymbol = 4;

ModulatorConfig.stdSuffix = 's2';
ModulatorConfig.codeIDF = '2/3';
ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = DVBSAPSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);

% 多天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 16;
SamplePerSymbol = 4;
NumTransmitAntennnas = 2;

ModulatorConfig.stdSuffix = 's2';
ModulatorConfig.codeIDF = '2/3';
ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = DVBSAPSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    NumTransmitAntennnas = NumTransmitAntennnas, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);