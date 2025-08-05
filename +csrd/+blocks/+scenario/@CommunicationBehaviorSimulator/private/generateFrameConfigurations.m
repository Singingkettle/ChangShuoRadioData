function [txConfigs, rxConfigs, globalLayout] = generateFrameConfigurations(obj, frameId)
    % generateFrameConfigurations - Generate frame-specific configurations
    %
    % Creates frame-specific configurations by copying the fixed scenario
    % configurations and updating only the temporal/transmission state parameters.

    % Start with scenario configurations
    txConfigs = obj.scenarioTxConfigs;
    rxConfigs = obj.scenarioRxConfigs;
    globalLayout = obj.scenarioGlobalLayout;

    % Update frame-specific information
    globalLayout.FrameId = frameId;

    % Update transmission states for each transmitter
    for i = 1:length(txConfigs)
        txConfig = txConfigs(i);
        txConfig.FrameId = frameId;

        % Update transmission state based on pattern
        txConfig.TransmissionState = calculateTransmissionState(obj, frameId, txConfig);

        % Update temporal parameters if needed
        if strcmp(txConfig.TransmissionPattern.Type, 'Burst')
            txConfig.TransmissionState = updateBurstState(obj, frameId, txConfig);
        elseif strcmp(txConfig.TransmissionPattern.Type, 'Scheduled')
            txConfig.TransmissionState = updateScheduledState(obj, frameId, txConfig);
        end

        txConfigs(i) = txConfig;
    end

    % Update receiver states
    for i = 1:length(rxConfigs)
        rxConfig = rxConfigs(i);
        rxConfig.FrameId = frameId;
        rxConfigs(i) = rxConfig;
    end

    obj.logger.debug('Frame %d: Updated transmission states for %d transmitters', ...
        frameId, length(txConfigs));
end
