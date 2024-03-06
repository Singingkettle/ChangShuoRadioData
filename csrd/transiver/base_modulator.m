function m = base_modulator(modType, sps, fs, filterCoeffs)
% 本方程主要基于符号序列产生基带调制信号（不包含载频）。
% 通过查阅《通信原理》这本书可知从基带信号的角度来看，PAM和ASK是一致的

switch modType
  % order 2 has 7 categories
  case "OOK"
    m = @(x)ookModulator(x, sps, filterCoeffs);    
  case "GFSK"
    m = @(x)gfskModulator(x, sps);
  case "CPFSK"
    m = @(x)cpfskModulator(x, sps);
  case "MSK"
    m = @(x)mskModulator(x, sps);  
  case "GMSK"
    m = @(x)gmskModulator(x, sps);
  case "BPSK"
    m = @(x)pskModulator(x, 2, sps, filterCoeffs);
  case "DBPSK"
    m = @(x)dbpskModulator(x, sps, filterCoeffs); 
  case "2PAM"
    m = @(x)pamModulator(x, 2, sps, filterCoeffs);
  case "2ASK"
    m = @(x)pamModulator(x, 2, sps, filterCoeffs);
  case "2FSK"
    m = @(x)fskModulator(x, 2, sps, fs);
  
  % order 4 has 3 categories
  case "4PAM"
    m = @(x)pamModulator(x, 4, sps, filterCoeffs);
  case "4ASK"
    m = @(x)pamModulator(x, 4, sps, filterCoeffs);
  case "QPSK"
    m = @(x)pskModulator(x, 4, sps, filterCoeffs);
  case "OQPSK"
    m = @(x)oqpskModulator(x, sps, filterCoeffs);
  case "DQPSK"
    m = @(x)dqpskModulator(x, sps, filterCoeffs, 0);
  case "Pi/4-DQPSK"
    m = @(x)dqpskModulator(x, sps, filterCoeffs, pi/4);

  % order 8 has 3 categories
  case "8PAM"
    m = @(x)pamModulator(x, 8, sps, filterCoeffs);
  case "8ASK"
    m = @(x)pamModulator(x, 8, sps, filterCoeffs);
  case "8PSK"
    m = @(x)pskModulator(x, 8, sps, filterCoeffs);
  
  % order 16 has 4 categories
  case "16PAM"
    m = @(x)pamModulator(x, 16, sps, filterCoeffs);
  case "16ASK"
    m = @(x)pamModulator(x, 16, sps, filterCoeffs);
  case "16PSK"
    m = @(x)psk8Modulator(x, 16, sps, filterCoeffs);
  case "16QAM"
    m = @(x)qamModulator(x, 16, sps, filterCoeffs);
  case "16APSK"
    m = @(x)apskModulator(x, 16, sps, filterCoeffs);

  case "32PAM"
    m = @(x)pamModulator(x, 32, sps, filterCoeffs);
  case "32ASK"
    m = @(x)pamModulator(x, 32, sps, filterCoeffs);
  case "32PSK"
    m = @(x)psk8Modulator(x, 32, sps, filterCoeffs);
  case "32QAM"
    m = @(x)qamModulator(x, 32, sps, filterCoeffs);
  case "32APSK"
    m = @(x)apskModulator(x, 32, sps, filterCoeffs);

  case "64PAM"
    m = @(x)pamModulator(x, 64, sps, filterCoeffs);
  case "64ASK"
    m = @(x)pamModulator(x, 64, sps, filterCoeffs);
  case "64PSK"
    m = @(x)psk8Modulator(x, 64, sps, filterCoeffs);
  case "64QAM"
    m = @(x)qamModulator(x, 64, sps, filterCoeffs);
  case "64APSK"
    m = @(x)apskModulator(x, 64, sps, filterCoeffs);

  case "128ASK"
    m = @(x)pamModulator(x, 128, sps, filterCoeffs);
  case "128PSK"
    m = @(x)psk8Modulator(x, 128, sps, filterCoeffs);
  case "128QAM"
    m = @(x)qamModulator(x, 128, sps, filterCoeffs);
  case "128APSK"
    m = @(x)apskModulator(x, 128, sps, filterCoeffs);
  
  case "256QAM"
    m = @(x)qamModulator(x, 256, sps, filterCoeffs);
  case "256APSK"
    m = @(x)apskModulator(x, 256, sps, filterCoeffs);
  
  case "512QAM"
    m = @(x)qamModulator(x, 1024, sps, filterCoeffs);
  
  case "1024QAM"
    m = @(x)qamModulator(x, 1024, sps, filterCoeffs);

  case "2048QAM"
    m = @(x)qamModulator(x, 2048, sps, filterCoeffs);
  
  case "4096QAM"
    m = @(x)qamModulator(x, 4096, sps, filterCoeffs);

  case "FM"
    m = @(x)fmModulator(x, fs);
  case "PM"
    m = @(x)pmModulator(x, fs);  
  case "DSB-AM"
    m = @(x)dsbamModulator(x, fs);
  case "DSB-SC-AM"
    m = @(x)dsbamModulator(x, fs, 1);
  case "VSB-AM"
    m = @(x)vsbamModulator(x, fs, 1);
  case "SSB-SC-Upper-AM"
    m = @(x)ssbamModulator(x, fs, 1, 1);
  case "SSB-SC-Lower-AM"
    m = @(x)ssbamModulator(x, fs, 0, 1);
  case "SSB-Upper-AM"
    m = @(x)ssbamModulator(x, fs, 1, 0);
  case "SSB-Lower-AM"
    m = @(x)ssbamModulator(x, fs, 0, 0);
