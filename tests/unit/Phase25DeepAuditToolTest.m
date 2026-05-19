classdef Phase25DeepAuditToolTest < matlab.unittest.TestCase
    %PHASE25DEEPAUDITTOOLTEST Quick contract tests for Phase 25 audit tool.

    methods (Test)

        function dryRunWritesReportsWithoutRunningLongJobs(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(fullfile(root, 'tools', 'audit'));

            outDir = tempname;
            perfDir = tempname;
            logDir = tempname;
            mkdir(outDir);
            mkdir(perfDir);
            mkdir(logDir);
            cleanupObj = onCleanup(@() localRemoveDirs({outDir, perfDir, logDir})); %#ok<NASGU>

            summary = run_phase25_deep_audit( ...
                'AuditDirectory', outDir, ...
                'PerformanceDirectory', perfDir, ...
                'RunStaticAudit', true, ...
                'RunTests', false, ...
                'RunDefaultSimulation', false, ...
                'RunOsmLargeMapSmoke', false, ...
                'RunFullCoverageDryRun', false, ...
                'RunPhase16DryRun', false, ...
                'RunStress', false, ...
                'LogRoots', {logDir}, ...
                'Verbose', false);

            testCase.verifyTrue(summary.Success);
            testCase.verifyTrue(isfile(summary.MatPath));
            testCase.verifyTrue(isfile(summary.JsonPath));
            testCase.verifyTrue(isfile(summary.MarkdownPath));
            testCase.verifyFalse(summary.Runs.DefaultSimulation.Ran);
            testCase.verifyGreaterThan(numel(summary.ConfigMatrix), 0);
            testCase.verifyGreaterThan(numel(summary.TestMatrix), 0);
        end

        function logClassifierFindsHardFailureCategories(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(fullfile(root, 'tools', 'audit'));

            outDir = tempname;
            perfDir = tempname;
            logDir = tempname;
            mkdir(outDir);
            mkdir(perfDir);
            mkdir(logDir);
            cleanupObj = onCleanup(@() localRemoveDirs({outDir, perfDir, logDir})); %#ok<NASGU>

            fid = fopen(fullfile(logDir, 'synthetic.log'), 'w');
            cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'ERROR FrameWindow resolves to wrong length\n');
            fprintf(fid, 'WARNING Measurement failed: detectBurstEnvelope\n');
            fprintf(fid, 'WARNING RayTracing failed for map mode OSMBuildings\n');
            fprintf(fid, 'WARNING Insufficient bandwidth, using overlapping allocation\n');
            clear cleanupFile;

            summary = run_phase25_deep_audit( ...
                'AuditDirectory', outDir, ...
                'PerformanceDirectory', perfDir, ...
                'RunStaticAudit', false, ...
                'LogRoots', {logDir}, ...
                'Verbose', false);

            testCase.verifyEqual(summary.LogAudit.TotalErrors, 1);
            testCase.verifyGreaterThan(summary.LogAudit.TotalFrameContract, 0);
            testCase.verifyGreaterThan(summary.LogAudit.TotalMeasurement, 0);
            testCase.verifyGreaterThan(summary.LogAudit.TotalRayTracing, 0);
            testCase.verifyGreaterThan(summary.LogAudit.TotalFrequencyOverlap, 0);
            testCase.verifyTrue(summary.HasBlockerFindings);
        end

        function repoInternalOutputMustStayIgnored(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            addpath(fullfile(root, 'tools', 'audit'));

            badDir = fullfile(root, 'docs', 'phase25_bad_output');
            testCase.verifyError(@() run_phase25_deep_audit( ...
                'AuditDirectory', badDir, ...
                'RunStaticAudit', false, ...
                'Verbose', false), ...
                'CSRD:Phase25:ArtifactPathOutsideIgnoredRoots');
        end

    end
end

function localRemoveDirs(paths)
for idx = 1:numel(paths)
    if isfolder(paths{idx})
        try
            rmdir(paths{idx}, 's');
        catch
        end
    end
end
end
