function RxInfo = validateRxPlanIntoRxInfo(rxPlan, FrameId, rxIdx)
    %VALIDATERXPLANINTORXINFO Phase 3 strict-construction receiver builder.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    %     - Physical group       : rxPlan.Physical.{Position, Velocity}
    %       are required. Velocity feeds Doppler truth, so construction
    %       must not silently zero it.
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
%   Errors (all hard failures in Phase 20, not scenario skips):
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
            || ~isfield(rxPlan.Physical, 'Position') ...
            || ~isfield(rxPlan.Physical, 'Velocity')
        error('CSRD:Construction:RxMissingPhysical', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Physical.{Position, Velocity} are required. ', ...
             'Phase 11 removed the [0,0,0] velocity fallback so Doppler ', ...
             'truth cannot be silently zeroed.'], ...
            FrameId, rxIdx, char(string(RxInfo.ID)));
    end
    if ~isnumeric(rxPlan.Physical.Position) || numel(rxPlan.Physical.Position) ~= 3 || ...
            any(~isfinite(rxPlan.Physical.Position(:))) || ...
            ~isnumeric(rxPlan.Physical.Velocity) || numel(rxPlan.Physical.Velocity) ~= 3 || ...
            any(~isfinite(rxPlan.Physical.Velocity(:)))
        error('CSRD:Construction:RxMissingPhysical', ...
            ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
             'rxPlan.Physical.Position and Velocity must be finite ', ...
             '3-element vectors.'], FrameId, rxIdx, char(string(RxInfo.ID)));
    end
    RxInfo.Position = double(rxPlan.Physical.Position(:)).';
    if isfield(rxPlan.Physical, 'PositionUnit') && ...
            ~isempty(rxPlan.Physical.PositionUnit)
        RxInfo.PositionUnit = char(string(rxPlan.Physical.PositionUnit));
    else
        RxInfo.PositionUnit = 'meters';
    end
    if isfield(rxPlan.Physical, 'GeoPositionDeg') && ...
            ~isempty(rxPlan.Physical.GeoPositionDeg)
        if ~isnumeric(rxPlan.Physical.GeoPositionDeg) || ...
                numel(rxPlan.Physical.GeoPositionDeg) ~= 3 || ...
                any(~isfinite(rxPlan.Physical.GeoPositionDeg(:)))
            error('CSRD:Construction:RxMissingPhysical', ...
                ['validateRxPlanIntoRxInfo: Frame %d, Rx %d (%s): ', ...
                 'rxPlan.Physical.GeoPositionDeg must be a finite ', ...
                 '3-element [lat lon height] vector.'], ...
                FrameId, rxIdx, char(string(RxInfo.ID)));
        end
        RxInfo.GeoPositionDeg = double(rxPlan.Physical.GeoPositionDeg(:)).';
    end
    RxInfo.Velocity = double(rxPlan.Physical.Velocity(:)).';

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

    % Carry the SDR ADC resolution through so the receiver RF chain can impose
    % the converter's quantization-noise floor (it bounds the realizable SNR at
    % ~6.02*AdcBits + 1.76 dB). Optional: absent/non-finite leaves ADC modeling
    % disabled on the block. RxInfo field names match RRFSimulator properties,
    % so configureReceiverBlock's isprop copy loop wires it automatically.
    if isfield(rxPlan.Observation, 'Sdr') && isstruct(rxPlan.Observation.Sdr) ...
            && isfield(rxPlan.Observation.Sdr, 'AdcBits')
        adcBits = rxPlan.Observation.Sdr.AdcBits;
        if isnumeric(adcBits) && isscalar(adcBits) && isfinite(adcBits) && adcBits > 0
            RxInfo.AdcBits = double(adcBits);
        end
    end
end
