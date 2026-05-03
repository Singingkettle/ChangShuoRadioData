classdef ApplyDopplerShiftTest < matlab.unittest.TestCase
    %APPLYDOPPLERSHIFTTEST Phase 4 §3.2 / S2 Doppler-shift contract.
    %
    %   Pin the contract for
    %   csrd.blocks.physical.channel.impairments.applyDopplerShift:
    %     1) Static Tx -> dopplerHz == 0, signal unchanged.
    %     2) Closing LOS  -> dopplerHz > 0 with classical f_d formula.
    %     3) Opening LOS  -> dopplerHz < 0 (mirror of #2).
    %     4) Pure transverse motion -> dopplerHz ~ 0 (LOS projection).
    %     5) Coincident Tx/Rx geometry -> fail-fast.
    %     6) Spectrum centroid shifts by analytical f_d on a 1 kHz tone.

    properties (Constant, Access = private)
        SpeedOfLight = 299792458; % m/s, exact SI
    end

    methods (Test)

        function staticTxYieldsZeroDoppler(testCase)
            sig = (1:1000).' + 1j * 0;
            [shifted, fd, vRad] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], [0, 0, 0], [100, 0, 0]);
            testCase.verifyEqual(fd, 0);
            testCase.verifyEqual(vRad, 0);
            testCase.verifyEqual(shifted, sig);
        end

        function closingLosYieldsPositiveDoppler(testCase)
            % Tx at origin moving toward Rx at +x (10 m/s). Carrier 1 GHz.
            % f_d = 10 * 1e9 / c
            t = (0:1/1e6:0.001 - 1/1e6).';
            sig = exp(1j * 2 * pi * 0 * t); % DC tone -> easy verification
            txVel = [10, 0, 0];
            [~, fd, vRad] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], txVel, [100, 0, 0]);
            expected = 10 * 1e9 / testCase.SpeedOfLight;
            testCase.verifyEqual(vRad, 10, 'AbsTol', 1e-9);
            testCase.verifyEqual(fd, expected, 'RelTol', 1e-9);
            testCase.verifyGreaterThan(fd, 0);
        end

        function openingLosYieldsNegativeDoppler(testCase)
            t = (0:1/1e6:0.001 - 1/1e6).';
            sig = exp(1j * 2 * pi * 0 * t);
            txVel = [-10, 0, 0];
            [~, fd, vRad] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], txVel, [100, 0, 0]);
            expected = -10 * 1e9 / testCase.SpeedOfLight;
            testCase.verifyEqual(vRad, -10, 'AbsTol', 1e-9);
            testCase.verifyEqual(fd, expected, 'RelTol', 1e-9);
            testCase.verifyLessThan(fd, 0);
        end

        function transverseMotionGivesZeroDoppler(testCase)
            % Tx at origin moving in +y (perpendicular to Tx->Rx along +x).
            t = (0:1/1e6:0.001 - 1/1e6).';
            sig = exp(1j * 2 * pi * 0 * t);
            txVel = [0, 10, 0];
            [shifted, fd, vRad] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], txVel, [100, 0, 0]);
            testCase.verifyEqual(vRad, 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(fd, 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(shifted, sig);
        end

        function movingReceiverContributesToRelativeDoppler(testCase)
            % Tx stationary, Rx at +x moving toward Tx at -10 m/s. The
            % caller composes Tx-Rx velocity, so Doppler is still closing.
            t = (0:1/1e6:0.001 - 1/1e6).';
            sig = exp(1j * 2 * pi * 0 * t);
            [relativeVel, ~, ~] = ...
                csrd.core.ChangShuo.resolveRelativeVelocityForDoppler( ...
                    struct('Velocity', [0, 0, 0]), ...
                    struct('Velocity', [-10, 0, 0]));
            [~, fd, vRad] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], relativeVel, [100, 0, 0]);
            expected = 10 * 1e9 / testCase.SpeedOfLight;
            testCase.verifyEqual(vRad, 10, 'AbsTol', 1e-9);
            testCase.verifyEqual(fd, expected, 'RelTol', 1e-9);
        end

        function coincidentGeometryThrows(testCase)
            sig = (1:100).' + 1j * 0;
            f = @() csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0, 0], [10, 0, 0], [0, 0, 0]);
            testCase.verifyError(f, 'CSRD:Channel:DopplerInvalidGeometry');
        end

        function spectrumCentroidShiftsByAnalyticalFd(testCase)
            % Generate a complex sinusoid at +100 kHz baseband; apply Doppler
            % from a 300 m/s closing Tx at 1 GHz carrier.
            % f_d_analytical = 300 * 1e9 / c ~ 1000.69 Hz.
            % After Doppler the centroid should shift to ~ 100 kHz + f_d.
            fs = 1e6;
            t = (0:1/fs:0.01 - 1/fs).';
            baseTone = exp(1j * 2 * pi * 100e3 * t);
            txVel = [300, 0, 0];
            [shifted, fd, ~] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(baseTone, fs, 1e9, ...
                    [0, 0, 0], txVel, [1000, 0, 0]);
            measuredCentroid = csrd.pipeline.measurement.spectrumCentroid( ...
                shifted, fs);
            expectedCentroid = 100e3 + fd;
            testCase.verifyEqual(measuredCentroid, expectedCentroid, ...
                'AbsTol', fs / length(shifted) * 2);
        end

        function multiAntennaSignalIsBroadcastShifted(testCase)
            % 2 antennas should both receive the same time-varying phase.
            fs = 1e6;
            t = (0:1/fs:0.001 - 1/fs).';
            sig = [exp(1j * 2 * pi * 50e3 * t), exp(1j * 2 * pi * 80e3 * t)];
            [shifted, fd, ~] = csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, fs, 1e9, ...
                    [0, 0, 0], [10, 0, 0], [100, 0, 0]);
            testCase.verifySize(shifted, size(sig));
            % phase ratio across antennas should equal sig column ratio.
            ratio = shifted(end, 1) ./ shifted(end, 2);
            sigRatio = sig(end, 1) ./ sig(end, 2);
            testCase.verifyEqual(ratio, sigRatio, 'RelTol', 1e-9);
            testCase.verifyGreaterThan(fd, 0);
        end

        function badSampleRateThrows(testCase)
            sig = (1:10).' + 1j * 0;
            f = @() csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 0, 1e9, ...
                    [0, 0, 0], [10, 0, 0], [100, 0, 0]);
            testCase.verifyError(f, 'CSRD:Channel:DopplerInvalidSampleRate');
        end

        function badGeometryVectorThrows(testCase)
            sig = (1:10).' + 1j * 0;
            f = @() csrd.blocks.physical.channel.impairments ...
                .applyDopplerShift(sig, 1e6, 1e9, ...
                    [0, 0], [10, 0, 0], [100, 0, 0]);
            testCase.verifyError(f, 'CSRD:Channel:DopplerInvalidGeometryVector');
        end

    end
end
