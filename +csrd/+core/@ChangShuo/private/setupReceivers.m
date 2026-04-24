function RxInfos = setupReceivers(obj, FrameId, numRxThisFrame)
    % setupReceivers - Setup receiver configurations for current frame
    %
    % Inputs:
    %   FrameId - Frame identifier
    %   numRxThisFrame - Number of receivers in this frame
    %
    % Outputs:
    %   RxInfos - Cell array of receiver information structures

    obj.logger.debug("Frame %d: Setting up %d receiver(s).", FrameId, numRxThisFrame);

    RxInfos = cell(1, numRxThisFrame);

    for rxIdx = 1:numRxThisFrame
        try
            if rxIdx > length(obj.ScenarioConfig.Receivers)
                obj.logger.warning('Frame %d, Rx Index %d: Receiver not defined in scenario.', FrameId, rxIdx);
                RxInfos{rxIdx} = struct('Status', 'Error_MissingRxScenario');
                continue;
            end

            rxPlan = obj.ScenarioConfig.Receivers{rxIdx};

            RxInfo = struct();
            RxInfo.ID = rxPlan.EntityID;
            RxInfo.Status = 'Ready';

            % Physical
            if isfield(rxPlan, 'Physical') && isfield(rxPlan.Physical, 'Position')
                RxInfo.Position = rxPlan.Physical.Position;
            else
                RxInfo.Position = [0, 0, 10];
            end
            if isfield(rxPlan, 'Physical') && isfield(rxPlan.Physical, 'Velocity')
                RxInfo.Velocity = rxPlan.Physical.Velocity;
            else
                RxInfo.Velocity = [0, 0, 0];
            end

            % Hardware
            if isfield(rxPlan, 'Hardware')
                RxInfo.Type = getFieldOrDefault(rxPlan.Hardware, 'Type', 'Simulation');
                RxInfo.NumAntennas = getFieldOrDefault(rxPlan.Hardware, 'NumAntennas', 1);
            else
                RxInfo.Type = 'Simulation';
                RxInfo.NumAntennas = 1;
            end

            % Observation
            if isfield(rxPlan, 'Observation')
                RxInfo.SampleRate = getFieldOrDefault(rxPlan.Observation, 'SampleRate', 50e6);
                RxInfo.ObservableRange = getFieldOrDefault(rxPlan.Observation, 'ObservableRange', [-25e6, 25e6]);
                RxInfo.CenterFrequency = getFieldOrDefault(rxPlan.Observation, 'CenterFrequency', 0);
                RxInfo.RealCarrierFrequency = getFieldOrDefault(rxPlan.Observation, 'RealCarrierFrequency', 2.4e9);
            else
                RxInfo.SampleRate = 50e6;
                RxInfo.ObservableRange = [-25e6, 25e6];
                RxInfo.CenterFrequency = 0;
                RxInfo.RealCarrierFrequency = 2.4e9;
            end

            RxInfos{rxIdx} = RxInfo;

            obj.logger.debug("Frame %d, RxID %s: Receiver configured (Type: %s, SampleRate: %.2f MHz).", ...
                FrameId, string(RxInfo.ID), RxInfo.Type, RxInfo.SampleRate / 1e6);

        catch ME_rx
            obj.logger.error("Frame %d, Rx Index %d: Error setting up receiver: %s", ...
                FrameId, rxIdx, ME_rx.message);
            RxInfos{rxIdx} = struct('Status', 'Error_ReceiverSetup', 'ErrorMessage', ME_rx.message);
        end
    end

    obj.logger.debug("Frame %d: Receiver setup complete.", FrameId);
end

function val = getFieldOrDefault(s, fieldName, default)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end
