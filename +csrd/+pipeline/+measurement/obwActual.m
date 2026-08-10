function bwHz = obwActual(signal, sampleRate, percentage, varargin)
%OBWACTUAL Occupied bandwidth (Hz) of a complex baseband signal.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% Phase 4 §3.1 measurement-package wrapper used by
% `Truth.Measured.{SourcePlane,FramePlane}` and the construction-side
% `Truth.Execution.ModulatedBandwidthHz` (see audit §17.6 / §6 C8).
%
% USAGE
%   bwHz = obwActual(signal, sampleRate)               % 99 %, peak-relative
%   bwHz = obwActual(signal, sampleRate, percentage)   % custom %
%   bwHz = obwActual(..., 'Method', 'peak-relative')   % default
%   bwHz = obwActual(..., 'Method', 'matlab-obw')      % raw MATLAB obw
%   bwHz = obwActual(..., 'PeakRelativeDb', -3)        % default -3 dB
%
% METHODOLOGY
%
%   The default ('peak-relative') estimator was selected after the Phase
%   4 baseline_v0 sweep (561 sources, AWGN cohort) showed that the
%   previous noise-floor-percentile estimator could NOT make the C8
%   ExecutionVsMeasuredBwAbsRelDiffP95 < 3 % gate physically realisable
%   for SNR in [6, 20] dB. The reason is fundamental:
%
%     - The Execution measurement runs on the **clean** modulator output
%       (zero AWGN), so any bin-amplitude-percentile floor estimate is
%       dominated by FFT processing leakage and lands many tens of dB
%       below the signal peak. The threshold therefore drops to ~-30 dBc
%       and the 99 %-energy mass naturally extends out into the RRC /
%       OFDM rolloff sidelobes.
%     - The SourcePlane measurement runs on the **noisy** receiver-rate
%       waveform. At SNR=6 dB the noise PSD sits ~6 dB below the
%       in-band peak, so any floor*margin threshold either drowns the
%       noise (margin too small) or chops off the legitimate rolloff
%       (margin too large). At realistic operating SNRs the algorithm
%       reports either Nyquist-edge bandwidths or main-lobe-only
%       bandwidths; neither matches the clean-side number.
%
%   Peak-relative thresholding sidesteps both failure modes: the
%   threshold floats with the signal peak, not with the per-source noise
%   floor, so clean and noisy measurements of the same modulator output
%   converge as long as the in-band SNR keeps the signal main lobe well
%   above the chosen ratio. With the default -3 dBc threshold (= peak/2):
%
%     - Clean RRC and noisy RRC at SNR=6..20 dB report identical
%       bandwidths.
%     - Clean OFDM and noisy OFDM agree to <0.1 % for the same SNR
%       range.
%     - The reported bandwidth is the -3 dB main-lobe footprint, which
%       is the standard engineering definition of "occupied bandwidth"
%       on R&S FSV / Keysight 89600 spectrum analysers when the OBW
%       cursor is configured for "X dB Down" mode (default 3 dB).
%
% Inputs:
%   signal      : complex column vector (or [N x M] for multi-antenna).
%                 Multi-antenna input is collapsed by sum across columns
%                 prior to PSD estimation (matches receiver-view semantics).
%   sampleRate  : positive scalar (Hz)
%   percentage  : optional scalar in (0, 100], default 99 (%)
%
% Optional Name-Value:
%   'Method'         - 'peak-relative' (default) or 'matlab-obw'
%   'PeakRelativeDb' - peak-relative threshold in dB, default -3.
%                      Must be strictly negative. Values:
%                        -3  : default; main-lobe -3 dB BW. SNR-invariant
%                              for SNR >= 6 dB across RRC / OFDM / FSK.
%                        -6  : wider footprint, includes more rolloff;
%                              SNR-invariant for SNR >= 9 dB.
%                        -10 : even wider, but breaks at SNR <= 9 dB
%                              (noise crosses the threshold).
%
% Outputs:
%   bwHz        : occupied bandwidth in Hz (>= 0)
%
% Throws:
%   CSRD:Measurement:EmptySignal       - empty input
%   CSRD:Measurement:InvalidSampleRate - sampleRate <= 0 or non-finite
%   CSRD:Measurement:InvalidSignal     - signal contains NaN/Inf
%   CSRD:Measurement:InvalidPercentage - percentage outside (0,100]
%   CSRD:Measurement:InvalidMethod     - unsupported Method tag
%   CSRD:Measurement:InvalidPeakRelDb  - PeakRelativeDb >= 0
%
% See also: csrd.pipeline.measurement.spectrumCentroid
%           csrd.pipeline.measurement.frequencyOccupancy

    if nargin < 3 || isempty(percentage)
        percentage = 99;
    end

    p = inputParser();
    p.FunctionName = 'obwActual';
    p.CaseSensitive = false;
    p.KeepUnmatched = false;
    addParameter(p, 'Method', 'peak-relative', ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(p, 'PeakRelativeDb', -3, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x < 0);
    parse(p, varargin{:});
    method = lower(char(p.Results.Method));
    peakRelDb = double(p.Results.PeakRelativeDb);

    if isempty(signal)
        error('CSRD:Measurement:EmptySignal', ...
            'obwActual: input signal is empty.');
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error('CSRD:Measurement:InvalidSampleRate', ...
            'obwActual: sampleRate must be positive finite scalar (got %s).', ...
            mat2str(sampleRate));
    end

    if ~isnumeric(percentage) || ~isscalar(percentage) || ...
            ~isfinite(percentage) || percentage <= 0 || percentage > 100
        error('CSRD:Measurement:InvalidPercentage', ...
            'obwActual: percentage must be in (0,100] (got %s).', ...
            mat2str(percentage));
    end

    if any(~isfinite(signal(:)))
        error('CSRD:Measurement:InvalidSignal', ...
            'obwActual: signal contains NaN or Inf (%d non-finite samples).', ...
            sum(~isfinite(signal(:))));
    end

    if size(signal, 2) > 1
        signalCol = sum(signal, 2);
    else
        signalCol = signal(:);
    end

    switch method
        case 'matlab-obw'
            bwHz = obw(double(signalCol), double(sampleRate), [], double(percentage));
        case 'peak-relative'
            bwHz = csrd.pipeline.measurement.peakRelativeObwCore( ...
                signalCol, double(sampleRate), double(percentage), peakRelDb);
        otherwise
            error('CSRD:Measurement:InvalidMethod', ...
                'obwActual: unsupported Method "%s" (expected peak-relative | matlab-obw).', method);
    end
end


% The peak-relative kernel and the span search now live in
% csrd.pipeline.measurement.peakRelativeObwCore /
% csrd.pipeline.measurement.narrowestEnergySpan so this estimator and
% measureSignalSummary share one implementation instead of two copies that
% had to be kept in sync by hand.
