clc
clear
close all
% Generate train data
spses = [12, 15, 16];        % Set of samples per symbol
spf = 1200;                  % Samples per frame
sr = 150e3;                  % Sample rate

% Modulator set
modulationTypes = ["BPSK", "QPSK", "8PSK", "16QAM", "64QAM"];

% Channel set
% https://www.mathworks.com/help/comm/ug/fading-channels.html#a1069863931b1
% For indoor environments, path delays after the first are typically between 1e-9 seconds and 1e-7 seconds.
% For outdoor environments, path delays after the first are typically between 1e-7 seconds and 1e-5 seconds. 
% Large delays in this range might correspond, for example, to an area surrounded by mountains.
rayleigh_channel = comm.RayleighChannel( ...
      'SampleRate', sr, ...
      'PathDelays', [0 1.8 3.4] / 10000000, ...
      'AveragePathGains', [0 -2 -10], ...
      'MaximumDopplerShift', 4);

rician_channel = comm.RicianChannel(...
        'SampleRate', sr, ...
        'PathDelays', [0 1.8 3.4] / 10000000, ...
        'AveragePathGains', [0 -2 -10], ...
        'KFactor', 4, ...
        'MaximumDopplerShift', 4);

channels.rayleigh = rayleigh_channel;
channels.rician = rician_channel;
frequency_shifter = comm.PhaseFrequencyOffset('SampleRate', sr);

data_id = 0;
for dB=-6:2:20
    for i=1:1000
        data_id = data_id + 1;
        fprintf('Generate data of number %05d.\n', data_id);
        y = simulate_transmitter(-sr/2, sr/2, sr, spf, spses, modulationTypes);
        y = pass_channels(y, channels, frequency_shifter, dB);
        is_ok = save_item(y, 55, data_id, spf);
    end
end
function new = pass_channels(x, channels, frequency_shifter, dB)

static_speed = 0;
pedestrian_speed = 1.1;
car_speed = 12;

speeds = [static_speed pedestrian_speed car_speed];


% =========================================================================
% Real: 
%      1）随机从瑞利信道和莱斯信道选择；
%      2）物体的速度随机选择；
%      3）物体的噪声随机选择；
%      4）采用固定的clockOffset，由maxOffset=5得到
% =========================================================================
new = {};
for sub_signal_index=1:length(x)
    new_sub = x{sub_signal_index};
    cid = randi(2);
    speed = speeds(randi(length(speeds)));
    if cid==1
        c = channels.rician;
        c.MaximumDopplerShift = abs(new_sub.center_frequency) * speed / 3e8;
        c.KFactor = 4;
        new_sub.channel = sprintf('rician_MaximumDopplerShift-%02d_KFactor-%02d', c.MaximumDopplerShift, c.KFactor);
    else
        c = channels.rayleigh;
        c.MaximumDopplerShift = abs(new_sub.center_frequency) * speed / 3e8;
        new_sub.channel = sprintf('rayleigh_MaximumDopplerShift-%02d', c.MaximumDopplerShift);
    end

    new_sub.snr = sprintf('%ddB', dB);
    data = c(new_sub.data);
    data = add_clock_offset(data, 5, new_sub.sample_rate, ...
        frequency_shifter, abs(new_sub.center_frequency));
    new_sub.data = awgn(data, dB);
    new = [new, new_sub];
    release(c);
end


end


function is_ok = save_item(y, version, item_index, spf)

signal_data = zeros(length(y), 2, spf);
signal_info.center_frequency = zeros(length(y), 1);
signal_info.bandwidth = zeros(length(y), 1);
signal_info.snr = strings(length(y), 1);
signal_info.modulation = strings(length(y), 1);
signal_info.channel = strings(length(y), 1);
signal_info.sample_rate = zeros(length(y), 1);
signal_info.sample_num = zeros(length(y), 1);
signal_info.sample_per_symbol = zeros(length(y), 1);
for j=1:length(y)
    y{j}.data(isnan(y{j}.data)) = 0;
    signal_data(j, 1, :) = real(y{j}.data);
    signal_data(j, 2, :) = imag(y{j}.data);
    signal_info.center_frequency(j, 1) = y{j}.center_frequency;
    signal_info.bandwidth(j, 1) = y{j}.bandwidth;
    signal_info.snr(j, 1) = y{j}.snr;
    signal_info.modulation(j, 1) = y{j}.modulation;
    signal_info.channel(j, 1) = y{j}.channel;
    signal_info.sample_rate(j, 1) = y{j}.sample_rate;
    signal_info.sample_num(j, 1) = y{j}.sample_num;
    signal_info.sample_per_symbol(j, 1) = y{j}.sample_per_symbol;
end
signal_info.file_name = sprintf('%06d.mat', item_index);
s = jsonencode(signal_info, 'PrettyPrint', true);

if ~exist(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d', version), 'dir')
    mkdir(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d', version));
    mkdir(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d/anno', version));
    mkdir(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d/sequence_data', version));
    mkdir(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d/sequence_data/iq', version));
end

fid = fopen(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d/anno/%06d.json', version, item_index),'w');
fprintf(fid, s); 
fclose(fid);

save(sprintf('D:/Projects/ChangShuoRadioRecognition/data/ChangShuo/v%d/sequence_data/iq/%06d.mat', version, item_index),  'signal_data');

is_ok = 1;

end