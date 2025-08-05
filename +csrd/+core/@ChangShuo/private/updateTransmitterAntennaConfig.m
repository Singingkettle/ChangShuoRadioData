function updateTransmitterAntennaConfig(obj, FrameId, currentTxId, signalSegmentsPerTx, TxInfo)
    % updateTransmitterAntennaConfig - Update transmitter antenna configuration
    %
    % This method updates the transmitter antenna configuration based on
    % the modulator output, ensuring consistency between the configuration
    % and the actual signal segments generated.
    %
    % Inputs:
    %   obj - ChangShuo object instance
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   signalSegmentsPerTx - Cell array of signal segments for this transmitter
    %   TxInfo - Transmitter information structure (modified by reference)

    if ~isempty(signalSegmentsPerTx) && ~isempty(signalSegmentsPerTx{end}) && ...
            isstruct(signalSegmentsPerTx{end}) && isfield(signalSegmentsPerTx{end}, 'NumTransmitAntennas')

        finalNumAntennas = signalSegmentsPerTx{end}.NumTransmitAntennas;

        if TxInfo.NumTransmitAntennas ~= finalNumAntennas
            obj.logger.debug("Frame %d, TxID %s: Updating NumTransmitAntennas from %d to %d based on modulator output.", ...
                FrameId, string(currentTxId), TxInfo.NumTransmitAntennas, finalNumAntennas);

            TxInfo.NumTransmitAntennas = finalNumAntennas;
            TxInfo.SiteConfig.Antenna.NumAntennas = finalNumAntennas;

            % Array type determination
            if finalNumAntennas == 1
                arrayType = 'Isotropic';
            elseif mod(finalNumAntennas, 2) == 0 && finalNumAntennas > 2
                arrayType = "URA";
            else
                arrayType = "ULA";
            end

            TxInfo.SiteConfig.Antenna.Array = arrayType;
        end

    end

end
