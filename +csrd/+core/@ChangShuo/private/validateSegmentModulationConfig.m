function isValid = validateSegmentModulationConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
    % validateSegmentModulationConfig - Validate segment modulation configuration
    %
    % This method validates that the segment has proper modulation configuration
    % including SymbolRate and TypeID fields.
    %
    % Inputs:
    %   currentSegmentScenario - Current segment scenario configuration
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %
    % Outputs:
    %   isValid - Boolean indicating if configuration is valid

    isValid = true;

    if ~isfield(currentSegmentScenario, 'Modulation') || ~isstruct(currentSegmentScenario.Modulation) || ...
            ~isfield(currentSegmentScenario.Modulation, 'SymbolRate') || ~isfield(currentSegmentScenario.Modulation, 'TypeID')
        obj.logger.error('Frame %d, TxID %s, Seg %d: Modulation config, SymbolRate or TypeID missing.', ...
            FrameId, string(currentTxId), segIdx);
        isValid = false;
    end

end
