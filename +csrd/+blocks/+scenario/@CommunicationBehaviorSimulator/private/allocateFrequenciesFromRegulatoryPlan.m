function [txConfigs, globalLayout] = allocateFrequenciesFromRegulatoryPlan(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout)
    %allocateFrequenciesFromRegulatoryPlan Preserve Phase 8 catalog placements.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Frequency center, bandwidth, and absolute RF center are selected by
    % RegionSpectrumSelector before this point. This allocation step only
    % validates the receiver-baseband projection and stamps ReceiverViews.

    globalLayout.FrequencyAllocations = {};
    isCellArray = iscell(txConfigs);
    % The regulatory catalog places each emitter independently, so two can land
    % co-channel. That is a realistic monitoring phenomenon (not an error to
    % forbid as the receiver-centric path does), but colliding emitters must NOT
    % be recorded as clean isolated placements -- detect actual band overlap and
    % stamp globalLayout.OverlapOccurred honestly.
    usedRanges = zeros(0, 2);

    for i = 1:length(txConfigs)
        if isCellArray
            txConfig = txConfigs{i};
        else
            txConfig = txConfigs(i);
        end

        if ~isfield(txConfig, 'Spectrum') || ...
                ~isfield(txConfig.Spectrum, 'PlannedBandwidth') || ...
                ~isfield(txConfig.Spectrum, 'PlannedFreqOffset')
            error('CSRD:Spectrum:MissingRegulatoryPlacement', ...
                ['Transmitter %s missing Spectrum.PlannedBandwidth or ', ...
                 'Spectrum.PlannedFreqOffset from regulatory selector.'], ...
                txConfig.EntityID);
        end

        txBW = txConfig.Spectrum.PlannedBandwidth;
        centerFreq = txConfig.Spectrum.PlannedFreqOffset;
        lowerEdge = centerFreq - txBW / 2;
        upperEdge = centerFreq + txBW / 2;
        if lowerEdge < observableRange(1) - 1 || upperEdge > observableRange(2) + 1
            error('CSRD:Spectrum:PlacementOutsideObservableRange', ...
                ['Transmitter %s regulatory placement [%.0f %.0f] Hz ', ...
                 'is outside observable range [%.0f %.0f] Hz.'], ...
                txConfig.EntityID, lowerEdge, upperEdge, ...
                observableRange(1), observableRange(2));
        end

        proposedRange = [lowerEdge, upperEdge];
        for j = 1:size(usedRanges, 1)
            if checkFrequencyOverlap(obj, proposedRange, usedRanges(j, :))
                globalLayout.OverlapOccurred = true;
                globalLayout.OverlapReason = 'RegulatoryCatalogCoChannel';
                break;
            end
        end
        usedRanges = [usedRanges; proposedRange]; %#ok<AGROW>

        txConfig.Spectrum.LowerBound = lowerEdge;
        txConfig.Spectrum.UpperBound = upperEdge;
        txConfig.ReceiverViews = ...
            csrd.blocks.scenario.CommunicationBehaviorSimulator.projectReceiverViews( ...
            txConfig.Spectrum, rxConfigs, observableRange);

        if isCellArray
            txConfigs{i} = txConfig;
        else
            txConfigs(i) = txConfig;
        end
        globalLayout.FrequencyAllocations{i} = [lowerEdge, upperEdge];

        obj.logger.debug(['Regulatory allocation [%.1f, %.1f] MHz ', ...
            'offset to transmitter %s (absolute center %.3f MHz)'], ...
            lowerEdge / 1e6, upperEdge / 1e6, txConfig.EntityID, ...
            getAbsoluteCenterHz(txConfig) / 1e6);
    end
end


function f = getAbsoluteCenterHz(txConfig)
    % getAbsoluteCenterHz - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
f = NaN;
if isfield(txConfig, 'Spectrum') && ...
        isfield(txConfig.Spectrum, 'AbsoluteCenterFrequencyHz')
    f = txConfig.Spectrum.AbsoluteCenterFrequencyHz;
elseif isfield(txConfig, 'Regulatory') && ...
        isfield(txConfig.Regulatory, 'SelectedCenterFrequencyHz')
    f = txConfig.Regulatory.SelectedCenterFrequencyHz;
end
end
