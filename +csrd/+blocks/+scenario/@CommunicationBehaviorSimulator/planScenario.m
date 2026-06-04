function [txConfigs, rxConfigs, globalLayout, entities] = planScenario(obj, entities)
%PLANSCENARIO Freeze scenario-level communication configuration.

if nargin < 2 || isempty(entities)
    error('CSRD:Scenario:EmptyEntities', ...
        'CommunicationBehaviorSimulator.planScenario requires physical entities.');
end

if ~obj.scenarioInitialized
    obj.logger.debug('Planning scenario-level communication configuration.');
    entities = initializeScenarioConfigurations(obj, entities);
    obj.scenarioInitialized = true;
else
    entities = obj.scenarioEntities;
end

txConfigs = obj.scenarioTxConfigs;
rxConfigs = obj.scenarioRxConfigs;
globalLayout = obj.scenarioGlobalLayout;
globalLayout.FrameId = 0;
globalLayout.Entities = entities;
obj.scenarioEntities = entities;

obj.logger.debug('Planned communication scenario with %d Tx and %d Rx.', ...
    numel(txConfigs), numel(rxConfigs));
end
