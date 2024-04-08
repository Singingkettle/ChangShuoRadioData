clc
clear
close all

% Test DSBAM
ModulatorConfig.carramp = 1;
ModulatorConfig.initPhase = 0;
TimeDuration = 1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);

baseBandSignal = DSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x = source();
y = baseBandSignal(x);

% Test DSSCBAM
ModulatorConfig.initPhase = 0;
TimeDuration = 1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);

baseBandSignal = DSBSCAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x = source();
y = baseBandSignal(x);

% Test SSBAM
ModulatorConfig.fa = 3000;
ModulatorConfig.mode = 'upper';
ModulatorConfig.initPhase = 0;
TimeDuration = 1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);

baseBandSignal = SSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x = source();
y = baseBandSignal(x);

% Test VSBAM
ModulatorConfig.fa = 3000;
ModulatorConfig.mode = 'upper';
ModulatorConfig.initPhase = 0;
TimeDuration = 1;
SampleRate = 200e3;
NumTransmitAntennnas = 1;

source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);

baseBandSignal = VSBAM(ModulatorConfig = ModulatorConfig, NumTransmitAntennnas = NumTransmitAntennnas);

x = source();
y = baseBandSignal(x);
