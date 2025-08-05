function [FrameData, FrameAnnotation] = generateSingleFrame(obj, FrameId)
    % generateSingleFrame - Generate data for a single frame (refactored)
    %
    % This method orchestrates the complete frame generation process by calling
    % specialized private methods for each major processing stage. This modular
    % approach improves maintainability and enables easier testing.
    %
    % Processing Pipeline:
    %   1. Scenario processing using ScenarioFactory (already instantiated in setup)
    %   2. Transmitter processing (message generation and modulation)
    %   3. Transmitter frontend impairments
    %   4. Receiver setup and configuration
    %   5. Channel propagation modeling
    %   6. Receiver processing and final output generation
    %
    % Inputs:
    %   FrameId - Frame identifier within current scenario (1-based)
    %
    % Outputs:
    %   FrameData - Generated signal data for this frame
    %   FrameAnnotation - Metadata and annotations for this frame

    FrameData = {}; % Initialize output
    FrameAnnotation = {}; % Initialize output

    obj.logger.debug("Scenario frame %d: Starting single frame generation.", FrameId);

    try
        % Step 1: Validate scenario configuration
        if isempty(obj.FactoryConfigs) || ~isstruct(obj.FactoryConfigs) || ...
                ~isfield(obj.FactoryConfigs, 'Scenario') || ~isstruct(obj.FactoryConfigs.Scenario)
            obj.logger.error("Scenario frame %d: Scenario configuration is missing or invalid in FactoryConfigs.", FrameId);
            FrameAnnotation = {struct('FrameId', FrameId, 'Error', 'MissingScenarioConfig')};
            return;
        end

        % Step 2: Process scenario (using already instantiated ScenarioFactory)
        [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId);

        numTxThisFrame = length(instantiatedTxs);
        numRxThisFrame = length(instantiatedRxs);

        if numTxThisFrame == 0
            obj.logger.debug("Scenario frame %d: No transmitters in instantiated scenario.", FrameId);
            FrameAnnotation = {struct('FrameId', FrameId, 'Status', 'NoTransmittersInInstantiatedScenario')};
            return;
        end

        % Step 3: Process all transmitters (message generation and modulation)
        [txsSignalSegments, TxInfos] = processTransmitters(obj, FrameId, numTxThisFrame);

        % Step 4: Apply transmitter frontend impairments
        txsSignalSegments = processTransmitImpairments(obj, FrameId, txsSignalSegments, TxInfos);

        % Step 5: Setup receivers
        RxInfos = setupReceivers(obj, FrameId, numRxThisFrame);

        % Step 6: Process channel propagation
        signalsAtReceivers = processChannelPropagation(obj, FrameId, txsSignalSegments, TxInfos, RxInfos);

        % Step 7: Process receiver processing and generate final outputs
        [FrameData, FrameAnnotation] = processReceiverProcessing(obj, FrameId, signalsAtReceivers, RxInfos);

        obj.logger.debug("Scenario frame %d: Single frame generation completed successfully.", FrameId);

    catch ME
        obj.logger.error("Scenario frame %d: Error during frame generation: %s", FrameId, ME.message);
        obj.logger.error("Stack trace: %s", getReport(ME, 'extended', 'hyperlinks', 'off'));
        FrameData = {};
        FrameAnnotation = {struct('FrameId', FrameId, 'Error', 'FrameGenerationFailed', 'Message', ME.message)};
    end

end
