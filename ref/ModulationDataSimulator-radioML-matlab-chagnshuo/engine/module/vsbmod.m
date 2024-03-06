function y = vsbmod(x, Fc, Fs)
% VSBMOD Residual sideband modulation.
%   Y = VSBMOD(X, Fc, Fs) uses the message signal X to modulate the carrier
%   frequency Fc (Hz) using single sideband amplitude modulation. X and Fc
%   have sample frequency Fs (Hz). The modulated signal has zero initial
%   phase, and the default sideband modulated is the upper sideband.

wcut = 0.05;    % normalized cutoff frequency for LPF
P = 5;          % order of LPF
%
% Modulation (generation) of VSB signal
%
[B,A] = butter(P,wcut);    % low-pass Butterworth filter of order P
                          % and normalized cutoff frequency wcut.
m = filter(B,A,x);         % filtering white noise to get correlated
                          % message signal with normalized bandwidth wcut. 
wc = 2*Fc/Fs;      % carrier frequency in normalized radians/second							  
wv = 0.25*wcut;    % normalized residual bandwidth
NN = 512;          % number of frequency response samples of VSB filter

n0 = round(NN*(wc - wv));  % number of data points below wc - wv
n1 = round(NN*(2*wv));     % number of data points within the bandwidth 
                         % [wc-wv, wc+wv]
vn1 = (0:n1-1)/n1;         % samples of the ramp
vn1 = vn1(:);
n2 = round(NN*(wcut-wv));  % number of data points within the bandwidth
                         % [wc+wv,wc+wcut]
n3 = NN - round(NN*(wc+wcut));  % number of data points above wc + wcut
Hi = [zeros(n0,1); vn1; ones(n2,1); zeros(n3,1)];   % frequency response
                                                  % of VSB filter
                             
hi = 2*real(ifft(Hi));         % impulse response of VSB filter
hi = ifftshift(hi);            % shift hi to have symmetrical form
hi = hi((NN/2)-100:(NN/2)+100);
%
% VSB signal generation
%
N = size(x);
phi = m'.*cos(2*pi*Fc*(0:N-1)/Fs);
y = filter(hi, [1], phi)';


% --- EOF --- %
