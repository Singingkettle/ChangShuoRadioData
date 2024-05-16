clear
clc
close all

SampleRate = 200e3;
TimeDuration = 1;
ModulationOrder = 4;
SamplePerSymbol = 8;
NumTransmitAntennnas = 1;
NumDataSubcarriers = 48;

ModulatorConfig.base.mode = 'QPSK';
ModulatorConfig.base.PhaseOffset = pi/8;
ModulatorConfig.base.SymbolOrder = 'gray';
ModulatorConfig.ofdm.FFTLength = 128;
ModulatorConfig.ofdm.CyclicPrefixLength = 16;
ModulatorConfig.ofdm.OversamplingFactor = 1;

source = RandomSource(SampleRate = SampleRate, ...
    TimeDuration = TimeDuration, ...
    ModulationOrder = ModulationOrder, ...
    SamplePerSymbol = SamplePerSymbol);

modualtor = SCFDMA(SampleRate = SampleRate, ...
    TimeDuration = TimeDuration, ...
    NumDataSubcarriers = NumDataSubcarriers, ...
    ModulationOrder = ModulationOrder, ...
    SamplePerSymbol = SamplePerSymbol, ...
    ModulatorConfig = ModulatorConfig);

x = source();
y = modualtor(x);