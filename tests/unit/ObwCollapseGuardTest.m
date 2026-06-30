classdef ObwCollapseGuardTest < matlab.unittest.TestCase
    % ObwCollapseGuardTest
    %
    % Pins the OBW collapse guard. A genuinely wideband signal whose flat
    % occupied band sits a few dB below a single localized spectral spike
    % (short bursts with high spectral variance, or a frequency-selective
    % channel peak) must NOT collapse to the spike's width: the peak-relative
    % -3 dB threshold would otherwise clip the whole flat band away. Both
    % estimators (obwActual peak-relative + measureSignalSummary) must report
    % the wide band, and must stay equivalent. The guard must also not
    % over-trigger on a genuinely narrow signal.

    methods (Test)

        function widebandWithDominantSpikeDoesNotCollapse(testCase)
            fs = 50e6; N = 8192;
            s = RandStream('mt19937ar', 'Seed', 7);
            % ~20 MHz two-sided flat occupied band: low-pass filtered noise.
            b = fir1(80, 0.4);
            x = filter(b, 1, complex(randn(s, N, 1), randn(s, N, 1)));
            x = x / sqrt(mean(abs(x) .^ 2));
            % A dominant localized spectral spike at +4 MHz. Pre-fix, the
            % peak-relative -3 dB threshold latches onto this and collapses the
            % measured OBW to ~1 bin.
            t = (0:N - 1)' / fs;
            x = x + 0.8 * exp(1j * 2 * pi * 4e6 * t);

            bwA = csrd.pipeline.measurement.obwActual(x, fs);
            sm = csrd.pipeline.measurement.measureSignalSummary(x, fs, fs);

            testCase.verifyGreaterThan(bwA, 10e6, ...
                'obwActual collapsed on the spike instead of measuring the wide band');
            testCase.verifyGreaterThan(sm.OccupiedBandwidthHz, 10e6, ...
                'measureSignalSummary collapsed on the spike');
            % the two estimators must stay equivalent
            testCase.verifyEqual(sm.OccupiedBandwidthHz, bwA, 'RelTol', 0.05);

            % The center frequency must also resist the spike: the band is
            % centred near 0 Hz, so the measured center must track the band, not
            % collapse onto the +4 MHz spike (peak-relative alone gives ~+4 MHz).
            fc = csrd.pipeline.measurement.spectrumCentroid(x, fs);
            testCase.verifyLessThan(abs(fc), 3e6, ...
                'center frequency collapsed onto the spike instead of the band');
            testCase.verifyEqual(sm.CenterFrequencyHz, fc, 'AbsTol', 1e5);
        end

        function cleanNarrowbandStaysNarrow(testCase)
            % The guard must not over-trigger: a genuinely narrow signal keeps
            % its narrow OBW (the floor-relative fallback only wins when the
            % peak-relative estimate is implausibly narrow vs the occupied band).
            fs = 50e6; N = 8192;
            t = (0:N - 1)' / fs;
            x = exp(1j * 2 * pi * 1e6 * t);   % pure tone -> genuinely narrow
            bwA = csrd.pipeline.measurement.obwActual(x, fs);
            testCase.verifyLessThan(bwA, 5e6, ...
                'collapse guard over-widened a genuinely narrow tone');
        end

    end
end
