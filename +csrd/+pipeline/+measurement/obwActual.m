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
%   bwHz = obwActual(signal, sampleRate)               % ITU 99 % OBW (default)
%   bwHz = obwActual(signal, sampleRate, percentage)   % custom power %
%   bwHz = obwActual(..., 'Method', 'itu-99')          % default
%   bwHz = obwActual(..., 'Method', 'matlab-obw')      % same definition, obw()
%   bwHz = obwActual(..., 'Method', 'peak-relative')   % LEGACY x-dB-down width
%
% DEFINITION
%   The default reports the ITU-R SM.328 / Radio Regulations No. 1.153 occupied
%   bandwidth: the band that excludes `(100-percentage)/2` % of the mean power at
%   each edge, i.e. 99 % of the power in band for the default percentage.
%
% HISTORY -- WHY THE DEFAULT CHANGED
%   This function previously defaulted to a peak-relative (-3 dBc) clip followed
%   by the narrowest band holding 99 % of the SURVIVING energy, and documented
%   that as "the standard engineering definition of occupied bandwidth ... X dB
%   Down mode". The instrument mode is real, but it measures the x-dB-down
%   bandwidth, which ITU-R SM.328 lists as a SEPARATE quantity; ITU-R SM.443
%   requires x ~ 26 dB before an x-dB-down width approximates OBW. At x = 3 dB
%   the result is the main-lobe footprint, and for a root-raised-cosine signal
%   that footprint is ~1.0*Rs INDEPENDENT OF ROLL-OFF (measured: 0.897 / 0.901 /
%   0.803 Rs at beta = 0.1 / 0.25 / 0.5, while the true OBW rises 1.027 -> 1.096
%   -> 1.266 Rs). So the old default published something close to the baud rate
%   under the name "occupied bandwidth", blind to a parameter it should track.
%
%   The peak-relative form was adopted for one reason, stated in the original
%   note below: a power-integral definition is unusable on a NOISY waveform,
%   because noise contributes power across the whole band. That constraint was
%   removed when the measurement moved BEFORE noise injection -- both planes now
%   measure clean, per-emitter, per-antenna buffers, where the power integral is
%   well posed. ECC/REC/(06)01 agrees from the metrology side: 99 % OBW
%   measurement requires the peak at least 30 dB above the noise floor.
%
%   'peak-relative' is retained, opt-in only, so the historical behaviour stays
%   reproducible for before/after comparison. It must never be used as a
%   published label.
%
% ORIGINAL NOTE (kept because it records why the noisy-waveform constraint
% existed, which is what justifies the current ordering):
%
%   The 'peak-relative' estimator was selected after the Phase 4 baseline_v0
%   sweep (561 sources, AWGN cohort) showed that a noise-floor-percentile
%   estimator could NOT make the C8 ExecutionVsMeasuredBwAbsRelDiffP95 < 3 %
%   gate physically realisable for SNR in [6, 20] dB, because the Execution
%   measurement ran on the clean modulator output while the SourcePlane
%   measurement ran on the noisy receiver-rate waveform. Note that the gate it
%   was tuned against was itself self-referential: both planes called the same
%   kernel, so the gate verified repeatability rather than correctness.
%
% Inputs:
%   signal      : complex column vector (or [N x M] for multi-antenna).
%                 Multi-antenna input is collapsed by sum across columns
%                 prior to PSD estimation (matches receiver-view semantics).
%   sampleRate  : positive scalar (Hz)
%   percentage  : optional scalar in (0, 100], default 99 (%)
%
% Optional Name-Value:
%   'Method'         - 'itu-99' (default) | 'matlab-obw' | 'peak-relative'
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
    addParameter(p, 'Method', 'itu-99', ...
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
        case 'itu-99'
            % Default. The ITU-R SM.328 / RR No. 1.153 quantity, computed on this
            % package's prepared spectrum so the Nyquist recentre, the
            % discarded-tail fallback and the degenerate-input contracts all hold.
            bwHz = csrd.pipeline.measurement.occupiedBandwidthCore( ...
                signalCol, double(sampleRate), double(percentage));
        case 'matlab-obw'
            % Independent implementation of the same definition, kept as a
            % cross-check on the one above. It lacks the spectrum preparation, so
            % it is not suitable as the production path for edge-placed emitters
            % or frame-tail bursts.
            bwHz = obw(double(signalCol), double(sampleRate), [], double(percentage));
        case 'peak-relative'
            % LEGACY, opt-in only. An x-dB-down main-lobe width, NOT an occupied
            % bandwidth: ITU-R SM.443 needs x ~ 26 dB to approximate OBW and this
            % uses x = 3 dB, which for RRC is ~1.0*Rs independent of roll-off.
            % Retained so the peak-relative behaviour stays reproducible for
            % before/after comparisons; never use it as a published label.
            bwHz = csrd.pipeline.measurement.peakRelativeObwCore( ...
                signalCol, double(sampleRate), double(percentage), peakRelDb);
        otherwise
            error('CSRD:Measurement:InvalidMethod', ...
                'obwActual: unsupported Method "%s" (expected itu-99 | matlab-obw | peak-relative).', method);
    end
end


% The peak-relative kernel and the span search now live in
% csrd.pipeline.measurement.peakRelativeObwCore /
% csrd.pipeline.measurement.narrowestEnergySpan so this estimator and
% measureSignalSummary share one implementation instead of two copies that
% had to be kept in sync by hand.
