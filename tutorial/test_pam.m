clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 4;
SamplePerSymbol = 8;

ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;

source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = PAM(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);