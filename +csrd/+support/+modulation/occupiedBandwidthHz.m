function bwHz = occupiedBandwidthHz(signal, sampleRate)
    % occupiedBandwidthHz - Robust occupied bandwidth for analog modulation.
    %
    %   bwHz = csrd.support.modulation.occupiedBandwidthHz(signal, sampleRate)
    %
    %   Wraps MATLAB obw() with a degenerate-input floor. obw() returns NaN for
    %   very short signals (e.g. a 64-sample minimum-length analog message) and
    %   can collapse to 0 for a near-silent / near-DC segment. The analog
    %   modulator contract requires a finite positive bandwidth, so when the
    %   estimate is non-finite or non-positive this falls back to the FFT bin
    %   resolution (sampleRate / N), a small but physically meaningful minimum
    %   occupied bandwidth rather than a hard failure.
    %
    %   Inputs:
    %     signal     - real or complex sample vector.
    %     sampleRate - positive scalar sample rate (Hz).
    %
    %   Outputs:
    %     bwHz - positive finite occupied bandwidth (Hz).

    bwHz = obw(signal, sampleRate);
    if ~isfinite(bwHz) || bwHz <= 0
        n = max(1, numel(signal));
        bwHz = sampleRate / n;
    end
end
