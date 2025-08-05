function [txConfigs, rxConfigs, globalLayout] = stepImpl(obj, frameId, entities, factoryConfigs)
    % stepImpl - Generate frame-specific communication states
    %
    % For the first frame, initializes scenario-level configurations (frequency,
    % modulation, etc.) that remain fixed throughout the scenario. For subsequent
    % frames, only updates frame-specific temporal behaviors (transmission timing,
    % on/off states, burst patterns).
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %   entities - Entity configurations from PhysicalEnvironmentSimulator
    %   factoryConfigs - Factory configurations for component instantiation
    %
    % Output Arguments:
    %   txConfigs - Transmitter configurations for current frame
    %   rxConfigs - Receiver configurations for current frame
    %   globalLayout - Global communication layout

    obj.logger.debug('Frame %d: Processing communication behavior for %d entities', ...
        frameId, length(entities));

    % Initialize scenario-level configurations on first frame
    if ~obj.scenarioInitialized
        obj.logger.debug('Frame %d: Initializing scenario-level communication configurations', frameId);
        initializeScenarioConfigurations(obj, frameId, entities, factoryConfigs);
        obj.scenarioInitialized = true;
    end

    % Generate frame-specific configurations based on fixed scenario configs
    [txConfigs, rxConfigs, globalLayout] = generateFrameConfigurations(obj, frameId);

    % Store frame state for continuity
    frameState = struct();
    frameState.txConfigs = txConfigs;
    frameState.rxConfigs = rxConfigs;
    frameState.globalLayout = globalLayout;
    frameState.frameId = frameId;
    obj.allocationHistory(frameId) = frameState;

    obj.logger.debug('Frame %d: Communication behavior processing completed', frameId);
end
