classdef SnapSpacingForTractableResampleTest < matlab.unittest.TestCase
    % SnapSpacingForTractableResampleTest - the multicarrier resample contract.
    %
    %   csrd.pipeline.signal.snapSpacingForTractableResample nudges a subcarrier
    %   spacing so the modulator rate (scs*N) can be resampled to the receiver rate
    %   -- TRFSimulator.resampleToTarget refuses receiverRate/(scs*N) when its exact
    %   rational p/q has max(p,q) > 50000, and that refusal loses the whole
    %   scenario (measured at 1 in 24 before this existed). The properties below are
    %   what the planner relies on; if any breaks, the 4.2 % loss returns silently.

    properties (Constant)
        MaxFactor = 50000
        ReceiverRate = 50e6
    end

    methods (Test)

        function makesTheDocumentedFailureTractable(testCase)
            % The exact case from the field: OFDM 15140.144497 Hz x 2048 = 31.007
            % MHz against 50 MHz resolved to 1902671/1179923 and failed.
            N = 2048;
            rawScs = 15140.144497;
            [pRaw, qRaw] = rat(testCase.ReceiverRate / (rawScs * N), 1e-12);
            testCase.assertGreaterThan(max(pRaw, qRaw), testCase.MaxFactor, ...
                'Fixture no longer reproduces the intractable case.');

            scs = csrd.pipeline.signal.snapSpacingForTractableResample( ...
                rawScs, N, testCase.ReceiverRate);
            testCase.verifyTrue(testCase.isTractable(scs, N), ...
                'The documented failing spacing must be made resampleable.');
        end

        function spacingChangeIsNegligible(testCase)
            % The nudge must not distort the emitter. scs is the only control on the
            % occupied bandwidth (= usableBins*scs), so the relative change bounds
            % the bandwidth error; it must be far below measurement resolution.
            cases = { ...
                15140.144497, 2048; ...   % the documented OFDM case
                15000, 1024; ...
                216920.5, 256; ...        % short-burst raised spacing
                31313.7, 592};            % an arbitrary OTFS-like delay grid
            for k = 1:size(cases, 1)
                raw = cases{k, 1}; N = cases{k, 2};
                scs = csrd.pipeline.signal.snapSpacingForTractableResample( ...
                    raw, N, testCase.ReceiverRate);
                rel = abs(scs - raw) / raw;
                testCase.verifyLessThan(rel, 1e-3, sprintf( ...
                    'scs %.6g (N=%d) moved %.2e relative, over the 0.1%% cap.', ...
                    raw, N, rel));
                testCase.verifyTrue(testCase.isTractable(scs, N), sprintf( ...
                    'scs %.6g (N=%d) still intractable after the nudge.', raw, N));
            end
        end

        function alreadyTractableSpacingIsNotMadeWorse(testCase)
            % An exact receiver submultiple is already tractable (p/q = k/1). The
            % nudge must leave it essentially untouched, never push it to a worse
            % rational.
            N = 1024;
            scsExact = testCase.ReceiverRate / 4 / N;   % modRate = Fs/4, ratio 4/1
            scs = csrd.pipeline.signal.snapSpacingForTractableResample( ...
                scsExact, N, testCase.ReceiverRate);
            testCase.verifyEqual(scs, scsExact, 'RelTol', 1e-9, ...
                'A spacing that is already an exact submultiple must be left alone.');
        end

        function missingReceiverRateLeavesSpacingUnchanged(testCase)
            % The planner passes NaN when the receiver rate is unavailable; the nudge
            % must be a no-op rather than error, so an under-configured run still
            % produces a (possibly intractable, loudly-failing) emitter.
            for badRx = {NaN, 0, -1, []}
                scs = csrd.pipeline.signal.snapSpacingForTractableResample( ...
                    15140.144497, 2048, badRx{1});
                testCase.verifyEqual(scs, 15140.144497, ...
                    'A missing/invalid receiver rate must leave scs unchanged.');
            end
        end

        % NOTE on the resampler contract. isTractable above mirrors
        % TRFSimulator.resampleToTarget's exact acceptance test (rat at 1e-12,
        % max factor 50000). The end-to-end guarantee -- that a spacing this
        % function blesses actually survives the full pipeline -- is asserted where
        % scenarios really run: test_measured_truth_plausibility and
        % test_measured_plane_is_noise_independent now require
        % SimulationRunner.LastRunSummary.Failed == 0, so a regression in this nudge
        % fails them. resampleToTarget itself is a restricted method and is not
        % called directly from here.

    end

    methods (Access = private)

        function tf = isTractable(testCase, scs, N)
            [p, q] = rat(testCase.ReceiverRate / (scs * N), 1e-12);
            tf = p > 0 && q > 0 && max(p, q) <= testCase.MaxFactor;
        end

    end

end
