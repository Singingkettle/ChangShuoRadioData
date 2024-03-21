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

modulatorConfig.beta = 0.35;
modulatorConfig.span = 4;
modulatorConfig.order = 4;

param.iqImbalanceConfig = iqImbalanceConfig;
param.phaseNoiseConfig = phaseNoiseConfig;
param.memoryLessNonlinearityConfig = memoryLessNonlinearityConfig;
param.carrierFrequency = 60000;
param.timeDuration = 1;
param.sampleRate = 200e3;
param.modulatorConfig = modulatorConfig;
param.samplePerSymbol = 8;

source = RandomSource(param);

modualtor = PSK(param);

x = source();
y = modualtor(x);