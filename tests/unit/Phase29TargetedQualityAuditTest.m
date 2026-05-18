classdef Phase29TargetedQualityAuditTest < matlab.unittest.TestCase
    %PHASE29TARGETEDQUALITYAUDITTEST Phase 29 audit tool control-plane tests.

    methods (Test)
        function dryRunWritesAllCaseManifestsUnderArtifacts(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'audit'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase29_targeted_quality_audit( ...
                'ArtifactRoot', outDir, ...
                'DryRun', true, ...
                'Verbose', false);

            expectedNames = { ...
                'statistical_baseline_smoke', ...
                'empty_osm_flatterrain_north_dakota', ...
                'osm_building_medium_london', ...
                'osm_building_large_barcelona_bridge', ...
                'multi_link_raytracing_dense', ...
                'short_frame_measurement', ...
                'frequency_no_overlap_default'};

            testCase.verifyTrue(isfile(fullfile(outDir, ...
                'phase29_targeted_quality_summary.json')));
            testCase.verifyEqual({summary.Cases.Name}, expectedNames);
            testCase.verifyEqual(summary.Totals.Planned, numel(expectedNames));
            testCase.verifyEqual(summary.Totals.Failed, 0);
            for idx = 1:numel(summary.Cases)
                c = summary.Cases(idx);
                testCase.verifyEqual(c.Status, 'Planned');
                testCase.verifyTrue(startsWith(c.ConfigPath, outDir), ...
                    'Generated configs must remain inside the ignored artifact root.');
                testCase.verifyTrue(isfile(c.ConfigPath));
                configText = fileread(c.ConfigPath);
                testCase.verifyNotEmpty(strfind(configText, ...
                    'config.Runner.Performance.EnableStageTiming = true;'));
                testCase.verifyNotEmpty(strfind(configText, ...
                    'config.Metadata.Phase29Audit.CaseName'));
            end
        end

        function dryRunCanSelectSingleCase(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'audit'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            summary = run_phase29_targeted_quality_audit( ...
                'ArtifactRoot', outDir, ...
                'DryRun', true, ...
                'CaseNames', {'empty_osm_flatterrain_north_dakota'}, ...
                'Verbose', false);

            testCase.verifyEqual(numel(summary.Cases), 1);
            testCase.verifyEqual(summary.Cases(1).Name, ...
                'empty_osm_flatterrain_north_dakota');
            configText = fileread(summary.Cases(1).ConfigPath);
            testCase.verifyNotEmpty(strfind(configText, ...
                'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Terrain = ''none'';'));
            testCase.verifyEmpty(strfind(configText, 'gmted2010'));
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
