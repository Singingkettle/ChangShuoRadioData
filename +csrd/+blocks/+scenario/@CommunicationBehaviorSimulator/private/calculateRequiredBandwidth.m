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

    % Modulation order (M). Needed by M-ary FSK whose occupied band grows with
    % the number of tones; defaults to 2 for binary/analog where it is unused.
    modOrder = 2;
    if isfield(modulationConfig, 'Order') && isnumeric(modulationConfig.Order) && ...
            isscalar(modulationConfig.Order) && isfinite(modulationConfig.Order) && ...
            modulationConfig.Order >= 2
        modOrder = double(modulationConfig.Order);
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
            % M-ary FSK with an orthogonal tone spacing of ~1 symbol rate
            % (modulation index h ~= 1, up to 1.2): the realized band spans the
            % M tones, ~h·(M-1)·Rs plus ~2·Rs of skirts. The old fixed 2.0x
            % factor ignored M and the modulator's separation tracked the
            % (SPS-inflated) sample rate, so high-SPS narrow FSK overran its
            % channel >15x. See FSK.genModulatorHandle (separation now scales
            % with the symbol rate, not the sample rate).
            bandwidth = symbolRate * (1.2 * (modOrder - 1) + 2);

            % Continuous Phase Modulation (bandwidth efficient)
        case {'CPFSK', 'GFSK'}
            % M-ary continuous-phase FSK (modulation index h ~= 1): the realized
            % band spans the M frequency levels (~M*Rs), nearly identical to
            % plain FSK (measured M=2->2.2, M=4->4.5, M=8->7.9 x Rs). The old
            % fixed 1.0x factor (binary GMSK-like efficiency) under-allocated up
            % to ~8x for 8-ary CPM. The Gaussian/CPM smoothing barely changes the
            % 99% OBW, so reuse the FSK plan that accounts for the tone count.
            bandwidth = symbolRate * (1.2 * (modOrder - 1) + 2);
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
            % Carson's rule: BW = 2(Δf + fm) with a realistic narrowband-FM
            % modulation index beta = 2 (Δf = 2·fm). With fm ~= symbolRate this
            % is BW = 2(2·fm + fm) = 6·fm. The modulator's FrequencyDeviation is
            % set to bandwidth/3 (= 2·symbolRate) so the realized FM occupies
            % its planned channel instead of overrunning it ~7x (the old 2.5x
            % factor implied beta ~= 0.25 while the modulator used a fixed 75 kHz
            % broadcast deviation -> beta ~= 5).
            bandwidth = symbolRate * 6; % Carson BW for narrowband FM (beta = 2)
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
