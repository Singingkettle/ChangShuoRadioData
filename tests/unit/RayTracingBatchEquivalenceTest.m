classdef RayTracingBatchEquivalenceTest < matlab.unittest.TestCase
    %RAYTRACINGBATCHEQUIVALENCETEST Phase 21 RayTracing cache contract.

    methods (Test)

        function channelFactoryCachesRayTracingByMapProfile(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+factories', 'ChannelFactory.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, 'Phase 21'), ...
                'ChannelFactory should document the Phase 21 RayTracing cache policy.');
            testCase.verifyTrue(contains(code, 'Map=%s|File=%s|Terrain=%s'), ...
                'RayTracing cache key must be map/profile scoped.');
            testCase.verifyTrue(contains(code, 'cacheKey = sprintf(''%s|Tx=%s|Rx=%s'''), ...
                'Non-RayTracing channels must remain per Tx/Rx cached.');
        end

        function rayTracingBlockCachesMapResources(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, '+csrd', '+blocks', '+physical', ...
                '+channel', 'RayTracing.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, 'siteViewerCache'), ...
                'OSM siteviewer construction must be cached per OSM file.');
            testCase.verifyTrue(contains(code, 'propagationModelCache'), ...
                'Propagation model construction must be cached per map/profile.');
        end

    end
end
