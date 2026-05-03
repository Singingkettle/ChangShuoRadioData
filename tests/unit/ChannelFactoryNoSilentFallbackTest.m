classdef ChannelFactoryNoSilentFallbackTest < matlab.unittest.TestCase
    %CHANNELFACTORYNOSILENTFALLBACKTEST Phase 2 (D5) unit tests covering
    %the deletion of the `modelNames{1}` arbitrary-first-key silent
    %fallback inside ChannelFactory.resolveChannelModelName.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.6.3.
    %
    %   Phase 2 removes the historical fallback that picked an arbitrary
    %   field of factoryConfig.ChannelModels whenever resolution could
    %   not land on the requested model or the explicit mode default. Phase
    %   18 removes the declarative AWGN rescue as well. After the deletion,
    %   any blueprint that asks for a non-existent model AND lacks an
    %   AWGN registry entry must fail fast with
    %   CSRD:Blueprint:ChannelModelMismatch — the same identifier the
    %   validator's checkChannelModelInRegistry produces, so consumers
    %   downstream see one consistent contract.
    %
    %   Tests target the Hidden static helper
    %   `ChannelFactory.resolveChannelModelNameFromConfig` directly so
    %   they don't need to spin up matlab.System setupImpl or pull in
    %   any actual channel block.

    methods (TestMethodSetup)
        function silenceLogger(~)
            try
                csrd.runtime.logger.GlobalLogManager.setLevel('error');
            catch
            end
        end
    end

    methods (Test)

        function requestedRayTracingModelInRegistryReturnsRayTracing(testCase)
            cfg = makeRegistryWithRayTracingAndAWGN();
            modelName = csrd.factories.ChannelFactory ...
                .resolveChannelModelNameFromConfig('RayTracing', '', cfg);
            testCase.verifyEqual(modelName, 'RayTracing');
        end

        function statisticalPlaceholderResolvesToModeDefault(testCase)
            cfg = makeRegistryWithRayTracingAndAWGN();
            cfg.DefaultModels = struct('Statistical', 'AWGN', 'RayTracing', 'RayTracing');
            modelName = csrd.factories.ChannelFactory ...
                .resolveChannelModelNameFromConfig('Statistical', 'Statistical', cfg);
            testCase.verifyEqual(modelName, 'AWGN');
        end

        function unknownModelWithAwgnInRegistryFailsFast(testCase)
            cfg = makeRegistryWithRayTracingAndAWGN();
            testCase.verifyError(@() csrd.factories.ChannelFactory ...
                .resolveChannelModelNameFromConfig('UnknownXYZ', '', cfg), ...
                'CSRD:Blueprint:ChannelModelMismatch');
        end

        function unknownModelWithoutAwgnRaisesChannelModelMismatch(testCase)
            % This is the *deleted* `modelNames{1}` path. Pre-Phase-2 it
            % would silently return 'Rician' (the only registered key);
            % Phase 2 must fail fast.
            cfg = struct('ChannelModels', struct('Rician', struct('handle', 'comm.RicianChannel')));
            testCase.verifyError(@() ...
                csrd.factories.ChannelFactory ...
                    .resolveChannelModelNameFromConfig('UnknownXYZ', '', cfg), ...
                'CSRD:Blueprint:ChannelModelMismatch');
        end

        function emptyRegistryRaisesChannelModelMismatch(testCase)
            % An empty ChannelModels struct used to crash silently inside
            % `modelNames{1}` (index out of bounds). Phase 2 turns this
            % into a deterministic Blueprint:ChannelModelMismatch.
            cfg = struct('ChannelModels', struct());
            testCase.verifyError(@() ...
                csrd.factories.ChannelFactory ...
                    .resolveChannelModelNameFromConfig('AWGN', '', cfg), ...
                'CSRD:Blueprint:ChannelModelMismatch');
        end

        function missingChannelModelsFieldRaisesChannelModelMismatch(testCase)
            % Defensive: if factoryConfig is malformed (no ChannelModels
            % field at all) the helper should still emit the canonical
            % CSRD:Blueprint:ChannelModelMismatch identifier rather than
            % a generic MATLAB struct error.
            cfg = struct('DefaultModels', struct('Statistical', 'AWGN'));
            testCase.verifyError(@() ...
                csrd.factories.ChannelFactory ...
                    .resolveChannelModelNameFromConfig('AWGN', '', cfg), ...
                'CSRD:Blueprint:ChannelModelMismatch');
        end

        function getDefaultModelForModeFromConfigUsesModeKey(testCase)
            cfg = struct('ChannelModels', struct('AWGN', struct(), ...
                                                 'RayTracing', struct(), ...
                                                 'Rician', struct()), ...
                        'DefaultModels', struct('RayTracing', 'RayTracing', 'Statistical', 'Rician'));
            testCase.verifyEqual( ...
                csrd.factories.ChannelFactory ...
                    .getDefaultModelForModeFromConfig('RayTracing', cfg), ...
                'RayTracing');
            testCase.verifyEqual( ...
                csrd.factories.ChannelFactory ...
                    .getDefaultModelForModeFromConfig('Statistical', cfg), ...
                'Rician');
        end

        function getDefaultModelForModeFromConfigRequiresExplicitDefault(testCase)
            cfg = struct('ChannelModels', struct('AWGN', struct()));
            testCase.verifyError(@() csrd.factories.ChannelFactory ...
                .getDefaultModelForModeFromConfig('Whatever', cfg), ...
                'CSRD:Blueprint:MissingChannelDefaultModel');
        end

    end
end


function cfg = makeRegistryWithRayTracingAndAWGN()
    %MAKEREGISTRYWITHRAYTRACINGANDAWGN A minimal factoryConfig that has
    %both a RayTracing and an AWGN entry so the resolution helper can
    %exercise the "requested model is registered" and explicit default
    %branches without actually instantiating any channel block.
    cfg = struct();
    cfg.ChannelModels = struct( ...
        'AWGN', struct('handle', 'comm.AWGNChannel'), ...
        'RayTracing', struct('handle', 'csrd.fake.RayTracingBlock'));
    cfg.DefaultModels = struct('Statistical', 'AWGN');
end
