clc
clear 
close all

% Add Modulator Classification with Deep Learning Tool in the environment
addpath('C:\Users\97147\Documents\MATLAB\Examples\R2022b\deeplearning_shared\ModulatorClassificationWithDeepLearningExample');

rng(123)

load('D.mat');

% Generate train data
numFramesPerModType = 1000;
SNR = 10;
sps = 25;                    % Samples per symbol, must be an even number
spf = 1025;                  % Samples per frame
fs = 200e3;                  % Sample rate

modulationTypes = categorical(["BPSK", "QPSK", "8PSK", "16QAM", "64QAM"]);
channel = MyModClassTestChannel(...
  'SampleRate', fs, ...
  'SNR', SNR, ...
  'PathDelays', [0 1.8 3.4] / fs, ...
  'AveragePathGains', [0 -2 -10], ...
  'KFactor', 4, ...
  'MaximumDopplerShift', 4, ...
  'MaximumClockOffset', 5, ...
  'CarrierFrequency', 902e6);

% channel = comm.AWGNChannel('SNR', SNR);

numModulatorTypes = length(modulationTypes);
tic
transDelay = 50;

i = 0;
two_set = zeros(numModulatorTypes*(numModulatorTypes+1)/2, 2);
for modType1 = 1:numModulatorTypes
    for modType2 = modType1:numModulatorTypes
        i = i+1;
        two_set(i, 1) = modType1;
        two_set(i, 2) = modType2;
    end
end

x = zeros(size(two_set, 1)*numFramesPerModType, 2, spf);
m = zeros(size(two_set, 1)*numFramesPerModType, 2);
b = zeros(size(two_set, 1)*numFramesPerModType, 2);
x_i = 0;
for index = 1:size(two_set, 1)
    elapsedTime = seconds(toc);
    elapsedTime.Format = 'hh:mm:ss';
    fprintf('%s - Generating %s %s frames of %d dB\n', ...
      elapsedTime, modulationTypes(two_set(index, 1)), ...
      modulationTypes(two_set(index, 2)), SNR);
    
    label1 = modulationTypes(two_set(index, 1));
    label2 = modulationTypes(two_set(index, 2));
    dataSrc1 = helperModClassGetSource( ...
        modulationTypes(two_set(index, 1)), sps, spf, fs);
    modulator1 = helperModClassGetModulator( ...
        modulationTypes(two_set(index, 1)), sps, fs);
    
    dataSrc2 = helperModClassGetSource( ...
        modulationTypes(two_set(index, 2)), sps, spf, fs);
    modulator2 = helperModClassGetModulator( ...
        modulationTypes(two_set(index, 2)), sps, fs);

    % Digital modulation types use a center frequency of 902 MHz
    % channel.CarrierFrequency = 902e6;
   
    
    % Set band index in random and move baseban signal to the speicifed
    % sub-band
    bands = ([1:num_bands]-(num_bands+1)/2).*per_carrier;
    exp1 = expWave(bands(3), fs, spf/2);
    exp2 = expWave(bands(2), fs, spf/2);
    band1 = exp1();
    band2 = exp2();
    % Generate random data
    x1 = dataSrc1();
    x2 = dataSrc2();
    
    % Modulate
    y1 = modulator1(x1);
    y2 = modulator2(x2);
   
    % Add carrier
    y3 = y1.*band1;
    y4 = y2.*band2;
    
    % Pass through independent channels
    y5 = channel(y3);
    y6 = channel(y4);
    rxSamples = y5 + y6;

    frame1 = rxSamples.*expWave(-1*bands(3), fs, spf/2);
    frame1 = filter(D,[frame1; zeros(452,1)]);
    frame1 = frame1(453:end,:);
    
    frame2 = rxSamples.*expWave(-1*bands(2), fs, spf/2);
    frame2 = filter(D,[frame2; zeros(452,1)]);
    frame2 = frame2(453:end,:);
       
    frame3 = rxSamples.*expWave(-1*bands(1), fs, spf/2);
    frame3 = filter(D,[frame3; zeros(452,1)]);
    frame3 = frame3(453:end,:);

%     tmp = lowpass(rxSamples, per_carrier/2, fs, ImpulseResponse="fir",Steepness=0.9999);
%     y_0 = rxSamples1.*expWave(-1*bands(1), fs, spf);
%     frame_0 = lowpass(y_0, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
% 
%     y_1 = rxSamples.*expWave(-1*bands(1), fs, spf);
%     frame_1 = lowpass(y_1, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
%     frame_1_ = filter(D,[frame_1; zeros(399,1)]);
%             frame_1_ = frame_1_(400:end,:);
% 
%     y_2 = rxSamples.*expWave(-1*bands(2), fs, spf);
%     frame_2 = lowpass(y_2, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
%     frame_2_ = filter(D,[frame_2; zeros(399,1)]);
%             frame_2_ = frame_2_(400:end,:);
% 
%     y_3 = rxSamples.*expWave(-1*bands(3), fs, spf);
%     frame_3 = lowpass(y_3, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
%     frame_3_ = filter(D,[frame_3; zeros(399,1)]);
%             frame_3_ = frame_3_(400:end,:);
% 
%     y_4 = rxSamples.*expWave(-1*bands(4), fs, spf);
%     frame_4 = lowpass(y_4, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
%     frame_4_ = filter(D,[frame_4; zeros(399,1)]);
%             frame_4_ = frame_4_(400:end,:);
% 
%     y_5 = rxSamples.*expWave(-1*bands(5), fs, spf);
%     frame_5 = lowpass(y_5, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
%     frame_5_ = filter(D,[frame_5; zeros(399,1)]);
%             frame_5_ = frame_5_(400:end,:);

%     y_6 = y.*expWave(bands(6), fs, spf);
%     frame_6 = lowpass(y_6, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
% 
%     y_7 = y.*expWave(bands(7), fs, spf);
%     frame_7 = lowpass(y_7, sb/2, fs, ...
%         ImpulseResponse="fir",Steepness=0.9999);
end

function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end