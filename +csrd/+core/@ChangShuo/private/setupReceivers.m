function RxInfos = setupReceivers(obj, FrameId, numRxThisFrame)
    %SETUPRECEIVERS Phase 3 strict-construction receiver setup.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 setupReceivers 实现。
    %
    %   RxInfos = setupReceivers(obj, FrameId, numRxThisFrame)
    %
    %   Phase 3 (audit §3.1.ter / §17.5 P3-5) removed every silent fallback
    %   from this function. Per-receiver validation lives in the Static,
    %   Hidden helper csrd.core.ChangShuo.validateRxPlanIntoRxInfo so the
    %   fail-fast contract can be unit-tested without instantiating the
    %   full engine. Errors propagate to SimulationRunner, which decides
    %   per-scenario skip versus sweep abort via
    %   csrd.pipeline.scenario.isScenarioSkipException.
    %
    %   Inputs:
    %       FrameId         - Frame identifier (used for diagnostics).
    %       numRxThisFrame  - Number of receivers expected this frame.
    %
    %   Output:
    %       RxInfos         - 1 x numRxThisFrame cell array of validated
    %                         receiver info structs.
    %
    %   Errors (added to isScenarioSkipException whitelist in S6):
    %       CSRD:Construction:RxScenarioOutOfRange
    %       CSRD:Construction:RxMissingPlan
    %       CSRD:Construction:RxMissingPhysical
    %       CSRD:Construction:RxMissingHardware
    %       CSRD:Construction:RxMissingObservation

    obj.logger.debug("Frame %d: Setting up %d receiver(s).", FrameId, numRxThisFrame);

    RxInfos = cell(1, numRxThisFrame);

    for rxIdx = 1:numRxThisFrame
        if rxIdx > length(obj.ScenarioConfig.Receivers)
            error('CSRD:Construction:RxScenarioOutOfRange', ...
                ['Frame %d, Rx %d: ScenarioConfig.Receivers only has %d ', ...
                 'entries. Phase 3 removed the silent ', ...
                 '''Error_MissingRxScenario'' fallback; the upstream ', ...
                 'CommunicationBehaviorSimulator must publish one rxPlan ', ...
                 'per receiver requested by stepImpl.'], ...
                FrameId, rxIdx, length(obj.ScenarioConfig.Receivers));
        end

        rxPlan = obj.ScenarioConfig.Receivers{rxIdx};
        RxInfo = csrd.core.ChangShuo.validateRxPlanIntoRxInfo(rxPlan, FrameId, rxIdx);
        RxInfos{rxIdx} = RxInfo;

        obj.logger.debug("Frame %d, RxID %s: Receiver configured (Type: %s, SampleRate: %.2f MHz).", ...
            FrameId, string(RxInfo.ID), RxInfo.Type, RxInfo.SampleRate / 1e6);
    end

    obj.logger.debug("Frame %d: Receiver setup complete.", FrameId);
end
