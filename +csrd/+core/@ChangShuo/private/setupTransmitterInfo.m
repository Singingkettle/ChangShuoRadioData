function TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId)
    % setupTransmitterInfo - Setup transmitter information structure
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

    % Physical group
    if isfield(currentTxScenario, 'Physical') && isfield(currentTxScenario.Physical, 'Position')
        TxInfo.Position = currentTxScenario.Physical.Position;
    else
        TxInfo.Position = [0, 0, 50];
    end
    if isfield(currentTxScenario, 'Physical') && isfield(currentTxScenario.Physical, 'Velocity')
        TxInfo.Velocity = currentTxScenario.Physical.Velocity;
    else
        TxInfo.Velocity = [0, 0, 0];
    end

    % Hardware group
    if isfield(currentTxScenario, 'Hardware')
        hw = currentTxScenario.Hardware;
        TxInfo.Type = getFieldOrDefault(hw, 'Type', 'Simulation');
        TxInfo.Power = getFieldOrDefault(hw, 'Power', 20);
        TxInfo.NumTransmitAntennas = getFieldOrDefault(hw, 'NumAntennas', 2);
        TxInfo.AntennaGain = getFieldOrDefault(hw, 'AntennaGain', 3);
    else
        TxInfo.Type = 'Simulation';
        TxInfo.Power = 20;
        TxInfo.NumTransmitAntennas = 2;
        TxInfo.AntennaGain = 3;
    end

    % Spectrum group
    if isfield(currentTxScenario, 'Spectrum')
        spec = currentTxScenario.Spectrum;
        TxInfo.FrequencyOffset = getFieldOrDefault(spec, 'PlannedFreqOffset', 0);
        TxInfo.Bandwidth = getFieldOrDefault(spec, 'PlannedBandwidth', 10e6);
    else
        TxInfo.FrequencyOffset = 0;
        TxInfo.Bandwidth = 10e6;
    end

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

function val = getFieldOrDefault(s, fieldName, default)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end
