%%
% =========================================================================
% Project: ModulationDataSimulator
% Script: Class-> testChannel
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================

clc;
clear;
close all;
addpath('./Classes/Channel/gaussianNoise/');
channelParam.snr = 30;
channelParam.centerFrequency = 902e6;
channelParam.sampleRate = 200e3;
channelParam.pathDelays = [0 1.8 3.4] / 200e3;
channelParam.averagePathGains = [0 -2 -10];
channelParam.kfactor = 4;
channelParam.maximumDopplerShift = 4;
channelParam.maximumClockOffset = 5;
channelParam.channelType = 'whiteGaussian';

Channel.helpInfo;
d = Channel.create(channelParam);
x = complex(rand(2048, 1));
y = d(x);
disp('Test Success!');