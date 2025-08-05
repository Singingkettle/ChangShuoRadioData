function TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId)
    % setupTransmitterInfo - Setup transmitter information structure
    %
    % This method creates and configures the transmitter information structure
    % including antenna configuration and site parameters.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxScenario - Current transmitter scenario configuration
    %   currentTxId - Current transmitter ID
    %
    % Outputs:
    %   TxInfo - Configured transmitter information structure

    % Get number of antennas
    numAntennas = 2; % Default value

    if isfield(currentTxScenario, 'Site') && isstruct(currentTxScenario.Site) && ...
            isfield(currentTxScenario.Site, 'NumAntennas')
        numAntennas = currentTxScenario.Site.NumAntennas;
        obj.logger.debug("Frame %d, TxID %s: Using scenario NumAntennas: %d", ...
            FrameId, string(currentTxId), numAntennas);
    else
        obj.logger.warning('Frame %d, TxID %s: Site configuration or NumAntennas missing. Using default value.', ...
            FrameId, string(currentTxId));
    end

    % Create site configuration structure for backward compatibility
    txSiteConfig = struct();
    txSiteConfig.NumAntennas = numAntennas;
    txSiteConfig.Name = sprintf('Tx_%d_%d', FrameId, currentTxId);
    txSiteConfig.Position = [0, 0, 50]; % Default position
    txSiteConfig.Antenna = struct('NumAntennas', numAntennas);

    % Setup transmitter info structure
    TxInfo = struct();
    TxInfo.ID = currentTxId;
    TxInfo.SiteConfig = txSiteConfig;
    TxInfo.NumTransmitAntennas = numAntennas;

    % Set impairment model type
    if isfield(currentTxScenario, 'ImpairmentModelType')
        TxInfo.ParentTransmitterType = currentTxScenario.ImpairmentModelType;
    else
        TxInfo.ParentTransmitterType = "Ideal";
        obj.logger.debug("Frame %d, TxID %s: ImpairmentModelType not in scenario, defaulting to Ideal.", ...
            FrameId, string(currentTxId));
    end

    % Add default frequency parameters if not set by ScenarioFactory
    if ~isfield(TxInfo, 'CarrierFrequency')
        TxInfo.CarrierFrequency = 100e6; % Default 100 MHz
    end

    if ~isfield(TxInfo, 'BandWidth')
        TxInfo.BandWidth = 10e6; % Default 10 MHz
    end

    if ~isfield(TxInfo, 'SampleRate')
        TxInfo.SampleRate = 25e6; % Default 25 MS/s
    end

end
