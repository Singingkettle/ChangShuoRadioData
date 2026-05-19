classdef TransmitFactoryRequiresReceiverSampleRateTest < matlab.unittest.TestCase
    % TransmitFactoryRequiresReceiverSampleRateTest - TRF target rate is Rx-owned.

    methods (TestMethodSetup)
        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
                'Level', 'ERROR', 'SaveToFile', false, ...
                'DisplayInConsole', false));
        end
    end

    methods (TestMethodTeardown)
        function teardown(~)
            csrd.runtime.logger.GlobalLogManager.reset();
        end
    end

    methods (Test)
        function missingReceiverSampleRateFailsFast(testCase)
            cfg = localTxFactoryConfig();
            factory = csrd.factories.TransmitFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() step(factory, localInput(), 1, ...
                localTxInfo(), struct('Type', 'Simulation', 'ID', 'Tx1')), ...
                'CSRD:TransmitFactory:MissingReceiverSampleRate');
        end

        function explicitReceiverSampleRatePassesTargetRate(testCase)
            cfg = localTxFactoryConfig();
            factory = csrd.factories.TransmitFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            txScenario = struct('Type', 'Simulation', 'ID', 'Tx1', ...
                'Spectrum', struct('ReceiverSampleRate', 2e6));
            out = step(factory, localInput(), 1, localTxInfo(), txScenario);

            testCase.verifyEqual(out.SampleRate, 2e6);
        end

        function antennaColumnMismatchFailsFast(testCase)
            cfg = localTxFactoryConfig();
            factory = csrd.factories.TransmitFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            txScenario = struct('Type', 'Simulation', 'ID', 'Tx1', ...
                'Spectrum', struct('ReceiverSampleRate', 2e6));
            input = localInput();
            input.NumTransmitAntennas = 2;
            input.Signal = complex(ones(64, 3));

            testCase.verifyError(@() step(factory, input, 1, ...
                localTxInfo(), txScenario), ...
                'CSRD:TransmitFactory:AntennaColumnMismatch');
        end
    end
end

function s = localInput()
s = struct();
s.Signal = complex(0.01 * ones(64, 1));
s.SampleRate = 1e6;
s.FrequencyOffset = 0;
s.Bandwidth = 100e3;
end

function tx = localTxInfo()
tx = struct('ID', 'Tx1', 'Power', 0);
end

function cfg = localTxFactoryConfig()
cfg.Simulation.handle = 'csrd.blocks.physical.txRadioFront.TRFSimulator';
cfg.Simulation.IQImbalance = struct('Amplitude', [0, 0], 'Phase', [0, 0]);
cfg.Simulation.PhaseNoise = struct('Level', [-100, -100], ...
    'FrequencyOffsets', 10e3);
cfg.Simulation.Nonlinearity = struct();
cfg.Simulation.Nonlinearity.Methods = {'Cubic polynomial'};
cfg.Simulation.Nonlinearity.ReferenceImpedance = 50;
cfg.Simulation.Nonlinearity.CubicPolynomial = struct( ...
    'LinearGain', [0, 0], ...
    'TOISpecifications', {{'IIP3'}}, ...
    'IIP3', [30, 30], ...
    'OIP3', [30, 30], ...
    'IP1dB', [30, 30], ...
    'OP1dB', [30, 30], ...
    'IPsat', [30, 30], ...
    'OPsat', [30, 30], ...
    'AMPMConversion', [0, 0], ...
    'PowerLowerLimit', -50, ...
    'PowerUpperLimit', 10);
end
