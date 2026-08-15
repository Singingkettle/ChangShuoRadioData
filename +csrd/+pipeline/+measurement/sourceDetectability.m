function [detectable, status, floorDb] = sourceDetectability(snrDb)
%SOURCEDETECTABILITY Whether a source is detectable in the saved noisy frame.
%
%   [detectable, status, floorDb] = sourceDetectability(snrDb)
%
%   The ONE rule, shared by every site that needs it (the annotation writer,
%   the plausibility gate, the COCO converter), so the detectability floor
%   cannot drift across them.
%
%   WHY THIS EXISTS
%   The measured SourcePlane is taken PRE-NOISE and per-emitter, so its
%   occupied bandwidth / center / family labels are clean and confident even
%   for a source that, in the SAVED noisy frame, sits far below the noise
%   floor. Ray tracing makes this routine: it applies physical path loss and
%   does NOT go through the controlled-SNR realization, so a shadowed NLOS
%   link can arrive 100+ dB under the frame noise while still carrying a
%   confident label. A source that no detector could find in the delivered
%   frame must be MARKED, not silently labeled visible -- otherwise a
%   consumer trains "there is an OFDM signal here" on what is, in the saved
%   frame, pure noise.
%
%   THE FLOOR: -30 dB. This is deliberately NOT a specific detector's SNR
%   wall (that would be arbitrary and detector-dependent). At SNR = -30 dB
%   the source contributes 0.1 % of the noise power -- it moves the frame's
%   total power by 0.0043 dB and its spectral signature sits ~30 dB under the
%   noise floor, below the single-frame SNR wall of energy AND practical
%   feature/cyclostationary detectors. It marks the sources that are so far
%   under noise that NO detector on this one frame could find them, i.e. the
%   ones whose label is untrustworthy. Consumers that want a tighter,
%   detector-specific gate can re-derive from the required SNRdB field; this
%   is the conservative "definitely undetectable" line. The threshold travels
%   with the data (SourcePlane.DetectabilityThresholdDb) so a reader sees
%   which line was applied.
%
%   Inputs:
%     snrDb - realized received SNR in dB (Truth.Measured.SourcePlane.SNRdB),
%             signal power over the realized frame noise. NaN for a source
%             with no measurable signal.
%
%   Outputs:
%     detectable - logical; true when snrDb >= floorDb.
%     status     - 'Detectable' | 'BelowNoiseFloor' | 'NoSignal'.
%     floorDb    - the applied detectability floor (dB).

floorDb = -30;
if ~isnumeric(snrDb) || ~isscalar(snrDb) || ~isfinite(snrDb)
    detectable = false;
    status = 'NoSignal';
    return;
end
detectable = double(snrDb) >= floorDb;
if detectable
    status = 'Detectable';
else
    status = 'BelowNoiseFloor';
end
end
