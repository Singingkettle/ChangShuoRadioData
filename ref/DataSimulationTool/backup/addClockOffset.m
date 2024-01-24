function y = addClockOffset(x, fs, frequency_shifter, CenterFrequency)
%   adds effects of clock offset. Clock offset
%   has two effects on the received signal: 1) Frequency offset,
%   which is determined by the clock offset (ppm) and the carrier
%   frequency; 2) Sampling time drift, which is determined by the
%   clock offset (ppm) and sampling rate. This method first generates
%   a clock offset value in ppm, based on the specified maximum clock
%   offset and calculates the offset factor, C, as
%   
%   C = (1+offset/1e6), where offset is the clock offset in ppm.
%
%   applyFrequencyOffset and applyTimingDrift add frequency offset
%   and sampling time drift to the signal, respectively.

% Determine clock offset factor
maxOffset = 5;
clockOffset = (rand() * 2*maxOffset) - maxOffset;
C = 1 + clockOffset / 1e6;

% (1)
frequency_shifter.FrequencyOffset = -(C-1)*CenterFrequency;
x = FrequencyShifter(x);

% (2)
x = (0:length(x)-1)' / fs;
newFs = fs * C;
xp = (0:length(in)-1)' / newFs;
y = interp1(x, in, xp);

end

