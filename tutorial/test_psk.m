clc
clear
close all

% 单天线场景
SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 4;
SamplePerSymbol = 8;

ModulatorConfig.Differential = true;
ModulatorConfig.PhaseOffset = pi/8;
ModulatorConfig.SymbolOrder = 'gray';
ModulatorConfig.beta = 0.35;
ModulatorConfig.span = 4;

source = RandomSource(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol);

modualtor = PSK(SampleRate=SampleRate, ...
    TimeDuration=TimeDuration, ...
    ModulationOrder=ModulationOrder, ...
    SamplePerSymbol=SamplePerSymbol, ...
    ModulatorConfig=ModulatorConfig);

x = source();
y = modualtor(x);