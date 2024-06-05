%% 

function simulate_signal(worker_id, num_worker)

rng(123+worker_id)

% Generate train data
SNR = 10;
spses = [12, 15, 16];        % Set of samples per symbol
spf = 1200;                  % Samples per frame
fs = 150e3;                  % Sample rate
% 
% modulationTypes = categorical(["BPSK", "QPSK", "8PSK", ...
%   "16QAM", "64QAM", "PAM4", "GFSK", "CPFSK", ...
%   "B-FM", "DSB-AM", "SSB-AM"]);

modulationTypes = ["BPSK", "QPSK", "8PSK", "16QAM", "64QAM"];

channel_rician = MyModClassTestChannel(...
                        'channel_type', 'rician', ...
                        'SampleRate', fs, ...
                        'SNR', SNR, ...
                        'PathDelays', [0 1.8 3.4] / fs, ...
                        'AveragePathGains', [0 -2 -10], ...
                        'KFactor', 4, ...
                        'MaximumDopplerShift', 4, ...
                        'MaximumClockOffset', 5, ...
                        'CarrierFrequency', 902e6);

channel_rayleigh = MyModClassTestChannel(...
                        'channel_type', 'rayleigh', ...
                        'SampleRate', fs, ...
                        'SNR', SNR, ...
                        'PathDelays', [0 1.8 3.4] / fs, ...
                        'AveragePathGains', [0 -2 -10], ...
                        'KFactor', 4, ...
                        'MaximumDopplerShift', 4, ...
                        'MaximumClockOffset', 5, ...
                        'CarrierFrequency', 902e6);

channels = {channel_rayleigh, channel_rician};

n = 3000;

for i=worker_id:num_worker:n
%     s = clock;
    y = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channels);
    
    if ~isempty(y)
        signal_data = zeros(length(y), 2, spf);
        signal_info.center_frequency = zeros(length(y), 1);
        signal_info.bandwidth = zeros(length(y), 1);
        signal_info.snr = zeros(length(y), 1);
        signal_info.modulation = strings(length(y), 1);
        signal_info.channel = strings(length(y), 1);
        signal_info.sample_rate = zeros(length(y), 1);
        signal_info.sample_num = zeros(length(y), 1);
        signal_info.sample_per_symbol = zeros(length(y), 1);
        for j=1:length(y)
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
        signal_info.file_name = sprintf("%06d.mat", i);
        s = jsonencode(signal_info, "PrettyPrint", true);
    
        fid = fopen(sprintf("./anno/%06d.json", i),'w');
        fprintf(fid, s); 
        fclose(fid);
    
        save(sprintf("./sequence_data/iq/%06d.mat", i),  'signal_data');
    end
%     t = etime(clock, s);
%     esttime = t * (n-i);
% 
%     if a == 0
%         a = esttime;
%     else
%         a = 0.9 * (a - t) + 0.1 * esttime;
%     end
% 
%     h = floor(a / 3600);
%     m = floor((a - h*3600)/60);
%     s = ceil(a - h * 3600 - m * 60);
%     waitbar(i/n, w, ['Remaining time = ', ...
%         sprintf('%02d:%02d:%02d', h, m, s), ...
%         sprintf(' and Progress: %.2f %%', i/n*100)]);
end
% close(w);

end

% y1 = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channel);
% specAn1 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
%         "Method", "Filter bank",...
%         "AveragingMethod", "Exponential", ...
%         "Title", "Data0");
% specAn2 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
%         "Method", "Filter bank",...
%         "AveragingMethod", "Exponential", ...
%         "Title", "Data1");
% 
% d = 0;
% for i=1:length(y1)
%     d = d + y1{1, i}.data;
% end
% specAn1(d);


% y2 = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channel);
% 
% 
% d = 0;
% for i=1:length(y2)
%     d = d + y2{1, i}.data;
% end
% specAn2(d);