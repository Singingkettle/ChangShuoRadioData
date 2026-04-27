function RxInfo = validateRxPlanIntoRxInfo(rxPlan, FrameId, rxIdx)
    %VALIDATERXPLANINTORXINFO Phase 3 strict-construction receiver builder.
    %
    %   RxInfo = csrd.core.ChangShuo.validateRxPlanIntoRxInfo(rxPlan, FrameId, rxIdx)
    %
    %   Validates a single rxPlan (as published by
    %   CommunicationBehaviorSimulator into ScenarioConfig.Receivers) and
    %   returns the canonical RxInfo struct used by setupReceivers /
    %   processChannelPropagation / ReceiveFactory.
    %
    %   This routine is the single source of truth for the Phase 3
    %   receiver-side fail-fast contract:
    %     - Physical group       : rxPlan.Physical.Position is required.
    %       Velocity is optional (defaults to [0,0,0] because
    %       generateScenarioReceiverConfigurations does not yet wire it
    %       through; mobility models will overwrite Velocity in
    %       subsequent frames).
    %     - Hardware group       : rxPlan.Hardware.{Type, NumAntennas} are
    %       required.
    %     - Observation group    : rxPlan.Observation.{SampleRate,
    %       ObservableRange, CenterFrequency, RealCarrierFrequency} are
    %       all required.
    %
    %   The legacy 50e6 / [-25e6,25e6] / 0 / 2.4e9 magic defaults and the
    %   `Simulation` / 1 hardware fallbacks were removed in Phase 3
    %   (audit §3.1.ter / §17.5 P3-5). Validator #1
    %   (FrameSampleConsistency) and #2 (RxFsEqualsObservableBw) already
    %   guarantee these fields exist on every accepted blueprint, so any
    %   missing data here is a planner-side bug.
    %
    %   Errors (all on the scenario-skip whitelist in
    %   +csrd/+utils/+scenario/isScenarioSkipException.m):
    %     CSRD:Construction:RxMissingPhysical
    %     CSRD:Construction:RxMissingHardware
    %     CSRD:Construction:RxMissingObservation

    if ~isstruct(rxPlan) || isempty(rxPlan)
        error('CSRD:Construction:RxMissingPlan', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d: rxPlan must be a ', ...
             'non-empty struct (got %s).'], FrameId, rxIdx, class(rxPlan));
    end

    RxInfo = struct();
    if isfield(rxPlan, 'EntityID')
        RxInfo.ID = rxPlan.EntityID;
    else
        RxInfo.ID = sprintf('Rx%d', rxIdx);
    end
    RxInfo.Status = 'Ready';

    if ~isfield(rxPlan, 'Physical') || ~isstruct(rxPlan.Physical) ...
            || ~isfield(rxPlan.Physical, 'Position')
        error('CSRD:Construction:RxMissingPhysical', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Physical.Position is required (Phase 3 removed the ', ...
             '[0,0,10] fallback).'], FrameId, rxIdx, char(string(RxInfo.ID)));
    end
    RxInfo.Position = rxPlan.Physical.Position;

    if isfield(rxPlan.Physical, 'Velocity') && ~isempty(rxPlan.Physical.Velocity)
        RxInfo.Velocity = rxPlan.Physical.Velocity;
    else
        RxInfo.Velocity = [0, 0, 0];
    end

    if ~isfield(rxPlan, 'Hardware') || ~isstruct(rxPlan.Hardware) ...
            || ~isfield(rxPlan.Hardware, 'Type') ...
            || ~isfield(rxPlan.Hardware, 'NumAntennas')
        error('CSRD:Construction:RxMissingHardware', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Hardware.{Type, NumAntennas} are required ', ...
             '(Phase 3 removed the Simulation/1 defaults).'], ...
            FrameId, rxIdx, char(string(RxInfo.ID)));
    end
    RxInfo.Type = rxPlan.Hardware.Type;
    RxInfo.NumAntennas = rxPlan.Hardware.NumAntennas;

    if ~isfield(rxPlan, 'Observation') || ~isstruct(rxPlan.Observation) ...
            || ~isfield(rxPlan.Observation, 'SampleRate') ...
            || ~isfield(rxPlan.Observation, 'ObservableRange') ...
            || ~isfield(rxPlan.Observation, 'CenterFrequency') ...
            || ~isfield(rxPlan.Observation, 'RealCarrierFrequency')
        error('CSRD:Construction:RxMissingObservation', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Observation must carry all of {SampleRate, ', ...
             'ObservableRange, CenterFrequency, RealCarrierFrequency}. ', ...
             'Phase 3 removed the 50e6 / [-25e6,25e6] / 0 / 2.4e9 magic ', ...
             'defaults.'], FrameId, rxIdx, char(string(RxInfo.ID)));
    end

    sr = rxPlan.Observation.SampleRate;
    if ~isnumeric(sr) || ~isscalar(sr) || ~isfinite(sr) || sr <= 0
        error('CSRD:Construction:RxMissingObservation', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Observation.SampleRate must be a positive scalar ', ...
             '(got %s).'], FrameId, rxIdx, char(string(RxInfo.ID)), mat2str(sr));
    end
    RxInfo.SampleRate = sr;
    RxInfo.ObservableRange = rxPlan.Observation.ObservableRange;
    RxInfo.CenterFrequency = rxPlan.Observation.CenterFrequency;
    RxInfo.RealCarrierFrequency = rxPlan.Observation.RealCarrierFrequency;
end
