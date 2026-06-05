classdef RayTracingGeometryCacheToleranceTest < matlab.unittest.TestCase
    %RAYTRACINGGEOMETRYCACHETOLERANCETEST Guard RayTracing long-tail cache policy.

    methods (Test)

        function defaultConfigDeclaresGeometryTolerance(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'config', '_base_', 'factories'));
            cfg = channel_factory();
            rtCfg = cfg.Factories.Channel.ChannelModels.RayTracing.Config;

            testCase.verifyTrue(isfield(rtCfg, 'RayCachePositionToleranceM'));
            testCase.verifyEqual(rtCfg.RayCachePositionToleranceM, 0.01);
            testCase.verifyTrue(isfield(rtCfg, 'SlowStageInfoThresholdSec'));
            testCase.verifyEqual(rtCfg.SlowStageInfoThresholdSec, 30);
        end

        function rayTracingKeysAndMetadataIncludeTolerance(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, 'TolM=%.17g'), ...
                'Ray/site cache keys must include the explicit geometry tolerance.');
            testCase.verifyTrue(contains(code, 'quantizeGeoPosition'), ...
                'RayTracing cache keys must quantize sub-tolerance endpoint drift.');
            testCase.verifyTrue(contains(code, ...
                'channelInfo.RayCachePositionToleranceM'), ...
                'RayTracing ChannelInfo must export the cache tolerance used.');
            testCase.verifyTrue(contains(code, 'logSlowRayTracingStage'), ...
                ['Slow OSM siteviewer/raytrace stages must be visible in ', ...
                 'normal logs, not only in optional performance traces.']);
        end

        function channelObjectCacheResetsBeforeReuse(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, 'rayTracingChannelCacheKey'), ...
                'RayTracing channel object cache key must be explicit.');
            testCase.verifyTrue(contains(code, 'resetSystemObjectIfPossible'), ...
                ['Cached comm.RayTracingChannel objects must be reset before ', ...
                 'reuse so filter state does not leak across bursts.']);
            testCase.verifyTrue(contains(code, ...
                'RayTracing.RayTracingChannelCacheHit'), ...
                'RayTracing channel object cache hits must be measurable.');
        end

    end
end
