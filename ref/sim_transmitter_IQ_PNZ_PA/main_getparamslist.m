clc;clear;close all;
rng('default');
addpath(genpath('visualizaion'));
addpath(genpath('myPA'));
addpath(genpath('myFIR'));

sys1 = emitter_system();
sys1.flag_plot = false;
% numBits = 10040;
% dataIn = randi([0 1], numBits, 1); 
% s1 = sys1.get_signal_tx(dataIn);
% s1_cha = sys1.get_signal_channel(s1);
% dataOut = sys1.get_signal_bits(s1_cha);
% errStats = sys1.cal_BER(dataIn, dataOut);

params_lists = [];
num_items = 0;

ampImb_list = 1:2:5;%dB
phImb_list = 5:10:25;% 10:5:20 % deg
dcOffset_list = 2:2:6;% 1:1:3 % percentage (0~100)
pNoise_list = -70:5:-60;%dB
PA_order_list = [1,7];
PA_memory_list = [1,4];
num_for = length(ampImb_list)*length(phImb_list)*length(dcOffset_list)*length(pNoise_list)*length(PA_order_list)*length(PA_memory_list);

for ampImb = ampImb_list
    for phImb = phImb_list
        for dcOffset = dcOffset_list
            for pNoise = pNoise_list
                for PA_order = PA_order_list
                    for PA_memory = PA_memory_list
                        tic
                        sys1.ampImb = ampImb;
                        sys1.phImb = phImb;
                        sys1.dcOffset = dcOffset;
                        
                        sys1.phaseNoise_level = pNoise;
                        
                        sys1.nonlinear_order = PA_order;
                        sys1.memory_depth = PA_memory;
                        
                        sys1.numBits = 10040;
                        
                        [dataIn_tx, dataIn] = sys1.get_signal_tx();
                        dataIn_cha = sys1.get_signal_channel(dataIn_tx);
                        dataOut = sys1.get_signal_bits(dataIn_cha);
                        errStats = sys1.cal_BER(dataIn, dataOut);
                        
                        
                        if errStats(1) < 1e-2 && errStats(1) > 1e-3
                            params = [errStats(1), ampImb, phImb, dcOffset, pNoise, PA_order, PA_memory]
                            params_lists = [params_lists; params];
                        end
                        num_items = num_items + 1;
                        each_time = toc;
                        disp(['current_time = ',num2str(num_items),', all_time= ',num2str(num_for)]);
                        disp([', est_time(min:s) = ',num2str(floor(each_time*(num_for - num_items)/60)),...
                            ':',num2str(floor(mod(each_time*(num_for - num_items),60)))]);
                    end
                end
            end
        end
    end
end

save('./params_list/params_lists_1e-3_1e-2.mat','params_lists','ampImb_list','phImb_list',...
    'dcOffset_list','pNoise_list','PA_order_list','PA_memory_list');








