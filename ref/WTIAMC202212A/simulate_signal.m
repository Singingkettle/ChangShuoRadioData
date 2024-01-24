
function simulate_signal(worker_id, num_worker)

% Add Modulation Classification with Deep Learning Tool in the environment
addpath('C:\Users\97147\Documents\MATLAB\Examples\R2022b\deeplearning_shared\ModulationClassificationWithDeepLearningExample');

rng(123+worker_id)

% Generate train data
SNR = 10;
spses = [4, 8, 16, 32];      % Set of samples per symbol
spf = 1024;                  % Samples per frame
fs = 200e3;                  % Sample rate

modulationTypes = categorical(["BPSK", "QPSK", "8PSK", ...
  "16QAM", "64QAM", "PAM4", "GFSK", "CPFSK", ...
  "B-FM", "DSB-AM", "SSB-AM"]);
channel = MyModClassTestChannel(...
  'SampleRate', fs, ...
  'SNR', SNR, ...
  'PathDelays', [0 1.8 3.4] / fs, ...
  'AveragePathGains', [0 -2 -10], ...
  'KFactor', 4, ...
  'MaximumDopplerShift', 4, ...
  'MaximumClockOffset', 5, ...
  'CenterFrequency', 902e6);

% channel = comm.AWGNChannel('SNR', SNR);
% w = waitbar(0,'Starting');

a = 0;
n = 1000000;

% for i=worker_id:num_worker:n
% %     s = clock;
%     y = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channel);
%     save(sprintf("./data/%06d.mat", i),  'y');
% %     t = etime(clock, s);
% %     esttime = t * (n-i);
% % 
% %     if a == 0
% %         a = esttime;
% %     else
% %         a = 0.9 * (a - t) + 0.1 * esttime;
% %     end
% % 
% %     h = floor(a / 3600);
% %     m = floor((a - h*3600)/60);
% %     s = ceil(a - h * 3600 - m * 60);
% %     waitbar(i/n, w, ['Remaining time = ', ...
% %         sprintf('%02d:%02d:%02d', h, m, s), ...
% %         sprintf(' and Progress: %.2f %%', i/n*100)]);
% end
% % close(w);
% 
% end

y1 = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channel);
specAn1 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
        "Method", "Filter bank",...
        "AveragingMethod", "Exponential", ...
        "Title", "Data0");
specAn2 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
        "Method", "Filter bank",...
        "AveragingMethod", "Exponential", ...
        "Title", "Data1");

d = 0;
for i=1:length(y1)
    d = d + y1{1, i}.data;
end
specAn1(d);


y2 = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channel);


d = 0;
for i=1:length(y2)
    d = d + y2{1, i}.data;
end
specAn2(d);