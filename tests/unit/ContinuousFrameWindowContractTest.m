classdef ContinuousFrameWindowContractTest < matlab.unittest.TestCase
    % ContinuousFrameWindowContractTest

    methods (Test)

        function continuousTransmissionIsClippedToEachFrame(testCase)
            frameSamples = 1024;
            sampleRate = 50e6;
            numFrames = 10;
            frameDuration = frameSamples / sampleRate;

            sim = csrd.blocks.scenario.CommunicationBehaviorSimulator( ...
                'Config', localContinuousConfig(frameSamples, sampleRate, numFrames));

            entities = localEntities();
            [txFrame1, ~, ~] = step(sim, 1, entities);
            [txFrame2, ~, ~] = step(sim, 2, entities);

            st1 = txFrame1{1}.TransmissionState;
            st2 = txFrame2{1}.TransmissionState;

            testCase.verifyEqual(st1.FrameWindow, [0, frameDuration], ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(st1.ActiveIntervals, [0, frameDuration], ...
                'AbsTol', 1e-15);
            testCase.verifyTrue(st1.IsActive);

            testCase.verifyEqual(st2.FrameWindow, [frameDuration, 2 * frameDuration], ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(st2.ActiveIntervals, [frameDuration, 2 * frameDuration], ...
                'AbsTol', 1e-15);
            testCase.verifyTrue(st2.IsActive);
        end

    end
end

function cfg = localContinuousConfig(frameSamples, sampleRate, numFrames)
frameDuration = frameSamples / sampleRate;
cfg = struct();
cfg.Global.FrameNumSamples = frameSamples;
cfg.Global.NumFramesPerScenario = numFrames;
framePlan = struct( ...
    'FrameNumSamples', frameSamples, ...
    'FrameDurationSec', frameDuration, ...
    'ObservationDurationSec', frameDuration * numFrames, ...
    'NumFramesPerScenario', numFrames, ...
    'Source', 'Test.ScenarioPlan.Frame');
cfg.ScenarioPlan = struct('Frame', framePlan);
cfg.Receiver.Type = 'Simulation';
cfg.Receiver.SampleRate = sampleRate;
cfg.Receiver.NumAntennas = 1;
cfg.Receiver.CenterFrequency = 0;
cfg.Receiver.RealCarrierFrequency = 2.4e9;
cfg.Regulatory.Enable = false;
cfg.FrequencyAllocation.Strategy = 'ReceiverCentric';
cfg.FrequencyAllocation.MinSeparation = 100e3;
cfg.TransmissionPattern.DefaultType = 'Continuous';
cfg.Transmitter.Types = {'Simulation'};
cfg.Transmitter.Power = struct('Min', 10, 'Max', 10);
cfg.Transmitter.NumAntennas = struct('Min', 1, 'Max', 1);
cfg.Transmitter.BandwidthRatio = struct('Min', 0.02, 'Max', 0.02);
cfg.Modulation.Types = {'PSK'};
cfg.Modulation.DefaultOrders.PSK = 2;
cfg.Modulation.RolloffFactor = 0.25;
cfg.Modulation.SamplesPerSymbol = struct('Min', 2, 'Max', 2);
cfg.Message.Types = {'RandomBit'};
cfg.Message.Length = struct('Min', 64, 'Max', 4096);
cfg.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.TemporalBehavior.PatternDistribution = 1;
end

function entities = localEntities()
baseSnapshot = struct( ...
    'FrameId', 1, ...
    'Timestamp', 0, ...
    'Physical', struct( ...
        'Position', [0, 0, 30], ...
        'PositionUnit', 'meters', ...
        'GeoPositionDeg', [], ...
        'Velocity', [0, 0, 0], ...
        'Orientation', [0, 0], ...
        'AngularVelocity', [0, 0]), ...
    'Communication', struct(), ...
    'Temporal', struct());

tx = struct( ...
    'ID', 'Tx1', ...
    'Type', 'Transmitter', ...
    'Position', [0, 0, 30], ...
    'PositionUnit', 'meters', ...
    'GeoPositionDeg', [], ...
    'Velocity', [0, 0, 0], ...
    'Orientation', [0, 0], ...
    'AngularVelocity', [0, 0], ...
    'Snapshots', {{baseSnapshot}}, ...
    'FrameId', 1);
rx = tx;
rx.ID = 'Rx1';
rx.Type = 'Receiver';
rx.Position = [100, 0, 10];
rx.Snapshots{1}.Physical.Position = rx.Position;
entities = [tx, rx];
end
