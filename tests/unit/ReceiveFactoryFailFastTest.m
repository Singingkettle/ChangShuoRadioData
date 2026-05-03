classdef ReceiveFactoryFailFastTest < matlab.unittest.TestCase
    % ReceiveFactoryFailFastTest - ReceiveFactory must throw, not emit Error structs.

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
        function missingReceiverTypeThrows(testCase)
            factory = csrd.factories.ReceiveFactory('Config', struct());
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() step(factory, localInput(), 1, ...
                localRxInfo(), struct('Type', 'MissingRx', 'ID', 'Rx1')), ...
                'CSRD:ReceiveFactory:ReceiverTypeNotFound');
        end

        function missingReceiverHandleThrows(testCase)
            cfg = struct();
            cfg.Simulation = struct();
            factory = csrd.factories.ReceiveFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() step(factory, localInput(), 1, ...
                localRxInfo(), struct('Type', 'Simulation', 'ID', 'Rx1')), ...
                'CSRD:ReceiveFactory:ReceiverTypeHandleNotFound');
        end
    end
end

function s = localInput()
s = struct('Signal', complex(zeros(16, 1)));
end

function rx = localRxInfo()
rx = struct('ID', 'Rx1', 'SampleRate', 1e6);
end
