function TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId)
    % setupTransmitterInfo - Setup transmitter information structure
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 setupTransmitterInfo 实现。
    %
    % This method creates and configures the transmitter information structure
    % including antenna configuration and site parameters.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxScenario - Current transmitter scenario configuration (TxPlan format)
    %   currentTxId - Current transmitter ID
    %
    % Outputs:
    %   TxInfo - Configured transmitter information structure

    TxInfo = struct();
    TxInfo.ID = currentTxId;

    requireStructField(currentTxScenario, 'Physical', ...
        'CSRD:Construction:TxMissingPhysical', FrameId, currentTxId);
    requireNumericVector(currentTxScenario.Physical, 'Position', 3, ...
        'CSRD:Construction:TxMissingPhysical', FrameId, currentTxId);
    requireNumericVector(currentTxScenario.Physical, 'Velocity', 3, ...
        'CSRD:Construction:TxMissingPhysical', FrameId, currentTxId);
    TxInfo.Position = double(currentTxScenario.Physical.Position(:)).';
    TxInfo.Velocity = double(currentTxScenario.Physical.Velocity(:)).';

    % Hardware group
    requireStructField(currentTxScenario, 'Hardware', ...
        'CSRD:Construction:TxMissingHardware', FrameId, currentTxId);
    hw = currentTxScenario.Hardware;
    requireAnyField(hw, 'Type', ...
        'CSRD:Construction:TxMissingHardware', FrameId, currentTxId);
    requireFiniteScalar(hw, 'Power', ...
        'CSRD:Construction:TxMissingHardware', FrameId, currentTxId);
    requirePositiveIntegerScalar(hw, 'NumAntennas', ...
        'CSRD:Construction:TxMissingHardware', FrameId, currentTxId);
    requireFiniteScalar(hw, 'AntennaGain', ...
        'CSRD:Construction:TxMissingHardware', FrameId, currentTxId);
    TxInfo.Type = hw.Type;
    TxInfo.Power = double(hw.Power);
    TxInfo.NumTransmitAntennas = double(hw.NumAntennas);
    TxInfo.AntennaGain = double(hw.AntennaGain);

    % Spectrum group
    requireStructField(currentTxScenario, 'Spectrum', ...
        'CSRD:Construction:TxMissingSpectrum', FrameId, currentTxId);
    spec = currentTxScenario.Spectrum;
    requireFiniteScalar(spec, 'PlannedFreqOffset', ...
        'CSRD:Construction:TxMissingSpectrum', FrameId, currentTxId);
    requirePositiveScalar(spec, 'PlannedBandwidth', ...
        'CSRD:Construction:TxMissingSpectrum', FrameId, currentTxId);
    TxInfo.FrequencyOffset = double(spec.PlannedFreqOffset);
    TxInfo.Bandwidth = double(spec.PlannedBandwidth);

    % Temporal group
    if isfield(currentTxScenario, 'Temporal')
        TxInfo.Temporal = currentTxScenario.Temporal;
    end

    % Modulation and Message (pass through for downstream reference)
    if isfield(currentTxScenario, 'Modulation')
        TxInfo.Modulation = currentTxScenario.Modulation;
    end
    if isfield(currentTxScenario, 'Message')
        TxInfo.Message = currentTxScenario.Message;
    end

    obj.logger.debug("Frame %d, TxID %s: TxInfo configured (Type: %s, Power: %.1f dBm)", ...
        FrameId, string(currentTxId), TxInfo.Type, TxInfo.Power);

end

function requireStructField(s, fieldName, errId, FrameId, txId)
    % requireStructField - Production declaration in CSRD.
    % 中文说明：requireStructField 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if ~isfield(s, fieldName) || ~isstruct(s.(fieldName))
        error(errId, ...
            'Frame %d, TxID %s: transmitter plan must include struct field %s.', ...
            FrameId, char(string(txId)), fieldName);
    end
end

function requireAnyField(s, fieldName, errId, FrameId, txId)
    % requireAnyField - Production declaration in CSRD.
    % 中文说明：requireAnyField 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if ~isfield(s, fieldName) || isempty(s.(fieldName))
        error(errId, ...
            'Frame %d, TxID %s: transmitter plan missing %s.', ...
            FrameId, char(string(txId)), fieldName);
    end
end

function requireFiniteScalar(s, fieldName, errId, FrameId, txId)
    % requireFiniteScalar - Production declaration in CSRD.
    % 中文说明：requireFiniteScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    requireAnyField(s, fieldName, errId, FrameId, txId);
    value = s.(fieldName);
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error(errId, ...
            'Frame %d, TxID %s: %s must be a finite scalar.', ...
            FrameId, char(string(txId)), fieldName);
    end
end

function requirePositiveScalar(s, fieldName, errId, FrameId, txId)
    % requirePositiveScalar - Production declaration in CSRD.
    % 中文说明：requirePositiveScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    requireFiniteScalar(s, fieldName, errId, FrameId, txId);
    if s.(fieldName) <= 0
        error(errId, ...
            'Frame %d, TxID %s: %s must be positive.', ...
            FrameId, char(string(txId)), fieldName);
    end
end

function requirePositiveIntegerScalar(s, fieldName, errId, FrameId, txId)
    % requirePositiveIntegerScalar - Production declaration in CSRD.
    % 中文说明：requirePositiveIntegerScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    requirePositiveScalar(s, fieldName, errId, FrameId, txId);
    if abs(s.(fieldName) - round(s.(fieldName))) > 0
        error(errId, ...
            'Frame %d, TxID %s: %s must be a positive integer.', ...
            FrameId, char(string(txId)), fieldName);
    end
end

function requireNumericVector(s, fieldName, expectedNumel, errId, FrameId, txId)
    % requireNumericVector - Production declaration in CSRD.
    % 中文说明：requireNumericVector 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    requireAnyField(s, fieldName, errId, FrameId, txId);
    value = s.(fieldName);
    if ~isnumeric(value) || numel(value) ~= expectedNumel || ...
            any(~isfinite(value(:)))
        error(errId, ...
            'Frame %d, TxID %s: %s must be a finite %d-element vector.', ...
            FrameId, char(string(txId)), fieldName, expectedNumel);
    end
end
