clc
clear
close all

% Test FM
ModulatorConfig.frequencyDeviation = 75e3;
ModulatorConfig.initPhase = pi / 4;

TimeDuration = 1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);

baseBandSignal = FM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x = source();
y = baseBandSignal(x);
