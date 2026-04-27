classdef MeasurementPackageTest < matlab.unittest.TestCase
    %MEASUREMENTPACKAGETEST Phase 4 §3.1 / S1 measurement-package contracts.
    %
    %   Pin the contract for the 5 receiver-view measurement helpers
    %   (`+csrd/+utils/+measurement/`):
    %       obwActual / spectrumCentroid / actualSnrFromComponents /
    %       detectBurstEnvelope / frequencyOccupancy
    %
    %   These functions provide Truth.Measured.{SourcePlane,FramePlane}
    %   primitives. They MUST be deterministic, MUST fail-fast on dirty
    %   input, and MUST never return silent NaN unless the caller-supplied
    %   semantics require it (only frequencyOccupancy is allowed to return
    %   NaN, and only when observableBwHz <= 0).

    properties (Constant, Access = private)
        % Common reference setup for spectral tests.
        SampleRate = 1e6;        % 1 MHz baseband
        Duration   = 0.01;       % 10 ms -> 10 000 samples
    end

    methods (Test)

        % =========================================================
        % obwActual: 6 cases
        % =========================================================

        function obwActualBandlimitedNoiseClose(testCase)
            % AWGN low-pass-filtered to 200 kHz should report ~200-220 kHz OBW.
            rng(20260425, 'twister');
            t = (0:1/testCase.SampleRate:testCase.Duration - 1/testCase.SampleRate)';
            noise = (randn(numel(t), 1) + 1j * randn(numel(t), 1)) / sqrt(2);
            cutoff = 200e3 / (testCase.SampleRate / 2);
            [b, a] = butter(8, cutoff);
            filtered = filter(b, a, noise);
            bw = csrd.utils.measurement.obwActual(filtered, testCase.SampleRate, 99);
            testCase.verifyGreaterThan(bw, 100e3);
            testCase.verifyLessThan(bw, 600e3);
        end

        function obwActualSinusoidNarrow(testCase)
            % Pure sinusoid -> very narrow OBW (~ 2 main-lobe widths).
            t = (0:1/testCase.SampleRate:testCase.Duration - 1/testCase.SampleRate)';
            sig = exp(1j * 2 * pi * 100e3 * t);
            bw = csrd.utils.measurement.obwActual(sig, testCase.SampleRate, 99);
            testCase.verifyLessThan(bw, 5e3);
        end

        function obwActualEmptyThrows(testCase)
            f = @() csrd.utils.measurement.obwActual([], 1e6, 99);
            testCase.verifyError(f, 'CSRD:Measurement:EmptySignal');
        end

        function obwActualNaNThrows(testCase)
            sig = [1; 2; NaN; 4];
            f = @() csrd.utils.measurement.obwActual(sig, 1e6, 99);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidSignal');
        end

        function obwActualBadSampleRateThrows(testCase)
            f = @() csrd.utils.measurement.obwActual([1; 2; 3], 0, 99);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidSampleRate');
        end

        function obwActualBadPercentageThrows(testCase)
            f = @() csrd.utils.measurement.obwActual([1; 2; 3], 1e6, 0);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidPercentage');
        end

        % =========================================================
        % spectrumCentroid: 5 cases
        % =========================================================

        function spectrumCentroidDcAtZero(testCase)
            sig = ones(2048, 1);
            fc = csrd.utils.measurement.spectrumCentroid(sig, testCase.SampleRate);
            testCase.verifyEqual(fc, 0, 'AbsTol', 10);
        end

        function spectrumCentroidPositiveTone(testCase)
            t = (0:1/testCase.SampleRate:testCase.Duration - 1/testCase.SampleRate)';
            sig = exp(1j * 2 * pi * 200e3 * t);
            fc = csrd.utils.measurement.spectrumCentroid(sig, testCase.SampleRate);
            testCase.verifyEqual(fc, 200e3, 'RelTol', 0.02);
        end

        function spectrumCentroidNegativeTone(testCase)
            t = (0:1/testCase.SampleRate:testCase.Duration - 1/testCase.SampleRate)';
            sig = exp(1j * 2 * pi * (-150e3) * t);
            fc = csrd.utils.measurement.spectrumCentroid(sig, testCase.SampleRate);
            testCase.verifyEqual(fc, -150e3, 'RelTol', 0.02);
        end

        function spectrumCentroidEmptyThrows(testCase)
            f = @() csrd.utils.measurement.spectrumCentroid([], 1e6);
            testCase.verifyError(f, 'CSRD:Measurement:EmptySignal');
        end

        function spectrumCentroidNaNThrows(testCase)
            f = @() csrd.utils.measurement.spectrumCentroid([1; NaN], 1e6);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidSignal');
        end

        % =========================================================
        % actualSnrFromComponents: 6 cases
        % =========================================================

        function snrThirtyDb(testCase)
            snr = csrd.utils.measurement.actualSnrFromComponents(1, 1e-3);
            testCase.verifyEqual(snr, 30, 'AbsTol', 1e-9);
        end

        function snrZeroDb(testCase)
            snr = csrd.utils.measurement.actualSnrFromComponents(1, 1);
            testCase.verifyEqual(snr, 0, 'AbsTol', 1e-9);
        end

        function snrZeroSignalGivesNegInf(testCase)
            snr = csrd.utils.measurement.actualSnrFromComponents(0, 1);
            testCase.verifyEqual(snr, -Inf);
        end

        function snrNonPositiveNoiseThrows(testCase)
            f = @() csrd.utils.measurement.actualSnrFromComponents(1, 0);
            testCase.verifyError(f, 'CSRD:Measurement:NonPositiveNoise');
        end

        function snrNegativeSignalThrows(testCase)
            f = @() csrd.utils.measurement.actualSnrFromComponents(-1, 1);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidPower');
        end

        function snrNanInputThrows(testCase)
            f = @() csrd.utils.measurement.actualSnrFromComponents(NaN, 1);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidPower');
        end

        % =========================================================
        % detectBurstEnvelope: 5 cases
        % =========================================================

        function detectBurstFullEnvelope(testCase)
            sig = ones(10000, 1);
            info = csrd.utils.measurement.detectBurstEnvelope( ...
                sig, testCase.SampleRate);
            testCase.verifyEqual(info.TimeOccupancy, 1, 'AbsTol', 1e-9);
            testCase.verifyEqual(info.NumBursts, 1);
        end

        function detectBurstHalfEnvelope(testCase)
            % First 5000 samples high, remainder zero. WindowSec=1e-4 ->
            % 100 windows of 100 samples each at Fs=1e6. The transition
            % window straddles the boundary; with peak-relative -20 dB
            % threshold, half of the windows are above threshold.
            sig = [ones(5000, 1); zeros(5000, 1)];
            info = csrd.utils.measurement.detectBurstEnvelope( ...
                sig, testCase.SampleRate);
            testCase.verifyEqual(info.TimeOccupancy, 0.5, 'AbsTol', 0.02);
            testCase.verifyGreaterThanOrEqual(info.NumBursts, 1);
        end

        function detectBurstAllZeroIsZero(testCase)
            sig = zeros(10000, 1);
            info = csrd.utils.measurement.detectBurstEnvelope( ...
                sig, testCase.SampleRate);
            testCase.verifyEqual(info.TimeOccupancy, 0);
            testCase.verifyEqual(info.NumBursts, 0);
        end

        function detectBurstMultipleRunsCounted(testCase)
            sig = repmat([ones(1000, 1); zeros(1000, 1)], 5, 1);
            info = csrd.utils.measurement.detectBurstEnvelope( ...
                sig, testCase.SampleRate);
            testCase.verifyEqual(info.NumBursts, 5);
            testCase.verifyEqual(info.TimeOccupancy, 0.5, 'AbsTol', 0.05);
        end

        function detectBurstNanThrows(testCase)
            f = @() csrd.utils.measurement.detectBurstEnvelope( ...
                [1; NaN; 1], 1e6);
            testCase.verifyError(f, 'CSRD:Measurement:InvalidSignal');
        end

        % =========================================================
        % frequencyOccupancy: 5 cases
        % =========================================================

        function freqOccHalf(testCase)
            occ = csrd.utils.measurement.frequencyOccupancy(25e6, 50e6);
            testCase.verifyEqual(occ, 0.5);
        end

        function freqOccClipsToOne(testCase)
            occ = csrd.utils.measurement.frequencyOccupancy(75e6, 50e6);
            testCase.verifyEqual(occ, 1);
        end

        function freqOccZeroObservableIsNaN(testCase)
            occ = csrd.utils.measurement.frequencyOccupancy(25e6, 0);
            testCase.verifyTrue(isnan(occ));
        end

        function freqOccNanOccupiedIsNaN(testCase)
            occ = csrd.utils.measurement.frequencyOccupancy(NaN, 50e6);
            testCase.verifyTrue(isnan(occ));
        end

        function freqOccNegativeThrows(testCase)
            f = @() csrd.utils.measurement.frequencyOccupancy(-1, 50e6);
            testCase.verifyError(f, 'CSRD:Measurement:NegativeBandwidth');
        end

    end
end
