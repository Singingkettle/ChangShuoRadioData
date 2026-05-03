classdef OFDMMimoModeTest < matlab.unittest.TestCase
    % OFDMMimoModeTest - Verify explicit OFDM multi-antenna abstractions.
    % 中文说明：验证 OFDM 多天线模式显式生效，避免把 OSTBC 与独立空间流混用。

    methods (Test)
        function spatialMultiplexingKeepsRequestedStreams(testCase)
            % spatialMultiplexingKeepsRequestedStreams - Use OFDM stream dimension directly.
            % 中文说明：SpatialMultiplexing 应直接输出请求的发射流数量。
            modulator = localOFDM('SpatialMultiplexing', 4);
            cleanup = onCleanup(@() release(modulator)); %#ok<NASGU>

            out = step(modulator, struct('data', randi([0 1], 40000, 1)));

            testCase.verifyEqual(size(out.Signal, 2), 4);
            testCase.verifyEqual(out.NumTransmitAntennas, 4);
            testCase.verifyEqual(out.ModulatorConfig.mimo.Mode, 'SpatialMultiplexing');
        end

        function ostbcKeepsRequestedAntennaColumns(testCase)
            % ostbcKeepsRequestedAntennaColumns - Preserve historical OSTBC path.
            % 中文说明：OSTBC 模式保留历史空时分集路径，并输出对应天线列。
            modulator = localOFDM('OSTBC', 2);
            cleanup = onCleanup(@() release(modulator)); %#ok<NASGU>

            out = step(modulator, struct('data', randi([0 1], 40000, 1)));

            testCase.verifyEqual(size(out.Signal, 2), 2);
            testCase.verifyEqual(out.NumTransmitAntennas, 2);
            testCase.verifyEqual(out.ModulatorConfig.mimo.Mode, 'OSTBC');
        end

        function invalidModeFailsFast(testCase)
            % invalidModeFailsFast - Reject unknown OFDM spatial modes.
            % 中文说明：未知 OFDM 多天线模式必须 fail-fast，不能静默回退。
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
    % 中文说明：构造确定性的 OFDM 调制器测试夹具。
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
