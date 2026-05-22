function tf = isScenarioSkipException(ME)
%ISSCENARIOSKIPEXCEPTION True for identifiers that mean "skip this scenario".
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
%
%   Measurement, annotation, and construction identifiers are deliberately
%   not skip tokens. They mean the generated signal/metadata contract is
%   broken and must be counted as failure, not as a successful scenario.

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
        "EntityDriftDetected" ...
    ];
    tf = any(arrayfun(@(t) contains(identifier, t), skipTokens));
end
