%% This code simulate the AD/DA processing discussed in Chapter 4.8.3 [1]

close all; clear all;

%% parameters.

% analog

analog_fps = 1500;

analog_window_time = 3; %sec

t = 0:1/analog_fps: analog_window_time-1/analog_fps;

% digital

digital_fps = 5;

n = downsample(t,analog_fps/digital_fps);

% ADC: Quantizer

X_m = 1; % Range

B = 10;% Bit number.

%% Signal generation

freq_hz = 1; % Hz.

x_a_1 = 0.5*cos(2*pi*freq_hz*t+0.1);

% add a small high frequency component as asked.

signal_freq = 2; %Hz

x_a_2 = 0.5*cos(2*pi*signal_freq*t+pi/2);

x_a = x_a_1 + x_a_2;

%% ADC

% Sampling

x_s = downsample(x_a,analog_fps/digital_fps);

% Quantizing (abs of input value should not over 1)

% x_d = Quantizing(x_s,B,X_m); % A For complete ADC, a quantizing should

% be added here.

x_d = x_s; % For basic case, we skip the quantizing here.

%% DAC

% up sample / DAC

x_up = upsample(x_d,analog_fps/digital_fps);

% LPF (Reconstruction Filters)

h = intfilt(analog_fps/digital_fps,4,0.9);

%% Important

% please not the parameter 0.9, ideally should be 1 for Nyquist rate.

% 0.9 here is ratio of Nyquist.

% Given known limit band signal, shourter ratio can enhance SNR by oversampling.

% (i,e, here I filterout the freq larger than 2.5(Nyquist rate) * 0.9 = 2.25Hz)

x_r = filter(h,1,x_up);

x_r(1:floor(mean(grpdelay(h)))) = [];

x_r = [x_r zeros(1,floor(mean(grpdelay(h))))];

%% Display

figure;

plot(t,x_a);

hold on;

plot(n,x_d);

plot(t,x_r);

title('analog signal (1500Hz) v.s. digital signal (5Hz) v.s. Reconstructed signal (1500Hz)');

legend('x_a','x_d','x_r');