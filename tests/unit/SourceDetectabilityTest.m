classdef SourceDetectabilityTest < matlab.unittest.TestCase
    % SourceDetectabilityTest - the shared detectability rule and its two
    % downstream consumers (the plausibility gate, the RT OBW bound).
    %
    %   Ray tracing bypasses the controlled-SNR realization, so a shadowed
    %   link can arrive far under the frame noise while its pre-noise
    %   SourcePlane still carries a confident label. sourceDetectability is
    %   the one rule that marks such a source; these cases pin the rule, that
    %   the plausibility gate exempts a marked-buried source from the SNR
    %   lower bound, and that it relaxes the occupied-bandwidth bound for RT.

    methods (Test)

        function ruleSplitsAtTheDocumentedFloor(testCase)
            [d1, s1, f1] = csrd.pipeline.measurement.sourceDetectability(-29.9);
            testCase.verifyTrue(d1);
            testCase.verifyEqual(s1, 'Detectable');
            testCase.verifyEqual(f1, -30);
            [d2, s2] = csrd.pipeline.measurement.sourceDetectability(-30.1);
            testCase.verifyFalse(d2);
            testCase.verifyEqual(s2, 'BelowNoiseFloor');
        end

        function nanSnrIsNoSignal(testCase)
            [d, s] = csrd.pipeline.measurement.sourceDetectability(NaN);
            testCase.verifyFalse(d);
            testCase.verifyEqual(s, 'NoSignal');
        end

        function gateExemptsBuriedSourceFromSnrLowerBound(testCase)
            % A ray-traced blocked link at -106 dB, explicitly marked
            % not-detectable, must NOT be a hard violation -- the deep SNR is
            % the honest label of a buried emitter, reported once already.
            sp = SourceDetectabilityTest.plane(20e6, 0, -106.2, false);
            ctx = struct('ChannelModel', 'RayTracing', 'MeasurementStatus', 'Measured');
            v = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 'buried', ctx);
            testCase.verifyEmpty(v, ...
                'A marked-buried source must not trip the SNR lower bound.');
        end

        function gateStillFlagsBuriedSnrOnADetectableSource(testCase)
            % If a source is flagged Detectable yet its SNR is -106, that is a
            % contradiction the gate must still catch.
            sp = SourceDetectabilityTest.plane(20e6, 0, -106.2, true);
            ctx = struct('ChannelModel', 'RayTracing', 'MeasurementStatus', 'Measured');
            v = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 'bad', ctx);
            testCase.verifyNotEmpty(v, ...
                'A Detectable source at -106 dB is a contradiction, not exempt.');
        end

        function gateAlwaysFlagsAbsurdlyHighSnr(testCase)
            sp = SourceDetectabilityTest.plane(20e6, 0, 250, false);
            ctx = struct('ChannelModel', 'RayTracing', 'MeasurementStatus', 'Measured');
            v = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 'hi', ctx);
            testCase.verifyNotEmpty(v, '+250 dB SNR is a bug regardless of channel.');
        end

        function rayTracingRelaxesTheOccupiedBandwidthBound(testCase)
            % A 40 MHz OFDM emitter multipath-widened to 49.5 MHz on a 50 MHz
            % capture: a violation under the statistical 0.85*Fs bound, legal
            % under the RayTracing 0.98*Fs bound.
            sp = SourceDetectabilityTest.plane(49.5e6, 4e6, 14, true);
            stat = struct('ChannelModel', 'Rayleigh', 'MeasurementStatus', 'Measured');
            rt = struct('ChannelModel', 'RayTracing', 'MeasurementStatus', 'Measured');
            vStat = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 's', stat);
            vRt = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 'r', rt);
            testCase.verifyNotEmpty(vStat, ...
                'Statistical channel keeps the strict 0.85*Fs bound.');
            testCase.verifyEmpty(vRt, ...
                'RayTracing multipath fill to 0.99*Fs is legitimate.');
        end

        function rayTracingStillFlagsBandwidthExceedingFs(testCase)
            % Even under RT, an OBW past the sampled band is an aliasing fault.
            sp = SourceDetectabilityTest.plane(52e6, 0, 14, true);
            rt = struct('ChannelModel', 'RayTracing', 'MeasurementStatus', 'Measured');
            v = csrd.test_support.measuredPlausibilityViolations(sp, 50e6, 'r', rt);
            testCase.verifyNotEmpty(v, 'OBW > Fs must still be a violation under RT.');
        end

    end

    methods (Static)

        function sp = plane(obwHz, ctrHz, snrDb, detectable)
            % plane - a minimal well-formed SourcePlane for the gate.
            sp = struct( ...
                'OccupiedBandwidthHz', obwHz, ...
                'CenterFrequencyHz', ctrHz, ...
                'SNRdB', snrDb, ...
                'TimeOccupancy', 1, ...
                'FrequencyOccupancy', 0.5, ...
                'BandwidthResolutionHz', 1e5, ...
                'BandwidthResolutionCells', obwHz / 1e5, ...
                'ActiveSampleCount', 4096, ...
                'SpectralConcentrationRatio', 3.5, ...
                'Detectable', detectable, ...
                'MeasurementStatus', 'Measured');
        end

    end

end
