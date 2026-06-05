classdef Phase34BoundaryQualityAuditTest < matlab.unittest.TestCase
    %PHASE34BOUNDARYQUALITYAUDITTEST Phase 34 audit control-plane tests.

    methods (Test)
        function dryRunWritesTargetedAndStressManifests(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'audit'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase34_boundary_quality_audit( ...
                'ArtifactRoot', outDir, ...
                'DryRun', true, ...
                'StressCount', 3, ...
                'Verbose', false);

            testCase.verifyTrue(isfile(fullfile(outDir, ...
                'phase34_boundary_quality_summary.json')));
            testCase.verifyEqual(summary.Schema, ...
                'csrd.phase34.boundary-quality-audit.v1');
            testCase.verifyEqual(summary.StaticAudit.NumBlockers, 0);
            testCase.verifyTrue(summary.Targeted.Ran);
            testCase.verifyTrue(summary.Stress.Ran);
            testCase.verifyEqual(numel(summary.Stress.Cases), 3);
            testCase.verifyEqual({summary.Stress.Cases.Status}, ...
                {'Planned', 'Planned', 'Planned'});
            for idx = 1:numel(summary.Stress.Cases)
                c = summary.Stress.Cases(idx);
                testCase.verifyTrue(startsWith(c.ConfigPath, outDir), ...
                    'Generated configs must stay under ignored artifacts.');
                testCase.verifyTrue(isfile(c.ConfigPath));
                configText = fileread(c.ConfigPath);
                testCase.verifyNotEmpty(strfind(configText, ...
                    'config.Runner.Performance.EnableStageTiming = true;'));
                testCase.verifyNotEmpty(strfind(configText, ...
                    'config.Metadata.Phase34Audit.Mode'));
            end
        end

        function dryRunCanSkipStress(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'audit'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase34_boundary_quality_audit( ...
                'ArtifactRoot', outDir, ...
                'DryRun', true, ...
                'RunStress', false, ...
                'Verbose', false);

            testCase.verifyTrue(summary.Targeted.Ran);
            testCase.verifyFalse(summary.Stress.Ran);
            testCase.verifyGreaterThan(summary.Totals.Planned, 0);
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