end

end

function y = fskModulator(x, order, sps, fs)

freqsep = 8; % Frequency separation (Hz)

y = fskmod(x, order, freqsep, sps, fs);

end

function y = apskModulator(x, order, sps, filterCoeffs)

y = dvbsapskmod(x, order, "s2x", 'UnitAveragePower', true);
% Pulse shape
y = filter(filterCoeffs, 1, upsample(x, sps));

end

function y = ookModulator(x, sps, filterCoeffs)

filterCoeffs = rcosdesign(0.35, 4, sps, filterCoeffs);
% Pulse shape
y = filter(filterCoeffs, 1, upsample(x, sps));

end

function y = dbpskModulator(x, sps, filterCoeffs)

mod = comm.DBPSKModulator;
syms = mod(x);
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = dqpskModulator(x, sps, phase, filterCoeffs)

mod = comm.DQPSKModulator(PhaseRotation=phase);
syms = mod(x);
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = pskModulator(x, order, sps, filterCoeffs)

syms = pskmod(x, order);
% Pulse shape
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = oqpskModulator(x, sps, filterCoeffs)

mod = comm.OQPSKModulator(SamplesPerSymbol=sps, ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    PulseShape='Root raised cosine');

syms = mod(x);
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = qamModulator(x, order, sps, filterCoeffs)

% Modulate and pulse shape
syms = qammod(x, order, 'UnitAveragePower',true);
% Pulse shape
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = pamModulator(x, order, sps, filterCoeffs)

amp = 1 / sqrt(mean(abs(pammod(0:order-1, order)).^2));
% Modulate
syms = amp * pammod(x, order);
% Pulse shape
y = filter(filterCoeffs, 1, upsample(syms, sps));

end

function y = mskModulator(x, sps)

mod = comm.MSKModulator(BitInput=true, SamplesPerSymbol=sps);
y = mod(x);

end

function y = gmskModulator(x, sps)

mod = comm.GMSKModulator(BitInput=true, ...
    BandwidthTimeProduct=3.5, SamplesPerSymbol=sps);
y = mod(x);

end

function y = gfskModulator(x, sps)

M = 2;
mod = comm.CPMModulator(...
'ModulationOrder', M, ...
'FrequencyPulse', 'Gaussian', ...
'BandwidthTimeProduct', 0.35, ...
'ModulationIndex', 1, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));

end


function y = cpfskModulator(x,sps)
%cpfskModulator CPFSK modulator
%   Y = cpfskModulator(X,sps, filterCoeffs) CPFSK modulates the input X and returns
%   the signal Y. X must be a column vector of values in the set [0 1].
%   the modulation index is 0.5. The output signal Y has unit power.

M = 2;
mod = comm.CPFSKModulator(...
'ModulationOrder', M, ...
'ModulationIndex', 0.5, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));

end

function y = fmModulator(x,fs)
%fmModulator Broadcast FM modulator

y = fmmod(x, 50e3, fs, 0);
end

function y = pmModulator(x,fs)
%pmModulator Broadcast PM modulator

y = pmmod(x, 50e3, fs, 0);
end


function y = dsbamModulator(x,fs, is_sc)
%dsbamModulator Double sideband AM modulator
%   Y = dsbamModulator(X,FS) double sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.
%   It is common to set the value of k to the maximum absolute value of the negative part of the input signal u(t).
if is_sc
    y = ammod(x,50e3,fs);
else
    y = ammod(x,50e3,fs, 0, abs(min(x)));
end
end

function y = vsbamModulator(x,fs)
%vsbamModulator Double sideband AM modulator

f = -fs/2:fs/(length(x)-1):fs/2;
f = arrayfun(@(x) vsb_filer(x, 50e3, 30e3), f);

y = ammod(x,50e3,fs);

fy = fftshift(fft(y));
fy = fy.*f;
y = ifft(ifftshift(fy));

end


function y = ssbamModulator(x,fs, is_upper, is_sc)
%ssbamModulator Single sideband AM modulator
%   Y = ssbamModulator(X,FS) single sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.
if is_upper
    y = ssbmod(x,50e3,fs, 0, 'upper');
else
    y = ssbmod(x,50e3,fs);
end

if ~is_sc
    Fc = 50e3;
    t = (0:1/fs:((size(x,1)-1)/fs))';
    t = t(:, ones(1, size(x, 2)));
    y = y + abs(min(x)) .* cos(2 * pi * Fc * t + 0);
end

end


function y = vsb_filer(x, fc, w)

x  = abs(x);

if x < fc - w*0.01
    y = 0;
elseif x > fc + w * 0.01
    y = 1;
else
    y = (x - fc + w*0.01) /(w*0.02);
end

end