function refDbm = paInputCompressionDbm(pa, referenceImpedance)
    % paInputCompressionDbm - a PA/LNA's input-referred 1 dB compression point.
    % Inputs: pa - an unlocked comm.MemorylessNonlinearity instance to sweep
    %              (released after use); referenceImpedance - ohms, the
    %              impedance the dBm convention is referred to.
    % Outputs: refDbm - input power (dBm at referenceImpedance) where the
    %          device's gain has compressed 1 dB below its PEAK value over the
    %          sweep; NaN when it never compresses within the probe range (a
    %          linear device needs no back-off).
    %
    % The ONE compression-point kernel shared by TRFSimulator (PA back-off,
    % Step 3.5) and RRFSimulator (LNA back-off): the input-back-off guard on
    % both sides positions the drive relative to the value measured here, so
    % the two front ends must never disagree on what "compression" means.
    %
    % Measured NUMERICALLY rather than derived from per-Method closed forms,
    % for two reasons. First, one procedure covers all six
    % comm.MemorylessNonlinearity Methods identically -- IIP3-to-P1dB
    % conversions exist only for the polynomial models, the
    % Saleh/Ghorbani/Rapp/Lookup reference points would each need their own
    % formula, and a wrong formula here silently mis-positions the operating
    % point (the exact defect class the back-off mechanism exists to remove).
    % Second, the sweep measures the device THE PIPELINE ACTUALLY BUILT,
    % InputScaling and all, so a future Method or parameter change cannot
    % desynchronise a formula from the implementation.
    %
    % Compression is referenced to the PEAK gain, searched only past the
    % peak. Referencing the smallest-amplitude gain instead is wrong for the
    % Ghorbani model: its AM/AM (x4 < 0) is gain-EXPANSIVE at small drive, so
    % a small-signal reference misreads the expansion slope as compression
    % and reports ~-47 dBm -- and the back-off step then crushes a healthy
    % drive by 40-60 dB into that expansion region. For the monotonically
    % compressing Methods the peak sits at the start of the sweep and both
    % definitions agree. Pinned by TrfPaOperatingPointTest.
    cleanup = onCleanup(@() release(pa));
    amps = logspace(-3, 1.5, 160).';   % ~ -47 .. +43 dBm at 50 ohm
    y = pa(complex(amps, zeros(size(amps))));
    gainDb = 20 * log10(max(abs(y), realmin) ./ amps);
    [peakGainDb, peakIdx] = max(gainDb);
    idx = find(gainDb(peakIdx:end) <= peakGainDb - 1, 1);
    if isempty(idx)
        refDbm = NaN;
        return;
    end
    idx = idx + peakIdx - 1;
    refDbm = 20 * log10(amps(idx)) + 30 - 10 * log10(referenceImpedance);
end
