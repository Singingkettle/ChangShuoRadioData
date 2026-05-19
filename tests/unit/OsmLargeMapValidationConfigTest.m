classdef OsmLargeMapValidationConfigTest < matlab.unittest.TestCase
    %OSMLARGEMAPVALIDATIONCONFIGTEST Specific OSM smoke config stays explicit.

    methods (Test)

        function validationConfigUsesSpecificFileWithoutSizeCap(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            cfg = csrd.runtime.config_loader( ...
                'csrd2025/csrd2025_osm_large_map_validation.m');
            osmCfg = cfg.Factories.Scenario.PhysicalEnvironment.Map.OSM;

            testCase.verifyEqual(cfg.Runner.NumScenarios, 1);
            testCase.verifyEqual( ...
                cfg.Factories.Scenario.Global.NumFramesPerScenario, 1);
            testCase.verifyNotEmpty(osmCfg.SpecificFile);
            testCase.verifyTrue(isfile(osmCfg.SpecificFile));
            testCase.verifyFalse(isfield(osmCfg, 'MaxFileSizeMB'));
        end

    end
end
