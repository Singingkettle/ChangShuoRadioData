classdef SetupReceiversFailFastTest < matlab.unittest.TestCase
    %SETUPRECEIVERSFAILFASTTEST Phase 3 (§3.3.A) receiver setup fail-fast.
    %
    %   Pin the contract that csrd.core.ChangShuo.validateRxPlanIntoRxInfo
    %   refuses to fabricate receiver state from magic defaults. The
    %   legacy 50e6 / [-25e6,25e6] / 0 / 2.4e9 magic numbers and the
    %   Simulation/1 hardware fallbacks were deleted in Phase 3; any
    %   missing field in the rxPlan must surface as a
    %   CSRD:Construction:RxMissing* identifier so the planner-side bug
    %   can be diagnosed.
    %
    %   The validator is exposed as a Static, Hidden method on
    %   csrd.core.ChangShuo so we can pin the contract here without
    %   instantiating the full engine.

    properties (Constant)
        FRAME_ID = 11
        RX_IDX = 1
    end

    methods (Test)

        % ---------- Happy path -----------------------------------------

        function happyPathReturnsPopulatedRxInfo(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            info = csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);

            testCase.verifyEqual(info.ID, 'Rx1');
            testCase.verifyEqual(info.Status, 'Ready');
            testCase.verifyEqual(info.Position, [10, 20, 30]);
            testCase.verifyEqual(info.Velocity, [0, 0, 0]);
            testCase.verifyEqual(info.Type, 'Simulation');
            testCase.verifyEqual(info.NumAntennas, 1);
            testCase.verifyEqual(info.SampleRate, 40e6);
            testCase.verifyEqual(info.ObservableRange, [-20e6, 20e6]);
            testCase.verifyEqual(info.CenterFrequency, 0);
            testCase.verifyEqual(info.RealCarrierFrequency, 2.4e9);
        end

        function explicitVelocityIsPropagated(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Physical.Velocity = [1, 2, 3];
            info = csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyEqual(info.Velocity, [1, 2, 3]);
        end

        % ---------- Sad paths : Physical -------------------------------

        function missingPhysicalRaisesRxMissingPhysical(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx = rmfield(rx, 'Physical');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingPhysical');
        end

        function missingPositionRaisesRxMissingPhysical(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Physical = rmfield(rx.Physical, 'Position');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingPhysical');
        end

        % ---------- Sad paths : Hardware -------------------------------

        function missingHardwareRaisesRxMissingHardware(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx = rmfield(rx, 'Hardware');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingHardware');
        end

        function missingHardwareTypeRaisesRxMissingHardware(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Hardware = rmfield(rx.Hardware, 'Type');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingHardware');
        end

        function missingNumAntennasRaisesRxMissingHardware(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Hardware = rmfield(rx.Hardware, 'NumAntennas');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingHardware');
        end

        % ---------- Sad paths : Observation ----------------------------

        function missingObservationRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx = rmfield(rx, 'Observation');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        function missingSampleRateRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Observation = rmfield(rx.Observation, 'SampleRate');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        function missingObservableRangeRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Observation = rmfield(rx.Observation, 'ObservableRange');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        function missingCenterFrequencyRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Observation = rmfield(rx.Observation, 'CenterFrequency');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        function missingRealCarrierFrequencyRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Observation = rmfield(rx.Observation, 'RealCarrierFrequency');
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        function nonPositiveSampleRateRaisesRxMissingObservation(testCase)
            rx = SetupReceiversFailFastTest.makeMinimalRxPlan();
            rx.Observation.SampleRate = 0;
            f = @() csrd.core.ChangShuo.validateRxPlanIntoRxInfo( ...
                rx, testCase.FRAME_ID, testCase.RX_IDX);
            testCase.verifyError(f, 'CSRD:Construction:RxMissingObservation');
        end

        % ---------- Dead-code grep on the production setupReceivers ----

        function deadCodeMagicDefaultsAreRemoved(testCase)
            here = fileparts(mfilename('fullpath'));
            srcFile = fullfile(here, '..', '..', '+csrd', '+core', ...
                '@ChangShuo', 'private', 'setupReceivers.m');
            testCase.assertTrue(isfile(srcFile), ...
                sprintf('Expected to find setupReceivers.m at %s', srcFile));
            txt = fileread(srcFile);
            codeOnly = SetupReceiversFailFastTest.stripComments(txt);

            testCase.verifyEmpty(regexp(codeOnly, '50e6\s*;', 'once'), ...
                'Phase 3 §3.3.A: legacy 50e6 SampleRate fallback must be removed.');
            testCase.verifyEmpty(regexp(codeOnly, '-25e6\s*,\s*25e6', 'once'), ...
                'Phase 3 §3.3.A: legacy [-25e6, 25e6] ObservableRange fallback must be removed.');
            testCase.verifyEmpty(regexp(codeOnly, '2\.4e9\s*;', 'once'), ...
                'Phase 3 §3.3.A: legacy 2.4e9 RealCarrierFrequency fallback must be removed.');
            testCase.verifyEmpty(regexp(codeOnly, 'getFieldOrDefault', 'once'), ...
                'Phase 3 §3.3.A: getFieldOrDefault helper must be deleted.');
            testCase.verifyEmpty(regexp(codeOnly, 'Status''\s*,\s*''Error_MissingRxScenario''', 'once'), ...
                'Phase 3 §3.3.A: legacy Error_MissingRxScenario sentinel must be removed.');
            testCase.verifyEmpty(regexp(codeOnly, 'Status''\s*,\s*''Error_ReceiverSetup''', 'once'), ...
                'Phase 3 §3.3.A: legacy Error_ReceiverSetup catch fallback must be removed.');
        end

    end

    methods (Static, Access = private)

        function rx = makeMinimalRxPlan()
            % The smallest rxPlan that should pass Phase 3 validation.
            rx = struct();
            rx.EntityID = 'Rx1';
            rx.Physical = struct('Position', [10, 20, 30]);
            rx.Hardware = struct('Type', 'Simulation', 'NumAntennas', 1);
            rx.Observation = struct( ...
                'SampleRate', 40e6, ...
                'ObservableRange', [-20e6, 20e6], ...
                'CenterFrequency', 0, ...
                'RealCarrierFrequency', 2.4e9);
        end

        function out = stripComments(src)
            % Strip MATLAB single-line comments (% to EOL) so dead-code
            % grep regexes can be applied to executable code only.
            lines = regexp(src, '\r?\n', 'split');
            out = '';
            for k = 1:numel(lines)
                line = lines{k};
                inStr = false;
                cutAt = numel(line) + 1;
                for c = 1:numel(line)
                    ch = line(c);
                    if ch == '''' && (c == 1 || line(c-1) ~= '''')
                        inStr = ~inStr;
                    elseif ch == '%' && ~inStr
                        cutAt = c;
                        break;
                    end
                end
                out = [out, line(1:cutAt-1), newline]; %#ok<AGROW>
            end
        end

    end

end
