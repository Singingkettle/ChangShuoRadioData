classdef SdrNoiseFigureWiredTest < matlab.unittest.TestCase
    % SdrNoiseFigureWiredTest - guards the round-13 fix (H10): the SDR profile
    % noise figure (carried on RxInfo.NoiseFigure from Sdr.NoiseFigureDb) must
    % drive the realized thermal-noise figure, NOT a fresh factory random draw.
    % Otherwise the realized thermal floor is a profile-independent [10,20] dB
    % draw that disagrees with the annotated Sdr.NoiseFigureDb (biasing the
    % measured received-SNR GT) and is identical across SDR models.

    methods (Test)
        function profileNoiseFigureOverridesRandomDraw(testCase)
            cfg = localHardwareConfig();
            cfg.Hardware.ThermalNoise = struct('NoiseFigure', [10, 20]);
            factory = csrd.factories.ReceiveFactory('Config', cfg);

            % RxInfo carries the SDR profile NF (6 dB), well outside the [10,20]
            % factory range so the source is unambiguous.
            rxInfo = struct('NumAntennas', 1, 'SampleRate', 20e6, 'ID', 'Rx1', ...
                'EntityID', 'Rx1', 'NoiseFigure', 6);
            recvScenario = struct('ID', 'Rx1', 'EntityID', 'Rx1', 'Type', 'Hardware');
            inputSig = struct('Signal', complex(zeros(64, 1)), 'SampleRate', 20e6, ...
                'ID', 1, 'TxId', 'Tx1', 'BurstId', 'Tx1.B0');

            out = step(factory, inputSig, 1, rxInfo, recvScenario);

            testCase.verifyEqual(out.RxImpairments.ThermalNoiseConfig.NoiseFigure, 6, ...
                'AbsTol', 1e-9, ...
                'Realized NF must equal the SDR profile NoiseFigure, not a [10,20] draw.');
        end

        function fallsBackToFactoryRangeWhenNoProfileNf(testCase)
            cfg = localHardwareConfig();
            cfg.Hardware.ThermalNoise = struct('NoiseFigure', [10, 20]);
            factory = csrd.factories.ReceiveFactory('Config', cfg);

            % No NoiseFigure on RxInfo -> the factory range is used (back-compat
            % for non-SDR-profile receivers).
            rxInfo = struct('NumAntennas', 1, 'SampleRate', 20e6, 'ID', 'Rx1', ...
                'EntityID', 'Rx1');
            recvScenario = struct('ID', 'Rx1', 'EntityID', 'Rx1', 'Type', 'Hardware');
            inputSig = struct('Signal', complex(zeros(64, 1)), 'SampleRate', 20e6, ...
                'ID', 1, 'TxId', 'Tx1', 'BurstId', 'Tx1.B0');

            out = step(factory, inputSig, 1, rxInfo, recvScenario);
            nf = out.RxImpairments.ThermalNoiseConfig.NoiseFigure;

            testCase.verifyGreaterThanOrEqual(nf, 10);
            testCase.verifyLessThanOrEqual(nf, 20);
        end
    end
end

function cfg = localHardwareConfig()
cfg = struct();
cfg.Hardware = struct();
cfg.Hardware.handle = 'csrd.blocks.physical.rxRadioFront.RRFSimulator';
cfg.Hardware.DCOffset = [-60, -40];
cfg.Hardware.IQImbalance = struct('Amplitude', [-1, 1], 'Phase', [-3, 3]);
cfg.Hardware.Nonlinearity = struct( ...
    'Methods', {{'Cubic polynomial'}}, ...
    'ReferenceImpedance', 50, ...
    'CubicPolynomial', struct( ...
        'LinearGain', [10, 12], ...
        'TOISpecifications', {{'IIP3'}}, ...
        'IIP3', [25, 35], 'OIP3', [25, 35], 'IP1dB', [25, 35], ...
        'OP1dB', [25, 35], 'IPsat', [25, 35], 'OPsat', [25, 35], ...
        'AMPMConversion', [-1, 1], 'PowerLowerLimit', [-30, -20], ...
        'PowerUpperLimit', [10, 20]));
end
