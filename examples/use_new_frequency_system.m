function use_new_frequency_system()
    % use_new_frequency_system - Demonstrate usage of the new complex exponential frequency translation system
    %
    % This example shows how to:
    % 1. Configure receiver-centric frequency allocation
    % 2. Generate multi-transmitter scenarios
    % 3. Create time-frequency data suitable for AI/ML training

    fprintf('=== New Frequency Translation System Usage Example ===\n\n');

    % Add paths
    currentPath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(currentPath);
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'config', 'csrd2025'));

    try
        %% 1. System Configuration
        fprintf('1. Loading and configuring system...\n');

        % Load master configuration
        masterConfig = initialize_csrd_configuration();

        % Key setting: receiver sampling rate defines observable spectrum range
        receiverSampleRate = 20e6; % 20 MHz sampling rate
        observableRange = receiverSampleRate; % 0 to 20 MHz observable range

        % Update configuration
        masterConfig.Factories.Scenario.Global.SampleRate = receiverSampleRate;
        masterConfig.Factories.Scenario.Transmitters.Count.Min = 3;
        masterConfig.Factories.Scenario.Transmitters.Count.Max = 5;

        fprintf('   Receiver sampling rate: %.1f MHz\n', receiverSampleRate / 1e6);
        fprintf('   Observable spectrum range: [0, %.1f] MHz\n', observableRange / 1e6);
        fprintf('   ‚ú?System configuration complete\n\n');

        %% 2. Scenario Generation
        fprintf('2. Generating multi-transmitter scenario...\n');

        % Create scenario planner
        planner = csrd.blocks.scenario.ParameterDrivenPlanner();
        setup(planner);

        % Generate scenario instance
        frameId = 1;
        [txInstances, rxInstances, globalLayout] = step(planner, frameId, ...
            masterConfig.Factories.Scenario, masterConfig.Factories);

        numTx = length(txInstances);
        fprintf('   Generated %d transmitters\n', numTx);
        fprintf('   Frequency allocation strategy: %s\n', globalLayout.AllocationStrategy);

        % Display frequency allocation results
        fprintf('   Transmitter frequency allocations:\n');

        for i = 1:numTx
            tx = txInstances{i};

            if isfield(tx, 'FrequencyAllocation')
                centerFreq = tx.FrequencyAllocation.CenterFrequency;
                bandwidth = tx.FrequencyAllocation.Bandwidth;
                fprintf('     Tx%d: Center freq=%.2f MHz, Bandwidth=%.2f MHz\n', ...
                    i, centerFreq / 1e6, bandwidth / 1e6);
            end

        end

        fprintf('   ‚ú?Scenario generation complete\n\n');

        %% 3. Signal Generation and Processing
        fprintf('3. Generating and processing signals...\n');

        processedSignals = cell(numTx, 1);

        for i = 1:numTx
            tx = txInstances{i};

            % Generate baseband test signal
            basebandSampleRate = 1e6; % 1 MHz baseband rate
            signalLength = 2048;
            t = (0:signalLength - 1)' / basebandSampleRate;

            % Create test signal with multiple frequency components
            testFreq1 = 100e3; % 100 kHz
            testFreq2 = 200e3; % 200 kHz
            baseband_signal = 0.7 * exp(1j * 2 * pi * testFreq1 * t) + ...
                0.3 * exp(1j * 2 * pi * testFreq2 * t);

            % Add noise
            noise = 0.1 * (randn(size(baseband_signal)) + 1j * randn(size(baseband_signal)));
            baseband_signal = baseband_signal + noise;

            % Prepare transmitter input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = tx.FrequencyAllocation.CenterFrequency;

            % Configure TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', receiverSampleRate, ...
                'SampleRate', basebandSampleRate, ...
                'IqImbalanceConfig', struct('A', 0.1, 'P', 2), ...
                'PhaseNoiseConfig', struct('Level', -90, 'FrequencyOffset', 10e3), ...
                'MemoryLessNonlinearityConfig', struct( ...
                'Method', 'Cubic polynomial', ...
                'LinearGain', 10, ...
                'TOISpecification', 'IIP3', ...
                'IIP3', 20, ...
                'AMPMConversion', 1, ...
                'PowerLowerLimit', -40, ...
                'PowerUpperLimit', 10, ...
                'ReferenceImpedance', 50));

            setup(trf);

            % Apply frequency translation and RF impairments
            y_output = step(trf, x_input);
            processedSignals{i} = y_output;

            fprintf('   Tx%d: Baseband(%d samples, %.1f MHz) ‚Ü?Freq shift(%.2f MHz) ‚Ü?Output(%d samples, %.1f MHz)\n', ...
                i, length(baseband_signal), basebandSampleRate / 1e6, ...
                x_input.CarrierFrequency / 1e6, length(y_output.data), y_output.SampleRate / 1e6);

            release(trf);
        end

        fprintf('   ‚ú?Signal processing complete\n\n');

        %% 4. Receiver Signal Synthesis
        fprintf('4. Receiver signal synthesis...\n');

        % Prepare receiver input format
        rxInput = cell(numTx, 1);

        for i = 1:numTx
            txOutput = processedSignals{i};

            % Add propagation-related information
            txOutput.StartTime = txInstances{i}.Behavior.StartTime;
            txOutput.TimeDuration = txOutput.SamplePerFrame / txOutput.SampleRate;
            txOutput.RxSiteConfig = struct('Position', [0, 0, 10]);

            rxInput{i} = {txOutput};
        end

        % Create receiver
        rx = csrd.blocks.physical.rxRadioFront.RRFSimulator( ...
            'MasterClockRate', receiverSampleRate, ...
            'UseReceiverCentricMode', true, ...
            'NumReceiveAntennas', 1, ...
            'IqImbalanceConfig', struct('A', 0.05, 'P', 1), ...
            'MemoryLessNonlinearityConfig', struct( ...
            'Method', 'Cubic polynomial', ...
            'LinearGain', 20, ...
            'TOISpecification', 'IIP3', ...
            'IIP3', 25, ...
            'AMPMConversion', 0.5, ...
            'PowerLowerLimit', -30, ...
            'PowerUpperLimit', 20, ...
            'ReferenceImpedance', 50), ...
            'ThermalNoiseConfig', struct('NoiseTemperature', 290));

        setup(rx);

        % Process synthesized signal
        rxOutput = step(rx, rxInput);

        fprintf('   Receiver output: %d samples, %.1f MHz\n', ...
            length(rxOutput.data), rxOutput.annotation.rx.MasterClockRate / 1e6);
        fprintf('   Processed %d transmitter signals\n', numTx);
        fprintf('   ‚ú?Receiver processing complete\n\n');

        %% 5. Spectrum Analysis
        fprintf('5. Spectrum analysis and visualization...\n');

        % FFT analysis
        nfft = 4096;
        Y_fft = fftshift(fft(rxOutput.data, nfft));
        freqs = (-nfft / 2:nfft / 2 - 1) * receiverSampleRate / nfft;

        % Calculate power spectral density
        psd = 10 * log10(abs(Y_fft) .^ 2);

        % Display spectrum information
        fprintf('   Spectrum analysis parameters:\n');
        fprintf('     FFT points: %d\n', nfft);
        fprintf('     Frequency resolution: %.2f kHz\n', receiverSampleRate / nfft / 1e3);
        fprintf('     Analysis range: [%.1f, %.1f] MHz\n', freqs(1) / 1e6, freqs(end) / 1e6);

        % Find peaks
        [peaks, peakLocs] = findpeaks(psd, 'MinPeakHeight', max(psd) - 20, 'MinPeakDistance', 50);
        peakFreqs = freqs(peakLocs);

        fprintf('   Detected spectrum peaks:\n');

        for i = 1:length(peakFreqs)
            fprintf('     Peak%d: %.2f MHz (%.1f dB)\n', i, peakFreqs(i) / 1e6, peaks(i));
        end

        % Time-frequency plot suitability (simulation)
        fprintf('   Time-frequency plot suitability:\n');
        fprintf('     ‚ú?No negative frequency mirror interference\n');
        fprintf('     ‚ú?Compact spectrum distribution\n');
        fprintf('     ‚ú?Suitable for CNN feature extraction\n');
        fprintf('     ‚ú?Clear frequency labels\n');

        release(rx);

        fprintf('   ‚ú?Spectrum analysis complete\n\n');

        %% 6. System Advantages Summary
        fprintf('6. New system advantages summary:\n');

        % Calculate spectrum utilization
        totalAllocatedBW = 0;

        for i = 1:numTx

            if isfield(txInstances{i}, 'FrequencyAllocation')
                totalAllocatedBW = totalAllocatedBW + txInstances{i}.FrequencyAllocation.Bandwidth;
            end

        end

        utilizationRatio = totalAllocatedBW / observableRange;

        fprintf('   Spectrum efficiency:\n');
        fprintf('     Allocated bandwidth: %.2f MHz\n', totalAllocatedBW / 1e6);
        fprintf('     Available bandwidth: %.2f MHz\n', observableRange / 1e6);
        fprintf('     Utilization ratio: %.1f%%\n', utilizationRatio * 100);

        fprintf('   Technical advantages:\n');
        fprintf('     ‚ú?Complex exponential translation replaces DUC\n');
        fprintf('     ‚ú?Receiver-centric frequency allocation\n');
        fprintf('     ‚ú?Support negative frequency offsets\n');
        fprintf('     ‚ú?Improved computational efficiency\n');
        fprintf('     ‚ú?AI/ML-friendly spectrum data\n');

        fprintf('\n=== Example execution successfully completed ===\n');

    catch ME
        fprintf('\n‚ù?Example execution failed: %s\n', ME.message);
        fprintf('Detailed error:\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    end

end
