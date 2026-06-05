classdef RFPropagationCapabilitiesTest < matlab.unittest.TestCase
    %RFPROPAGATIONCAPABILITIESTEST Verify OSM RayTracing runtime probing.

    methods (Test)
        function detectsInstalledRayTracingSymbols(testCase)
            % detectsInstalledRayTracingSymbols - Check symbol availability report.
            caps = csrd.runtime.capabilities.rfPropagationCapabilities();
            fprintf('RF propagation capability report:\n');
            fprintf('  siteviewer: exist=%d which=%s\n', ...
                caps.Symbols.siteviewer.ExistCode, caps.Symbols.siteviewer.Which);
            fprintf('  txsite: exist=%d which=%s\n', ...
                caps.Symbols.txsite.ExistCode, caps.Symbols.txsite.Which);
            fprintf('  rxsite: exist=%d which=%s\n', ...
                caps.Symbols.rxsite.ExistCode, caps.Symbols.rxsite.Which);
            fprintf('  propagationModel: exist=%d which=%s\n', ...
                caps.Symbols.propagationModel.ExistCode, ...
                caps.Symbols.propagationModel.Which);
            fprintf('  raytrace: exist=%d which=%s\n', ...
                caps.Symbols.raytrace.ExistCode, caps.Symbols.raytrace.Which);
            fprintf('  comm.RayTracingChannel: exist=%d which=%s\n', ...
                caps.Symbols.RayTracingChannel.ExistCode, ...
                caps.Symbols.RayTracingChannel.Which);

            testCase.verifyTrue(caps.Symbols.siteviewer.IsAvailable, ...
                'siteviewer must be detected even when MATLAB reports it as p-code.');
            testCase.verifyTrue(caps.Symbols.txsite.IsAvailable);
            testCase.verifyTrue(caps.Symbols.rxsite.IsAvailable);
            testCase.verifyTrue(caps.Symbols.propagationModel.IsAvailable);
            testCase.verifyTrue(caps.Symbols.raytrace.IsAvailable, ...
                'raytrace is a txsite method and must not be checked only as a top-level function.');
            testCase.verifyTrue(caps.Symbols.RayTracingChannel.IsAvailable);
            testCase.verifyTrue(caps.CanUseBuildingOsmRayTracing);
        end

        function buildingOsmSmokePassesWhenCapabilitiesExist(testCase)
            % buildingOsmSmokePassesWhenCapabilitiesExist - Create hidden OSM siteviewer.
            projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            buildingFiles = dir(fullfile(projectRoot, 'data', 'map', 'osm', ...
                'Dense_Urban_Mid_Rise', '*.osm'));
            testCase.assumeFalse(isempty(buildingFiles), ...
                'No Dense_Urban_Mid_Rise OSM file is available for RF propagation smoke.');
            buildingOsm = fullfile(buildingFiles(1).folder, buildingFiles(1).name);

            caps = csrd.runtime.capabilities.rfPropagationCapabilities( ...
                'OsmFile', buildingOsm, 'RunSmoke', true);
            testCase.verifyTrue(caps.CanUseBuildingOsmRayTracing, ...
                char(caps.SkipReason));
            testCase.verifyTrue(caps.SmokePassed, char(caps.SmokeMessage));
        end
    end
end
