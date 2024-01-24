function y = generate(x, sr, channels, frequency_shifter, cf)

% make sure the input signal is normalized to unity power
x = x ./ sqrt(mean(abs(x).^2));

% =========================================================================
% Clean: 理想信道条件下，没有噪声
% =========================================================================
% v1: clean
y.clean = x;

% =========================================================================
% Awgn: 加性高斯白噪声信道条件下，噪声水平变化
% Awgn+fs: 带有频率偏移的加性高斯白噪声信道条件下，噪声水平变化
% =========================================================================
y.awgn = zeros(13, 2, 1200);
y.awgn_fs = zeros(13, 2, 1200);
for i=1:14
    dB = (i-1)*2+-6;
    x = awgn(x, dB);
    y.awgn(i, :, :) = x;
    y.awgn(i, :, :) = addClockOffset(x, sr, frequency_shifter, cf);
end


% =========================================================================
% Awgn: 加性高斯白噪声信道条件下，噪声水平变化
% Awgn+fs: 带有频率偏移的加性高斯白噪声信道条件下，噪声水平变化
% =========================================================================
y.awgn = zeros(13, 2, 1200);
y.awgn_fs = zeros(13, 2, 1200);
for i=1:14
    dB = (i-1)*2+-6;
    x = awgn(x, dB);
    y.awgn(i, :, :) = x;
    y.awgn(i, :, :) = addClockOffset(x, sr, frequency_shifter, cf);
end


end
