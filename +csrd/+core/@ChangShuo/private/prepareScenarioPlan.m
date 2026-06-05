function scenarioPlan = prepareScenarioPlan(obj, scenarioId)
%PREPARESCENARIOPLAN Build the frozen construction plan for one scenario.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

if ~isfield(obj.Factories, 'Scenario') || isempty(obj.Factories.Scenario)
    error('CSRD:ScenarioPlan:MissingScenarioFactory', ...
        'Scenario factory must be initialized before preparing ScenarioPlan.');
end
scenarioFactory = obj.Factories.Scenario;
scenarioPlan = scenarioFactory.planScenario(scenarioId);
if isempty(scenarioPlan) || ~isstruct(scenarioPlan) || ...
        ~isfield(scenarioPlan, 'Frame') || ~isstruct(scenarioPlan.Frame)
    error('CSRD:ScenarioPlan:InvalidScenarioPlan', ...
        'ScenarioFactory.planScenario must return ScenarioPlan.Frame.');
end
end
