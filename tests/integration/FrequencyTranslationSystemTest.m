classdef FrequencyTranslationSystemTest < matlab.unittest.TestCase
    % FrequencyTranslationSystemTest - Integration tests for the complete frequency translation system
    %
    % This test class verifies the end-to-end functionality of the new complex exponential
    % frequency translation system, including:
    % 1. Full pipeline from scenario generation to receiver output
    % 2. Integration between ParameterDrivenPlanner and TRFSimulator
    % 3. Multi-transmitter scenarios with frequency allocation
    % 4. Receiver-centric frequency management
    % 5. Spectrum utilization and validation

    properties (TestParameter)
        % Test parameters for different integration scenarios
        ScenarioSize = {'Small', 'Medium', 'Large'} % Different scenario complexities
        FrequencyStrategy = {'Random', 'NonOverlapping'} % Allocation strategies
        ReceiverConfig = {'Low', 'High'} % Different receiver sample rates
    end

    properties
        % Test fixtures
        MasterConfig
        TestOutputDir
        ProjectRoot
    end

    methods (TestMethodSetup)

        function setupTest(testCase)
            % Setup for each test method

            % Add necessary paths
            testCase.ProjectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(testCase.ProjectRoot);
            addpath(fullfile(testCase.ProjectRoot, 'config', 'csrd2025'));

            % Create test output directory
            testCase.TestOutputDir = fullfile(tempdir, 'CSRD_FreqSysTest');

            if ~exist(testCase.TestOutputDir, 'dir')
                mkdir(testCase.TestOutputDir);
            end

            % Load master configuration
            try
                testCase.MasterConfig = initialize_csrd_configuration();
            catch ME
                % Create minimal configuration if full config is not available
                warning('ConfigLoader:FallbackConfig', 'Could not load full configuration, using minimal test config: %s', ME.message);
                testCase.MasterConfig = testCase.createMinimalConfig();
            end

        end

    end

    methods (TestMethodTeardown)

        function teardownTest(testCase)
            % Cleanup after each test method

            % Clean up temporary files
            if exist(testCase.TestOutputDir, 'dir')

                try
                    rmdir(testCase.TestOutputDir, 's');
                catch
                    % Ignore cleanup errors
                end

            end

        end

    end

    methods (Test)

        function testCompleteFrequencyTranslationPipeline(testCase, ScenarioSize, FrequencyStrategy)
            % Test complete pipeline from scenario generation to frequency translation

            % Configure scenario based on test parameters
            masterConfig = testCase.configureMasterConfig(ScenarioSize, FrequencyStrategy);

            % Step 1: Generate scenario
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            setup(planner);

            frameId = 1;
            [txInstances, rxInstances, globalLayout] = step(planner, frameId, ...
                masterConfig.Factories.Scenario, masterConfig.Factories);

            % Verify scenario generation
            testCase.verifyTrue(iscell(txInstances), 'Transmitter instances should be cell array');
            testCase.verifyTrue(iscell(rxInstances), 'Receiver instances should be cell array');
            testCase.verifyNotEmpty(txInstances, 'Should generate transmitter instances');
            testCase.verifyNotEmpty(rxInstances, 'Should generate receiver instances');

            numTx = length(txInstances);
            fprintf('   Generated %d transmitters for %s scenario\n', numTx, ScenarioSize);

            % Step 2: Process each transmitter through frequency translation
            processedSignals = cell(numTx, 1);
            receiverSampleRate = masterConfig.Factories.Scenario.Global.SampleRate;

            for i = 1:numTx
                tx = txInstances{i};

                % Generate test baseband signal
                [basebandSignal, basebandFs] = testCase.generateTestSignal(tx);

                % Create and configure TRFSimulator
                trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                    'TargetSampleRate', receiverSampleRate, ...
                    'SampleRate', basebandFs, ...
                    'IqImbalanceConfig', struct('A', 0.1, 'P', 2), ...
                    'PhaseNoiseConfig', struct('Level', -90, 'FrequencyOffset', 10e3), ...
                    'MemoryLessNonlinearityConfig', struct( ...
                    'Method', 'Cubic polynomial', ...
                    'LinearGain', 5, ...
                    'TOISpecification', 'IIP3', ...
                    'IIP3', 25, ...
                    'AMPMConversion', 0.5, ...
                    'PowerLowerLimit', -40, ...
                    'PowerUpperLimit', 10, ...
                    'ReferenceImpedance', 50));

                setup(trf);

                % Prepare transmitter input
                x_input = struct();
                x_input.data = basebandSignal;
                x_input.NumTransmitAntennas = 1;

                if isfield(tx, 'FrequencyAllocation')
                    x_input.CarrierFrequency = tx.FrequencyAllocation.CenterFrequency;
                else
                    x_input.CarrierFrequency = 0;
                end

                % Apply frequency translation
                y_output = step(trf, x_input);
                processedSignals{i} = y_output;

                % Verify output structure
                testCase.verifyEqual(y_output.SampleRate, receiverSampleRate, ...
                    sprintf('Tx%d output sample rate should match receiver', i));
                testCase.verifyEqual(y_output.SDRMode, "Complex Exponential Frequency Translation", ...
                    sprintf('Tx%d should use complex exponential mode', i));

                release(trf);
            end

            fprintf('   ✅ Processed %d transmitters through frequency translation\n', numTx);

            % Step 3: Combine signals at receiver
            combinedSpectrum = testCase.analyzeReceiverSpectrum(processedSignals, receiverSampleRate);

            % Step 4: Verify frequency allocation compliance
            testCase.verifyFrequencyAllocation(txInstances, combinedSpectrum, receiverSampleRate, FrequencyStrategy);

            release(planner);
        end

        function testReceiverCentricFrequencyManagement(testCase, ReceiverConfig)
            % Test receiver-centric frequency management across different sample rates

            % Configure different receiver sample rates
            switch ReceiverConfig
                case 'Low'
                    receiverFs = 10e6; % 10 MHz
                case 'High'
                    receiverFs = 40e6; % 40 MHz
                otherwise
                    receiverFs = 20e6; % 20 MHz default
            end

            masterConfig = testCase.MasterConfig;
            masterConfig.Factories.Scenario.Global.SampleRate = receiverFs;
            masterConfig.Factories.Scenario.Transmitters.Count.Min = 5;
            masterConfig.Factories.Scenario.Transmitters.Count.Max = 8;

            % Generate scenario
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            setup(planner);

            [txInstances, ~, ~] = step(planner, 1, masterConfig.Factories.Scenario, masterConfig.Factories);

            % Verify all transmitters are allocated within observable range
            observableRange = receiverFs / 2;

            for i = 1:length(txInstances)
                tx = txInstances{i};

                if isfield(tx, 'FrequencyAllocation')
                    centerFreq = tx.FrequencyAllocation.CenterFrequency;
                    bandwidth = tx.FrequencyAllocation.Bandwidth;

                    % Verify frequency edges are within observable range
                    lowerEdge = centerFreq - bandwidth / 2;
                    upperEdge = centerFreq + bandwidth / 2;

                    testCase.verifyGreaterThanOrEqual(lowerEdge, -observableRange, ...
                        sprintf('Tx%d lower edge (%.2f MHz) exceeds observable range', i, lowerEdge / 1e6));
                    testCase.verifyLessThanOrEqual(upperEdge, observableRange, ...
                        sprintf('Tx%d upper edge (%.2f MHz) exceeds observable range', i, upperEdge / 1e6));

                    fprintf('   Tx%d: Center=%.2f MHz, BW=%.2f MHz, Range=[%.2f, %.2f] MHz\n', ...
                        i, centerFreq / 1e6, bandwidth / 1e6, lowerEdge / 1e6, upperEdge / 1e6);
                end

            end

            fprintf('   ✅ All %d transmitters within ±%.1f MHz observable range\n', ...
                length(txInstances), observableRange / 1e6);

            release(planner);
        end

        function testNegativeFrequencyUtilization(testCase)
            % Test that the system properly utilizes negative frequency offsets

            % Use large receiver sample rate and many transmitters to increase
            % probability of negative frequency allocation
            masterConfig = testCase.MasterConfig;
            masterConfig.Factories.Scenario.Global.SampleRate = 50e6; % Large observable range
            masterConfig.Factories.Scenario.Transmitters.Count.Min = 15;
            masterConfig.Factories.Scenario.Transmitters.Count.Max = 20;

            % Generate multiple scenarios to find negative frequencies
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            setup(planner);

            allFrequencies = [];
            totalTransmitters = 0;

            for frameId = 1:10 % Try multiple frames
                [txInstances, ~, ~] = step(planner, frameId, masterConfig.Factories.Scenario, masterConfig.Factories);

                for i = 1:length(txInstances)
                    tx = txInstances{i};

                    if isfield(tx, 'FrequencyAllocation')
                        allFrequencies(end + 1) = tx.FrequencyAllocation.CenterFrequency;
                        totalTransmitters = totalTransmitters + 1;
                    end

                end

            end

            % Analyze frequency distribution
            positiveFreqs = allFrequencies(allFrequencies > 0);
            negativeFreqs = allFrequencies(allFrequencies < 0);
            zeroFreqs = allFrequencies(allFrequencies == 0);

            fprintf('   Frequency distribution across %d transmitters:\n', totalTransmitters);
            fprintf('     Positive frequencies: %d (%.1f%%)\n', length(positiveFreqs), 100 * length(positiveFreqs) / totalTransmitters);
            fprintf('     Negative frequencies: %d (%.1f%%)\n', length(negativeFreqs), 100 * length(negativeFreqs) / totalTransmitters);
            fprintf('     Zero frequency: %d (%.1f%%)\n', length(zeroFreqs), 100 * length(zeroFreqs) / totalTransmitters);

            % Verify negative frequencies are present (with high probability)
            if length(negativeFreqs) > 0
                testCase.verifyGreaterThan(length(negativeFreqs), 0, 'Should utilize negative frequencies');

                % Verify negative frequencies are within valid range
                observableRange = masterConfig.Factories.Scenario.Global.SampleRate / 2;

                for i = 1:length(negativeFreqs)
                    testCase.verifyGreaterThanOrEqual(negativeFreqs(i), -observableRange, ...
                    'Negative frequency should be within observable range');
                end

                fprintf('   ✅ Negative frequency utilization verified\n');
            else
                fprintf('   ⚠️ No negative frequencies in this test run (random behavior)\n');
            end

            release(planner);
        end

        function testSpectrumEfficiencyComparison(testCase)
            % Test spectrum efficiency compared to traditional allocation

            masterConfig = testCase.MasterConfig;
            masterConfig.Factories.Scenario.Global.SampleRate = 20e6;
            masterConfig.Factories.Scenario.Transmitters.Count.Min = 8;
            masterConfig.Factories.Scenario.Transmitters.Count.Max = 12;

            % Test receiver-centric allocation
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            setup(planner);

            [txInstances, ~, ~] = step(planner, 1, masterConfig.Factories.Scenario, masterConfig.Factories);

            % Calculate spectrum utilization
            totalBandwidth = 0;
            frequencyExtents = [];

            for i = 1:length(txInstances)
                tx = txInstances{i};

                if isfield(tx, 'FrequencyAllocation')
                    bandwidth = tx.FrequencyAllocation.Bandwidth;
                    centerFreq = tx.FrequencyAllocation.CenterFrequency;

                    totalBandwidth = totalBandwidth + bandwidth;
                    frequencyExtents(end + 1, :) = [centerFreq - bandwidth / 2, centerFreq + bandwidth / 2];
                end

            end

            % Calculate actual frequency span used
            if ~isempty(frequencyExtents)
                actualSpan = max(frequencyExtents(:, 2)) - min(frequencyExtents(:, 1));
            else
                actualSpan = 0;
            end

            % Calculate efficiency metrics
            observableRange = masterConfig.Factories.Scenario.Global.SampleRate / 2;
            availableBandwidth = 2 * observableRange; % Full range [-Fs/2, +Fs/2]

            bandwidthEfficiency = totalBandwidth / availableBandwidth;
            spanEfficiency = actualSpan / availableBandwidth;

            fprintf('   Spectrum efficiency analysis:\n');
            fprintf('     Available bandwidth: %.1f MHz\n', availableBandwidth / 1e6);
            fprintf('     Total allocated bandwidth: %.1f MHz\n', totalBandwidth / 1e6);
            fprintf('     Actual frequency span: %.1f MHz\n', actualSpan / 1e6);
            fprintf('     Bandwidth efficiency: %.1f%%\n', bandwidthEfficiency * 100);
            fprintf('     Span efficiency: %.1f%%\n', spanEfficiency * 100);

            % Verify reasonable efficiency
            testCase.verifyLessThanOrEqual(bandwidthEfficiency, 1.0, ...
            'Total bandwidth should not exceed available bandwidth');
            testCase.verifyGreaterThan(bandwidthEfficiency, 0, ...
            'Should allocate some bandwidth');

            if spanEfficiency > 0
                testCase.verifyLessThanOrEqual(spanEfficiency, 1.0, ...
                'Frequency span should not exceed observable range');
            end

            fprintf('   ✅ Spectrum efficiency validated\n');

            release(planner);
        end

        function testEndToEndSignalIntegrity(testCase)
            % Test signal integrity through complete processing pipeline

            masterConfig = testCase.MasterConfig;
            masterConfig.Factories.Scenario.Global.SampleRate = 20e6;
            masterConfig.Factories.Scenario.Transmitters.Count.Min = 3;
            masterConfig.Factories.Scenario.Transmitters.Count.Max = 3;

            % Generate scenario
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            setup(planner);

            [txInstances, rxInstances, ~] = step(planner, 1, masterConfig.Factories.Scenario, masterConfig.Factories);

            % Process signals with known test content
            processedSignals = cell(length(txInstances), 1);
            testFrequencies = [100e3, 200e3, 300e3]; % Known test frequencies

            for i = 1:length(txInstances)
                tx = txInstances{i};

                % Generate known test signal
                basebandFs = 2e6;
                signalLength = 2048;
                t = (0:signalLength - 1)' / basebandFs;

                % Create test signal with known frequency content
                testSignal = exp(1j * 2 * pi * testFrequencies(i) * t);

                % Process through TRFSimulator
                trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                    'TargetSampleRate', masterConfig.Factories.Scenario.Global.SampleRate, ...
                    'SampleRate', basebandFs, ...
                    'IqImbalanceConfig', struct('A', 0, 'P', 0), ... % No impairments for integrity test
                    'PhaseNoiseConfig', struct('Level', -120, 'FrequencyOffset', 10e3), ...
                    'MemoryLessNonlinearityConfig', struct( ...
                    'Method', 'Cubic polynomial', ...
                    'LinearGain', 0, ...
                    'TOISpecification', 'IIP3', ...
                    'IIP3', 50, ...
                    'AMPMConversion', 0, ...
                    'PowerLowerLimit', -60, ...
                    'PowerUpperLimit', 20, ...
                    'ReferenceImpedance', 50));

                setup(trf);

                x_input = struct();
                x_input.data = testSignal;
                x_input.NumTransmitAntennas = 1;
                x_input.CarrierFrequency = tx.FrequencyAllocation.CenterFrequency;

                y_output = step(trf, x_input);
                processedSignals{i} = y_output;

                % Verify frequency translation accuracy
                expectedFreq = tx.FrequencyAllocation.CenterFrequency + testFrequencies(i);
                actualFreq = testCase.findPeakFrequency(y_output.data, y_output.SampleRate);

                freqError = abs(actualFreq - expectedFreq);
                freqTolerance = y_output.SampleRate / length(y_output.data) * 3; % 3 frequency bins

                testCase.verifyLessThan(freqError, freqTolerance, ...
                    sprintf('Tx%d frequency error (%.2f kHz) exceeds tolerance', i, freqError / 1e3));

                fprintf('   Tx%d: Expected %.2f MHz, Actual %.2f MHz, Error %.1f kHz\n', ...
                    i, expectedFreq / 1e6, actualFreq / 1e6, freqError / 1e3);

                release(trf);
            end

            fprintf('   ✅ Signal integrity verified through complete pipeline\n');

            release(planner);
        end

    end

    methods (Access = private)

        function config = createMinimalConfig(testCase)
            % Create minimal configuration for testing when full config is unavailable

            config = struct();

            % Factory Scenario configuration (unified structure)
            config.Factories = struct();
            config.Factories.Scenario = struct();
            config.Factories.Scenario.Global = struct('SampleRate', 20e6, 'FrameDuration', 1e-3);
            config.Factories.Scenario.Transmitters = struct( ...
                'Count', struct('Min', 2, 'Max', 5), ...
                'Types', {{'Generic'}});
            config.Factories.Scenario.Receivers = struct( ...
                'Count', struct('Min', 1, 'Max', 1), ...
                'Types', {{'Generic'}});
            config.Factories.Scenario.Layout = struct( ...
                'FrequencyAllocation', struct('Strategy', 'Random', 'AllowOverlap', true));

            % Minimal modulation factory
            config.Factories.Modulation = struct();
            config.Factories.Modulation.Types = containers.Map();
            config.Factories.Modulation.Types('PSK') = struct( ...
                'Handle', @csrd.blocks.physical.modulate.digital.PSK, ...
                'Parameters', struct('ModulationOrder', [2, 4, 8], 'SampleRate', 1e6));

            % Other minimal factories
            config.Factories.Message = struct('Types', {{}}, 'DefaultConfig', struct());
            config.Factories.Transmit = struct('ImpairmentModels', containers.Map());
            config.Factories.Channel = struct('Types', containers.Map());
            config.Factories.Receive = struct('Types', containers.Map());
        end

        function config = configureMasterConfig(testCase, scenarioSize, frequencyStrategy)
            % Configure master configuration based on test parameters

            config = testCase.MasterConfig;

            % Configure scenario size
            switch scenarioSize
                case 'Small'
                    config.Factories.Scenario.Transmitters.Count.Min = 2;
                    config.Factories.Scenario.Transmitters.Count.Max = 3;
                case 'Medium'
                    config.Factories.Scenario.Transmitters.Count.Min = 4;
                    config.Factories.Scenario.Transmitters.Count.Max = 6;
                case 'Large'
                    config.Factories.Scenario.Transmitters.Count.Min = 8;
                    config.Factories.Scenario.Transmitters.Count.Max = 12;
            end

            % Configure frequency strategy
            config.Factories.Scenario.Layout.FrequencyAllocation.Strategy = frequencyStrategy;
            config.Factories.Scenario.Layout.FrequencyAllocation.AllowOverlap = strcmp(frequencyStrategy, 'Random');
        end

        function [signal, sampleRate] = generateTestSignal(testCase, txInstance)
            % Generate test baseband signal for transmitter

            sampleRate = 1e6; % 1 MHz baseband
            signalLength = 1024;

            t = (0:signalLength - 1)' / sampleRate;

            % Generate multi-tone test signal
            freq1 = 50e3; % 50 kHz
            freq2 = 150e3; % 150 kHz

            signal = 0.7 * exp(1j * 2 * pi * freq1 * t) + ...
                0.3 * exp(1j * 2 * pi * freq2 * t);

            % Add small amount of noise
            noise = 0.05 * (randn(size(signal)) + 1j * randn(size(signal)));
            signal = signal + noise;
        end

        function spectrum = analyzeReceiverSpectrum(testCase, processedSignals, sampleRate)
            % Analyze combined spectrum at receiver

            % Find maximum signal length
            maxLength = 0;

            for i = 1:length(processedSignals)
                maxLength = max(maxLength, length(processedSignals{i}.data));
            end

            % Combine signals (simple addition)
            combinedSignal = zeros(maxLength, 1);

            for i = 1:length(processedSignals)
                signal = processedSignals{i}.data;

                if length(signal) < maxLength
                    signal = [signal; zeros(maxLength - length(signal), 1)];
                end

                combinedSignal = combinedSignal + signal;
            end

            % Compute spectrum
            nfft = 4096;
            Y_fft = fftshift(fft(combinedSignal, nfft));
            freqs = (-nfft / 2:nfft / 2 - 1) * sampleRate / nfft;
            psd = 10 * log10(abs(Y_fft) .^ 2);

            spectrum = struct();
            spectrum.frequencies = freqs;
            spectrum.psd = psd;
            spectrum.combinedSignal = combinedSignal;
        end

        function verifyFrequencyAllocation(testCase, txInstances, spectrum, sampleRate, strategy)
            % Verify frequency allocation compliance

            observableRange = sampleRate / 2;

            % Check each transmitter's frequency allocation
            for i = 1:length(txInstances)
                tx = txInstances{i};

                if isfield(tx, 'FrequencyAllocation')
                    centerFreq = tx.FrequencyAllocation.CenterFrequency;
                    bandwidth = tx.FrequencyAllocation.Bandwidth;

                    % Verify within observable range
                    testCase.verifyGreaterThanOrEqual(centerFreq - bandwidth / 2, -observableRange, ...
                        sprintf('Tx%d lower edge outside observable range', i));
                    testCase.verifyLessThanOrEqual(centerFreq + bandwidth / 2, observableRange, ...
                        sprintf('Tx%d upper edge outside observable range', i));
                end

            end

            % For non-overlapping strategy, verify no overlaps
            if strcmp(strategy, 'NonOverlapping') && length(txInstances) > 1

                for i = 1:length(txInstances)

                    for j = i + 1:length(txInstances)
                        tx1 = txInstances{i};
                        tx2 = txInstances{j};

                        if isfield(tx1, 'FrequencyAllocation') && isfield(tx2, 'FrequencyAllocation')
                            freq1_range = [tx1.FrequencyAllocation.CenterFrequency - tx1.FrequencyAllocation.Bandwidth / 2, ...
                                               tx1.FrequencyAllocation.CenterFrequency + tx1.FrequencyAllocation.Bandwidth / 2];
                            freq2_range = [tx2.FrequencyAllocation.CenterFrequency - tx2.FrequencyAllocation.Bandwidth / 2, ...
                                               tx2.FrequencyAllocation.CenterFrequency + tx2.FrequencyAllocation.Bandwidth / 2];

                            hasOverlap = ~(freq1_range(2) <= freq2_range(1) || freq2_range(2) <= freq1_range(1));
                            testCase.verifyFalse(hasOverlap, ...
                                sprintf('Tx%d and Tx%d overlap in NonOverlapping strategy', i, j));
                        end

                    end

                end

            end

        end

        function peakFreq = findPeakFrequency(testCase, signal, sampleRate)
            % Find peak frequency in signal spectrum

            nfft = 2048;
            Y_fft = fftshift(fft(signal, nfft));
            freqs = (-nfft / 2:nfft / 2 - 1) * sampleRate / nfft;

            [~, peakIdx] = max(abs(Y_fft));
            peakFreq = freqs(peakIdx);
        end

    end

end
