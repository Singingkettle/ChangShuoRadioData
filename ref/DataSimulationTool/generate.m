clc
clear
close all
% Generate train data
spses = [10, 12, 15];        % Set of samples per symbol
spf = 12000;                  % Samples per frame
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

for i=1:1000
    fprintf('Generate data of number %05d.\n', i);
    y = simulate_transmitter(-sr/2, sr/2, sr, spf, spses, modulationTypes);
    % a = 0;
    % for version=1:length(y)
    %     a = a + y{version}.data;
    % end
    y = pass_channels(y, channels, frequency_shifter);
    for version=1:length(y)
        is_ok = save_item(y{version}, version, i, spf);
    end
end

function y = pass_channels(x, channels, frequency_shifter)

% static_speed = 0;
% pedestrian_speed = 1.1;
% car_speed = 12;

speeds = 0:2:12;
snrs = -8:2:30;

% Res
y = {};

% =========================================================================
% Ideal: 理想信道条件下，没有噪声，没有衰落，没有频偏相偏
% =========================================================================
new = {};
for sub_signal_index=1:length(x)
    new_sub = x{sub_signal_index};
    new_sub.channel = 'ideal';
    new_sub.snr = 'infdB';
    new = [new, new_sub];
end
y = {new};

% =========================================================================
% Rician: 莱斯信道条件下, 不同的多普勒偏移，不同的KFactor
% =========================================================================
c = channels.rician;
for i=1:length(speeds)
    for k=1:10
        new = {};
        c.KFactor = k;
        for sub_signal_index=1:length(x)
            new_sub = x{sub_signal_index};
            c.MaximumDopplerShift =  900e6 * speeds(i) / 3e8;
            new_sub.snr = 'infdB';
            new_sub.data = c(new_sub.data);
            new_sub.channel = sprintf('rician_speed_%d', speeds(i));
            new = [new, new_sub];
            release(c);
        end
        new = {new};
        y = [y new];
    end
end

% =========================================================================
% Rayleigh: 瑞利信道条件下
% =========================================================================
c = channels.rayleigh;
for i=1:length(speeds)
    new = {};
    for sub_signal_index=1:length(x)
        new_sub = x{sub_signal_index};
        c.MaximumDopplerShift =  900e6 * speeds(i) / 3e8;
        new_sub.snr = 'infdB';
        new_sub.data = c(new_sub.data);
        new_sub.channel = sprintf('rayleigh_speed_%d', speeds(i));
        new = [new, new_sub];
        release(c);
    end
    new = {new};
    y = [y new];
end

% =========================================================================
% Awgn: 加性高斯白噪声信道条件下，噪声水平变化
% =========================================================================
for i=1:length(snrs)
    new = {};
    dB = snrs(i);
    for sub_signal_index=1:length(x)
        new_sub = x{sub_signal_index};
        if sub_signal_index == 1
            new_sub.data = awgn(new_sub.data, dB);
        end
        new_sub.channel = sprintf('awgn-%ddB', dB);
        new_sub.snr = sprintf('%ddB', dB);
        new = [new, new_sub];
    end
    new = {new};
    y = [y new];
end

% =========================================================================
% ClockOffset: 接收到的信号受时钟偏移影响，时钟偏移值变化
% =========================================================================
for maxOffset=1:2:9
    new = {};
    for sub_signal_index=1:length(x)
        new_sub = x{sub_signal_index};
        new_sub.snr = 'infdB';
        new_sub.data = add_clock_offset(new_sub.data, maxOffset, ...
            new_sub.sample_rate, frequency_shifter, ...
            abs(new_sub.center_frequency));
        new_sub.channel = sprintf('clockOffset_maxOffset-%d', maxOffset);
        new = [new, new_sub];
    end
    new = {new};
    y = [y new];
end

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
        c.KFactor = 5;
    else
        c = channels.rayleigh;
    end
    c.MaximumDopplerShift =  900e6 * speed / 3e8;
    new_sub.channel = 'real';
    dB = snrs(randi(length(snrs)));
    new_sub.snr = sprintf('%ddB', dB);
    data = c(new_sub.data);
    data = add_clock_offset(data, 5, new_sub.sample_rate, ...
        frequency_shifter, abs(new_sub.center_frequency));
    if sub_signal_index == 1
        new_sub.data = awgn(new_sub.data, dB);
    end
    new = [new, new_sub];
    release(c);
end
new = {new};
y = [y new];


% =========================================================================
% Real: 
%      1）随机从瑞利信道和莱斯信道选择；
%      2）物体的速度随机选择；
%      3）物体的噪声固定选择；
%      4）采用固定的clockOffset，由maxOffset=5得到
% =========================================================================

for i=1:length(snrs)
    new = {};
    dB = snrs(i);
    for sub_signal_index=1:length(x)
        new_sub = x{sub_signal_index};
        cid = randi(2);
        speed = speeds(randi(length(speeds)));
        if cid==1
            c = channels.rician;
            c.KFactor = 5;
        else
            c = channels.rayleigh;
        end
        c.MaximumDopplerShift =  900e6 * speed / 3e8;
        new_sub.channel = sprintf('real_awgn-%ddB', dB);
        new_sub.snr = sprintf('%ddB', dB);
        data = c(new_sub.data);
        data = add_clock_offset(data, 5, new_sub.sample_rate, ...
            frequency_shifter, abs(new_sub.center_frequency));
        if sub_signal_index == 1
            new_sub.data = awgn(data, dB);
        end
        new = [new, new_sub];
        release(c);
    end
    new = {new};
    y = [y new];
end

end


function is_ok = save_item(y, version, item_index, spf)

signal_data = zeros(length(y), 2, spf/10);
signal_info.center_frequency = zeros(length(y), 1);
signal_info.bandwidth = zeros(length(y), 1);
signal_info.snr = strings(length(y), 1);
signal_info.modulation = strings(length(y), 1);
signal_info.channel = strings(length(y), 1);
signal_info.sample_rate = zeros(length(y), 1);
signal_info.sample_num = zeros(length(y), 1);
signal_info.sample_per_symbol = zeros(length(y), 1);
a = 0;
for j=1:length(y)
    y{j}.data(isnan(y{j}.data)) = 0;
    signal_data(j, 1, :) = real(y{j}.data);
    signal_data(j, 2, :) = imag(y{j}.data);
    a = a + y{j}.data;
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

if ~exist(sprintf('./data/ChangShuo/v%d', version), 'dir')
    mkdir(sprintf('./data/ChangShuo/v%d', version));
    mkdir(sprintf('./data/ChangShuo/v%d/anno', version));
    mkdir(sprintf('./data/ChangShuo/v%d/sequence_data', version));
    mkdir(sprintf('./data/ChangShuo/v%d/sequence_data/iq', version));
end

fid = fopen(sprintf('./data/ChangShuo/v%d/anno/%06d.json', version, item_index),'w');
fprintf(fid, s); 
fclose(fid);

save(sprintf('./data/ChangShuo/v%d/sequence_data/iq/%06d.mat', version, item_index),  'signal_data');

is_ok = 1;

end