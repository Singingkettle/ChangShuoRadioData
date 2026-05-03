function [FrameData, FrameAnnotation] = generateSingleFrame(obj, FrameId)
    % generateSingleFrame - Generate data for a single frame (refactored)
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 generateSingleFrame 实现。
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

    obj.logger.debug("Scenario frame %d: Starting single frame generation.", FrameId);

    try
        % Step 1: Validate scenario configuration
        if isempty(obj.FactoryConfigs) || ~isstruct(obj.FactoryConfigs) || ...
                ~isfield(obj.FactoryConfigs, 'Scenario') || ~isstruct(obj.FactoryConfigs.Scenario)
            obj.logger.error("Scenario frame %d: Scenario configuration is missing or invalid in FactoryConfigs.", FrameId);
            error('CSRD:Construction:MissingScenarioConfig', ...
                'Scenario frame %d: FactoryConfigs.Scenario is missing or invalid.', FrameId);
        end

        % Step 2: Process scenario (using already instantiated ScenarioFactory)
        [instantiatedTxs, instantiatedRxs, globalLayout] = processScenarioInstantiation(obj, FrameId);

        % Phase 3 (audit §3.5 / §17.5 P3-7): expose the freshly-built
        % globalLayout as a public read-only property so SimulationRunner
        % can stamp Header.Runtime.{BlueprintHash, BlueprintResamples,
        % ValidatorVersion} via ChangShuo.extractProvenanceFromGlobalLayout
        % without the legacy Hidden accessor + ismethod ladder.
        obj.LastGlobalLayout = globalLayout;

        % Store scenario config for use by other processing methods
        obj.ScenarioConfig = struct();
        obj.ScenarioConfig.Transmitters = instantiatedTxs;
        obj.ScenarioConfig.Receivers = instantiatedRxs;
        obj.ScenarioConfig.Layout = globalLayout;
        
        % Store entities with Snapshots for downstream processing
        if isfield(globalLayout, 'Entities')
            obj.ScenarioConfig.Entities = globalLayout.Entities;
        end

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
        if csrd.pipeline.scenario.isScenarioSkipException(ME)
            rethrow(ME);
        end
        obj.logger.error("Scenario frame %d: Error during frame generation: %s", FrameId, ME.message);
        obj.logger.error("Stack trace: %s", getReport(ME, 'extended', 'hyperlinks', 'off'));
        rethrow(ME);
    end

end
