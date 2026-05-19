classdef Phase21DefaultPerformanceSmokeTest < matlab.unittest.TestCase
    %PHASE21DEFAULTPERFORMANCESMOKETEST Quick Phase 21 config/tool smoke.

    methods (Test)

        function defaultConfigUsesProductionPerformancePolicy(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.verifyEqual(cfg.Runner.Log.Policy, 'LargeMC');
            testCase.verifyFalse(logical(cfg.Runner.Data.PrettyPrintAnnotations));
            testCase.verifyTrue(isfield(cfg.Runner, 'Performance'));
            testCase.verifyFalse(logical(cfg.Runner.Performance.EnableStageTiming), ...
                'Stage timing must be opt-in so default production runs stay lean.');
        end

        function profileToolQuickPathWritesOnlyPerformanceSummary(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'performance'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase21_generation_profile( ...
                'OutputDirectory', outDir, ...
                'RunMeasurementMicrobench', false, ...
                'RunOsmFlatSmoke', false, ...
                'RunOsmBuildingSmoke', false, ...
                'RunDefaultSimulation', false, ...
                'Verbose', false);

            testCase.verifyTrue(summary.Success);
            testCase.verifyTrue(isfile(summary.SummaryPath));
            testCase.verifyTrue(isfile(summary.JsonPath));
            testCase.verifyFalse(summary.Probes.DefaultSimulation.Ran);
        end

    end
end

function localRemoveDir(pathText)
if isfolder(pathText)
    try
        rmdir(pathText, 's');
    catch
    end
end
end
