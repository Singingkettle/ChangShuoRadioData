clc;clear;close all;
rng('default')
addpath(genpath('visualizaion'));
addpath(genpath('myPA'));
addpath(genpath('myFIR'));
addpath(genpath('params_list'));


% Selecting params
% 57*7 matrix
% amp 17,47,57
% pha 1,17,33
% DC 1,10,16
% phn 17,20,24
% PA 20,21,22,23

% 1,10,16,17,20,21,22,23,24,33,47,57

% Getting transmitter object
% for 

load params_lists_1e-3_1e-2.mat


% 修改amp
% 保留17，并复制到47,57，将47,57改为1.5和2
params_lists(47, :) = params_lists(17, :);
params_lists(57, :) = params_lists(17, :);
params_lists(47, 2) = 1.5;
params_lists(57, 2) = 2;

% 修改pha
% 保留17，并复制到1,13，修改1，33改为12,18
params_lists(1, :) = params_lists(17, :);
params_lists(33, :) = params_lists(17, :);
params_lists(1, 3) = 12;
params_lists(33, 3) = 18;

% 修改DC
% 保留1，并复制到10,16，修改10,16改为2.5和3
params_lists(10, :) = params_lists(1, :);
params_lists(16, :) = params_lists(1, :);
params_lists(10, 4) = 2.5;
params_lists(16, 4) = 3;

% 修改phn
% 保留17，并复制到20,24，固定20，24的phn
params_lists(20, :) = params_lists(17, :);
params_lists(24, :) = params_lists(17, :);
params_lists(20, 5) = -65;
params_lists(24, 5) = -60;

transmitterargs.index = [1,10,16,17,20,21,22,23,24,33,47,57];
transmitterargs.num = length(transmitterargs.index);
sys1 = emitter_system();
sys1.flag_plot = false;

% Making datasets and showing results
SNR = [20];%dB
for SNR_set = SNR
    for i = 1:transmitterargs.num        % 遍历12种发射机参数
        tic;
        index = transmitterargs.index(i);
        transmitterargs.choice = index;  % 编号0到9的功放系数
        
        sys1.ampImb = params_lists(index, 2);
        sys1.phImb = params_lists(index, 3);
        sys1.dcOffset = params_lists(index, 4);
        
        sys1.phaseNoise_level = params_lists(index, 5);
        
        sys1.nonlinear_order = params_lists(index, 6);
        sys1.memory_depth = params_lists(index, 7);
        
        % sample args
        sigargs.length_seg = 1024*2;
        sigargs.num_perEmitter = 400;
        
        % bit args
        sys1.numBits = (sigargs.length_seg * sigargs.num_perEmitter)/sys1.sps * log2(sys1.modOrder) + sys1.span * log2(sys1.modOrder);
        
        sys1.snr = SNR_set;
        sys1.freq_offset = 0;
        
        [dataIn_tx, dataIn] = sys1.get_signal_tx();
        dataIn_cha = sys1.get_signal_channel(dataIn_tx);
        
        sigargs.format.output = "pic";
        sigargs.format.preprocess = "density";
        sigargs.label = "sample";
        
        sys1.cut_save(dataIn_cha(sys1.span*sys1.sps+1:end), sigargs, transmitterargs, sys1.snr);
        toc;
        disp(['SNR= ',num2str(SNR_set),', PA= ',num2str(i-1),', time= ',num2str(toc)]);

    end
end


























