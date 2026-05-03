function tf = isScenarioSkipException(ME)
%ISSCENARIOSKIPEXCEPTION True for identifiers that mean "skip this scenario".
% 中文说明：提供 CSRD 生产链路中的 isScenarioSkipException 实现。
%
%   tf = csrd.pipeline.scenario.isScenarioSkipException(ME)
%
%   Returns true when the given MException carries one of the
%   well-known scenario-level identifiers used throughout the CSRD
%   pipeline. Centralising this predicate keeps the rethrow / skip
%   logic in ``ChannelFactory``, ``processChannelPropagation``,
%   ``generateSingleFrame``, ``SimulationRunner``, ``ScenarioFactory``
%   and friends in lockstep, instead of depending on every author
%   remembering the magic strings independently.
%
%   Recognised tokens (substring match on the identifier):
%     * SkipScenario          - explicit, raised by ScenarioFactory
%     * NoBuildingData        - raised when an OSM payload has no buildings
%     * NoValidPaths          - raised when ray tracing returns 0 rays
%     * EmptyEntities         - Phase 1 / A4: scenario layer produced no
%                               physical entities; refuse to fabricate
%                               communication behaviour
%     * EntityDriftDetected   - Phase 1 / A4: scenarioEntities/entities
%                               IDs drifted mid-scenario, sync collapsed
%     * CSRD:Construction:    - Phase 3 / §3.4: any strict-construction
%                               fail-fast (Missing*, Rx*, Channel*,
%                               Unknown*) is skip-scenario. The upstream
%                               BlueprintFeasibilityValidator + Phase 2
%                               ScenarioFactory should never let one of
%                               these fire on a healthy blueprint;
%                               surfacing them lets the sweep continue
%                               instead of crashing.
%     * CSRD:Annotation:      - Phase 4 / §2 (decision A) + §6 (C4):
%                               write-back hook
%                               `validateMeasurementCompleteness` rejects
%                               annotations that are missing
%                               `Truth.Measured.{SourcePlane,FramePlane}`
%                               required scalars. Like the
%                               Construction tokens these are
%                               schema-strict failures the upstream
%                               pipeline should have prevented; demoting
%                               them to SkipScenario keeps the 200+
%                               baseline sweep moving instead of fatal-
%                               aborting on a single bad scenario.
%     * CSRD:Measurement:     - Phase 4 / Phase 5: measurement helpers
%                               reject invalid observed data (for example
%                               empty or non-finite IQ). These are data-
%                               generation contract failures, not values
%                               to be written as partial annotations.

    arguments
        ME (1, 1) MException
    end

    identifier = string(ME.identifier);
    if identifier == ""
        tf = false;
        return;
    end

    skipTokens = [ ...
        "SkipScenario", ...
        "NoBuildingData", ...
        "NoValidPaths", ...
        "EmptyEntities", ...
        "EntityDriftDetected", ...
        "CSRD:Construction:", ...
        "CSRD:Annotation:", ...
        "CSRD:Measurement:" ...
    ];
    tf = any(arrayfun(@(t) contains(identifier, t), skipTokens));
end
