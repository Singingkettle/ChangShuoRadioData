function [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId)
    % processScenarioInstantiation - Generate scenario using ScenarioFactory

    if isempty(obj.Factories.Scenario)
        error('ChangShuo:NoScenarioFactory', 'ScenarioFactory not initialized');
    end

    try
        [instantiatedTxs, instantiatedRxs, globalLayout] = step(obj.Factories.Scenario, FrameId);
        obj.logger.debug("Frame %d: Generated %d Tx, %d Rx", ...
            FrameId, length(instantiatedTxs), length(instantiatedRxs));
    catch ME
        obj.logger.error("Frame %d: Scenario generation failed: %s", FrameId, ME.message);
        rethrow(ME);
    end
end
