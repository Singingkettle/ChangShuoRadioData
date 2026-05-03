classdef RFPropagationCapabilitiesTest < matlab.unittest.TestCase
    %RFPROPAGATIONCAPABILITIESTEST Verify OSM RayTracing runtime probing.
    % 中文说明：验证 RF propagation 能力探针不会把 p-code 或对象方法误判为缺失。

    methods (Test)
        function detectsInstalledRayTracingSymbols(testCase)
            % detectsInstalledRayTracingSymbols - Check symbol availability report.
            % 中文说明：检查 siteviewer、txsite、raytrace 和 RayTracingChannel 的符号探测结果。
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
            % 中文说明：在能力可用时创建并释放隐藏 OSM 建筑 siteviewer，验证真实 runtime 链路。
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
