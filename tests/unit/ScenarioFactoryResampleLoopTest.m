classdef ScenarioFactoryResampleLoopTest < matlab.unittest.TestCase
    %SCENARIOFACTORYRESAMPLELOOPTEST Phase 2 unit tests for the validator-
    %backed resample loop in csrd.factories.ScenarioFactory.stepImpl.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.4 / §5.2.
    %
    %   These tests cover the public-property contract and the helper
    %   methods exposed via the (Hidden) test-only API. The full stepImpl
    %   path (including PhysicalEnvironment + CommunicationBehavior
    %   simulators) is covered indirectly by the regression smoke tests
    %   (test_phase2_blueprint_smoke / test_baseline_sweep_200).

    methods (TestMethodSetup)
        function silenceLogger(~)
            try
                csrd.utils.logger.GlobalLogManager.setLevel('error');
            catch
            end
        end
    end

    methods (Test)

        function readOnlyPropertiesExposedAndDefault(testCase)
            cfg = makeMinimalScenarioConfig();
            f = csrd.factories.ScenarioFactory('Config', cfg);
            testCase.verifyTrue(isstruct(f.LastValidationReport));
            testCase.verifyEqual(f.LastBlueprintResamples, 0);
            testCase.verifyEqual(f.LastBlueprintHash, '');
        end

        function readOnlyPropertiesAreNotPublicSetAccess(testCase)
            f = csrd.factories.ScenarioFactory('Config', makeMinimalScenarioConfig());
            testCase.verifyError(@() assignProperty(f, 'LastValidationReport', struct('m', 1)), ...
                'MATLAB:class:SetProhibited');
            testCase.verifyError(@() assignProperty(f, 'LastBlueprintResamples', 99), ...
                'MATLAB:class:SetProhibited');
        end

        function getValidatorConfigDefaultsAreFiftyAndEnabled(testCase)
            f = csrd.factories.ScenarioFactory('Config', makeMinimalScenarioConfig());
            f.applyTestConfig(makeMinimalScenarioConfig());
            [maxResamples, enabled] = f.getValidatorConfig();
            testCase.verifyEqual(maxResamples, 50);
            testCase.verifyTrue(enabled);
        end

        function getValidatorConfigHonorsCustomMaxResamples(testCase)
            cfg = makeMinimalScenarioConfig();
            cfg.Validator = struct('MaxResamples', 7, 'Enabled', false);
            f = csrd.factories.ScenarioFactory('Config', cfg);
            f.applyTestConfig(cfg);
            [maxResamples, enabled] = f.getValidatorConfig();
            testCase.verifyEqual(maxResamples, 7);
            testCase.verifyFalse(enabled);
        end

        function blueprintAssemblyIncludesAllOptionalConfigSlots(testCase)
            cfg = makeMinimalScenarioConfig();
            cfg.Global             = struct('NumFrames', 4, 'FrameDuration', 1e-3);
            cfg.Validator          = struct('MaxResamples', 5);
            cfg.AnnotationPolicy   = struct('GeometryGranularity', 'Frame');
            cfg.OutputPolicy       = struct('OutputWindowPolicy', 'ExactFrameClip');
            cfg.MeasurementPolicy  = struct('MaxVisibleSourcesPerFrame', 1);
            cfg.ChannelPreference  = struct('Model', 'AWGN');
            cfg.ChannelModelRegistry = {'AWGN', 'Rician'};

            f = csrd.factories.ScenarioFactory('Config', cfg);
            f.applyTestConfig(cfg);

            txConfigs = {struct('id', 'tx1')};
            rxConfigs = {struct('id', 'rx1')};
            layout    = struct('FrameId', 1);
            env       = struct('MapType', 'Statistical');

            bp = f.assembleBlueprint(7, txConfigs, rxConfigs, layout, env);

            testCase.verifyEqual(bp.FrameId, 7);
            testCase.verifyEqual(bp.Emitters,  txConfigs);
            testCase.verifyEqual(bp.Receivers, rxConfigs);
            testCase.verifyEqual(bp.CommunicationLayout, layout);
            testCase.verifyEqual(bp.Global.NumFrames, 4);
            testCase.verifyEqual(bp.Validator.MaxResamples, 5);
            testCase.verifyEqual(bp.AnnotationPolicy.GeometryGranularity, 'Frame');
            testCase.verifyEqual(bp.OutputPolicy.OutputWindowPolicy, 'ExactFrameClip');
            testCase.verifyEqual(bp.MeasurementPolicy.MaxVisibleSourcesPerFrame, 1);
            testCase.verifyEqual(bp.ChannelPreference.Model, 'AWGN');
            testCase.verifyEqual(bp.ChannelModelRegistry, {'AWGN', 'Rician'});
            testCase.verifyEqual(bp.EnvironmentSummary.MapType, 'Statistical');
        end

        function assembledBlueprintIsAccepted_GoldenPath(testCase)
            cfg = makeMinimalScenarioConfig();
            cfg.Global = struct('NumFrames', 1, 'FrameDuration', 1e-3, 'FrameNumSamples', 4e4);

            f = csrd.factories.ScenarioFactory('Config', cfg);
            f.applyTestConfig(cfg);

            txConfigs = {struct( ...
                'Modulation', struct('Family', 'OFDM'), ...
                'Hardware',   struct('NumAntennas', 2), ...
                'Spectrum',   struct('PlannedBandwidth', 10e6, 'PlannedFreqOffset', 0))};
            rxConfigs = {struct( ...
                'Hardware', struct('NumAntennas', 1), ...
                'SampleRate', 40e6, 'ObservableBandwidth', 40e6)};
            layout = struct('FrameId', 1);
            env    = struct('MapType', 'Statistical');

            bp = f.assembleBlueprint(1, txConfigs, rxConfigs, layout, env);
            report = csrd.utils.blueprint.BlueprintFeasibilityValidator.validate(bp);
            testCase.verifyTrue(report.IsFeasible, sprintf( ...
                'golden-path blueprint should be feasible, but got %d failed checks', ...
                report.NumChecksFailed));
        end

        function unsamplableErrorIdentifierIsTheRightOne(testCase)
            ME = MException('CSRD:Blueprint:Unsamplable', 'synthetic test error');
            testCase.verifyEqual(ME.identifier, 'CSRD:Blueprint:Unsamplable');
        end

    end
end


function cfg = makeMinimalScenarioConfig()
    cfg = struct( ...
        'Architecture',         'DualComponent', ...
        'Version',              'p2-test', ...
        'PhysicalEnvironment',  struct( ...
            'Map', struct('Types', {{'Statistical'}}, 'Ratio', 1.0)), ...
        'CommunicationBehavior', struct( ...
            'FrequencyAllocation', struct('Strategy', 'ReceiverCentric')));
end


function assignProperty(obj, name, value)
    obj.(name) = value;
end
