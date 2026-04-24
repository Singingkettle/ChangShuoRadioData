function tf = isScenarioSkipException(ME)
%ISSCENARIOSKIPEXCEPTION True for identifiers that mean "skip this scenario".
%
%   tf = csrd.utils.scenario.isScenarioSkipException(ME)
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
%     * SkipScenario     - explicit, raised by ScenarioFactory
%     * NoBuildingData   - raised when an OSM payload has no buildings
%     * NoValidPaths     - raised when ray tracing returns 0 rays

    arguments
        ME (1, 1) MException
    end

    identifier = string(ME.identifier);
    if identifier == ""
        tf = false;
        return;
    end

    skipTokens = ["SkipScenario", "NoBuildingData", "NoValidPaths"];
    tf = any(arrayfun(@(t) contains(identifier, t), skipTokens));
end
