classdef OFDMMimoModeTest < matlab.unittest.TestCase
    % OFDMMimoModeTest - Verify explicit OFDM multi-antenna abstractions.

    methods (Test)
        function spatialMultiplexingKeepsRequestedStreams(testCase)
            % spatialMultiplexingKeepsRequestedStreams - Use OFDM stream dimension directly.
            modulator = localOFDM('SpatialMultiplexing', 4);
            cleanup = onCleanup(@() release(modulator)); %#ok<NASGU>

            out = step(modulator, struct('data', randi([0 1], 40000, 1)));

            testCase.verifyEqual(size(out.Signal, 2), 4);
            testCase.verifyEqual(out.NumTransmitAntennas, 4);
            testCase.verifyEqual(out.ModulatorConfig.mimo.Mode, 'SpatialMultiplexing');
        end

        function ostbcKeepsRequestedAntennaColumns(testCase)
            % ostbcKeepsRequestedAntennaColumns - Preserve historical OSTBC path.
            modulator = localOFDM('OSTBC', 2);
            cleanup = onCleanup(@() release(modulator)); %#ok<NASGU>

            out = step(modulator, struct('data', randi([0 1], 40000, 1)));

            testCase.verifyEqual(size(out.Signal, 2), 2);
            testCase.verifyEqual(out.NumTransmitAntennas, 2);
            testCase.verifyEqual(out.ModulatorConfig.mimo.Mode, 'OSTBC');
        end

        function invalidModeFailsFast(testCase)
            % invalidModeFailsFast - Reject unknown OFDM spatial modes.
            modulator = localOFDM('BadMode', 2);
            cleanup = onCleanup(@() release(modulator)); %#ok<NASGU>

            testCase.verifyError(@() step(modulator, ...
                struct('data', randi([0 1], 40000, 1))), ...
                'CSRD:Modulation:InvalidOFDMMimoMode');
        end
    end
end

function modulator = localOFDM(mode, numTx)
    % localOFDM - Build a deterministic OFDM modulator fixture.
    cfg = struct();
    cfg.base.mode = "qam";
    cfg.ofdm.FFTLength = 128;
    cfg.ofdm.NumGuardBandCarriers = [6; 5];
    cfg.ofdm.InsertDCNull = true;
    cfg.ofdm.CyclicPrefixLength = 16;
    cfg.ofdm.Subcarrierspacing = 15e3;
    cfg.ofdm.Windowing = false;
    cfg.mimo.Mode = mode;
    modulator = csrd.blocks.physical.modulate.digital.OFDM.OFDM( ...
        'ModulatorOrder', 16, ...
        'NumTransmitAntennas', numTx, ...
        'ModulatorConfig', cfg);
end
