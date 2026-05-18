classdef RegionSpectrumSelectorTest < matlab.unittest.TestCase
    %REGIONSPECTRUMSELECTORTEST Phase 8 selector behavior tests.

    methods (TestMethodSetup)
        function resetRng(~)
            rng(20260428, 'twister');
        end
    end

    methods (Test)
        function fixedSeedSelectionIsReproducible(testCase)
            cfg = localRegConfig('CN');
            rx = struct('SampleRate', 50e6);
            rng(11, 'twister');
            p1 = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 4);
            rng(11, 'twister');
            p2 = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 4);
            testCase.verifyEqual([p1.EmitterPlans.SelectedCenterFrequencyHz], ...
                [p2.EmitterPlans.SelectedCenterFrequencyHz]);
            testCase.verifyEqual({p1.EmitterPlans.BandId}, {p2.EmitterPlans.BandId});
            testCase.verifyEqual({p1.EmitterPlans.ModulationFamily}, ...
                {p2.EmitterPlans.ModulationFamily});
        end

        function analogFmBandDoesNotSelectDigitalModulation(testCase)
            cfg = localRegConfig('CN');
            cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_FM_BROADCAST';
            rx = struct('SampleRate', 20e6);
            plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 3);
            for k = 1:numel(plan.EmitterPlans)
                ep = plan.EmitterPlans(k);
                testCase.verifyEqual(ep.BandId, 'CN_FM_BROADCAST');
                testCase.verifyEqual(ep.ModulationFamily, 'FM');
            end
        end

        function nrBandUsesOfdmOrQamApproximation(testCase)
            cfg = localRegConfig('CN');
            cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_NR_N78';
            rx = struct('SampleRate', 100e6);
            plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 5);
            allowed = {'OFDM','QAM'};
            for k = 1:numel(plan.EmitterPlans)
                ep = plan.EmitterPlans(k);
                testCase.verifyEqual(ep.BandId, 'CN_NR_N78');
                testCase.verifyTrue(ismember(ep.ModulationFamily, allowed));
                testCase.verifyGreaterThanOrEqual(ep.SelectedCenterFrequencyHz - ep.BandwidthHz / 2, 3300e6);
                testCase.verifyLessThanOrEqual(ep.SelectedCenterFrequencyHz + ep.BandwidthHz / 2, 3600e6);
            end
        end

        function selectedCentersAreRasterAligned(testCase)
            cfg = localRegConfig('CN');
            cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_NR_N78';
            rx = struct('SampleRate', 100e6);
            plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 8);
            catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load('CN');
            band = catalog.Bands(strcmp({catalog.Bands.BandId}, 'CN_NR_N78'));
            ref = band.FrequencyRangeHz(1);
            raster = band.ChannelRasterHz;
            for k = 1:numel(plan.EmitterPlans)
                n = (plan.EmitterPlans(k).SelectedCenterFrequencyHz - ref) / raster;
                testCase.verifyLessThan(abs(n - round(n)), 1e-6);
            end
        end

        function fixedBandConstrainsEmittersInsideWideReceiverWindow(testCase)
            cfg = localRegConfig('KR');
            cfg.Regulatory.MonitoringBand.FixedBandId = 'KR_SRD_920';
            rx = struct('SampleRate', 50e6);

            plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan(cfg, rx, 5);

            testCase.verifyEqual(plan.Receiver.MonitoringBandId, 'KR_SRD_920');
            for k = 1:numel(plan.EmitterPlans)
                ep = plan.EmitterPlans(k);
                testCase.verifyEqual(ep.BandId, 'KR_SRD_920');
                testCase.verifyEqual(ep.ServiceClass, 'ShortRangeDevice');
            end
        end

        function partialReceiverWindowFiltersBandwidthChoices(testCase)
            cfg = localRegConfig('CN');
            cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_LAND_MOBILE_UHF';
            cfg.Regulatory.MonitoringBand.CenterFrequencyHz = 408.09e6;
            cfg.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = false;
            cfg.Regulatory.MonitoringBand.AllowIntersectingServices = true;
            rx = struct('SampleRate', 50e6);

            rng(20260513, 'twister');
            plan = csrd.catalog.spectrum.RegionSpectrumSelector ...
                .selectScenarioPlan(cfg, rx, 200);
            catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load('CN');
            sawSrd433 = false;

            for k = 1:numel(plan.EmitterPlans)
                ep = plan.EmitterPlans(k);
                band = catalog.Bands(strcmp({catalog.Bands.BandId}, ep.BandId));
                lowerEdge = ep.SelectedCenterFrequencyHz - ep.BandwidthHz / 2;
                upperEdge = ep.SelectedCenterFrequencyHz + ep.BandwidthHz / 2;
                testCase.verifyGreaterThanOrEqual(lowerEdge, ...
                    band.FrequencyRangeHz(1) - 1);
                testCase.verifyLessThanOrEqual(upperEdge, ...
                    band.FrequencyRangeHz(2) + 1);
                testCase.verifyGreaterThanOrEqual(lowerEdge, ...
                    plan.Receiver.MonitoringRangeHz(1) - 1);
                testCase.verifyLessThanOrEqual(upperEdge, ...
                    plan.Receiver.MonitoringRangeHz(2) + 1);
                if strcmp(ep.BandId, 'CN_SRD_433')
                    sawSrd433 = true;
                    testCase.verifyLessThanOrEqual(ep.BandwidthHz, 25e3);
                end
            end

            testCase.verifyTrue(sawSrd433, ...
                'The fixture should exercise the partially visible CN_SRD_433 band.');
        end
    end
end


function cfg = localRegConfig(regionId)
cfg = struct();
cfg.Regulatory.Enable = true;
cfg.Regulatory.Region.Policy = 'Fixed';
cfg.Regulatory.Region.Fixed = regionId;
cfg.Regulatory.ServiceTier = 'Tier1';
cfg.Regulatory.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
cfg.Regulatory.MonitoringBand.Selection = 'WeightedByRegion';
cfg.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
end
