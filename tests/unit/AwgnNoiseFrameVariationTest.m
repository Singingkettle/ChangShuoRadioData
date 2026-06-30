classdef AwgnNoiseFrameVariationTest < matlab.unittest.TestCase
    % AwgnNoiseFrameVariationTest
    %
    % Additive thermal/channel noise is i.i.d. per observation window, so the
    % noise REALIZATION must differ frame-to-frame within a scenario (while the
    % fading geometry stays burst-stable and the noise POWER tracks the same
    % target SNR). The channel seed deliberately excludes FrameId (so fading is
    % burst-stable, H13), which previously made the additive noise byte-identical
    % across every frame of a scenario -- a per-scenario noise mask a model could
    % memorize. ChannelFactory now frame-salts the additive-noise seed.

    methods (Test)

        function seedSaltVariesPerFrameButIsFrameStable(testCase)
            f = csrd.factories.ChannelFactory('Config', struct());
            base = 1234567;
            testCase.verifyNotEqual(f.frameSaltedNoiseSeed(base, 1), ...
                f.frameSaltedNoiseSeed(base, 2), ...
                'Noise seed must differ across frames');
            testCase.verifyEqual(f.frameSaltedNoiseSeed(base, 1), ...
                f.frameSaltedNoiseSeed(base, 1), ...
                'Noise seed must be stable for the same frame');
        end

        function injectedNoiseVariesAcrossFramesAtStablePower(testCase)
            factory = localFactory();
            cleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
            [input, txInfo, rxInfo, linkInfo] = localStepArgs();

            o1 = step(factory, input, 1, txInfo, rxInfo, linkInfo);
            o1b = step(factory, input, 1, txInfo, rxInfo, linkInfo);   % same frame
            o2 = step(factory, input, 2, txInfo, rxInfo, linkInfo);    % next frame

            testCase.verifyFalse(isequal(o1.Signal, o2.Signal), ...
                'Additive noise must differ between frames (i.i.d.)');
            testCase.verifyEqual(o1.Signal, o1b.Signal, ...
                'Same frame must reproduce the same noise realisation');
            % same target SNR -> comparable realized power across frames
            p1 = mean(abs(o1.Signal) .^ 2);
            p2 = mean(abs(o2.Signal) .^ 2);
            testCase.verifyEqual(p2, p1, 'RelTol', 0.1, ...
                'Noise power must track the same target across frames');
        end

    end
end

function factory = localFactory()
cfg = struct();
cfg.ChannelModels.Rayleigh = struct('handle', 'csrd.blocks.physical.channel.MIMO', ...
    'Config', struct('FadingDistribution', 'Rayleigh', 'MaximumDopplerShift', 0, ...
        'PathDelays', 0, 'AveragePathGains', 0, 'Seed', 73));
cfg.LinkBudget = struct('NoiseBandwidth', 1e6, 'NoiseFigure', 6, 'ThermalNoisePSD', -174, ...
    'MinDistance', 0.01, 'EnableDistanceBasedSNR', false, 'TargetSnrRangeDb', [10 10]);
cfg.DefaultModels.Statistical = 'Rayleigh';
cfg.NoValidPathFallback = 'FreeSpaceAttenuation';
factory = csrd.factories.ChannelFactory('Config', cfg);
setup(factory);
end

function [input, txInfo, rxInfo, linkInfo] = localStepArgs()
input = struct('Signal', complex(ones(4096, 1), zeros(4096, 1)), 'SampleRate', 1e6, 'StartTime', 0);
txInfo = struct('ID', 'Tx1', 'Position', [0 0 10], 'Power', 20, 'AntennaGain', 0, 'NumTransmitAntennas', 1);
rxInfo = struct('ID', 'Rx1', 'Position', [100 0 10], 'RealCarrierFrequency', 2.4e9, ...
    'ObservableRange', [-0.5e6 0.5e6], 'SampleRate', 1e6, 'AntennaGain', 0, 'NumAntennas', 1);
linkInfo = struct('ChannelModel', 'Rayleigh', 'BurstId', 'Tx1.Burst1', 'MapProfile', struct('Mode', 'Statistical'));
end

function localRelease(factory)
if isa(factory, 'matlab.System') && isLocked(factory)
    release(factory);
end
end
