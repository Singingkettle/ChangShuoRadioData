function [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId)
    % processScenarioInstantiation - Generate scenario using ScenarioFactory
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 processScenarioInstantiation 实现。

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
