classdef ControlledTargetSnrTest < matlab.unittest.TestCase
    % ControlledTargetSnrTest - Guards the controlled target-SNR mode.
    %
    %   When LinkBudget.EnableDistanceBasedSNR is false, each burst's applied
    %   SNR is a deterministic uniform sample from LinkBudget.TargetSnrRangeDb,
    %   realized via the AWGN channel's SNRdB or, for channels that carry no
    %   noise of their own (RayTracing propagation / fading), via the
    %   post-channel target-SNR noise injection. This shapes the dataset SNR into
    %   the spectrum-sensing-useful band instead of the physically-emergent (and
    %   often far too high) link-budget value. Distance-based mode must be
    %   unaffected (backward compatibility).

    methods (Test)

        function awgnControlledSnrIsDeterministicAndInBand(testCase)
            rangeDb = [5, 25];
            factory = ControlledTargetSnrTest.makeFactory('AWGN', rangeDb, false);
            cleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
            [input, txInfo, rxInfo, linkInfo] = ControlledTargetSnrTest.makeLink('AWGN', 'burst-1');

            out1 = step(factory, input, 1, txInfo, rxInfo, linkInfo);
            out2 = step(factory, input, 1, txInfo, rxInfo, linkInfo);

            testCase.verifyGreaterThanOrEqual(out1.AppliedSNRdB, rangeDb(1));
            testCase.verifyLessThanOrEqual(out1.AppliedSNRdB, rangeDb(2));
            testCase.verifyEqual(out2.AppliedSNRdB, out1.AppliedSNRdB, 'AbsTol', 1e-9, ...
                'Same burst must reproduce the same controlled SNR.');
            realizedDb = 10 * log10(out1.ChannelSignalPowerW / out1.ChannelNoisePowerW);
            testCase.verifyEqual(realizedDb, out1.AppliedSNRdB, 'AbsTol', 1.0, ...
                'AWGN must realize the controlled target SNR.');
        end

        function noiseFreeChannelInjectionRealizesTargetSnr(testCase)
            rangeDb = [-5, 15];
            factory = ControlledTargetSnrTest.makeFactory('Rayleigh', rangeDb, false);
            cleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
            [input, txInfo, rxInfo, linkInfo] = ControlledTargetSnrTest.makeLink('Rayleigh', 'burst-2');

            out = step(factory, input, 1, txInfo, rxInfo, linkInfo);

            testCase.verifyGreaterThanOrEqual(out.AppliedSNRdB, rangeDb(1));
            testCase.verifyLessThanOrEqual(out.AppliedSNRdB, rangeDb(2));
            % Fading carries no channel noise of its own; the injection must
            % establish a noise floor sized to the target SNR.
            testCase.verifyTrue(isfield(out, 'ChannelNoisePowerW') && ...
                out.ChannelNoisePowerW > 0, ...
                'Injection must establish a channel-noise floor for fading.');
            realizedDb = 10 * log10(out.ChannelSignalPowerW / out.ChannelNoisePowerW);
            testCase.verifyEqual(realizedDb, out.AppliedSNRdB, 'AbsTol', 1.0, ...
                'Injection must realize the controlled target SNR for fading.');
        end

        function distanceBasedModeIgnoresTargetRange(testCase)
            % EnableDistanceBasedSNR=true keeps the link-budget SNR (the target
            % range is inert) - guards backward compatibility.
            factory = ControlledTargetSnrTest.makeFactory('AWGN', [5, 25], true);
            cleanup = onCleanup(@() localRelease(factory)); %#ok<NASGU>
            [input, txInfo, rxInfo, linkInfo] = ControlledTargetSnrTest.makeLink('AWGN', 'burst-3');

            out = step(factory, input, 1, txInfo, rxInfo, linkInfo);
            testCase.verifyEqual(out.AppliedSNRdB, out.ComputedSNR, 'AbsTol', 1e-9, ...
                'Distance-based mode must keep AppliedSNRdB == ComputedSNR.');
        end

    end

    methods (Static, Access = private)

        function factory = makeFactory(model, rangeDb, enableDist)
            cfg = struct();
            if strcmp(model, 'AWGN')
                cfg.ChannelModels.AWGN = struct( ...
                    'handle', 'csrd.blocks.physical.channel.AWGNChannel', ...
                    'Config', struct('SNRdB', 20));
            else
                cfg.ChannelModels.Rayleigh = struct( ...
                    'handle', 'csrd.blocks.physical.channel.MIMO', ...
                    'Config', struct('FadingDistribution', 'Rayleigh', ...
                        'MaximumDopplerShift', 0, 'PathDelays', 0, ...
                        'AveragePathGains', 0, 'Seed', 73));
            end
            cfg.LinkBudget = struct('NoiseBandwidth', 1e6, 'NoiseFigure', 6, ...
                'ThermalNoisePSD', -174, 'MinDistance', 0.01, ...
                'EnableDistanceBasedSNR', enableDist, 'TargetSnrRangeDb', rangeDb);
            cfg.DefaultModels.Statistical = model;
            cfg.NoValidPathFallback = 'FreeSpaceAttenuation';
            factory = csrd.factories.ChannelFactory('Config', cfg);
            setup(factory);
        end

        function [input, txInfo, rxInfo, linkInfo] = makeLink(model, burstId)
            input = struct('Signal', complex(ones(512, 1), zeros(512, 1)), ...
                'SampleRate', 1e6, 'StartTime', 0);
            txInfo = struct('ID', 'Tx1', 'Position', [0, 0, 10], ...
                'PositionUnit', 'meters', 'Power', 20, 'AntennaGain', 0, ...
                'NumTransmitAntennas', 1);
            rxInfo = struct('ID', 'Rx1', 'Position', [100, 0, 10], ...
                'PositionUnit', 'meters', 'RealCarrierFrequency', 2.4e9, ...
                'ObservableRange', [-0.5e6, 0.5e6], 'SampleRate', 1e6, ...
                'AntennaGain', 0, 'NumAntennas', 1);
            linkInfo = struct('ChannelModel', model, ...
                'MapProfile', struct('Mode', 'Statistical'), 'BurstId', burstId);
        end

    end
end

function localRelease(obj)
if isLocked(obj)
    release(obj);
end
end
