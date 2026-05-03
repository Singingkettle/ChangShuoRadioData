function test_doppler_high_speed()
    %TEST_DOPPLER_HIGH_SPEED Phase 4 §6 C2 deterministic Doppler regression.
    %
    %   Closes audit hypothesis H12 (Doppler missing from physical layer)
    %   with a six-scenario deterministic gate that exercises
    %   `csrd.blocks.physical.channel.impairments.applyDopplerShift` at the
    %   high-velocity extremes the project supports today
    %   (v ∈ {100, 200, 500} m/s, f_c ∈ {2.4 GHz, 5.8 GHz}). For each
    %   combination the test:
    %
    %     1. Builds a single complex sinusoid baseband signal at a known
    %        baseband tone frequency f_tone (so the FFT peak is unambiguous).
    %     2. Places the Tx at a fixed offset from the Rx, points the Tx
    %        velocity straight along the +LOS direction (closing) so
    %        v_radial == |v|.
    %     3. Calls applyDopplerShift to apply f_d = v_radial * f_c / c.
    %     4. Compares the FFT peak shift between the input and the
    %        Doppler-shifted output against the analytical f_d. C2 fails
    %        the test if |f_measured - f_analytical| / |f_analytical|
    %        exceeds 5 %.
    %
    %   The test does NOT spin up SimulationRunner or
    %   ScenarioFactory: that integration coverage is provided by the
    %   accompanying `tests/regression/test_baseline_sweep_200.m` baseline
    %   sweep (HighSpeed_Aero_Doppler cohort) at S11. This test stays
    %   deterministic / fast / single-purpose so a Doppler regression is
    %   identified at the impairment layer rather than via the
    %   higher-level baseline metrics.
    %
    %   References:
    %     * docs/audits/2026-04-system-audit-v0.4.md §17.6 (Phase 4 plan)
    %     * docs/audits/phases/phase-4-measurement.md §6 C2
    %     * +csrd/+blocks/+physical/+channel/+impairments/applyDopplerShift.m

    fprintf('=== Phase 4 Doppler high-speed deterministic ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    speedOfLight = 299792458;
    sampleRate   = 4e6;     % Hz; 4 MHz baseband window
    durationSec  = 0.020;   % 20 ms (enough for a sub-Hz bin at 50 Hz, well
                            % below all expected f_d magnitudes; smallest
                            % expected |f_d| at 100 m/s @ 2.4 GHz is 800 Hz)
    toneHz       = 100e3;   % baseband tone that the Doppler shifts
    relTol       = 0.05;    % 5 % per phase-4 plan §6 C2

    velocitiesMps     = [100, 200, 500];
    carrierHz         = [2.4e9, 5.8e9];

    cases = repmat(struct('VelocityMps', 0, 'CarrierHz', 0, ...
        'AnalyticalDopplerHz', 0, 'MeasuredDopplerHz', 0, ...
        'AbsRelError', NaN), 0, 1);

    for vIdx = 1:numel(velocitiesMps)
        for fIdx = 1:numel(carrierHz)
            v  = velocitiesMps(vIdx);
            fc = carrierHz(fIdx);

            [analytical, measured] = localRunOneCase( ...
                v, fc, sampleRate, durationSec, toneHz);

            err = abs(measured - analytical) / abs(analytical);

            cases(end + 1) = struct( ...
                'VelocityMps', v, ...
                'CarrierHz', fc, ...
                'AnalyticalDopplerHz', analytical, ...
                'MeasuredDopplerHz', measured, ...
                'AbsRelError', err); %#ok<AGROW>

            fprintf( ['  v=%4d m/s | f_c=%.2e Hz | f_d analytical=%9.2f Hz ', ...
                'measured=%9.2f Hz | err=%.3f %%\n'], ...
                v, fc, analytical, measured, 100 * err);
        end
    end

    assert(numel(cases) == numel(velocitiesMps) * numel(carrierHz), ...
        'C2: expected %d Doppler scenarios but only ran %d.', ...
        numel(velocitiesMps) * numel(carrierHz), numel(cases));

    failures = cases([cases.AbsRelError] > relTol);
    if ~isempty(failures)
        for k = 1:numel(failures)
            f = failures(k);
            fprintf(2, ...
                'C2 FAIL  v=%d m/s f_c=%.2e Hz analytical=%.3f measured=%.3f err=%.3f%%\n', ...
                f.VelocityMps, f.CarrierHz, f.AnalyticalDopplerHz, ...
                f.MeasuredDopplerHz, 100 * f.AbsRelError);
        end
        error('CSRD:Phase4:DopplerC2Failed', ...
            ['Phase 4 C2 violated: %d/%d Doppler scenarios exceeded the ', ...
             '5%% absolute-relative error gate.'], numel(failures), numel(cases));
    end

    fprintf('=== Phase 4 Doppler high-speed deterministic PASSED (%d/%d) ===\n', ...
        numel(cases), numel(cases));
end


% =====================================================================
function [analyticalDopplerHz, measuredDopplerHz] = localRunOneCase( ...
        velocityMps, carrierHz, sampleRate, durationSec, toneHz)
    %LOCALRUNONECASE Generate a CW tone, apply Doppler, recover the shift.
    %
    %   The Tx is placed at the origin and pointed straight along the +x
    %   axis at the Rx, which sits one km away. Tx velocity is also along
    %   +x so the projected radial velocity equals |v| exactly (closing).
    %   The baseband tone is a complex sinusoid at toneHz; after applying
    %   the analytical Doppler shift f_d, the FFT peak should move from
    %   toneHz to (toneHz + f_d). We compare the peak displacement against
    %   the analytical f_d.

    nSamples = round(sampleRate * durationSec);
    t        = (0:nSamples - 1).' / sampleRate;
    signal   = exp(1j * 2 * pi * toneHz * t);

    txPos = [0, 0, 0];
    rxPos = [1000, 0, 0];
    txVel = [velocityMps, 0, 0];

    [shifted, dopplerHz, radialVelocityMps] = ...
        csrd.blocks.physical.channel.impairments.applyDopplerShift( ...
            signal, sampleRate, carrierHz, txPos, txVel, rxPos);

    assert(abs(radialVelocityMps - velocityMps) < 1e-9, ...
        'Doppler test geometry: expected v_radial=%g, got %g.', ...
        velocityMps, radialVelocityMps);

    analyticalDopplerHz = dopplerHz;

    % Estimate the measured Doppler by FFT-peak displacement between input
    % and shifted signal. Zero-pad so the bin resolution is sub-Hz at the
    % expected f_d magnitudes.
    fftLen = 2^nextpow2(nSamples * 8);
    fAxis  = (-fftLen / 2 : fftLen / 2 - 1).' * (sampleRate / fftLen);

    inSpec  = fftshift(fft(signal,  fftLen));
    outSpec = fftshift(fft(shifted, fftLen));

    [~, inIdx]  = max(abs(inSpec));
    [~, outIdx] = max(abs(outSpec));

    inPeakHz  = fAxis(inIdx);
    outPeakHz = fAxis(outIdx);

    measuredDopplerHz = outPeakHz - inPeakHz;
end
