function [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId)
    % processScenarioInstantiation - Handle scenario instantiation using ScenarioFactory
    %
    % This method uses ScenarioFactory to generate specific transmitter and receiver
    % instances based on parameter ranges defined in the scenario configuration.
    %
    % Inputs:
    %   FrameId - Frame identifier within current scenario (1-based)
    %
    % Outputs:
    %   instantiatedTxs - Cell array of instantiated transmitter configurations
    %   instantiatedRxs - Cell array of instantiated receiver configurations
    %   globalLayout - Global layout structure from scenario factory

    obj.logger.debug("Scenario frame %d: Processing scenario using ScenarioFactory.", FrameId);

    instantiatedTxs = {};
    instantiatedRxs = {};
    globalLayout = struct();

    if ~isempty(obj.pScenarioFactory)

        try
            % ScenarioFactory generates specific instances based on parameter ranges
            % Pass scenario configuration from FactoryConfigs.Scenario
            scenarioConfig = obj.FactoryConfigs.Scenario;
            [instantiatedTxs, instantiatedRxs, globalLayout] = ...
                step(obj.pScenarioFactory, FrameId, scenarioConfig, obj.FactoryConfigs);

            obj.logger.debug("Scenario frame %d: Scenario processed. Tx count: %d, Rx count: %d", ...
                FrameId, length(instantiatedTxs), length(instantiatedRxs));

        catch ME_scenario
            obj.logger.error("Scenario frame %d: Error during scenario processing: %s", FrameId, ME_scenario.message);
            error('ChangShuo:ScenarioProcessingFailed', ...
                'Scenario frame %d: Scenario processing failed: %s', FrameId, ME_scenario.message);
        end

    else
        obj.logger.warning("Scenario frame %d: ScenarioFactory not initialized. Using empty scenario.", FrameId);
        error('ChangShuo:NoScenarioFactory', ...
            'Scenario frame %d: ScenarioFactory not available for processing', FrameId);
    end

end
