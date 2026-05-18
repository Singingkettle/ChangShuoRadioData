classdef ModulationFactoryNoExecutionFallbackTest < matlab.unittest.TestCase
    % ModulationFactoryNoExecutionFallbackTest - No execution metadata backfill.
    % 中文说明：调制器必须显式输出执行带宽、采样率和天线数。

    methods (TestMethodSetup)
        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            logCfg = struct('Level', 'ERROR', 'SaveToFile', false, ...
                'DisplayInConsole', false);
            csrd.runtime.logger.GlobalLogManager.initialize(logCfg);
        end
    end

    methods (TestMethodTeardown)
        function teardown(~)
            csrd.runtime.logger.GlobalLogManager.reset();
        end
    end

    methods (Test)
        function missingSampleRateFailsFast(testCase)
            factory = localFactory('MissingSampleRate', ...
                'csrd.test_support.BadModulatorMissingSampleRate');
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() localStep(factory), ...
                'CSRD:Modulation:MissingSampleRate');
        end

        function missingBandwidthFailsFast(testCase)
            factory = localFactory('MissingBandwidth', ...
                'csrd.test_support.BadModulatorMissingBandwidth');
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() localStep(factory), ...
                'CSRD:Modulation:MissingBandwidth');
        end

        function antennasBySamplesOutputIsNormalized(testCase)
            factory = localFactory('AntennasBySamples', ...
                'csrd.test_support.BadModulatorAntennasBySamples');
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            out = localStep(factory);

            testCase.verifySize(out.Signal, [8, 2]);
            testCase.verifyEqual(out.SamplePerFrame, 8);
            testCase.verifyEqual(out.TimeDuration, 8 / out.SampleRate, ...
                'AbsTol', eps);
        end

        function wrongAntennaColumnsFailsFast(testCase)
            factory = localFactory('WrongAntennaColumns', ...
                'csrd.test_support.BadModulatorWrongAntennaColumns');
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() localStep(factory), ...
                'CSRD:Modulation:SignalAntennaColumnMismatch');
        end
    end
end

function factory = localFactory(typeId, handleName)
cfg = struct();
cfg.digital.(typeId).handle = handleName;
factory = csrd.factories.ModulationFactory('Config', cfg);
setup(factory);
end

function out = localStep(factory)
segMod = struct('TypeID', 'MissingSampleRate', ...
    'NumTransmitAntennas', 2, 'Order', 4, 'SymbolRate', 100e3, ...
    'SamplePerSymbol', 4, 'SamplesPerSymbol', 4, 'BitsPerSymbol', 2);
keys = fieldnames(factory.Config.digital);
segMod.TypeID = keys{1};
placement = struct('TargetBandwidth', 10e3);
out = step(factory, ones(32, 1), 1, "Tx1", 1, segMod, placement);
end
