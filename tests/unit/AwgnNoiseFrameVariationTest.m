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
    %
    % Since the measurement moved ahead of noise injection, ChannelFactory SIZES
    % the noise rather than adding it, so these assertions run on the
    % PendingChannelNoise descriptor and on the realization that
    % csrd.pipeline.signal.realizeChannelNoise produces from it -- which is the
    % noise that actually reaches the saved frame.

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

        function plannedNoiseVariesAcrossFramesAtStablePower(testCase)
            % The property under test is unchanged -- the noise REALIZATION must
            % differ frame to frame while its POWER tracks one target -- but the
            % factory now SIZES the noise instead of adding it, so it has to be
            % checked on the descriptor and on the realization the descriptor
            % produces, not on the factory's output waveform.
            %
            % Checking the waveform here would now be VACUOUS in the worst way: the
            % factory returns the clean signal unchanged, so `isequal(o1.Signal,
            % o2.Signal)` is trivially true and a test written against it fails for
            % the right reason today but could be "fixed" by relaxing it into
            % something that proves nothing. Going through the real injector keeps
            % the assertion about the noise that actually reaches the dataset.
            factory = localFactory();
            cleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
            [input, txInfo, rxInfo, linkInfo] = localStepArgs();

            o1 = step(factory, input, 1, txInfo, rxInfo, linkInfo);
            o1b = step(factory, input, 1, txInfo, rxInfo, linkInfo);   % same frame
            o2 = step(factory, input, 2, txInfo, rxInfo, linkInfo);    % next frame

            % The waveform must now be NOISE-FREE, and this is the exact inversion
            % of the assertion this test used to make. The fading seed deliberately
            % excludes FrameId (H13, so fading stays burst-stable), so the only
            % thing that ever differed between two frames of one burst was the
            % additive noise. Before the reorder that made o1.Signal ~= o2.Signal;
            % now they must be EQUAL, which is a direct proof that no noise is left
            % in the buffer the measured planes read.
            %
            % Note "clean" means noise-free, not unmodified: the factory still
            % applies propagation and fading, so comparing against input.Signal
            % would be wrong.
            testCase.verifyEqual(o1.Signal, o2.Signal, sprintf( ...
                ['Two frames of one burst must carry the IDENTICAL waveform, since ', ...
                 'fading is burst-stable and noise is no longer added here. A ', ...
                 'difference means noise reached the buffer the measured planes ', ...
                 'read (frames compared: 1 and 2, %d samples).'], ...
                size(o1.Signal, 1)));
            % RequestedChannelNoisePowerW is deliberately NON-zero here: it is the
            % per-link REQUESTED noise power that the frame's reference descriptor
            % may realize (applyFrameChannelNoise draws ONE whole-frame realization
            % from the first noise-owing component; the SNRdB labels are then
            % measured against that realization). The invariant is that the
            % request bookkeeping and the descriptor the injector consumes agree
            % exactly -- if they drifted apart, the diagnostic would describe a
            % different amount of noise than the frame could ever carry.
            testCase.verifyEqual(double(o1.RequestedChannelNoisePowerW), ...
                double(o1.PendingChannelNoise.PowerW), 'RelTol', 1e-12, ...
                ['RequestedChannelNoisePowerW must equal ', ...
                 'PendingChannelNoise.PowerW (which the injector realizes). A gap ', ...
                 'here means the request bookkeeping and the descriptor disagree.']);

            for o = {o1, o1b, o2}
                testCase.verifyTrue(isfield(o{1}, 'PendingChannelNoise') && ...
                    isstruct(o{1}.PendingChannelNoise), ...
                    'Every noised link must carry a PendingChannelNoise descriptor.');
            end

            testCase.verifyNotEqual(o1.PendingChannelNoise.Seed, ...
                o2.PendingChannelNoise.Seed, ...
                'Noise seed must differ across frames (additive noise is i.i.d.).');
            testCase.verifyEqual(o1.PendingChannelNoise.Seed, ...
                o1b.PendingChannelNoise.Seed, ...
                'Same frame must plan the same noise realisation.');
            testCase.verifyEqual(o2.PendingChannelNoise.PowerW, ...
                o1.PendingChannelNoise.PowerW, 'RelTol', 0.1, ...
                'Noise power must track the same target SNR across frames.');

            % And the descriptors must produce what they promise once realized.
            n1 = csrd.pipeline.signal.realizeChannelNoise( ...
                o1.PendingChannelNoise, o1.Signal) - o1.Signal;
            n1b = csrd.pipeline.signal.realizeChannelNoise( ...
                o1b.PendingChannelNoise, o1b.Signal) - o1b.Signal;
            n2 = csrd.pipeline.signal.realizeChannelNoise( ...
                o2.PendingChannelNoise, o2.Signal) - o2.Signal;

            testCase.verifyEqual(n1, n1b, ...
                'The same frame must realize a byte-identical noise sequence.');
            testCase.verifyFalse(isequal(n1, n2), ...
                ['Successive frames must realize DIFFERENT noise. A frame-invariant ', ...
                 'realization is a per-scenario noise fingerprint a model can ', ...
                 'memorise instead of learning the signal.']);
            testCase.verifyEqual(mean(abs(n2) .^ 2), mean(abs(n1) .^ 2), ...
                'RelTol', 0.15, ...
                'Realized noise power must track the same target across frames.');
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
