classdef RegulatoryEmitterRealismTest < matlab.unittest.TestCase
    %REGULATORYEMITTERREALISMTEST Service-aware transmit power and order limits.
    %
    % Regulatory emitters must be physically plausible: transmit power scales
    % with the service class (broadcast towers radiate far more than short-range
    % devices), and modulation order is bounded by the channel bandwidth (a
    % narrowband channel cannot carry a dense 256-QAM constellation).

    methods (Test)

        function broadcastPowerExceedsShortRangePower(testCase)
            broadcast = localBand('CN_FM_BROADCAST', 4, 11);
            srd = localBand('CN_SRD_433', 4, 11);
            bRange = broadcast(1).PowerDbmRange;
            sRange = srd(1).PowerDbmRange;
            testCase.verifyEqual(numel(bRange), 2);
            testCase.verifyGreaterThan(bRange(1), sRange(2), ...
                'Broadcast minimum power should exceed short-range maximum power.');
        end

        function powerRangeIsConsistentWithinService(testCase)
            emitters = localBand('CN_FM_BROADCAST', 6, 5);
            for k = 1:numel(emitters)
                r = emitters(k).PowerDbmRange;
                testCase.verifyTrue(all(isfinite(r)) && r(1) <= r(2), ...
                    'Power range must be a finite ordered pair.');
            end
        end

        function narrowbandChannelRejectsHighOrderQam(testCase)
            % CN_LAND_MOBILE_UHF allows QAM but at 12.5/25 kHz channels a dense
            % constellation is unrealistic; order must be capped well below 256.
            emitters = localBand('CN_LAND_MOBILE_UHF', 8, 3);
            for k = 1:numel(emitters)
                e = emitters(k);
                if strcmp(e.ModulationFamily, 'QAM') && e.BandwidthHz < 200e3
                    testCase.verifyLessThanOrEqual(e.ModulationOrder, 16, ...
                        'Narrowband QAM order must be bandwidth-limited.');
                end
            end
        end

    end
end


function emitters = localBand(fixedBandId, numTx, seed)
% localBand - Build CN regulatory emitter plans forcing a monitoring band.
rng(seed, 'twister');
cfg = struct();
cfg.Regulatory.Enable = true;
cfg.Regulatory.Region.Fixed = 'CN';
cfg.Regulatory.ServiceTier = 'Tier1';
cfg.Regulatory.ExcludedServiceClasses = {'Radar', 'Radiolocation', 'Radionavigation'};
cfg.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
cfg.Regulatory.MonitoringBand.FixedBandId = fixedBandId;
receiverConfig = struct('SampleRate', 20e6);
plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan( ...
    cfg, receiverConfig, numTx);
emitters = plan.EmitterPlans;
end
