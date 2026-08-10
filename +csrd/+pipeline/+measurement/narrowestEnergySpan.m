function bwHz = narrowestEnergySpan(spec, fAxis, sampleRate, threshold, pct)
%NARROWESTENERGYSPAN Narrowest contiguous band holding pct% of thresholded energy.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% Shared span search for the measurement package. Bins below `threshold` are
% zeroed, then a two-pointer scan finds the narrowest contiguous bin range
% whose retained energy reaches `pct` % of the total retained mass. Both
% edges advance monotonically, so the scan is O(nBins).
%
% Extracted from the former duplicate local functions in obwActual.m and
% measureSignalSummary.m so the two estimators cannot drift apart.
%
% Inputs:
%   spec       - nonnegative spectral density column vector.
%   fAxis      - frequency axis (Hz) matching `spec`, ascending.
%   sampleRate - positive finite scalar (Hz); reported for the degenerate
%                single-bin case.
%   threshold  - bins strictly below this are zeroed before the search.
%   pct        - energy percentage in (0, 100].
%
% Outputs:
%   bwHz - span in Hz (>= 0). Zero when every bin fell below `threshold`,
%          which means the signal is indistinguishable from the noise floor;
%          the caller reports that as a measurement failure rather than
%          silently propagating Nyquist as a measurement.
%
% See also: csrd.pipeline.measurement.peakRelativeObwCore

denoised = spec;
denoised(denoised < threshold) = 0;

totalEnergy = sum(denoised);
if totalEnergy <= 0
    bwHz = 0;
    return;
end

targetMass = totalEnergy * (pct / 100);
nBins = numel(denoised);
cumEnergy = cumsum(denoised);

bestSpan = nBins;
lBest = 1;
rBest = nBins;
rIdx = 1;
for lIdx = 1:nBins
    if rIdx < lIdx
        rIdx = lIdx;
    end
    while rIdx < nBins && localRangeMass(cumEnergy, lIdx, rIdx) < targetMass
        rIdx = rIdx + 1;
    end
    if localRangeMass(cumEnergy, lIdx, rIdx) >= targetMass
        span = rIdx - lIdx + 1;
        if span < bestSpan
            bestSpan = span;
            lBest = lIdx;
            rBest = rIdx;
        end
    end
end

if nBins == 1
    % A single nonzero sample is an impulse on the sample grid. Its discrete
    % spectrum occupies the full observable Nyquist span.
    bwHz = sampleRate;
else
    binWidth = median(diff(fAxis));
    bwHz = double(max(0, (fAxis(rBest) - fAxis(lBest)) + abs(binWidth)));
end
end

function mass = localRangeMass(cumEnergy, lIdx, rIdx)
    % localRangeMass - Retained energy in the inclusive bin range [lIdx, rIdx].
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if lIdx <= 1
    mass = cumEnergy(rIdx);
else
    mass = cumEnergy(rIdx) - cumEnergy(lIdx - 1);
end
end
