clc
clear
close all

addpath(genpath('../csrd'))
cfgs = load_config('../config/_base_/simulate/ChangShuo/CSRD2024.json');
cfgs = cfgs.runner;
DataCollection = sprintf("%s(NumFrames=cfgs.NumFrames, Seed=cfgs.Seed, Log=cfgs.Log, Data=cfgs.Data, Physical=cfgs.Physical)", cfgs.handle);
DataCollection = eval(DataCollection);
DataCollection(3, 10)