classdef OccupiedBandwidthAgainstTheoryTest < matlab.unittest.TestCase
    % OccupiedBandwidthAgainstTheoryTest - Pin the DEFINITION, not the repeatability.
    %
    %   Every other bandwidth gate in this repository compares one of our numbers
    %   against another of our numbers. Truth.Execution vs Truth.Measured run the
    %   same kernel on different buffers, so they agree even when the kernel
    %   computes the wrong quantity -- which is exactly what happened: a -3 dB-down
    %   main-lobe width shipped for several releases under the name "occupied
    %   bandwidth" with those gates green, because a definition error moves every
    %   self-referential comparison together.
    %
    %   This class closes that hole by testing against references OUTSIDE this
    %   codebase:
    %
    %     1. Published theory. A root-raised-cosine pulse with roll-off beta is
    %        STRICTLY bandlimited to (1+beta)*Rs (ITU-R SM.328 defines the
    %        occupied bandwidth as the 99 %-power band; the RRC transfer function
    %        is identically zero outside (1+beta)*Rs/2). Two consequences are
    %        mathematical facts, not tolerances:
    %          - OBW <= (1+beta)*Rs, with NO slack, for any percentage <= 100.
    %          - OBW/Rs rises monotonically with beta, because widening the
    %            roll-off moves power outward. An x-dB-down width does NOT have
    %            this property at small x -- the old estimator measured
    %            0.897/0.901/0.803 * Rs at beta = 0.1/0.25/0.5, i.e. it was blind
    %            to the very parameter it should track. That is the specific
    %            regression this test exists to prevent.
    %
    %     2. An independent implementation. MATLAB's obw() computes the same ITU
    %        definition with different spectrum preparation, so agreement to a
    %        percent is evidence about the definition rather than about our code.
    %
    %   The absolute anchors are deliberately hard coded. They come from the
    %   closed-form tail integral of the raised-cosine spectrum: the one-sided
    %   power beyond an edge is P = (beta/2pi)(x - sin x) with
    %   x = pi - (pi/beta)(2f/Rs - (1 - beta)), so the 99 % edge solves
    %   x - sin x = 0.01*pi/beta (a Kepler-type equation, no elementary closed
    %   form, but numerically exact) and
    %       OBW/Rs = (1 + beta) - 2*beta*x/pi.
    %   Values: 1.01922 / 1.07308 / 1.10307 / 1.16666 / 1.26801 * Rs at
    %   beta = 0.1 / 0.2 / 0.25 / 0.35 / 0.5. This agrees with the published
    %   curve in ITU-R SM.853-2 Table 2 and Figure 1 (K versus roll-off for m-QAM,
    %   parameterised by power-containment factor, with Bn = 2*K*Rs), reproduced as
    %   Figure 1 of NTIA Redbook Annex J. If a future refactor moves these, that is
    %   a change of published quantity and must be an explicit decision.
    %
    %   Scope note: the r <= 1 ceiling tested here belongs ONLY to strictly
    %   bandlimited families -- RRC-shaped linear single carrier, and AM/SSB with a
    %   bandlimited message. It does NOT generalise. A rectangular-windowed OFDM
    %   signal has sinc-squared tails and legitimately reaches
    %   OBW = 1.86 * (N*df) at N = 12 occupied subcarriers; 4-ary CPFSK at h = 1
    %   legitimately reaches 3.4x its (1+beta)Rs allocation. Do not copy this
    %   assertion to those families.

    properties (Constant)
        SymbolRate = 1e6
        NumSymbols = 8192
        SamplesPerSymbol = 8
        FilterSpanSymbols = 12
    end

    methods (Test)

        function obwNeverExceedsTheStrictBandlimit(testCase)
            % The hard ceiling. A strictly bandlimited pulse has ALL of its power
            % inside (1+beta)*Rs, so a 99 %-power band cannot be wider. No slack:
            % exceeding this is not imprecision, it is a different quantity.
            for beta = [0.1, 0.2, 0.25, 0.35, 0.5]
                [x, Fs] = testCase.makeRrcQam(beta);
                bwHz = csrd.pipeline.measurement.obwActual(x, Fs);
                limitHz = (1 + beta) * testCase.SymbolRate;
                testCase.verifyLessThanOrEqual(bwHz, limitHz, sprintf( ...
                    ['beta=%.2f: OBW=%.6g exceeds the strict bandlimit ', ...
                     '(1+beta)*Rs=%.6g. An RRC pulse has zero power beyond that ', ...
                     'frequency, so a 99%%-power band cannot reach it -- the ', ...
                     'reported quantity is not an occupied bandwidth.'], ...
                    beta, bwHz, limitHz));
            end
        end

        function obwRisesMonotonicallyWithRolloff(testCase)
            % The discriminating property. The published quantity must track
            % beta; the -3 dB-down width it replaced did not.
            betas = [0.1, 0.2, 0.25, 0.35, 0.5];
            ratios = zeros(size(betas));
            for k = 1:numel(betas)
                [x, Fs] = testCase.makeRrcQam(betas(k));
                ratios(k) = csrd.pipeline.measurement.obwActual(x, Fs) / ...
                    testCase.SymbolRate;
            end
            testCase.verifyTrue(all(diff(ratios) > 0), sprintf( ...
                ['OBW/Rs must increase with roll-off; got [%s] for beta [%s]. ', ...
                 'A non-increasing sequence means the estimator is measuring a ', ...
                 'main-lobe footprint, which is beta-independent, rather than ', ...
                 'the ITU 99%%-power band.'], ...
                strjoin(compose('%.4f', ratios), ' '), ...
                strjoin(compose('%.2f', betas), ' ')));
            % And the rise must be material, not floating-point noise. The
            % closed form gives 1.26801 - 1.01922 = 0.2488 * Rs over this range.
            testCase.verifyGreaterThan(ratios(end) - ratios(1), 0.20, sprintf( ...
                ['The beta = 0.1 -> 0.5 spread must be >= 0.20*Rs (closed form ', ...
                 '0.2488); got %.4f.'], ratios(end) - ratios(1)));
        end

        function obwMatchesTheAnalyticAnchorAtQuarterRolloff(testCase)
            % The absolute value, at the planner's default roll-off.
            [x, Fs] = testCase.makeRrcQam(0.25);
            ratio = csrd.pipeline.measurement.obwActual(x, Fs) / testCase.SymbolRate;
            % 1.10307 is the ideal infinite-length pulse. A 12-symbol truncation
            % raises the stopband floor slightly, so the realisable value sits a
            % few tenths of a percent low; 0.02 covers that without covering a
            % change of definition (the -3 dB width this replaced read 0.901).
            testCase.verifyEqual(ratio, 1.10307, 'AbsTol', 0.02, sprintf( ...
                ['OBW/Rs = %.4f at beta = 0.25; the closed-form value is ', ...
                 '1.10307 (ITU-R SM.853-2 Table 2). A drift here is a change ', ...
                 'of published quantity, not a tolerance question.'], ratio));
        end

        function ourKernelAgreesWithAnIndependentImplementation(testCase)
            % Cross-implementation agreement is evidence about the DEFINITION.
            for beta = [0.1, 0.25, 0.5]
                [x, Fs] = testCase.makeRrcQam(beta);
                ours = csrd.pipeline.measurement.obwActual(x, Fs);
                theirs = csrd.pipeline.measurement.obwActual(x, Fs, 99, ...
                    'Method', 'matlab-obw');
                testCase.verifyEqual(ours, theirs, 'RelTol', 0.02, sprintf( ...
                    ['beta=%.2f: our kernel %.6g vs MATLAB obw() %.6g. These are ', ...
                     'independent implementations of one ITU definition; a gap ', ...
                     'means one of them is not computing that definition.'], ...
                    beta, ours, theirs));
            end
        end

        function flatSpectrumMeasuresNinetyNinePercentOfNyquist(testCase)
            % The other end of the definition, and an exact analytic anchor: a flat
            % power spectral density spread over the whole Nyquist span has 99 % of
            % its power in 0.99 * Fs, by inspection of the integral. White noise is
            % the realisable case.
            %
            % This is also the asymptote every flat-topped family approaches -- a
            % root-raised-cosine with beta -> 0, a large-N OFDM signal, a
            % high-time-bandwidth chirp -- so it pins the ceiling of the whole
            % quantity, not just a noise property. And it is the direction an
            % estimator fails in when it mistakes a noise floor for signal, which
            % is the failure that produced the historical inflation: the number
            % must approach 0.99 * Fs, and an estimator that reported a plausible
            % NARROW band for pure noise would be finding structure that is not
            % there.
            Fs = 50e6;
            n = 32768;
            rs = RandStream('mt19937ar', 'Seed', 424242);
            x = (randn(rs, n, 1) + 1i * randn(rs, n, 1)) / sqrt(2);
            bwHz = csrd.pipeline.measurement.obwActual(x, Fs);
            testCase.verifyEqual(bwHz / Fs, 0.99, 'AbsTol', 0.01, sprintf( ...
                ['White noise measured %.4f * Fs; a flat spectrum contains 99 %% ', ...
                 'of its power in exactly 0.99 * Fs. A materially narrower answer ', ...
                 'means the estimator is finding structure in noise.'], bwHz / Fs));
        end

        function concentrationRatioSeparatesALobeFromAFloor(testCase)
            % The discriminator that BandwidthResolutionCells structurally cannot
            % provide. That one divides the reported width by the analysis
            % resolution, so an INFLATED reading earns a HIGH cell count and passes
            % as well resolved -- the dataset's worst Measured-vs-Execution cluster
            % sailed through it at 77 cells while holding half its power in 350 kHz.
            %
            % SpectralConcentrationRatio = 99 %-span / 50 %-span compares two widths
            % of the SAME distribution, so it measures shape. It is ~2 for anything
            % well behaved, including a flat spectrum (0.99*Fs / 0.5*Fs = 1.98), and
            % grows only when a narrow lobe sits on a broadband floor.
            [x, Fs] = testCase.makeRrcQam(0.25);
            lobe = csrd.pipeline.measurement.measureSignalSummary(x, Fs, Fs);
            testCase.verifyLessThan(lobe.SpectralConcentrationRatio, 4, sprintf( ...
                ['A clean root-raised-cosine is lobe-dominated; concentration ', ...
                 '%.3f should sit near 2.'], lobe.SpectralConcentrationRatio));

            rs = RandStream('mt19937ar', 'Seed', 424242);
            n = (randn(rs, 32768, 1) + 1i * randn(rs, 32768, 1)) / sqrt(2);
            flat = csrd.pipeline.measurement.measureSignalSummary(n, 50e6, 50e6);
            testCase.verifyLessThan(flat.SpectralConcentrationRatio, 4, sprintf( ...
                ['A flat spectrum must ALSO read near 2 (0.99*Fs / 0.5*Fs = 1.98); ', ...
                 'got %.3f. A metric that flagged wideband signals as pathological ', ...
                 'would just be a width test in disguise.'], ...
                flat.SpectralConcentrationRatio));

            % A narrow lobe on a wide floor: the shape a frequency-selective null
            % produces when it suppresses the lobe by ~10 dB and leaves the floor.
            % Its ITU 99 % bandwidth is CORRECTLY wide, which is exactly why width
            % alone cannot detect it.
            FsWide = 50e6;
            nWide = numel(x);
            tWide = (0:nWide - 1)' / FsWide;
            narrow = exp(1i * 2 * pi * 3e5 * tWide);
            rs2 = RandStream('mt19937ar', 'Seed', 99);
            floorNoise = (randn(rs2, nWide, 1) + 1i * randn(rs2, nWide, 1)) / sqrt(2);
            mixed = narrow + 0.1 * floorNoise;   % floor at -20 dBc, band-filling
            notched = csrd.pipeline.measurement.measureSignalSummary(mixed, FsWide, FsWide);
            testCase.verifyGreaterThan(notched.SpectralConcentrationRatio, 8, sprintf( ...
                ['A narrow lobe on a -20 dBc band-filling floor must be flagged: ', ...
                 'OBW %.4g Hz with half the power inside %.4g Hz is concentration ', ...
                 '%.2f, and the gate threshold is 8.'], ...
                notched.OccupiedBandwidthHz, notched.HalfPowerSpanHz, ...
                notched.SpectralConcentrationRatio));
        end

        function resolutionCellsRiseWithTheActiveBurstLength(testCase)
            % The conditions published beside the value must actually track the
            % measurement's quality. A burst gated into a long frame is the case
            % where a wide reading is TRUE of an unphysically gated signal rather
            % than a measurement error, and BandwidthResolutionCells is what lets
            % a consumer tell the two apart -- so it must move with the burst
            % length, not sit at a constant.
            [x, Fs] = testCase.makeRrcQam(0.25);
            frameLen = 32768;
            cellsByLength = zeros(1, 3);
            activeLengths = [128, 1024, 8192];
            for k = 1:numel(activeLengths)
                frame = zeros(frameLen, 1);
                n = min(activeLengths(k), numel(x));
                frame(1:n) = x(1:n);
                s = csrd.pipeline.measurement.measureSignalSummary(frame, Fs, Fs);
                cellsByLength(k) = s.BandwidthResolutionCells;
                testCase.verifyEqual(s.ActiveSampleCount, n, sprintf( ...
                    'ActiveSampleCount must count the samples carrying energy (%d).', n));
            end
            testCase.verifyTrue(all(diff(cellsByLength) > 0), sprintf( ...
                ['BandwidthResolutionCells must rise with the active burst ', ...
                 'length; got [%s] for active [%s]. A constant would mean the ', ...
                 'published conditions carry no information about the reading.'], ...
                strjoin(compose('%.2f', cellsByLength), ' '), ...
                strjoin(compose('%d', activeLengths), ' ')));
        end

    end

    methods (Access = private)

        function [x, Fs] = makeRrcQam(testCase, beta)
            % A textbook root-raised-cosine 16-QAM waveform: the reference signal
            % whose occupied bandwidth theory predicts in closed form. Built here
            % from MATLAB primitives rather than from a CSRD modulator, on purpose
            % -- a modulator defect must not be able to make this test agree.
            rng(7);
            symbols = qammod(randi([0, 15], testCase.NumSymbols, 1), 16, ...
                'UnitAveragePower', true);
            pulse = rcosdesign(beta, testCase.FilterSpanSymbols, ...
                testCase.SamplesPerSymbol, 'sqrt');
            x = upfirdn(symbols, pulse, testCase.SamplesPerSymbol);
            x = x(:) / sqrt(mean(abs(x) .^ 2));
            Fs = testCase.SymbolRate * testCase.SamplesPerSymbol;
        end

    end

end
