clc
clear 
close all

% Add Modulator Classification with Deep Learning Tool in the environment
addpath('C:\Users\97147\Documents\MATLAB\Examples\R2022b\deeplearning_shared\ModulatorClassificationWithDeepLearningExample');

load('D.mat');

rng(123)

snr_start = -8;
snr_end = 30;
% Generate train data
numFramesPerModType = 70;
for SNR=snr_start:2:snr_end
    [x, m] = generateDataWithSnr(SNR, numFramesPerModType, D);
    train.x = x;
    train.m = m;
    save(sprintf("./pure/train_%02d.mat", SNR),  'train');
end

% Generate val data
numFramesPerModType = 10;
for SNR=snr_start:2:snr_end
    [x, m] = generateDataWithSnr(SNR, numFramesPerModType, D);
    val.x = x;
    val.m = m;
    save(sprintf("./pure/val_%02d.mat", SNR),  'val');
end

% Generate test data
numFramesPerModType = 20;
for SNR=snr_start:2:snr_end
    [x, m] = generateDataWithSnr(SNR, numFramesPerModType, D);
    test.x = x;
    test.m = m;
    save(sprintf("./pure/test_%02d.mat", SNR), 'test');
end

function [x, m] = generateDataWithSnr(SNR, numFramesPerModType, D)

sps = 25;               % Samples per symbol, must be an even number
spf = 1025;             % Samples per frame
fs = 200e3;             % Sample rate
num_bands = 5;
atom_carrier = fs / num_bands;

modulationTypes = categorical(["BPSK", "QPSK", "8PSK", "16QAM", "64QAM"]);
modulationTypes_index = 0:4;
channel = MyModClassTestChannel(...
  'SampleRate', fs, ...
  'SNR', SNR, ...
  'PathDelays', [0 1.8 3.4] / fs, ...
  'AveragePathGains', [0 -2 -10], ...
  'KFactor', 4, ...
  'MaximumDopplerShift', 4, ...
  'MaximumClockOffset', 5, ...
  'CarrierFrequency', 902e6);

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

x = zeros(size(two_set, 1)*numFramesPerModType*2, 2, spf);
m = zeros(size(two_set, 1)*numFramesPerModType*2, 1);
x_i = 0;
for index = 1:size(two_set, 1)
    elapsedTime = seconds(toc);
    elapsedTime.Format = 'hh:mm:ss';
    fprintf('%s - Generating %s %s frames of %d dB\n', ...
      elapsedTime, modulationTypes(two_set(index, 1)), ...
      modulationTypes(two_set(index, 2)), SNR);
    
    label1 = modulationTypes_index(two_set(index, 1));
    label2 = modulationTypes_index(two_set(index, 2));
    dataSrc1 = helperModClassGetSource( ...
        modulationTypes(two_set(index, 1)), sps, spf, fs);
    modulator1 = helperModClassGetModulator( ...
        modulationTypes(two_set(index, 1)), sps, fs);
    
    dataSrc2 = helperModClassGetSource( ...
        modulationTypes(two_set(index, 2)), sps, spf, fs);
    modulator2 = helperModClassGetModulator( ...
        modulationTypes(two_set(index, 2)), sps, fs);
   
    for p=1:numFramesPerModType
        % Set band index in random and move baseban signal to the speicifed
        % sub-band
        bands_index = randperm(num_bands);
        bands = (bands_index-(num_bands+1)/2).*atom_carrier;
        exp1 = expWave(bands(1), fs, spf/2);
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
        
        % Remove transients from the beginning, trim to size, and normalize
        
        frame1 = rxSamples.*expWave(-1*bands(1), fs, spf/2);
        frame1 = filter(D,[frame1; zeros(452,1)]);
        frame1 = frame1(453:end,:);
            
        x_i = x_i + 1;
        x(x_i, 1, :) = real(frame1);
        x(x_i, 2, :) = imag(frame1);
        m(x_i, 1) = label1;
        
        frame2 = rxSamples.*expWave(-1*bands(2), fs, spf/2);
        frame2 = filter(D,[frame2; zeros(452,1)]);
        frame2 = frame2(453:end,:);
            
        x_i = x_i + 1;
        x(x_i, 1, :) = real(frame2);
        x(x_i, 2, :) = imag(frame2);
        m(x_i, 1) = label2;

    end
end

end

function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end