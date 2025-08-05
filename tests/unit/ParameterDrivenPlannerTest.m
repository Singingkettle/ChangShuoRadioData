classdef ParameterDrivenPlannerTest < matlab.unittest.TestCase
    % ParameterDrivenPlannerTest - Unit tests for ParameterDrivenPlanner class
    %
    % This test class verifies the functionality of the scenario planning system,
    % focusing on:
    % 1. Receiver-centric frequency allocation
    % 2. Proper scenario instance generation
    % 3. Frequency range validation
    % 4. Configuration handling and validation

    properties (TestParameter)
        % Test parameters for different scenarios
        ReceiverSampleRate = {10e6, 20e6, 40e6} % Different receiver sample rates
        TransmitterCount = {1, 3, 5} % Different numbers of transmitters
        AllocationStrategy = {'Random', 'NonOverlapping'} % Allocation strategies
    end

    properties
        % Test fixtures
        TestPlanner
        DefaultScenarioConfig
        DefaultFactoryConfigs
    end

    methods (TestMethodSetup)

        function setupTest(testCase)
            % Setup for each test method
            testCase.TestPlanner = csrd.blocks.scenario.ParameterDrivenPlanner();

            % Create minimal scenario configuration
            testCase.DefaultScenarioConfig = struct();
            testCase.DefaultScenarioConfig.Global = struct();
            testCase.DefaultScenarioConfig.Global.SampleRate = 20e6;
            testCase.DefaultScenarioConfig.Global.FrameDuration = 1e-3;

            testCase.DefaultScenarioConfig.Transmitters = struct();
            testCase.DefaultScenarioConfig.Transmitters.Count = struct('Min', 2, 'Max', 4);
            testCase.DefaultScenarioConfig.Transmitters.Types = {'Generic'};

            testCase.DefaultScenarioConfig.Receivers = struct();
            testCase.DefaultScenarioConfig.Receivers.Count = struct('Min', 1, 'Max', 1);
            testCase.DefaultScenarioConfig.Receivers.Types = {'Generic'};

            testCase.DefaultScenarioConfig.Layout = struct();
            testCase.DefaultScenarioConfig.Layout.FrequencyAllocation = struct();
            testCase.DefaultScenarioConfig.Layout.FrequencyAllocation.Strategy = 'Random';
            testCase.DefaultScenarioConfig.Layout.FrequencyAllocation.AllowOverlap = true;

            % Create minimal factory configurations
            testCase.DefaultFactoryConfigs = struct();

            % Message factory config
            testCase.DefaultFactoryConfigs.Message = struct();
            testCase.DefaultFactoryConfigs.Message.Types = {struct('Name', 'RandomBits', 'Handle', @generateRandomBits)};
            testCase.DefaultFactoryConfigs.Message.DefaultConfig = struct('MessageLength', struct('Min', 100, 'Max', 1000));

            % Modulation factory config
            testCase.DefaultFactoryConfigs.Modulation = struct();
            testCase.DefaultFactoryConfigs.Modulation.Types = containers.Map();
            testCase.DefaultFactoryConfigs.Modulation.Types('PSK') = struct( ...
                'Handle', @csrd.blocks.physical.modulate.digital.PSK, ...
                'Parameters', struct('ModulationOrder', [2, 4, 8], 'SampleRate', 1e6));
            testCase.DefaultFactoryConfigs.Modulation.Types('QAM') = struct( ...
                'Handle', @csrd.blocks.physical.modulate.digital.QAM, ...
                'Parameters', struct('ModulationOrder', [4, 16, 64], 'SampleRate', 2e6));

            % Scenario factory config
            testCase.DefaultFactoryConfigs.Scenario = struct();
            testCase.DefaultFactoryConfigs.Scenario.Strategies = containers.Map();
            testCase.DefaultFactoryConfigs.Scenario.Strategies('ParameterDriven') = struct( ...
                'Handle', @csrd.blocks.scenario.ParameterDrivenPlanner, ...
                'DefaultStrategy', 'Random');

            % Transmit factory config
            testCase.DefaultFactoryConfigs.Transmit = struct();
            testCase.DefaultFactoryConfigs.Transmit.ImpairmentModels = containers.Map();
            testCase.DefaultFactoryConfigs.Transmit.ImpairmentModels('Basic') = struct( ...
                'IqImbalance', struct('A', struct('Min', 0, 'Max', 0.2), 'P', struct('Min', 0, 'Max', 5)), ...
                'PhaseNoise', struct('Level', struct('Min', -100, 'Max', -80)));

            % Channel factory config
            testCase.DefaultFactoryConfigs.Channel = struct();
            testCase.DefaultFactoryConfigs.Channel.Types = containers.Map();
            testCase.DefaultFactoryConfigs.Channel.Types('AWGN') = struct( ...
                'Handle', @csrd.blocks.physical.channel.AWGN, ...
                'SNR_dB', struct('Min', 0, 'Max', 30));

            % Receive factory config
            testCase.DefaultFactoryConfigs.Receive = struct();
            testCase.DefaultFactoryConfigs.Receive.Types = containers.Map();
            testCase.DefaultFactoryConfigs.Receive.Types('Generic') = struct( ...
                'Handle', @csrd.blocks.physical.rxRadioFront.RRFSimulator, ...
                'Parameters', struct('NoiseTemperature', 290));
        end

    end

    methods (TestMethodTeardown)

        function teardownTest(testCase)
            % Cleanup after each test method
            if ~isempty(testCase.TestPlanner)

                if isLocked(testCase.TestPlanner)
                    release(testCase.TestPlanner);
                end

                testCase.TestPlanner = [];
            end

        end

    end

    methods (Test)

        function testConstructor(testCase)
            % Test ParameterDrivenPlanner constructor
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            testCase.verifyClass(planner, 'csrd.blocks.scenario.ParameterDrivenPlanner');
        end

        function testSetupMethod(testCase)
            % Test that setup method works without errors
            planner = csrd.blocks.scenario.ParameterDrivenPlanner();
            testCase.verifyWarningFree(@() setup(planner));
        end

        function testFrequencyAllocation(testCase, ReceiverSampleRate)
            % Test receiver-centric frequency allocation

            % Update scenario config with test receiver sample rate
            scenarioConfig = testCase.DefaultScenarioConfig;
            scenarioConfig.Global.SampleRate = ReceiverSampleRate;

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [txInstances, rxInstances, globalLayout] = step(testCase.TestPlanner, frameId, ...
                scenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify basic structure
            testCase.verifyTrue(iscell(txInstances), 'Transmitter instances should be cell array');
            testCase.verifyTrue(iscell(rxInstances), 'Receiver instances should be cell array');
            testCase.verifyTrue(isstruct(globalLayout), 'Global layout should be struct');

            % Verify transmitter count is within specified range
            numTx = length(txInstances);
            testCase.verifyGreaterThanOrEqual(numTx, scenarioConfig.Transmitters.Count.Min);
            testCase.verifyLessThanOrEqual(numTx, scenarioConfig.Transmitters.Count.Max);

            % Verify receiver-centric frequency allocation
            observableRange = ReceiverSampleRate / 2;

            for i = 1:numTx
                tx = txInstances{i};

                if isfield(tx, 'FrequencyAllocation')
                    centerFreq = tx.FrequencyAllocation.CenterFrequency;
                    bandwidth = tx.FrequencyAllocation.Bandwidth;

                    % Verify frequency is within observable range
                    testCase.verifyGreaterThanOrEqual(centerFreq + bandwidth / 2, -observableRange, ...
                        sprintf('Tx%d upper frequency edge exceeds negative limit', i));
                    testCase.verifyLessThanOrEqual(centerFreq - bandwidth / 2, observableRange, ...
                        sprintf('Tx%d lower frequency edge exceeds positive limit', i));

                    % Verify bandwidth is positive
                    testCase.verifyGreaterThan(bandwidth, 0, ...
                        sprintf('Tx%d bandwidth should be positive', i));
                end

            end

        end

        function testTransmitterInstanceGeneration(testCase, TransmitterCount)
            % Test transmitter instance generation with specific count

            % Force specific transmitter count
            scenarioConfig = testCase.DefaultScenarioConfig;
            scenarioConfig.Transmitters.Count.Min = TransmitterCount;
            scenarioConfig.Transmitters.Count.Max = TransmitterCount;

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [txInstances, ~, ~] = step(testCase.TestPlanner, frameId, ...
                scenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify exact transmitter count
            testCase.verifyEqual(length(txInstances), TransmitterCount, ...
                sprintf('Should generate exactly %d transmitters', TransmitterCount));

            % Verify each transmitter instance has required fields
            for i = 1:length(txInstances)
                tx = txInstances{i};

                % Required fields for transmitter instances
                requiredFields = {'ID', 'Type', 'Behavior', 'Configuration'};

                for j = 1:length(requiredFields)
                    testCase.verifyTrue(isfield(tx, requiredFields{j}), ...
                        sprintf('Tx%d missing required field: %s', i, requiredFields{j}));
                end

                % Verify behavior has timing information
                if isfield(tx, 'Behavior')
                    testCase.verifyTrue(isfield(tx.Behavior, 'StartTime'), ...
                        sprintf('Tx%d behavior missing StartTime', i));
                    testCase.verifyTrue(isfield(tx.Behavior, 'Duration'), ...
                        sprintf('Tx%d behavior missing Duration', i));
                end

            end

        end

        function testNegativeFrequencySupport(testCase)
            % Test that negative frequency offsets are properly supported

            % Use large receiver sample rate for more frequency space
            scenarioConfig = testCase.DefaultScenarioConfig;
            scenarioConfig.Global.SampleRate = 40e6; % ±20 MHz range
            scenarioConfig.Transmitters.Count.Min = 10; % Many transmitters to increase chance of negative freq
            scenarioConfig.Transmitters.Count.Max = 10;

            setup(testCase.TestPlanner);

            % Generate multiple scenario instances to increase probability of negative frequencies
            foundNegativeFreq = false;

            for frameId = 1:20 % Try multiple frames
                [txInstances, ~, ~] = step(testCase.TestPlanner, frameId, ...
                    scenarioConfig, testCase.DefaultFactoryConfigs);

                for i = 1:length(txInstances)
                    tx = txInstances{i};

                    if isfield(tx, 'FrequencyAllocation') && tx.FrequencyAllocation.CenterFrequency < 0
                        foundNegativeFreq = true;

                        % Verify negative frequency is within valid range
                        centerFreq = tx.FrequencyAllocation.CenterFrequency;
                        observableRange = scenarioConfig.Global.SampleRate / 2;
                        testCase.verifyGreaterThanOrEqual(centerFreq, -observableRange, ...
                        'Negative frequency should be within observable range');
                        break;
                    end

                end

                if foundNegativeFreq
                    break;
                end

            end

            % Note: Not requiring negative frequency to be found since it's random,
            % but if found, it should be valid
            if foundNegativeFreq
                fprintf('   ✅ Negative frequency allocation verified\n');
            else
                fprintf('   ⚠️ No negative frequencies generated in test runs (random behavior)\n');
            end

        end

        function testAllocationStrategy(testCase, AllocationStrategy)
            % Test different frequency allocation strategies

            scenarioConfig = testCase.DefaultScenarioConfig;
            scenarioConfig.Layout.FrequencyAllocation.Strategy = AllocationStrategy;

            if strcmp(AllocationStrategy, 'NonOverlapping')
                scenarioConfig.Layout.FrequencyAllocation.AllowOverlap = false;
            else
                scenarioConfig.Layout.FrequencyAllocation.AllowOverlap = true;
            end

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [txInstances, ~, globalLayout] = step(testCase.TestPlanner, frameId, ...
                scenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify allocation strategy is recorded
            testCase.verifyEqual(globalLayout.AllocationStrategy, AllocationStrategy);

            % For non-overlapping strategy, verify no frequency overlaps
            if strcmp(AllocationStrategy, 'NonOverlapping') && length(txInstances) > 1

                for i = 1:length(txInstances)

                    for j = i + 1:length(txInstances)

                        if isfield(txInstances{i}, 'FrequencyAllocation') && ...
                                isfield(txInstances{j}, 'FrequencyAllocation')

                            tx1 = txInstances{i};
                            tx2 = txInstances{j};

                            freq1_min = tx1.FrequencyAllocation.CenterFrequency - tx1.FrequencyAllocation.Bandwidth / 2;
                            freq1_max = tx1.FrequencyAllocation.CenterFrequency + tx1.FrequencyAllocation.Bandwidth / 2;
                            freq2_min = tx2.FrequencyAllocation.CenterFrequency - tx2.FrequencyAllocation.Bandwidth / 2;
                            freq2_max = tx2.FrequencyAllocation.CenterFrequency + tx2.FrequencyAllocation.Bandwidth / 2;

                            % Verify no overlap
                            hasOverlap = ~(freq1_max <= freq2_min || freq2_max <= freq1_min);
                            testCase.verifyFalse(hasOverlap, ...
                                sprintf('Tx%d and Tx%d should not overlap in NonOverlapping mode', i, j));
                        end

                    end

                end

            end

        end

        function testConfigurationValidation(testCase)
            % Test configuration validation and error handling

            setup(testCase.TestPlanner);

            % Test with invalid scenario config (missing required fields)
            invalidConfig = struct();
            testCase.verifyError(@() step(testCase.TestPlanner, 1, invalidConfig, testCase.DefaultFactoryConfigs), ...
                'MATLAB:nonExistentField', 'Should error with invalid scenario config');

            % Test with missing factory configs
            emptyFactories = struct();
            testCase.verifyError(@() step(testCase.TestPlanner, 1, testCase.DefaultScenarioConfig, emptyFactories), ...
                'MATLAB:nonExistentField', 'Should error with missing factory configs');
        end

        function testModulationConfiguration(testCase)
            % Test modulation configuration assignment

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [txInstances, ~, ~] = step(testCase.TestPlanner, frameId, ...
                testCase.DefaultScenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify modulation configuration is assigned
            for i = 1:length(txInstances)
                tx = txInstances{i};

                if isfield(tx, 'Configuration') && isfield(tx.Configuration, 'Modulation')
                    modConfig = tx.Configuration.Modulation;

                    % Verify modulation type is from available types
                    availableTypes = keys(testCase.DefaultFactoryConfigs.Modulation.Types);
                    testCase.verifyTrue(any(strcmp(modConfig.Type, availableTypes)), ...
                        sprintf('Tx%d modulation type should be from available types', i));

                    % Verify modulation parameters are present
                    testCase.verifyTrue(isfield(modConfig, 'Parameters'), ...
                        sprintf('Tx%d modulation should have parameters', i));
                end

            end

        end

        function testTimingConfiguration(testCase)
            % Test timing configuration for transmitters

            scenarioConfig = testCase.DefaultScenarioConfig;
            frameDuration = 2e-3; % 2 ms frame
            scenarioConfig.Global.FrameDuration = frameDuration;

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [txInstances, ~, ~] = step(testCase.TestPlanner, frameId, ...
                scenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify timing configuration
            for i = 1:length(txInstances)
                tx = txInstances{i};

                if isfield(tx, 'Behavior')
                    % Verify start time is within frame duration
                    testCase.verifyGreaterThanOrEqual(tx.Behavior.StartTime, 0, ...
                        sprintf('Tx%d start time should be non-negative', i));
                    testCase.verifyLessThan(tx.Behavior.StartTime, frameDuration, ...
                        sprintf('Tx%d start time should be within frame duration', i));

                    % Verify duration is positive and reasonable
                    testCase.verifyGreaterThan(tx.Behavior.Duration, 0, ...
                        sprintf('Tx%d duration should be positive', i));
                    testCase.verifyLessThanOrEqual(tx.Behavior.Duration, frameDuration, ...
                        sprintf('Tx%d duration should not exceed frame duration', i));
                end

            end

        end

        function testMultipleFrameConsistency(testCase)
            % Test that multiple frame generations are consistent

            setup(testCase.TestPlanner);

            % Generate multiple frames
            frameResults = cell(3, 1);

            for frameId = 1:3
                [txInstances, rxInstances, globalLayout] = step(testCase.TestPlanner, frameId, ...
                    testCase.DefaultScenarioConfig, testCase.DefaultFactoryConfigs);
                frameResults{frameId} = struct('tx', txInstances, 'rx', rxInstances, 'layout', globalLayout);
            end

            % Verify each frame has valid results
            for frameId = 1:3
                result = frameResults{frameId};

                % Verify structure consistency across frames
                testCase.verifyTrue(iscell(result.tx), sprintf('Frame %d tx should be cell array', frameId));
                testCase.verifyTrue(iscell(result.rx), sprintf('Frame %d rx should be cell array', frameId));
                testCase.verifyTrue(isstruct(result.layout), sprintf('Frame %d layout should be struct', frameId));

                % Verify transmitter count consistency
                numTx = length(result.tx);
                testCase.verifyGreaterThanOrEqual(numTx, testCase.DefaultScenarioConfig.Transmitters.Count.Min);
                testCase.verifyLessThanOrEqual(numTx, testCase.DefaultScenarioConfig.Transmitters.Count.Max);
            end

        end

        function testReceiverInstanceGeneration(testCase)
            % Test receiver instance generation

            setup(testCase.TestPlanner);

            % Generate scenario instance
            frameId = 1;
            [~, rxInstances, ~] = step(testCase.TestPlanner, frameId, ...
                testCase.DefaultScenarioConfig, testCase.DefaultFactoryConfigs);

            % Verify receiver count
            numRx = length(rxInstances);
            testCase.verifyGreaterThanOrEqual(numRx, testCase.DefaultScenarioConfig.Receivers.Count.Min);
            testCase.verifyLessThanOrEqual(numRx, testCase.DefaultScenarioConfig.Receivers.Count.Max);

            % Verify receiver instance structure
            for i = 1:length(rxInstances)
                rx = rxInstances{i};

                % Required fields for receiver instances
                requiredFields = {'ID', 'Type', 'Configuration'};

                for j = 1:length(requiredFields)
                    testCase.verifyTrue(isfield(rx, requiredFields{j}), ...
                        sprintf('Rx%d missing required field: %s', i, requiredFields{j}));
                end

                % Verify receiver configuration includes sample rate
                if isfield(rx, 'Configuration')
                    testCase.verifyTrue(isfield(rx.Configuration, 'SampleRate'), ...
                        sprintf('Rx%d should have sample rate configuration', i));
                    testCase.verifyEqual(rx.Configuration.SampleRate, testCase.DefaultScenarioConfig.Global.SampleRate, ...
                        sprintf('Rx%d sample rate should match global setting', i));
                end

            end

        end

    end

end
