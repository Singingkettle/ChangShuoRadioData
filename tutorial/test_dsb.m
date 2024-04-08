clc
clear
close all

iqImbalanceConfig.A = 0;
iqImbalanceConfig.P = 0;

phaseNoiseConfig.Level = -50;
phaseNoiseConfig.FrequencyOffset = 20;
phaseNoiseConfig.RandomStream = 'Global stream';
phaseNoiseConfig.Seed = 2137;

memoryLessNonlinearityConfig.Method = 'Cubic polynomial';
memoryLessNonlinearityConfig.LinearGain = 10;
memoryLessNonlinearityConfig.TOISpecification = 'IIP3';
memoryLessNonlinearityConfig.IIP3 = 30;

modulatorConfig.initPhase = 0;

param.iqImbalanceConfig = iqImbalanceConfig;
param.phaseNoiseConfig = phaseNoiseConfig;
param.memoryLessNonlinearityConfig = memoryLessNonlinearityConfig;
param.carrierFrequency = 50000;
param.timeDuration = 1;
param.sampleRate = 200e3;
param.modulatorConfig = modulatorConfig;
param.samplePerSymbol = 3;

source = Audio(param);

modualtor = DSBAM(param);

x = source();
y = modualtor(x);
