clc
clear
close all


% Load Simulation configs

cfgs = load_config('../config/_base_/simulate/ChangShuo/CSRD2024.json');
cfgs = cfgs.runner;
DataCollection = sprintf("%s(NumFrames=cfgs.NumFrames, Seed=cfgs.Seed, LogLevel=cfgs.LogLevel, Data=cfgs.Data, Physical=cfgs.Physical)", cfgs.handle);
DataCollection = eval(DataCollection);
DataCollection()