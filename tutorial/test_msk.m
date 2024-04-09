clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 2;
SamplePerSymbol = 8;

ModulatorConfig.DataEncode = 'diff';
ModulatorConfig.InitPhase = 0;

source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = MSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);