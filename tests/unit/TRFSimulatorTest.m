classdef TRFSimulatorTest < matlab.unittest.TestCase
    % TRFSimulatorTest - Unit tests for TRFSimulator class
    %
    % This test class verifies the functionality of the new complex exponential
    % frequency translation system in TRFSimulator, ensuring:
    % 1. Proper frequency translation using complex exponentials
    % 2. Correct sampling rate conversion
    % 3. RF impairments are applied correctly
    % 4. Output format compliance

    properties (TestParameter)
        % Test parameters for different scenarios
        TargetFrequency = {0, 1e6, -2e6, 5e6} % Various frequency offsets including negative
        BasebandSampleRate = {1e6, 2e6, 5e6} % Different baseband rates
        TargetSampleRate = {10e6, 20e6} % Different target rates
    end

    properties
        % Test fixtures
        TestTRF
        DefaultConfig
    end

    methods (TestMethodSetup)

        function setupTest(testCase)
            % Setup for each test method
            testCase.DefaultConfig = struct();
            testCase.DefaultConfig.TargetSampleRate = 20e6;
            testCase.DefaultConfig.SampleRate = 1e6;
            testCase.DefaultConfig.CarrierFrequency = 0;
            testCase.DefaultConfig.IqImbalanceConfig = struct('A', 0, 'P', 0);
            testCase.DefaultConfig.PhaseNoiseConfig = struct('Level', -100, 'FrequencyOffset', 10e3);
            testCase.DefaultConfig.MemoryLessNonlinearityConfig = struct( ...
                'Method', 'Cubic polynomial', ...
                'LinearGain', 0, ...
                'TOISpecification', 'IIP3', ...
                'IIP3', 30, ...
                'AMPMConversion', 0, ...
                'PowerLowerLimit', -50, ...
                'PowerUpperLimit', 10, ...
                'ReferenceImpedance', 50);
        end

    end

    methods (TestMethodTeardown)

        function teardownTest(testCase)
            % Cleanup after each test method
            if ~isempty(testCase.TestTRF)

                if isLocked(testCase.TestTRF)
                    release(testCase.TestTRF);
                end

                testCase.TestTRF = [];
            end

        end

    end

    methods (Test)

        function testConstructor(testCase)
            % Test TRFSimulator constructor
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator();
            testCase.verifyClass(trf, 'csrd.blocks.physical.txRadioFront.TRFSimulator');
            testCase.verifyEqual(trf.TargetSampleRate, 20e6);
            testCase.verifyEqual(trf.SampleRate, 20e6);
        end

        function testFrequencyTranslation(testCase, TargetFrequency)
            % Test frequency translation using complex exponentials

            % Create test signal
            signalLength = 1024;
            basebandSampleRate = 1e6;
            targetSampleRate = 20e6;

            t = (0:signalLength - 1)' / basebandSampleRate;
            testFreq = 100e3; % 100 kHz test tone
            baseband_signal = exp(1j * 2 * pi * testFreq * t);

            % Create TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', targetSampleRate, ...
                'SampleRate', basebandSampleRate, ...
                'CarrierFrequency', TargetFrequency, ...
                'IqImbalanceConfig', testCase.DefaultConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', testCase.DefaultConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', testCase.DefaultConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = TargetFrequency;

            % Apply frequency translation
            y_output = step(trf, x_input);

            % Verify output structure
            testCase.verifyTrue(isfield(y_output, 'data'));
            testCase.verifyTrue(isfield(y_output, 'SampleRate'));
            testCase.verifyTrue(isfield(y_output, 'CarrierFrequency'));
            testCase.verifyTrue(isfield(y_output, 'SDRMode'));

            % Verify sample rate
            testCase.verifyEqual(y_output.SampleRate, targetSampleRate);

            % Verify carrier frequency
            testCase.verifyEqual(y_output.CarrierFrequency, TargetFrequency);

            % Verify SDR mode
            testCase.verifyEqual(y_output.SDRMode, "Complex Exponential Frequency Translation");

            % Verify frequency translation by spectral analysis
            if TargetFrequency ~= 0
                Y_fft = fftshift(fft(y_output.data, 2048));
                freqs = (-1024:1023) * targetSampleRate / 2048;
                [~, peakIdx] = max(abs(Y_fft));
                peakFreq = freqs(peakIdx);
                expectedFreq = TargetFrequency + testFreq;

                % Allow for some frequency bin tolerance
                freqTolerance = targetSampleRate / 2048 * 3; % 3 bins
                testCase.verifyLessThan(abs(peakFreq - expectedFreq), freqTolerance, ...
                    sprintf('Frequency translation failed: expected %.2f MHz, got %.2f MHz', ...
                    expectedFreq / 1e6, peakFreq / 1e6));
            end

        end

        function testSampleRateConversion(testCase, BasebandSampleRate, TargetSampleRate)
            % Test sample rate conversion functionality

            signalLength = 512;
            t = (0:signalLength - 1)' / BasebandSampleRate;
            baseband_signal = exp(1j * 2 * pi * 50e3 * t); % 50 kHz tone

            % Create TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', TargetSampleRate, ...
                'SampleRate', BasebandSampleRate, ...
                'IqImbalanceConfig', testCase.DefaultConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', testCase.DefaultConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', testCase.DefaultConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = 0;

            % Process signal
            y_output = step(trf, x_input);

            % Verify output sample rate
            testCase.verifyEqual(y_output.SampleRate, TargetSampleRate);

            % Verify output length is approximately correct
            expectedLength = round(signalLength * TargetSampleRate / BasebandSampleRate);
            actualLength = length(y_output.data);

            % Allow for some tolerance in length due to resampling
            lengthTolerance = max(10, round(expectedLength * 0.1)); % 10 % or min 10 samples
            testCase.verifyLessThan(abs(actualLength - expectedLength), lengthTolerance, ...
                sprintf('Sample rate conversion failed: expected ~%d samples, got %d', ...
                expectedLength, actualLength));
        end

        function testMultipleAntennas(testCase)
            % Test processing with multiple transmit antennas

            numAntennas = 2;
            signalLength = 256;
            basebandSampleRate = 1e6;
            targetSampleRate = 10e6;

            t = (0:signalLength - 1)' / basebandSampleRate;
            baseband_signal = repmat(exp(1j * 2 * pi * 100e3 * t), 1, numAntennas);

            % Create TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', targetSampleRate, ...
                'SampleRate', basebandSampleRate, ...
                'IqImbalanceConfig', testCase.DefaultConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', testCase.DefaultConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', testCase.DefaultConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = numAntennas;
            x_input.CarrierFrequency = 1e6;

            % Process signal
            y_output = step(trf, x_input);

            % Verify output dimensions
            testCase.verifyEqual(size(y_output.data, 2), numAntennas, ...
            'Output should maintain number of antennas');

            % Verify each antenna column is processed independently
            for antIdx = 1:numAntennas
                testCase.verifyGreaterThan(var(y_output.data(:, antIdx)), 0, ...
                    sprintf('Antenna %d output should have non-zero variance', antIdx));
            end

        end

        function testRFImpairments(testCase)
            % Test that RF impairments are applied

            signalLength = 1024;
            basebandSampleRate = 1e6;

            t = (0:signalLength - 1)' / basebandSampleRate;
            baseband_signal = ones(signalLength, 1); % Constant signal to see impairments

            % Create TRFSimulator with noticeable impairments
            impairedConfig = testCase.DefaultConfig;
            impairedConfig.IqImbalanceConfig = struct('A', 0.2, 'P', 5); % Significant IQ imbalance

            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', 20e6, ...
                'SampleRate', basebandSampleRate, ...
                'IqImbalanceConfig', impairedConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', impairedConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', impairedConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = 0;

            % Process signal
            y_output = step(trf, x_input);

            % Verify impairments are applied (signal should be different from input)
            % Since we applied resampling and impairments, output should be notably different
            testCase.verifyNotEqual(length(y_output.data), length(baseband_signal), ...
            'Output length should change due to resampling');

            % Check that IQ imbalance config is preserved in output
            testCase.verifyEqual(y_output.IqImbalanceConfig.A, 0.2);
            testCase.verifyEqual(y_output.IqImbalanceConfig.P, 5);
        end

        function testNegativeFrequencyOffset(testCase)
            % Test that negative frequency offsets work correctly

            signalLength = 512;
            basebandSampleRate = 2e6;
            targetSampleRate = 20e6;
            negativeOffset = -3e6; % -3 MHz offset

            t = (0:signalLength - 1)' / basebandSampleRate;
            testFreq = 200e3; % 200 kHz test tone
            baseband_signal = exp(1j * 2 * pi * testFreq * t);

            % Create TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', targetSampleRate, ...
                'SampleRate', basebandSampleRate, ...
                'CarrierFrequency', negativeOffset, ...
                'IqImbalanceConfig', testCase.DefaultConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', testCase.DefaultConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', testCase.DefaultConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = negativeOffset;

            % Process signal
            y_output = step(trf, x_input);

            % Verify negative frequency is handled correctly
            testCase.verifyEqual(y_output.CarrierFrequency, negativeOffset);

            % Verify spectral content is shifted to negative frequencies
            Y_fft = fftshift(fft(y_output.data, 2048));
            freqs = (-1024:1023) * targetSampleRate / 2048;
            [~, peakIdx] = max(abs(Y_fft));
            peakFreq = freqs(peakIdx);
            expectedFreq = negativeOffset + testFreq;

            % Verify peak is in the negative frequency range
            testCase.verifyLessThan(peakFreq, 0, ...
            'Peak frequency should be negative for negative offset');

            % Verify frequency translation accuracy
            freqTolerance = targetSampleRate / 2048 * 3;
            testCase.verifyLessThan(abs(peakFreq - expectedFreq), freqTolerance, ...
                sprintf('Negative frequency translation failed: expected %.2f MHz, got %.2f MHz', ...
                expectedFreq / 1e6, peakFreq / 1e6));
        end

        function testOutputFieldsConsistency(testCase)
            % Test that all expected output fields are present and consistent

            signalLength = 128;
            baseband_signal = randn(signalLength, 1) + 1j * randn(signalLength, 1);

            % Create TRFSimulator
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', 10e6, ...
                'SampleRate', 1e6, ...
                'IqImbalanceConfig', testCase.DefaultConfig.IqImbalanceConfig, ...
                'PhaseNoiseConfig', testCase.DefaultConfig.PhaseNoiseConfig, ...
                'MemoryLessNonlinearityConfig', testCase.DefaultConfig.MemoryLessNonlinearityConfig);

            setup(trf);
            testCase.TestTRF = trf;

            % Prepare input
            x_input = struct();
            x_input.data = baseband_signal;
            x_input.NumTransmitAntennas = 1;
            x_input.CarrierFrequency = 2e6;
            x_input.TestField = 'test_value'; % Additional field to verify passthrough

            % Process signal
            y_output = step(trf, x_input);

            % Verify essential output fields
            requiredFields = {'data', 'SampleRate', 'SamplePerFrame', 'TimeDuration', ...
                                  'CarrierFrequency', 'SDRMode', 'IqImbalanceConfig', ...
                                  'MemoryLessNonlinearityConfig', 'PhaseNoiseConfig'};

            for i = 1:length(requiredFields)
                testCase.verifyTrue(isfield(y_output, requiredFields{i}), ...
                    sprintf('Output missing required field: %s', requiredFields{i}));
            end

            % Verify field consistency
            testCase.verifyEqual(y_output.SamplePerFrame, size(y_output.data, 1));
            testCase.verifyEqual(y_output.TimeDuration, y_output.SamplePerFrame / y_output.SampleRate);

            % Verify input fields are preserved
            testCase.verifyEqual(y_output.TestField, 'test_value');
        end

    end

end
