clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = [4 8 20];
SamplePerSymbol = 2;

ModulatorConfig.ModulationOrder = ModulationOrder;
ModulatorConfig.Radii = [0.3 0.7 1.2];
ModulatorConfig.PhaseOffset = [0 0 0];
ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = APSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);

% 多天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = [4 8 20];
SamplePerSymbol = 2;
NumTransmitAntennnas = 2;

ModulatorConfig.ModulationOrder = ModulationOrder;
ModulatorConfig.Radii = [0.3 0.7 1.2];
ModulatorConfig.PhaseOffset = [0 0 0];
ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;
source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = APSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    NumTransmitAntennnas = NumTransmitAntennnas, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);