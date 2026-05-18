classdef MassiveSimulationWatchdogTest < matlab.unittest.TestCase
    %MASSIVESIMULATIONWATCHDOGTEST Phase 27 watchdog control-plane tests.

    methods (Test)
        function dryRunWritesChunkConfigs(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 8, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 8, ...
                'DryRun', true, ...
                'Verbose', false);

            testCase.verifyTrue(isfile(fullfile(outDir, 'manifest.json')));
            testCase.verifyEqual(manifest.DryRunChunk.NumScenarios, 8);
            testCase.verifyEqual(numel(manifest.DryRunChunk.Workers), 2);
            testCase.verifyTrue(isfield(manifest, 'RunId'));
            for idx = 1:2
                configText = fileread(manifest.DryRunChunk.Workers(idx).ConfigPath);
                testCase.verifyNotEmpty(regexp(configText, ...
                    'config\.Runner\.NumScenarios = 8;', 'once'));
                testCase.verifyNotEmpty(regexp(configText, ...
                    'config\.Runner\.Performance\.EnableStageTiming = true;', 'once'));
                testCase.verifyNotEmpty(regexp(configText, ...
                    'config\.Runner\.Performance\.EnableHeartbeat = true;', 'once'));
                testCase.verifyNotEmpty(regexp(configText, ...
                    'config\.Runner\.Performance\.RawEventLimit = 2000;', 'once'));
                testCase.verifyNotEmpty(regexp(configText, ...
                    'config\.Runner\.Performance\.PartialWriteInterval = 50;', 'once'));
                testCase.verifyNotEmpty(strfind(configText, ...
                    'CSRD2025_massive/'));
                testCase.verifyNotEmpty(strfind(configText, ...
                    'chunk_000001'));
            end
        end

        function mockSuccessCleansFullOutputsAndKeepsReservoir(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 4, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 4, ...
                'RunPilot', true, ...
                'LaunchMode', 'MockSuccess', ...
                'ReservoirSampleLimit', 2, ...
                'MaxChunks', 1, ...
                'Verbose', false);

            testCase.verifyEqual(manifest.SuccessfulScenarios, 4);
            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Passed');
            testCase.verifyTrue(isfield(manifest, 'ActiveChunk'));
            testCase.verifyEqual(manifest.ChunkRecords(1).AnnotationAudit.InvalidMeasured, 0);
            testCase.verifyGreaterThanOrEqual(manifest.ReservoirCount, 1);
            sampleFiles = dir(fullfile(outDir, 'reservoir_samples', ...
                'sample_*', 'scenario_data.mat'));
            testCase.verifyGreaterThanOrEqual(numel(sampleFiles), 1);

            scenarioDirs = dir(fullfile(manifest.ChunkRecords(1).DataChunkRoot, ...
                '**', 'scenarios'));
            testCase.verifyEmpty(scenarioDirs);
        end

        function mockFailureRestartsWithNewSeedAndDoesNotCountFailure(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 2, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 2, ...
                'ProductionChunkScenarios', 2, ...
                'LaunchMode', 'MockFailureOnce', ...
                'MaxFailureRate', 1, ...
                'MaxChunks', 2, ...
                'Verbose', false);

            testCase.verifyEqual(numel(manifest.ChunkRecords), 2);
            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Failed');
            testCase.verifyEqual(manifest.ChunkRecords(2).Status, 'Passed');
            testCase.verifyEqual(manifest.SuccessfulScenarios, 2);
            testCase.verifyNotEqual(manifest.ChunkRecords(1).Seed, ...
                manifest.ChunkRecords(2).Seed);
            testCase.verifyTrue(isfolder(manifest.ChunkRecords(1).FailureArtifact));
        end

        function resumeArchivesStaleActiveChunkBeforeContinuing(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            chunkRoot = fullfile(outDir, 'chunks', 'chunk_000001');
            dataRoot = fullfile(outDir, 'data', 'chunk_000001');
            logDir = fullfile(dataRoot, 'worker_001', 'session_mock', 'logs');
            mkdir(logDir);
            mkdir(fullfile(chunkRoot, 'worker_stdout'));
            localWriteText(fullfile(logDir, 'CSRD_partial.log'), ...
                ['Worker 1 [SUCCESS]: Scenario 1/2 (ID: 1) | ', ...
                 'Time: 1.00s | Progress: 50.0%']);
            localWriteJson(fullfile(chunkRoot, 'chunk_state.json'), ...
                struct('ChunkId', 1, 'State', 'Running'));

            stale = localBaseManifest(outDir, chunkRoot, dataRoot);
            localWriteJson(fullfile(outDir, 'manifest.json'), stale);

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 2, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 2, ...
                'ProductionChunkScenarios', 2, ...
                'RunPilot', false, ...
                'Resume', true, ...
                'LaunchMode', 'MockSuccess', ...
                'MaxChunks', 1, ...
                'Verbose', false);

            testCase.verifyGreaterThanOrEqual(numel(manifest.ChunkRecords), 2);
            testCase.verifyEqual(manifest.ChunkRecords(1).ChunkId, 1);
            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Failed');
            testCase.verifyEqual(manifest.ChunkRecords(1).FirstFailure.Signature, ...
                'StaleActiveChunk');
            testCase.verifyEqual(manifest.ChunkRecords(1).SuccessfulScenarios, 0, ...
                'Partial stale outputs must not count as successful scenarios.');
            testCase.verifyEqual(manifest.ChunkRecords(2).Status, 'Passed');
            testCase.verifyEqual(manifest.SuccessfulScenarios, 2);
            testCase.verifyTrue(isfile(fullfile(chunkRoot, 'chunk_record.json')));
        end

        function resumeCountsCompletedStaleActiveChunkAsPassed(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            chunkRoot = fullfile(outDir, 'chunks', 'chunk_000001');
            dataRoot = fullfile(outDir, 'data', 'chunk_000001');
            mkdir(fullfile(chunkRoot, 'worker_stdout'));
            localWriteCompletedWorker(dataRoot, 1, 1:2);
            localWriteCompletedWorker(dataRoot, 2, 3:4);
            localWriteJson(fullfile(chunkRoot, 'chunk_state.json'), ...
                struct('ChunkId', 1, 'State', 'Running'));

            stale = localBaseManifest(outDir, chunkRoot, dataRoot);
            stale.ActiveChunk.NumScenarios = 4;
            localWriteJson(fullfile(outDir, 'manifest.json'), stale);

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 4, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 4, ...
                'RunPilot', false, ...
                'Resume', true, ...
                'LaunchMode', 'MockSuccess', ...
                'MaxChunks', 1, ...
                'Verbose', false);

            testCase.verifyEqual(numel(manifest.ChunkRecords), 1);
            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Passed');
            testCase.verifyEqual(manifest.ChunkRecords(1).SuccessfulScenarios, 4);
            testCase.verifyEqual(manifest.SuccessfulScenarios, 4);
            testCase.verifyEqual(manifest.ChunkRecords(1).AnnotationAudit.InvalidMeasured, 0);
            testCase.verifyTrue(isfile(fullfile(chunkRoot, 'chunk_record.json')));
            testCase.verifyGreaterThanOrEqual(manifest.ReservoirCount, 1);
        end

        function rayTracingFallbackWarningIsHardFailure(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 2, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 2, ...
                'ProductionChunkScenarios', 2, ...
                'LaunchMode', 'MockRayTracingFailureOnce', ...
                'MaxFailureRate', 1, ...
                'MaxChunks', 2, ...
                'Verbose', false);

            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Failed');
            testCase.verifyEqual(manifest.ChunkRecords(2).Status, 'Passed');
            testCase.verifyEqual(manifest.SuccessfulScenarios, 2);
            testCase.verifyNotEmpty(strfind( ...
                manifest.ChunkRecords(1).FirstFailure.Signature, ...
                'RayTracing failed'));
        end

        function spectrumPlanningErrorIsHardFailure(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 2, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 2, ...
                'ProductionChunkScenarios', 2, ...
                'LaunchMode', 'MockSpectrumFailureOnce', ...
                'MaxFailureRate', 1, ...
                'MaxChunks', 2, ...
                'Verbose', false);

            testCase.verifyEqual(manifest.ChunkRecords(1).Status, 'Failed');
            testCase.verifyEqual(manifest.ChunkRecords(2).Status, 'Passed');
            testCase.verifyEqual(manifest.SuccessfulScenarios, 2);
            testCase.verifyNotEmpty(strfind( ...
                manifest.ChunkRecords(1).FirstFailure.Signature, ...
                'CSRD:Spectrum'));
        end

        function subprocessCleanupTracksMatlabWorkerByConfigPath(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourcePath = fullfile(root, 'tools', 'massive', ...
                'run_massive_simulation_watchdog.m');
            code = fileread(sourcePath);

            testCase.verifyTrue(contains(code, ...
                "run_worker_%03d.cmd"), ...
                'Watchdog should keep the proven cmd/batch launch path for matlab -batch.');
            testCase.verifyTrue(contains(code, 'localIsWorkerRunning'));
            testCase.verifyTrue(contains(code, 'localFindWorkerProcessIds'));
            testCase.verifyTrue(contains(code, 'CommandLine.IndexOf'), ...
                ['Worker cleanup must find MATLAB children by generated ', ...
                 'config path so a failed chunk cannot leave orphan workers.']);
            testCase.verifyTrue(contains(code, 'pid <= 0'), ...
                ['Process id 0 is the Windows idle process, not a worker; ', ...
                 'watchdog liveness checks must never wait on it.']);
        end

        function slowSummaryParsesLogsAndAnnotationMetadata(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>

            chunkRoot = fullfile(outDir, 'chunks', 'chunk_000001');
            dataRoot = fullfile(outDir, 'data', 'worker_002');
            logDir = fullfile(dataRoot, 'session_mock', 'logs');
            annotationDir = fullfile(dataRoot, 'session_mock', 'annotations');
            mkdir(logDir);
            mkdir(annotationDir);
            logText = ['05/14 01:02:03 - CSRD - INFO ', ...
                '[csrd.SimulationRunner.displayProgress:767] ', ...
                'Worker 2 [SUCCESS]: Scenario 3/10 (ID: 42) | ', ...
                'Time: 12.50s | Progress: 30.0%'];
            localWriteText(fullfile(logDir, 'CSRD_mock.log'), logText);

            profile = struct('Mode', 'OSMBuildings', ...
                'OSMFile', 'demo.osm', ...
                'HasBuildings', true, ...
                'OSMFileSizeMB', 123.25);
            payload = struct('Header', struct('Runtime', struct('ScenarioId', 42)), ...
                'MapProfile', profile);
            localWriteJson(fullfile(annotationDir, ...
                'scenario_000042_annotation.json'), payload);

            worker = struct('WorkerId', 2, 'DataRoot', dataRoot);
            activeChunk = struct('ChunkId', 1, 'ChunkType', 'Pilot', ...
                'ChunkRoot', chunkRoot, 'DataChunkRoot', fullfile(outDir, 'data'), ...
                'Workers', worker);
            manifest = struct('ActiveChunk', activeChunk);
            localWriteJson(fullfile(outDir, 'manifest.json'), manifest);

            summary = write_massive_pilot_slow_summary(outDir, 'TopN', 5);

            testCase.verifyEqual(summary.ScenarioRecords, 1);
            testCase.verifyEqual(summary.TopSlowScenarios(1).ScenarioId, 42);
            testCase.verifyEqual(summary.TopSlowScenarios(1).OSMFile, 'demo.osm');
            testCase.verifyEqual(summary.TopSlowScenarios(1).MapMode, 'OSMBuildings');
            testCase.verifyTrue(isfile(fullfile(chunkRoot, ...
                'pilot_slow_scenarios.json')));
            testCase.verifyTrue(isfile(fullfile(outDir, ...
                'latest_slow_scenarios.md')));
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

function localWriteText(pathText, text)
parent = fileparts(pathText);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
fid = fopen(pathText, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text);
clear cleanup;
end

function localWriteJson(pathText, payload)
parent = fileparts(pathText);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
fid = fopen(pathText, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(payload));
clear cleanup;
end

function localWriteCompletedWorker(dataRoot, workerId, scenarioIds)
sessionRoot = fullfile(dataRoot, sprintf('worker_%03d', workerId), ...
    'session_mock');
logDir = fullfile(sessionRoot, 'logs');
scenarioDir = fullfile(sessionRoot, 'scenarios');
annotationDir = fullfile(sessionRoot, 'annotations');
mkdir(logDir);
mkdir(scenarioDir);
mkdir(annotationDir);
localWriteText(fullfile(logDir, sprintf('CSRD_worker_%03d.log', workerId)), ...
    sprintf(['Worker %d simulation completed:\n', ...
    '  Successful scenarios: %d\n  Failed scenarios: 0\n', ...
    '  Skipped scenarios: 0\n'], workerId, numel(scenarioIds)));

for idx = 1:numel(scenarioIds)
    scenarioId = scenarioIds(idx);
    mockSignal = scenarioId; %#ok<NASGU>
    save(fullfile(scenarioDir, sprintf('scenario_%06d_data.mat', scenarioId)), ...
        'mockSignal');
    measured = struct('SourcePlane', localMeasuredPlane(), ...
        'FramePlane', localMeasuredPlane());
    source = struct('Truth', struct('Measured', measured));
    payload = struct('Header', struct('ScenarioId', scenarioId), ...
        'Sources', source);
    localWriteJson(fullfile(annotationDir, ...
        sprintf('scenario_%06d_annotation.json', scenarioId)), payload);
end
end

function plane = localMeasuredPlane()
plane = struct('MeasurementStatus', 'Measured', ...
    'OccupiedBandwidthHz', 1, ...
    'CenterFrequencyHz', 0, ...
    'TimeOccupancy', 1, ...
    'FrequencyOccupancy', 0.1);
end

function manifest = localBaseManifest(outDir, chunkRoot, dataRoot)
manifest = struct();
manifest.Schema = 'csrd.massive-watchdog.v1';
manifest.RunId = 'stale_resume_test';
manifest.CreatedAtUtc = '2026-05-15T00:00:00.000Z';
manifest.UpdatedAtUtc = manifest.CreatedAtUtc;
manifest.Status = 'Running';
manifest.Settings = struct();
manifest.NextChunkId = 2;
manifest.LastSeed = 12345;
manifest.TotalChunks = 0;
manifest.FailedChunks = 0;
manifest.SuccessfulScenarios = 0;
manifest.AttemptedScenarios = 0;
manifest.PilotCompleted = true;
manifest.Pilot = struct();
manifest.ActiveChunk = struct('ChunkId', 1, ...
    'ChunkType', 'Production', ...
    'ChunkName', 'chunk_000001', ...
    'ChunkRoot', chunkRoot, ...
    'DataChunkRoot', dataRoot, ...
    'NumScenarios', 2, ...
    'Seed', 12345, ...
    'StartedAtUtc', '2026-05-15T00:00:00.000Z');
manifest.ChunkRecords = struct([]);
manifest.LastConsecutiveFailureSignature = '';
manifest.ConsecutiveFailureCount = 0;
manifest.ReservoirSeen = 0;
manifest.ReservoirCount = 0;
manifest.ArtifactRoot = outDir;
end
