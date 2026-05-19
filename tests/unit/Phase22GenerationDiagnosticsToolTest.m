classdef Phase22GenerationDiagnosticsToolTest < matlab.unittest.TestCase
    %PHASE22GENERATIONDIAGNOSTICSTOOLTEST Quick diagnostics entrypoint smoke.

    methods (Test)

        function quickPathWritesSummaryOnly(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'performance'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase22_generation_diagnostics( ...
                'ArtifactDirectory', outDir, ...
                'RunDefaultSimulation', false, ...
                'RunFullCoverageValidation', false, ...
                'RunOsmRayTracingValidation', false, ...
                'RunStress', false, ...
                'Verbose', false);

            testCase.verifyTrue(summary.Success);
            testCase.verifyTrue(isfile(summary.SummaryPath));
            testCase.verifyTrue(isfile(summary.JsonPath));
            testCase.verifyFalse(summary.Runs.DefaultSimulation.Ran);
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
