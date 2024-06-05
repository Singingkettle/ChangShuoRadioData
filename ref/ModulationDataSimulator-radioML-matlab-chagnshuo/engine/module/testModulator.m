%%
% =========================================================================
% Project: ModulationDataSimulator
% Script: Class-> testModulation
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================

clc;
clear;
close all;
restoredefaultpath;
addpath('./Classes/Source/ANALOG/');
addpath('./Classes/Modulation');
addpath('./Classes/Modulation/ANALOG/');
addpath('./Classes/Channel/gaussianNoise/');

sourceParam.modulatorType = 'VSB';
sourceParam.M = 2;
sourceParam.samplePerSymbol = 8;
sourceParam.samplePerFrame = 1024;
sourceParam.sampleRate = 200e3;

channelParam.snr = 30;
channelParam.centerFrequency = 902e6;
channelParam.sampleRate = 200e3;
channelParam.pathDelays = [0 1.8 3.4] / 200e3;
channelParam.averagePathGains = [0 -2 -10];
channelParam.kfactor = 4;
channelParam.maximumDopplerShift = 4;
channelParam.maximumClockOffset = 5;
channelParam.channelType = 'whiteGaussian';

filterParam.rolloffFactor = 0.35;
filterParam.numSymbol = 4;
filterParam.samplePerSymbol = sourceParam.samplePerSymbol;
filterParam.shape = 'sqrt';
filterCoefficients = generate(filterParam);

modulatorParam.sourceParam = sourceParam;
modulatorParam.channelParam = channelParam;
modulatorParam.modulatorType = sourceParam.modulatorType;
modulatorParam.filterCoefficients = filterCoefficients;
modulatorParam.rolloffFactor = filterParam.rolloffFactor;
modulatorParam.numSymbol = filterParam.numSymbol;
modulatorParam.samplePerSymbol = sourceParam.samplePerSymbol;
modulatorParam.samplePerFrame = sourceParam.samplePerFrame;
modulatorParam.symbolRate = channelParam.sampleRate;
modulatorParam.sampleRate = channelParam.sampleRate;
modulatorParam.windowLength = sourceParam.samplePerFrame;
modulatorParam.stepSize = sourceParam.samplePerFrame;
modulatorParam.offset = 50;
modulatorParam.filePrefix = '';
modulatorParam.repeatedNumber = 1;

Modulation.helpInfo;
d = Modulation.create(modulatorParam);

y = d();
disp('Test Success!');

function f = generate(filterParam)

f = rcosdesign(filterParam.rolloffFactor, filterParam.numSymbol, ...
    filterParam.samplePerSymbol, filterParam.shape);

end