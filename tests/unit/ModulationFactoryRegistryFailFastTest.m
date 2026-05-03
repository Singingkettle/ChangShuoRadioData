classdef ModulationFactoryRegistryFailFastTest < matlab.unittest.TestCase
    % ModulationFactoryRegistryFailFastTest - Bad modulator registry is fatal.

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
        function missingRegistryThrowsDuringSetup(testCase)
            factory = csrd.factories.ModulationFactory('Config', struct());
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() setup(factory), ...
                'CSRD:ModulationFactory:MissingRegistry');
        end

        function unknownTypeThrowsInsteadOfErrorStruct(testCase)
            cfg.digital.PSK.handle = ...
                'csrd.blocks.physical.modulate.digital.PSK.PSK';
            factory = csrd.factories.ModulationFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            segMod = struct('TypeID', 'UnknownType', 'Order', 4, ...
                'SymbolRate', 100e3, 'SamplePerSymbol', 4, ...
                'SamplesPerSymbol', 4, 'NumTransmitAntennas', 1);
            placement = struct('TargetBandwidth', 100e3);

            testCase.verifyError(@() step(factory, ones(16, 1), 1, ...
                "Tx1", 1, segMod, placement), ...
                'CSRD:ModulationFactory:ModulatorTypeNotFound');
        end

        function missingSymbolRateThrowsBeforeBandwidthInference(testCase)
            cfg.digital.PSK.handle = ...
                'csrd.blocks.physical.modulate.digital.PSK.PSK';
            factory = csrd.factories.ModulationFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            segMod = struct('TypeID', 'PSK', 'Order', 4, ...
                'SamplePerSymbol', 4, 'SamplesPerSymbol', 4, ...
                'NumTransmitAntennas', 1);
            placement = struct('TargetBandwidth', 100e3);

            testCase.verifyError(@() step(factory, ones(16, 1), 1, ...
                "Tx1", 1, segMod, placement), ...
                'CSRD:Modulation:MissingSymbolRate');
        end
    end
end
