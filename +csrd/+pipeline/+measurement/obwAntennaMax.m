function bwHz = obwAntennaMax(signal, sampleRate, percentage, varargin)
%OBWANTENNAMAX Occupied bandwidth for clean multi-antenna Tx output.
% 中文说明：逐发射天线测量 clean OBW，避免相位相反列求和抵消。

if nargin < 3 || isempty(percentage)
    percentage = 99;
end

if isempty(signal)
    error('CSRD:Measurement:EmptySignal', ...
        'obwAntennaMax: input signal is empty.');
end
if size(signal, 2) <= 1
    bwHz = csrd.pipeline.measurement.obwActual( ...
        signal, sampleRate, percentage, varargin{:});
    return;
end

bwByColumn = nan(1, size(signal, 2));
for col = 1:size(signal, 2)
    bwByColumn(col) = csrd.pipeline.measurement.obwActual( ...
        signal(:, col), sampleRate, percentage, varargin{:});
end

valid = bwByColumn(isfinite(bwByColumn) & bwByColumn > 0);
if isempty(valid)
    bwHz = 0;
else
    bwHz = max(valid);
end
end
