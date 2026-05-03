classdef SignalStructContractTest < matlab.unittest.TestCase
    % SignalStructContractTest
    %
    % Phase 1 / C1: validate the boundary contracts enforced by
    % csrd.pipeline.contract.assertSignalStructContract.
    %
    % Boundaries (per docs/audits/phases/phase-1-dataflow.md §3.6):
    %   modulator-output : Signal, SampleRate, ID, TxId, BurstId, ModulatorConfig
    %   trf-output       : Signal, SampleRate, ID, TxId, BurstId, CarrierFrequency
    %   channel-input    : Signal, SampleRate, ID, TxId, BurstId, CarrierFrequency
    %   channel-output   : Signal, SampleRate, ID, TxId, BurstId, PathLoss, ChannelModel
    %   receive-output   : Signal, SampleRate, RxImpairments

    methods (Test)

        function modulatorOutputAcceptsCompleteStruct(testCase)
            s = struct('Signal', complex(ones(8,1), 0), 'SampleRate', 1e6, ...
                'ID', 1, 'TxId', 'Tx1', 'BurstId', 'Tx1.B0', ...
                'ModulatorConfig', struct('ModulationType', 'QPSK'));
            testCase.verifyWarningFree(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'modulator-output'));
        end

        function modulatorOutputRejectsMissingFields(testCase)
            s = struct('Signal', complex(ones(4,1), 0), 'SampleRate', 1e6);
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'modulator-output'), ...
                'CSRD:Contract:SignalStructViolation');
        end

        function trfOutputRequiresCarrierFrequency(testCase)
            s = struct('Signal', [], 'SampleRate', 20e6, ...
                'ID', 1, 'TxId', 'Tx1', 'BurstId', 'Tx1.B0');
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'trf-output'), ...
                'CSRD:Contract:SignalStructViolation');

            s.CarrierFrequency = 2.4e9;
            testCase.verifyWarningFree(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'trf-output'));
        end

        function channelInputAcceptsCompleteStruct(testCase)
            s = struct('Signal', complex(ones(4,1), 1), 'SampleRate', 20e6, ...
                'ID', 7, 'TxId', 'Tx7', 'BurstId', 'Tx7.B2', ...
                'CarrierFrequency', 2.4e9);
            testCase.verifyWarningFree(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'channel-input'));
        end

        function channelOutputRequiresPathLossAndChannelModel(testCase)
            s = struct('Signal', complex(ones(2,1)), 'SampleRate', 20e6, ...
                'ID', 7, 'TxId', 'Tx7', 'BurstId', 'Tx7.B2');
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'channel-output'), ...
                'CSRD:Contract:SignalStructViolation');

            s.PathLoss = 50;
            s.ChannelModel = 'AWGN';
            testCase.verifyWarningFree(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'channel-output'));
        end

        function receiveOutputRequiresRxImpairments(testCase)
            s = struct('Signal', [], 'SampleRate', 20e6);
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'receive-output'), ...
                'CSRD:Contract:SignalStructViolation');

            s.RxImpairments = struct('Type', 'Hardware', 'DCOffset', -50);
            testCase.verifyWarningFree(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'receive-output'));
        end

        function unknownBoundaryRaises(testCase)
            s = struct('Signal', [], 'SampleRate', 1);
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'not-a-boundary'), ...
                'CSRD:Contract:UnknownBoundary');
        end

        function nonScalarStructRejected(testCase)
            s(1).Signal = []; s(1).SampleRate = 1; s(1).ID = 1; s(1).TxId = 'a'; s(1).BurstId = 'b'; s(1).ModulatorConfig = struct();
            s(2) = s(1);
            testCase.verifyError(@() ...
                csrd.pipeline.contract.assertSignalStructContract(s, 'modulator-output'), ...
                'CSRD:Contract:SignalStructViolation');
        end

        function contextLabelAppearsInErrorMessage(testCase)
            s = struct('SampleRate', 1);
            try
                csrd.pipeline.contract.assertSignalStructContract(s, 'channel-input', 'Frame=3,Tx=Tx7,Rx=Rx1');
                testCase.fatalAssertFail('Expected schema violation.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'CSRD:Contract:SignalStructViolation');
                testCase.verifyTrue(contains(ME.message, 'Frame=3,Tx=Tx7,Rx=Rx1'), ...
                    'Context label must be embedded in the error message.');
            end
        end

    end

end
