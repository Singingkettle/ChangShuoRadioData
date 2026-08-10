classdef ObwLowSnrNoiseFloorInflationTest < matlab.unittest.TestCase
    % ObwLowSnrNoiseFloorInflationTest - measured-OBW behaviour at low SNR.
    %
    %   The peak-relative (-3 dBc) + narrowest-99 %-energy estimator stops
    %   separating signal from noise once the noise-floor PSD rises to within
    %   ~3 dB of the signal peak: the clip then retains scattered noise bins
    %   across the whole band and the "narrowest contiguous 99 % span" bridges
    %   them. The reported occupied bandwidth saturates toward Fs.
    %
    %   Because this repository's ground truth is the MEASURED plane, an
    %   inflated OccupiedBandwidthHz is a data defect, not merely a cosmetic
    %   one: a downstream bandwidth regressor trained on it learns
    %   "low SNR => wide signal" with a 3-6x systematic bias, concentrated at
    %   exactly the operating point a spectrum-sensing dataset exists to cover
    %   (Runner config draws target SNR uniformly from [-10, 30] dB).
    %
    %   Breakdown is governed by IN-BAND SNR, not total-power SNR:
    %       inBandSNR_dB = totalSNR_dB + 10*log10(Fs/B)
    %   A calibration sweep (7 families x 15 SNRs x 5 seeds) put the knee at
    %   in-band SNR ~ +1 dB for every family, i.e. total-power SNR of -7 dB for
    %   a 15 %-occupancy emitter but 0 dB for a 77 %-occupancy one.
    %
    %   ASSERTION STYLE
    %   Every bound is expressed RELATIVE to the same family's clean-signal
    %   measurement computed inside the test, never as a hard-coded MHz value,
    %   so a legitimate future change to the occupied-bandwidth convention
    %   moves numerator and denominator together and does not fail the suite.
    %   Bounds are two-sided so that "improve by collapsing to the main lobe"
    %   is caught as well as inflation.
    %
    %   A measurement may legitimately be reported as unresolvable (NaN) where
    %   physics does not allow the band to be recovered. To stop a
    %   NaN-everything "fix" from passing, `recoverableRegime...` pins the
    %   specific (family, SNR) cells that a noise-floor-aware estimator does
    %   recover, and requires a finite, accurate value there.
    %
    %   Determinism: RandStream objects with pinned seeds (never `rng`), so no
    %   global state is mutated and the test is immune to execution order.

    properties (Constant)
        Fs = 50e6
        N = 32768
        SymbolSeed = 20260808
        NoiseSeed = 424242
        % Seeds for the metastable transition zone, where a single noise
        % realization moves the current estimator between 1.1x and 4.6x.
        TransitionSeeds = [1 7 101 424242 20260808]
    end

    methods (Static)
        function x = rrcSignal(n, sps, beta, seed)
            % Root-raised-cosine QPSK; occupancy ~ (1/sps) of Fs.
            rs = RandStream('mt19937ar', 'Seed', seed);
            h = rcosdesign(beta, 10, sps, 'sqrt');
            nsym = ceil(n / sps) + 64;
            sym = (2 * randi(rs, [0 1], nsym, 1) - 1 + ...
                1i * (2 * randi(rs, [0 1], nsym, 1) - 1)) / sqrt(2);
            x = upfirdn(sym, h, sps);
            x = x(1:n);
            x = x / sqrt(mean(abs(x) .^ 2));
        end

        function x = bandlimitedSignal(n, frac, seed)
            % Filtered noise occupying `frac` of the Nyquist band.
            rs = RandStream('mt19937ar', 'Seed', seed);
            b = fir1(200, frac);
            x = filter(b, 1, (randn(rs, n, 1) + 1i * randn(rs, n, 1)) / sqrt(2));
            x = x / sqrt(mean(abs(x) .^ 2));
        end

        function y = addNoise(x, snrDb, seed)
            % Complex AWGN scaled to a TOTAL-POWER SNR target, matching how
            % ChannelFactory realizes Factories.Channel.LinkBudget target SNR.
            rs = RandStream('mt19937ar', 'Seed', seed);
            n = numel(x);
            y = x + sqrt(10 ^ (-snrDb / 10) / 2) * ...
                (randn(rs, n, 1) + 1i * randn(rs, n, 1));
        end

        function bw = measure(x, fs)
            s = csrd.pipeline.measurement.measureSignalSummary(x, fs, fs);
            bw = s.OccupiedBandwidthHz;
        end
    end

    methods (Access = private)
        function fams = families(testCase)
            n = testCase.N;
            fams = struct('Name', {}, 'X', {});
            fams(1).Name = 'narrow-RRC';        % ~15 % occupancy
            fams(1).X = testCase.rrcSignal(n, 6, 0.25, testCase.SymbolSeed);
            fams(2).Name = 'vnarrow-RRC';       % ~4 % occupancy
            fams(2).X = testCase.rrcSignal(n, 24, 0.25, testCase.SymbolSeed + 1);
            fams(3).Name = 'mid-0.40';          % ~40 % occupancy
            fams(3).X = testCase.bandlimitedSignal(n, 0.40, 777);
            fams(4).Name = 'wide-cap-0.77';     % at the regulatory 0.8 cap
            fams(4).X = testCase.bandlimitedSignal(n, 0.80, 888);
            xw = testCase.bandlimitedSignal(n, 0.40, 999);
            t = (0:n - 1)';
            xw = xw .* exp(1i * 2 * pi * 0.42 * t);
            fams(5).Name = 'nyquist-straddle';  % wraps the +/-Fs/2 edge
            fams(5).X = xw / sqrt(mean(abs(xw) .^ 2));
            xb = testCase.rrcSignal(n, 6, 0.25, testCase.SymbolSeed + 2);
            mask = zeros(n, 1);
            mask(1:round(0.2 * n)) = 1;
            xb = xb .* mask;
            fams(6).Name = 'burst-20pct';       % 20 % duty cycle
            fams(6).X = xb / sqrt(mean(abs(xb) .^ 2));
        end
    end

    methods (Test)

        function inflationIsBoundedOrDeclaredUnresolved(testCase)
            % Deep low-SNR regime: the reported bandwidth must either stay
            % within a factor of ~1.6 of the clean value, or be reported as
            % unresolvable (NaN). Publishing a finite 2.4x-27x value is the
            % defect. Anchored at -10 dB and below on purpose: -7/-8 dB is a
            % metastable transition zone (covered separately, loosely).
            snrs = [-20 -15 -12 -10];
            fams = testCase.families();
            for f = 1:numel(fams)
                clean = testCase.measure(fams(f).X, testCase.Fs);
                for s = snrs
                    y = testCase.addNoise(fams(f).X, s, testCase.NoiseSeed);
                    bw = testCase.measure(y, testCase.Fs);
                    if isnan(bw)
                        continue;   % explicitly unresolvable: acceptable
                    end
                    ratio = bw / clean;
                    testCase.verifyGreaterThanOrEqual(ratio, 0.60, ...
                        sprintf('%s @ %d dB collapsed (ratio %.2f)', fams(f).Name, s, ratio));
                    testCase.verifyLessThanOrEqual(ratio, 1.60, ...
                        sprintf('%s @ %d dB inflated (ratio %.2f)', fams(f).Name, s, ratio));
                end
            end
        end

        function recoverableRegimeStillPublishesAFiniteValue(testCase)
            % Guards against a NaN-everything "fix". These (family, SNR) cells
            % are recoverable by a noise-floor-aware estimator (calibration:
            % 0.83-1.18x of clean), so a finite and accurate value is required.
            cells = { 'narrow-RRC', [-12 -10]; ...
                      'vnarrow-RRC', -12; ...
                      'burst-20pct', [-12 -10] };
            fams = testCase.families();
            for c = 1:size(cells, 1)
                idx = find(strcmp({fams.Name}, cells{c, 1}), 1);
                clean = testCase.measure(fams(idx).X, testCase.Fs);
                for s = cells{c, 2}
                    y = testCase.addNoise(fams(idx).X, s, testCase.NoiseSeed);
                    bw = testCase.measure(y, testCase.Fs);
                    testCase.verifyTrue(isfinite(bw) && bw > 0, sprintf( ...
                        '%s @ %d dB is recoverable and must not be reported unresolvable', ...
                        cells{c, 1}, s));
                    ratio = bw / clean;
                    testCase.verifyGreaterThanOrEqual(ratio, 0.60, ...
                        sprintf('%s @ %d dB ratio %.2f', cells{c, 1}, s, ratio));
                    testCase.verifyLessThanOrEqual(ratio, 1.60, ...
                        sprintf('%s @ %d dB ratio %.2f', cells{c, 1}, s, ratio));
                end
            end
        end

        function narrowbandNeverReportsMoreThanHalfNyquist(testCase)
            % Occupancy statement independent of any OBW convention: a 15 %- or
            % 4 %-occupancy emitter can never legitimately occupy half the
            % captured band. This is the assertion worth keeping forever.
            snrs = [-20 -15 -12 -10 -8 -6 0 6 20 30];
            fams = testCase.families();
            keep = ismember({fams.Name}, {'narrow-RRC', 'vnarrow-RRC', 'burst-20pct'});
            fams = fams(keep);
            for f = 1:numel(fams)
                for s = snrs
                    y = testCase.addNoise(fams(f).X, s, testCase.NoiseSeed);
                    bw = testCase.measure(y, testCase.Fs);
                    if isnan(bw)
                        continue;
                    end
                    testCase.verifyLessThan(bw, 0.5 * testCase.Fs, sprintf( ...
                        '%s @ %d dB reported %.1f%% of Fs', fams(f).Name, s, ...
                        100 * bw / testCase.Fs));
                end
            end
        end

        function widebandKeepsItsWideReadingAtUsableSnr(testCase)
            % Anti-overcorrection gate. An emitter at the regulatory occupancy
            % cap (MaxBandwidthFractionOfSampleRate = 0.8) must KEEP its wide
            % reading. A blunt fix -- clamping to a fixed fraction of Fs, or
            % always preferring the noise-floor-relative estimate -- fails here.
            snrs = [0 3 6 12 20 30];
            fams = testCase.families();
            keep = ismember({fams.Name}, {'wide-cap-0.77', 'nyquist-straddle', 'mid-0.40'});
            fams = fams(keep);
            for f = 1:numel(fams)
                clean = testCase.measure(fams(f).X, testCase.Fs);
                for s = snrs
                    y = testCase.addNoise(fams(f).X, s, testCase.NoiseSeed);
                    bw = testCase.measure(y, testCase.Fs);
                    testCase.verifyTrue(isfinite(bw) && bw > 0, sprintf( ...
                        '%s @ %d dB must stay measurable', fams(f).Name, s));
                    ratio = bw / clean;
                    testCase.verifyGreaterThanOrEqual(ratio, 0.85, sprintf( ...
                        '%s @ %d dB lost its wide reading (ratio %.2f)', ...
                        fams(f).Name, s, ratio));
                end
            end
        end

        function healthySnrCohortIsUnchanged(testCase)
            % SNR >= 6 dB is the cohort the frozen release gate
            % (ExecutionVsMeasuredBwAbsRelDiffP95 < 3 %, baseline 0.0222)
            % samples. Any fix must leave it alone, so this pins it tightly.
            snrs = [6 12 20 30];
            fams = testCase.families();
            for f = 1:numel(fams)
                clean = testCase.measure(fams(f).X, testCase.Fs);
                for s = snrs
                    y = testCase.addNoise(fams(f).X, s, testCase.NoiseSeed);
                    bw = testCase.measure(y, testCase.Fs);
                    testCase.verifyTrue(isfinite(bw) && bw > 0, sprintf( ...
                        '%s @ %d dB must stay measurable', fams(f).Name, s));
                    ratio = bw / clean;
                    testCase.verifyGreaterThanOrEqual(ratio, 0.90, sprintf( ...
                        '%s @ %d dB ratio %.3f', fams(f).Name, s, ratio));
                    testCase.verifyLessThanOrEqual(ratio, 1.10, sprintf( ...
                        '%s @ %d dB ratio %.3f', fams(f).Name, s, ratio));
                end
            end
        end

        function transitionZoneIsBoundedAcrossNoiseSeeds(testCase)
            % -7/-8 dB is metastable for a 15 %-occupancy emitter: across noise
            % realizations the current estimator swings between ~1.1x and ~4.6x.
            % A loose bound plus several pinned seeds is the right shape here;
            % robustness comes from the seed sweep, not from a tight number.
            fams = testCase.families();
            idx = find(strcmp({fams.Name}, 'narrow-RRC'), 1);
            clean = testCase.measure(fams(idx).X, testCase.Fs);
            for s = [-8 -7]
                for seed = testCase.TransitionSeeds
                    y = testCase.addNoise(fams(idx).X, s, seed);
                    bw = testCase.measure(y, testCase.Fs);
                    if isnan(bw)
                        continue;
                    end
                    ratio = bw / clean;
                    testCase.verifyLessThan(ratio, 2.0, sprintf( ...
                        'narrow-RRC @ %d dB seed %d ratio %.2f', s, seed, ratio));
                end
            end
        end

        function pureNoiseNeverReportsAPlausibleNarrowBand(testCase)
            % With no emitter present the estimator must not manufacture a
            % narrow detection. Either it reports unresolvable, or it reports a
            % band wide enough to be self-evidently the whole capture.
            rs = RandStream('mt19937ar', 'Seed', 31337);
            x = (randn(rs, testCase.N, 1) + 1i * randn(rs, testCase.N, 1)) / sqrt(2);
            bw = testCase.measure(x, testCase.Fs);
            if isnan(bw)
                return;
            end
            testCase.verifyGreaterThan(bw, 0.5 * testCase.Fs, sprintf( ...
                'pure noise reported %.1f%% of Fs as an occupied band', ...
                100 * bw / testCase.Fs));
        end

    end
end
