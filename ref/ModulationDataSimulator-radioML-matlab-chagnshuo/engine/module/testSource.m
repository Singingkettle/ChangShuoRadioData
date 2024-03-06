%%
% =========================================================================
% Project: ModulationDataSimulator
% Script: Class-> testSource
% Author: Shuo Chang
% Email: changshuo@bupt.edu.cn
% Date: 2020-05-21
% Copyright (c) 2020-present, WTI, BUPT.
% =========================================================================

clc;
clear;
close all;
addpath('./Classes/Source/ANALOG/');
sourceParam.modulatorType = 'VSB';
% sourceParam.M = 2;
% sourceParam.samplePerSymbol = 8;
sourceParam.samplePerFrame = 1024;
sourceParam.sampleRate = 200e3;

% data.help;
Source.helpInfo;
d = Source.create(sourceParam);
y = d();
disp('Test Success!');