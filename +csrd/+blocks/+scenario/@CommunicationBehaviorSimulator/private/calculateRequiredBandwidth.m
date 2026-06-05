function bandwidth = calculateRequiredBandwidth(obj, modulationConfig)
    % calculateRequiredBandwidth - Calculate required bandwidth based on modulation
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % IMPORTANT NOTE: This is an APPROXIMATE bandwidth calculation used only
    % for frequency planning purposes during simulation setup. It serves as
    % a "frequency planner" for allocating spectrum among multiple transmitters
    % in the scenario.
    %
    % This calculation is NOT precise and should NOT be used for actual
    % bandwidth measurements. When collecting simulation data, the actual
    % 99% occupied bandwidth will be calculated using MATLAB's obw() function
    % based on the real simulated signal power spectral density.
    %
    % Purpose:
    %   - Frequency allocation planning in multi-transmitter scenarios
    %   - Interference avoidance during spectrum assignment
    %   - Initial bandwidth estimation for system configuration
    %
    % Actual bandwidth measurement:
    %   - Use obw(signal, sampleRate) for 99% energy bandwidth
    %   - Based on actual transmitted signal characteristics
    %   - Accounts for real pulse shaping, filtering, and modulation effects

    if isfield(modulationConfig, 'SymbolRate') && ...
            isnumeric(modulationConfig.SymbolRate) && ...
            isscalar(modulationConfig.SymbolRate) && ...
            isfinite(modulationConfig.SymbolRate) && ...
            modulationConfig.SymbolRate > 0
        symbolRate = modulationConfig.SymbolRate;
    else
        error('CSRD:Scenario:MissingModulationSymbolRate', ...
            'modulationConfig.SymbolRate is required for bandwidth planning.');
    end

    if isfield(modulationConfig, 'Type') && ~isempty(modulationConfig.Type)
        modType = modulationConfig.Type;
    else
        error('CSRD:Scenario:MissingModulationType', ...
            'modulationConfig.Type is required for bandwidth planning.');
    end

    % Bandwidth calculation based on modulation type
    switch modType
            % Linear digital modulation schemes
        case 'PSK'
            bandwidth = symbolRate * 1.2; % 20 % excess bandwidth for pulse shaping
        case 'OQPSK'
            bandwidth = symbolRate * 1.2; % Similar to PSK
        case 'QAM'
            bandwidth = symbolRate * 1.25; % 25 % excess for QAM
        case 'Mill88QAM'
            bandwidth = symbolRate * 1.25; % Similar to QAM
        case 'ASK'
            bandwidth = symbolRate * 1.2; % 20 % excess bandwidth
        case 'OOK'
            bandwidth = symbolRate * 1.1; % Simple on-off keying

            % Amplitude and Phase Shift Keying
        case {'APSK', 'DVBSAPSK'}
            bandwidth = symbolRate * 1.3; % 30 % excess for APSK

            % Frequency Shift Keying
        case 'FSK'
            bandwidth = symbolRate * 2.0; % Wider bandwidth for FSK

            % Continuous Phase Modulation (bandwidth efficient)
        case {'CPFSK', 'GFSK'}
            bandwidth = symbolRate * 1.0; % Bandwidth efficient CPM
        case {'GMSK', 'MSK'}
            bandwidth = symbolRate * 0.8; % Very bandwidth efficient

            % Multi-carrier modulation schemes
        case 'OFDM'
            bandwidth = symbolRate * 1.1; % 10 % guard bands for OFDM
        case 'OTFS'
            bandwidth = symbolRate * 1.15; % 15 % overhead for OTFS
        case 'SCFDMA'
            bandwidth = symbolRate * 1.1; % Similar to OFDM

            % Analog modulation schemes
        case 'FM'
            % Carson's rule: BW = 2(Δf + fm)
            % Using moderate modulation index
            bandwidth = symbolRate * 2.5; % Wide bandwidth for FM
        case 'PM'
            bandwidth = symbolRate * 2.0; % Wide bandwidth for PM

            % Amplitude Modulation variants
        case 'SSBAM'
            bandwidth = symbolRate * 1.0; % Single sideband - most efficient
        case 'DSBAM'
            bandwidth = symbolRate * 2.0; % Double sideband
        case 'DSBSCAM'
            bandwidth = symbolRate * 2.0; % Double sideband suppressed carrier
        case 'VSBAM'
            bandwidth = symbolRate * 1.25; % Vestigial sideband

        otherwise
            error('CSRD:Scenario:UnsupportedModulationType', ...
                'Unsupported modulation type "%s" for bandwidth planning.', ...
                char(string(modType)));
    end

    % Apply minimum bandwidth constraint
    bandwidth = max(bandwidth, 1e3); % Minimum 1 kHz bandwidth
end
