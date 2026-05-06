classdef RayTracingFrequencySupportContractTest < matlab.unittest.TestCase
    % RayTracingFrequencySupportContractTest
    % 中文说明：RayTracing 场景必须在频谱规划阶段排除 MATLAB 不支持的载波。

    methods (Test)

        function fixedAmBandFailsBeforeRayTracing(testCase)
            cfg = localRegulatoryConfig();
            cfg.Runtime.RequiredCarrierFrequencyRangeHz = [100e6, 100e9];
            cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_AM_MW';
            cfg.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = true;

            testCase.verifyError(@() ...
                csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan( ...
                    cfg, struct('SampleRate', 50e6), 1), ...
                'CSRD:Spectrum:MonitoringBandCarrierUnsupported');
        end

        function weightedSelectionNeverPublishesUnsupportedCarrier(testCase)
            rng(7, 'twister');
            cfg = localRegulatoryConfig();
            cfg.Runtime.RequiredCarrierFrequencyRangeHz = [100e6, 100e9];
            for k = 1:30
                plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan( ...
                    cfg, struct('SampleRate', 50e6), 1);
                testCase.verifyGreaterThanOrEqual( ...
                    plan.Receiver.CenterFrequencyHz, 100e6);
                testCase.verifyLessThanOrEqual( ...
                    plan.Receiver.CenterFrequencyHz, 100e9);
            end
        end

    end
end

function cfg = localRegulatoryConfig()
cfg = struct();
cfg.Regulatory.Enable = true;
cfg.Regulatory.Region.Fixed = 'CN';
cfg.Regulatory.ServiceTier = 'Tier1';
cfg.Regulatory.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
cfg.Regulatory.MonitoringBand.Selection = 'WeightedByRegion';
cfg.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
end
