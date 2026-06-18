classdef SdrReceiverCatalogTest < matlab.unittest.TestCase
    %SDRRECEIVERCATALOGTEST Monitoring-receiver SDR capability contract.
    %
    % The monitoring receiver must behave like a real SDR: its capture
    % bandwidth, channel count, and reachable RF center are bounded by the
    % selected model. These tests pin the catalog contract and the tuning-range
    % constraint that keeps the regulatory planner from choosing a band the
    % radio cannot physically tune to.

    methods (Test)

        function loadsAllProfilesWithFiniteCapabilities(testCase)
            ids = csrd.catalog.receiver.SdrReceiverCatalog.supportedModelIds();
            testCase.verifyNotEmpty(ids);
            for k = 1:numel(ids)
                p = csrd.catalog.receiver.SdrReceiverCatalog.load(ids{k});
                testCase.verifyNotEmpty(p.Model);
                testCase.verifyEqual(numel(p.TuningRangeHz), 2);
                testCase.verifyLessThan(p.TuningRangeHz(1), p.TuningRangeHz(2));
                testCase.verifyGreaterThan(p.MaxInstantaneousBandwidthHz, 0);
                testCase.verifyGreaterThanOrEqual(p.NumChannels, 1);
                testCase.verifyGreaterThan(p.AdcBits, 0);
                testCase.verifyTrue(isfinite(p.NoiseFigureDb));
            end
        end

        function rejectsUnsupportedModel(testCase)
            testCase.verifyError( ...
                @() csrd.catalog.receiver.SdrReceiverCatalog.load('NOT_A_RADIO'), ...
                'CSRD:Receiver:UnsupportedSdrModel');
        end

        function narrowbandSdrConstrainsMonitoringToTuningRange(testCase)
            % An RTL-SDR (tuning <= 1.766 GHz) must never monitor a band whose
            % carrier falls outside its tuning range, even though the CN
            % catalog contains 3.5 GHz NR services.
            profile = csrd.catalog.receiver.SdrReceiverCatalog.load('RTL_SDR');
            % A 2.4 MHz RTL-SDR window only fits multi-channel narrowband
            % services (e.g. FM broadcast); seed 7 lands on such a band.
            plan = localPlan(profile, 8, 7);
            centers = arrayfun(@(e) e.SelectedCenterFrequencyHz, plan.EmitterPlans);
            testCase.verifyLessThanOrEqual(max(centers), profile.TuningRangeHz(2));
            testCase.verifyGreaterThanOrEqual(min(centers), profile.TuningRangeHz(1));
            testCase.verifyLessThanOrEqual(plan.Receiver.CenterFrequencyHz, ...
                profile.TuningRangeHz(2));
        end

        function widebandSdrCanReachHighBands(testCase)
            % A USRP B210 (up to 6 GHz) is not constrained away from the high
            % CN bands; repeated draws should sometimes land above 1.8 GHz.
            profile = csrd.catalog.receiver.SdrReceiverCatalog.load('USRP_B210');
            sawHigh = false;
            for seed = 1:25
                plan = localPlan(profile, 1, seed);
                if plan.Receiver.CenterFrequencyHz > 1.8e9
                    sawHigh = true;
                    break;
                end
            end
            testCase.verifyTrue(sawHigh, ...
                'Wideband SDR should be able to monitor bands above 1.8 GHz.');
        end

    end
end


function plan = localPlan(profile, numTx, seed)
% localPlan - Build a CN regulatory scenario plan for a given SDR profile.
rng(seed, 'twister');
cfg = struct();
cfg.Regulatory.Enable = true;
cfg.Regulatory.Region.Fixed = 'CN';
cfg.Regulatory.ServiceTier = 'Tier1';
cfg.Regulatory.ExcludedServiceClasses = {'Radar', 'Radiolocation', 'Radionavigation'};
cfg.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
receiverConfig = struct( ...
    'SampleRate', min(50e6, profile.MaxInstantaneousBandwidthHz), ...
    'Sdr', struct('TuningRangeHz', profile.TuningRangeHz));
plan = csrd.catalog.spectrum.RegionSpectrumSelector.selectScenarioPlan( ...
    cfg, receiverConfig, numTx);
end
