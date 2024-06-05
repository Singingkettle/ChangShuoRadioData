% Generate train data
SNR = 10000;
spses = [12, 15, 16];        % Set of samples per symbol
spf = 1200;                  % Samples per frame
fs = 150e3;                  % Sample rate
% 
% modulationTypes = categorical(["BPSK", "QPSK", "8PSK", ...
%   "16QAM", "64QAM", "PAM4", "GFSK", "CPFSK", ...
%   "B-FM", "DSB-AM", "SSB-AM"]);

modulationTypes = ["BPSK", "QPSK", "8PSK", "16QAM", "64QAM"];

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
channels = {channel_rayleigh};
snr_set = 0:5:30;

for s_index=1:7
    snrs = snr_set(s_index);
    for i=1:10000
    %     s = clock;
        fprintf('Under rayleigh channel, generate data of number %05d.\n', i);
        y = generate_signal(-fs/2, fs/2, fs, spf, spses, modulationTypes, channels, snrs);
        
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
        
            fid = fopen(sprintf("./v%d/anno/%06d.json", s_index+15, i),'w');
            fprintf(fid, s); 
            fclose(fid);
        
            save(sprintf("./v%d/sequence_data/iq/%06d.mat", s_index+15, i),  'signal_data');
        end
    end
end