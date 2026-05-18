classdef MassiveSimulationWatchdogGracefulStopTest < matlab.unittest.TestCase
    %MASSIVESIMULATIONWATCHDOGGRACEFULSTOPTEST Stop/resume status contracts.

    methods (Test)
        function stopFilePreventsNewChunkLaunch(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tools', 'massive'));
            outDir = tempname;
            mkdir(outDir);
            cleanupObj = onCleanup(@() localRemoveDir(outDir)); %#ok<NASGU>
            localWriteJson(fullfile(outDir, 'stop_requested.json'), ...
                struct('Reason', 'unit test stop'));

            manifest = run_massive_simulation_watchdog( ...
                'ArtifactRoot', outDir, ...
                'TargetSuccessfulScenarios', 4, ...
                'NumWorkers', 2, ...
                'PilotScenarios', 4, ...
                'LaunchMode', 'MockSuccess', ...
                'Verbose', false);

            testCase.verifyEqual(manifest.Status, 'Stopped');
            testCase.verifyEqual(manifest.StopReason, 'unit test stop');
            testCase.verifyNotEmpty(manifest.StoppedAtUtc);
            testCase.verifyEqual(manifest.TotalChunks, 0);
            testCase.verifyEqual(manifest.SuccessfulScenarios, 0);
            testCase.verifyFalse(localHasActiveChunk(manifest));
        end

        function stoppedStaleActiveChunkRecoversWithoutFailureCount(testCase)
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
            localWriteJson(fullfile(outDir, 'stop_requested.json'), ...
                struct('Reason', 'resume detected external stop'));

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

            testCase.verifyEqual(manifest.Status, 'Stopped');
            testCase.verifyEqual(manifest.ChunkRecords(1).Status, ...
                'RecoveredStopped');
            testCase.verifyEqual(manifest.FailedChunks, 0);
            testCase.verifyEqual(manifest.SuccessfulScenarios, 0);
            testCase.verifyEqual(manifest.LastKnownActiveChunk.ChunkId, 1);
            testCase.verifyFalse(localHasActiveChunk(manifest));
        end
    end
end

function tf = localHasActiveChunk(manifest)
tf = isfield(manifest, 'ActiveChunk') && isstruct(manifest.ActiveChunk) && ...
    isfield(manifest.ActiveChunk, 'ChunkId') && ~isempty(manifest.ActiveChunk.ChunkId);
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

function manifest = localBaseManifest(outDir, chunkRoot, dataRoot)
manifest = struct();
manifest.Schema = 'csrd.massive-watchdog.v1';
manifest.RunId = 'graceful_stop_test';
manifest.CreatedAtUtc = '2026-05-18T00:00:00.000Z';
manifest.UpdatedAtUtc = manifest.CreatedAtUtc;
manifest.Status = 'Running';
manifest.StoppedAtUtc = '';
manifest.StopReason = '';
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
    'StartedAtUtc', '2026-05-18T00:00:00.000Z');
manifest.LastKnownActiveChunk = struct();
manifest.ChunkRecords = struct([]);
manifest.LastConsecutiveFailureSignature = '';
manifest.ConsecutiveFailureCount = 0;
manifest.ReservoirSeen = 0;
manifest.ReservoirCount = 0;
manifest.ArtifactRoot = outDir;
end
