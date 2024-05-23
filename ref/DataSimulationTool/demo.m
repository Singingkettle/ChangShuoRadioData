clc
clear
close all
% Generate train data
spses = [10, 12, 15];        % Set of samples per symbol
spf = 120000;                  % Samples per frame
sr = 900e6;                  % Sample rate

% Modulation set
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

y = simulate_transmitter(-sr/2, sr/2, sr, spf, spses, modulationTypes);
y = pass_channels(y, channels, frequency_shifter);

y1 = y{1, 1}{1, 1}.data;
y2 = y{1, 2}{1, 1}.data;
y3 = y{1, 3}{1, 1}.data;
y4 = y{1, 4}{1, 1}.data;
y5 = y{1, 5}{1, 1}.data;
y6 = y{1, 6}{1, 1}.data;
y45 = y{1, 45}{1, 1}.data;
y54 = y{1, 54}{1, 1}.data;

function y = pass_channels(x, channels, frequency_shifter)

static_speed = 0;
pedestrian_speed = 1.1;
car_speed = 12;

speeds = [static_speed pedestrian_speed car_speed];
snrs = -6:2:20;

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
            c.MaximumDopplerShift = abs(new_sub.center_frequency) * speeds(i) / 3e8;
            new_sub.snr = 'infdB';
            new_sub.data = c(new_sub.data);
            new_sub.channel = sprintf('rician_MaximumDopplerShift-%02d_KFactor-%02d', c.MaximumDopplerShift, c.KFactor);
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
        c.MaximumDopplerShift = abs(new_sub.center_frequency) * speeds(i) / 3e8;
        new_sub.snr = 'infdB';
        new_sub.data = c(new_sub.data);
        new_sub.channel = sprintf('rayleigh_MaximumDopplerShift-%02d', c.MaximumDopplerShift);
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
    for sub_signal_index=1:length(x)
        new_sub = x{sub_signal_index};
        dB = snrs(i);
        new_sub.data = awgn(new_sub.data, dB);
        new_sub.channel = sprintf('awgn-%02ddB', dB);
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
        new_sub.channel = sprintf('clockOffset_maxOffset-%02d', maxOffset);
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
        c.MaximumDopplerShift = abs(new_sub.center_frequency) * speed / 3e8;
        c.KFactor = 4;
        new_sub.channel = sprintf('rician_MaximumDopplerShift-%02d_KFactor-%02d', c.MaximumDopplerShift, c.KFactor);
    else
        c = channels.rayleigh;
        c.MaximumDopplerShift = abs(new_sub.center_frequency) * speed / 3e8;
        new_sub.channel = sprintf('rayleigh_MaximumDopplerShift-%02d', c.MaximumDopplerShift);
    end
    
    dB = snrs(randi(length(snrs)));
    new_sub.snr = sprintf('%ddB', dB);
    data = c(new_sub.data);
    data = add_clock_offset(data, 5, new_sub.sample_rate, ...
        frequency_shifter, abs(new_sub.center_frequency));
    new_sub.data = awgn(data, dB);
    new = [new, new_sub];
    release(c);
end
new = {new};
y = [y new];

end