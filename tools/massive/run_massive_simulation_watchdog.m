function manifest = run_massive_simulation_watchdog(varargin)
%RUN_MASSIVE_SIMULATION_WATCHDOG Long-running CSRD simulation watchdog.
% 中文说明：通过 tools/simulation.m 入口执行大规模压力审计；默认不保留全量成功样本。

p = inputParser();
p.FunctionName = 'run_massive_simulation_watchdog';
addParameter(p, 'TargetSuccessfulScenarios', 100000000, @localPositiveInteger);
addParameter(p, 'NumWorkers', 4, @localPositiveInteger);
addParameter(p, 'RetentionMode', 'AuditOnly', @(x) ischar(x) || isstring(x));
addParameter(p, 'BaseConfig', 'csrd2025/csrd2025.m', @(x) ischar(x) || isstring(x));
addParameter(p, 'ArtifactRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'PilotScenarios', 400, @localPositiveInteger);
addParameter(p, 'ProductionChunkScenarios', 4000, @localPositiveInteger);
addParameter(p, 'RunPilot', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Resume', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MonitorIntervalSec', 60, @localNonnegativeScalar);
addParameter(p, 'DiskFreePauseBytes', 500 * 1024^3, @localNonnegativeScalar);
addParameter(p, 'ReservoirSampleLimit', 10000, @localNonnegativeInteger);
addParameter(p, 'FailureSampleLimit', 50, @localNonnegativeInteger);
addParameter(p, 'MaxConsecutiveFailureSignature', 3, @localPositiveInteger);
addParameter(p, 'MaxFailureRate', 0.01, @localNonnegativeScalar);
addParameter(p, 'InitialSeed', [], @(x) isempty(x) || localPositiveInteger(x));
addParameter(p, 'LaunchMode', 'Subprocess', @(x) any(strcmpi(char(string(x)), ...
    {'Subprocess', 'MockSuccess', 'MockFailureOnce', ...
    'MockRayTracingFailureOnce', 'MockSpectrumFailureOnce'})));
addParameter(p, 'StopSignalFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MaxChunks', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CleanupSuccessOutputs', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools'));

artifactRoot = char(string(p.Results.ArtifactRoot));
if isempty(artifactRoot)
    artifactRoot = fullfile(projectRoot, 'artifacts', 'massive_audit');
elseif ~localIsAbsolutePath(artifactRoot)
    artifactRoot = fullfile(projectRoot, artifactRoot);
end
localEnsureDirectory(artifactRoot);
localEnsureDirectory(fullfile(artifactRoot, 'chunks'));
localEnsureDirectory(fullfile(artifactRoot, 'generated_configs'));
localEnsureDirectory(fullfile(artifactRoot, 'failures'));
localEnsureDirectory(fullfile(artifactRoot, 'reservoir_samples'));

settings = localSettingsStruct(p.Results, projectRoot, artifactRoot);
manifestPath = fullfile(artifactRoot, 'manifest.json');
manifest = localLoadOrCreateManifest(manifestPath, settings, p.Results.Resume);
manifest.Settings = settings;
manifest.UpdatedAtUtc = localUtcNow();
if p.Results.Resume
    [manifest, recoveredRecord] = localRecoverStaleActiveChunk(manifest, settings);
    if ~isempty(recoveredRecord)
        manifest = localWriteManifest(manifestPath, manifest);
        if strcmp(recoveredRecord.Status, 'RecoveredStopped')
            manifest = localMarkStopped(manifest, settings, ...
                recoveredRecord.FirstFailure.Message);
            manifest = localWriteManifest(manifestPath, manifest);
            return;
        end
        if localShouldPause(manifest, settings)
            manifest.Status = 'Paused';
            manifest.PauseReason = 'Stale active chunk requires repair before continuing.';
            localWriteRepairQueue(manifest, settings, recoveredRecord);
            manifest = localWriteManifest(manifestPath, manifest);
            return;
        end
    end
end

[stopRequested, stopReason] = localStopRequested(settings);
if stopRequested
    manifest = localMarkStopped(manifest, settings, stopReason);
    manifest = localWriteManifest(manifestPath, manifest);
    if p.Results.Verbose
        fprintf('Massive watchdog stopped before starting a new chunk: %s\n', ...
            stopReason);
    end
    return;
end

if p.Results.DryRun
    [chunk, manifest] = localPrepareChunk(manifest, settings, ...
        p.Results.PilotScenarios, 'DryRun');
    manifest.DryRunChunk = chunk;
    manifest = localWriteManifest(manifestPath, manifest);
    if p.Results.Verbose
        fprintf('Massive watchdog dry-run prepared chunk %d under %s\n', ...
            chunk.ChunkId, chunk.ChunkRoot);
    end
    return;
end

chunksStartedThisCall = 0;
if p.Results.RunPilot && ~manifest.PilotCompleted && ...
        manifest.SuccessfulScenarios < p.Results.TargetSuccessfulScenarios
    [record, manifest] = localRunOneChunk(manifest, settings, ...
        p.Results.PilotScenarios, 'Pilot');
    chunksStartedThisCall = chunksStartedThisCall + 1;
    manifest = localApplyChunkRecord(manifest, record, settings);
    manifest = localWriteManifest(manifestPath, manifest);
    if strcmp(record.Status, 'Passed')
        manifest.PilotCompleted = true;
        manifest.Pilot = localPilotSummary(record);
        manifest = localWriteManifest(manifestPath, manifest);
    elseif localShouldPause(manifest, settings)
        manifest.Status = 'Paused';
        manifest.PauseReason = 'Pilot hard failure requires repair before production.';
        localWriteRepairQueue(manifest, settings, record);
        manifest = localWriteManifest(manifestPath, manifest);
        return;
    end
    [stopRequested, stopReason] = localStopRequested(settings);
    if stopRequested
        manifest = localMarkStopped(manifest, settings, stopReason);
        manifest = localWriteManifest(manifestPath, manifest);
        return;
    end
end

while manifest.SuccessfulScenarios < p.Results.TargetSuccessfulScenarios && ...
        chunksStartedThisCall < p.Results.MaxChunks
    [stopRequested, stopReason] = localStopRequested(settings);
    if stopRequested
        manifest = localMarkStopped(manifest, settings, stopReason);
        manifest = localWriteManifest(manifestPath, manifest);
        return;
    end
    remaining = p.Results.TargetSuccessfulScenarios - manifest.SuccessfulScenarios;
    chunkScenarios = min(p.Results.ProductionChunkScenarios, remaining);
    [record, manifest] = localRunOneChunk(manifest, settings, ...
        chunkScenarios, 'Production');
    chunksStartedThisCall = chunksStartedThisCall + 1;
    manifest = localApplyChunkRecord(manifest, record, settings);
    manifest = localWriteManifest(manifestPath, manifest);
    if localShouldPause(manifest, settings)
        manifest.Status = 'Paused';
        manifest.PauseReason = 'Repeated or high-rate hard failures detected.';
        localWriteRepairQueue(manifest, settings, record);
        manifest = localWriteManifest(manifestPath, manifest);
        return;
    end
    [stopRequested, stopReason] = localStopRequested(settings);
    if stopRequested
        manifest = localMarkStopped(manifest, settings, stopReason);
        manifest = localWriteManifest(manifestPath, manifest);
        return;
    end
end

[stopRequested, stopReason] = localStopRequested(settings);
if stopRequested
    manifest = localMarkStopped(manifest, settings, stopReason);
elseif manifest.SuccessfulScenarios >= p.Results.TargetSuccessfulScenarios
    manifest.Status = 'Completed';
else
    manifest.Status = 'Running';
end
manifest.UpdatedAtUtc = localUtcNow();
manifest = localWriteManifest(manifestPath, manifest);

if p.Results.Verbose
    fprintf('Massive watchdog status=%s success=%d target=%d manifest=%s\n', ...
        manifest.Status, manifest.SuccessfulScenarios, ...
        p.Results.TargetSuccessfulScenarios, manifestPath);
end
end

function [manifest, recoveredRecord] = localRecoverStaleActiveChunk(manifest, settings)
recoveredRecord = [];
if ~localHasActiveChunk(manifest)
    return;
end

activeChunkId = double(manifest.ActiveChunk.ChunkId);
if localChunkRecordExists(manifest, activeChunkId)
    manifest.ActiveChunk = struct();
    return;
end

chunk = localChunkFromActiveSummary(manifest.ActiveChunk, settings);
if localAnyWorkerRunning(chunk)
    error('CSRD:MassiveWatchdog:ActiveChunkStillRunning', ...
        ['Manifest has active chunk %d and worker MATLAB processes are ', ...
         'still running. Attach to the existing watchdog instead of ', ...
         'starting a second controller.'], chunk.ChunkId);
end

manifest.LastKnownActiveChunk = manifest.ActiveChunk;
recoveredRecord = localEmptyChunkRecord(chunk);
recoveredRecord.StartedAtUtc = localStructCharField( ...
    manifest.ActiveChunk, 'StartedAtUtc', '');
recoveredRecord.FinishedAtUtc = localUtcNow();
recoveredRecord = localCollectWorkerSummaries(recoveredRecord, chunk);
recoveredRecord = localClassifyChunkRecord(recoveredRecord, chunk);
[stopRequested, stopReason] = localStopRequested(settings);
if strcmp(recoveredRecord.Status, 'Failed') && stopRequested
    recoveredRecord.Status = 'RecoveredStopped';
    recoveredRecord.FirstFailure = struct('Detected', false, ...
        'Signature', 'RecoveredStopped', ...
        'Message', sprintf(['Active chunk %d was left Running in the ', ...
            'manifest after an external stop request. Observed %d/%d ', ...
            'successful scenarios; incomplete outputs were not counted as ', ...
            'successful. %s'], chunk.ChunkId, ...
            recoveredRecord.SuccessfulScenarios, chunk.NumScenarios, ...
            stopReason));
elseif strcmp(recoveredRecord.Status, 'Failed')
    recoveredRecord.FirstFailure = struct('Detected', true, ...
        'Signature', 'StaleActiveChunk', ...
        'Message', sprintf(['Active chunk %d was left Running in the ', ...
            'manifest but no worker MATLAB processes are alive. Observed ', ...
            '%d/%d successful scenarios; treating incomplete outputs as ', ...
            'failed.'], chunk.ChunkId, recoveredRecord.SuccessfulScenarios, ...
            chunk.NumScenarios));
end
recoveredRecord = localAuditChunk(recoveredRecord, chunk, settings);
if strcmp(recoveredRecord.Status, 'Passed') && ...
        strcmpi(settings.RetentionMode, 'AuditOnly')
    [recoveredRecord, manifest] = localRetainReservoirSamples( ...
        recoveredRecord, manifest, chunk, settings);
    if settings.CleanupSuccessOutputs
        recoveredRecord.CleanupStatus = localCleanupSuccessfulOutputs( ...
            chunk, settings);
    end
end
localWriteChunkRecord(chunk, recoveredRecord);
manifest = localApplyChunkRecord(manifest, recoveredRecord, settings);
end

function tf = localHasActiveChunk(manifest)
tf = isstruct(manifest) && isfield(manifest, 'ActiveChunk') && ...
    isstruct(manifest.ActiveChunk) && ...
    isfield(manifest.ActiveChunk, 'ChunkId') && ...
    ~isempty(manifest.ActiveChunk.ChunkId) && ...
    isnumeric(manifest.ActiveChunk.ChunkId) && ...
    isfinite(double(manifest.ActiveChunk.ChunkId));
end

function manifest = localMarkStopped(manifest, settings, reason)
if nargin < 3 || isempty(reason)
    reason = 'Stop requested.';
end
if localHasActiveChunk(manifest)
    manifest.LastKnownActiveChunk = manifest.ActiveChunk;
end
manifest.Status = 'Stopped';
manifest.StoppedAtUtc = localUtcNow();
manifest.StopReason = char(string(reason));
manifest.ActiveChunk = struct();
manifest.Settings = settings;
manifest.UpdatedAtUtc = localUtcNow();
end

function [tf, reason] = localStopRequested(settings)
tf = false;
reason = '';
if ~isstruct(settings) || ~isfield(settings, 'StopSignalFile') || ...
        isempty(settings.StopSignalFile)
    return;
end
stopPath = char(string(settings.StopSignalFile));
if ~isfile(stopPath)
    return;
end
tf = true;
reason = sprintf('Stop signal file detected: %s', stopPath);
try
    payload = jsondecode(localReadText(stopPath));
    if isstruct(payload)
        if isfield(payload, 'Reason') && ~isempty(payload.Reason)
            reason = char(string(payload.Reason));
        elseif isfield(payload, 'StopReason') && ~isempty(payload.StopReason)
            reason = char(string(payload.StopReason));
        end
    end
catch
end
end

function tf = localChunkRecordExists(manifest, chunkId)
tf = false;
if ~isstruct(manifest) || ~isfield(manifest, 'ChunkRecords') || ...
        isempty(manifest.ChunkRecords)
    return;
end
for idx = 1:numel(manifest.ChunkRecords)
    if isfield(manifest.ChunkRecords(idx), 'ChunkId') && ...
            isequal(double(manifest.ChunkRecords(idx).ChunkId), double(chunkId))
        tf = true;
        return;
    end
end
end

function chunk = localChunkFromActiveSummary(active, settings)
chunkId = double(active.ChunkId);
chunkName = localStructCharField(active, 'ChunkName', ...
    sprintf('chunk_%06d', chunkId));
chunkRoot = localStructCharField(active, 'ChunkRoot', ...
    fullfile(settings.ArtifactRoot, 'chunks', chunkName));
dataChunkRoot = localStructCharField(active, 'DataChunkRoot', ...
    fullfile(settings.ProjectRoot, 'data', 'CSRD2025_massive', ...
    chunkName));
numScenarios = localStructDoubleField(active, 'NumScenarios', 0);
seed = localStructDoubleField(active, 'Seed', NaN);
chunkType = localStructCharField(active, 'ChunkType', 'Recovered');

workers = repmat(localEmptyWorker(), 1, settings.NumWorkers);
for workerId = 1:settings.NumWorkers
    [startScenario, endScenario, scenarioCount] = localScenarioDistribution( ...
        numScenarios, workerId, settings.NumWorkers);
    workers(workerId) = struct( ...
        'WorkerId', workerId, ...
        'ConfigPath', fullfile(settings.ArtifactRoot, ...
            'generated_configs', sprintf( ...
            'massive_chunk_%06d_worker_%03d.m', chunkId, workerId)), ...
        'OutputDirectory', '', ...
        'DataRoot', fullfile(dataChunkRoot, ...
            sprintf('worker_%03d', workerId)), ...
        'StdoutPath', fullfile(chunkRoot, 'worker_stdout', ...
            sprintf('worker_%03d_stdout.log', workerId)), ...
        'StderrPath', fullfile(chunkRoot, 'worker_stdout', ...
            sprintf('worker_%03d_stderr.log', workerId)), ...
        'Pid', NaN, ...
        'StartScenario', startScenario, ...
        'EndScenario', endScenario, ...
        'ScenarioCount', scenarioCount);
end

chunk = struct('ChunkId', chunkId, ...
    'ChunkType', chunkType, ...
    'ChunkName', chunkName, ...
    'ChunkRoot', chunkRoot, ...
    'DataChunkRoot', dataChunkRoot, ...
    'NumScenarios', double(numScenarios), ...
    'Seed', double(seed), ...
    'Workers', workers, ...
    'StartedAtUtc', localStructCharField(active, 'StartedAtUtc', ''), ...
    'FinishedAtUtc', '');
end

function tf = localAnyWorkerRunning(chunk)
tf = false;
for idx = 1:numel(chunk.Workers)
    if localIsWorkerRunning(chunk.Workers(idx))
        tf = true;
        return;
    end
end
end

function [record, manifest] = localRunOneChunk(manifest, settings, numScenarios, chunkType)
[chunk, manifest] = localPrepareChunk(manifest, settings, numScenarios, chunkType);
localWriteChunkState(chunk, 'Prepared');
manifest.ActiveChunk = localActiveChunkSummary(chunk);
manifest.Status = 'Running';
manifest = localWriteManifest(settings.ManifestPath, manifest);
if strcmpi(settings.LaunchMode, 'Subprocess')
    record = localRunSubprocessChunk(chunk, settings);
else
    record = localRunMockChunk(chunk, settings);
end
record = localAuditChunk(record, chunk, settings);
if strcmp(record.Status, 'Passed') && strcmpi(settings.RetentionMode, 'AuditOnly')
    [record, manifest] = localRetainReservoirSamples(record, manifest, chunk, settings);
    if settings.CleanupSuccessOutputs
        record.CleanupStatus = localCleanupSuccessfulOutputs(chunk, settings);
    end
end
localWriteChunkRecord(chunk, record);
end

function [chunk, manifest] = localPrepareChunk(manifest, settings, numScenarios, chunkType)
chunkId = manifest.NextChunkId;
seed = localNextSeed(manifest);
chunkName = sprintf('chunk_%06d', chunkId);
chunkRoot = fullfile(settings.ArtifactRoot, 'chunks', chunkName);
dataChunkRelRoot = sprintf('CSRD2025_massive/%s/%s', ...
    manifest.RunId, chunkName);
dataChunkRoot = fullfile(settings.ProjectRoot, 'data', dataChunkRelRoot);
localEnsureDirectory(chunkRoot);
localEnsureDirectory(fullfile(chunkRoot, 'logs'));
localEnsureDirectory(fullfile(chunkRoot, 'performance'));
localEnsureDirectory(fullfile(chunkRoot, 'worker_stdout'));

workers = repmat(localEmptyWorker(), 1, settings.NumWorkers);
for workerId = 1:settings.NumWorkers
    workerOutput = sprintf('%s/worker_%03d', dataChunkRelRoot, workerId);
    configPath = localWriteWorkerConfig(settings, chunkRoot, chunkId, ...
        workerId, numScenarios, seed, workerOutput);
    [startScenario, endScenario, scenarioCount] = localScenarioDistribution( ...
        numScenarios, workerId, settings.NumWorkers);
    workers(workerId) = struct( ...
        'WorkerId', workerId, ...
        'ConfigPath', configPath, ...
        'OutputDirectory', workerOutput, ...
        'DataRoot', fullfile(settings.ProjectRoot, 'data', workerOutput), ...
        'StdoutPath', fullfile(chunkRoot, 'worker_stdout', ...
            sprintf('worker_%03d_stdout.log', workerId)), ...
        'StderrPath', fullfile(chunkRoot, 'worker_stdout', ...
            sprintf('worker_%03d_stderr.log', workerId)), ...
        'Pid', NaN, ...
        'StartScenario', startScenario, ...
        'EndScenario', endScenario, ...
        'ScenarioCount', scenarioCount);
end

chunk = struct( ...
    'ChunkId', chunkId, ...
    'ChunkType', char(string(chunkType)), ...
    'ChunkName', chunkName, ...
    'ChunkRoot', chunkRoot, ...
    'DataChunkRoot', dataChunkRoot, ...
    'NumScenarios', double(numScenarios), ...
    'Seed', double(seed), ...
    'Workers', workers, ...
    'StartedAtUtc', '', ...
    'FinishedAtUtc', '');
manifest.NextChunkId = manifest.NextChunkId + 1;
manifest.LastSeed = seed;
end

function record = localRunSubprocessChunk(chunk, settings)
record = localEmptyChunkRecord(chunk);
record.StartedAtUtc = localUtcNow();
for idx = 1:numel(chunk.Workers)
    worker = chunk.Workers(idx);
    if worker.ScenarioCount <= 0
        continue;
    end
    [pid, launchScript] = localStartWorkerProcess(worker, settings, chunk);
    chunk.Workers(idx).Pid = pid;
    chunk.Workers(idx).LaunchScript = launchScript;
end
localWriteChunkState(chunk, 'Running');

hardFailure = struct('Detected', false, 'Signature', '', 'Message', '');
stopRequested = false;
while true
    running = false;
    for idx = 1:numel(chunk.Workers)
        if localIsWorkerRunning(chunk.Workers(idx))
            running = true;
        end
    end
    hardFailure = localDetectHardFailure(chunk, settings);
    if hardFailure.Detected
        localStopWorkers(chunk.Workers);
        break;
    end
    if ~stopRequested
        [stopRequested, ~] = localStopRequested(settings);
        if stopRequested
            localWriteChunkState(chunk, 'StopRequested');
        end
    end
    if ~running
        break;
    end
    pause(max(0.1, settings.MonitorIntervalSec));
end

record.FinishedAtUtc = localUtcNow();
record = localCollectWorkerSummaries(record, chunk);
if hardFailure.Detected
    record.Status = 'Failed';
    record.FirstFailure = hardFailure;
else
    record = localClassifyChunkRecord(record, chunk);
end
end

function record = localRunMockChunk(chunk, settings)
record = localEmptyChunkRecord(chunk);
record.StartedAtUtc = localUtcNow();
shouldFail = strcmpi(settings.LaunchMode, 'MockFailureOnce') && chunk.ChunkId == 1;
shouldRayTracingFail = strcmpi(settings.LaunchMode, 'MockRayTracingFailureOnce') && ...
    chunk.ChunkId == 1;
shouldSpectrumFail = strcmpi(settings.LaunchMode, 'MockSpectrumFailureOnce') && ...
    chunk.ChunkId == 1;
for idx = 1:numel(chunk.Workers)
    worker = chunk.Workers(idx);
    localEnsureDirectory(fullfile(worker.DataRoot, 'session_mock', 'logs'));
    localEnsureDirectory(fullfile(worker.DataRoot, 'session_mock', 'scenarios'));
    localEnsureDirectory(fullfile(worker.DataRoot, 'session_mock', 'annotations'));
    logPath = fullfile(worker.DataRoot, 'session_mock', 'logs', ...
        sprintf('CSRD_mock_worker_%03d.log', worker.WorkerId));
    if shouldFail && idx == 1
        localWriteText(logPath, ['ERROR CSRD:SimulationFailed mock failure', newline]);
        localWriteText(worker.StderrPath, 'mock failure');
    elseif shouldRayTracingFail && idx == 1
        localWriteText(logPath, ['WARNING RayTracing failed for map mode OSMBuildings; ', ...
            'applying FreeSpaceAttenuation fallback. Error: mock column mismatch', newline]);
        localWriteText(worker.StderrPath, 'mock ray tracing failure');
    elseif shouldSpectrumFail && idx == 1
        localWriteText(logPath, ['ERROR CSRD:Spectrum:NoUsableChannel ', ...
            'Band CN_SRD_433 cannot fit bandwidth 100000 Hz in receiver window.', newline]);
        localWriteText(worker.StderrPath, 'mock spectrum placement failure');
    else
        localWriteMockScenarioFiles(worker);
        localWriteText(logPath, sprintf(['Worker %d simulation completed:\n', ...
            '  Successful scenarios: %d\n  Failed scenarios: 0\n', ...
            '  Skipped scenarios: 0\n'], worker.WorkerId, worker.ScenarioCount));
        localWriteText(worker.StdoutPath, 'mock success');
    end
end
record.FinishedAtUtc = localUtcNow();
record = localCollectWorkerSummaries(record, chunk);
if shouldFail
    record.Status = 'Failed';
    record.FirstFailure = struct('Detected', true, ...
        'Signature', 'CSRD:SimulationFailed mock failure', ...
        'Message', 'mock failure');
elseif shouldRayTracingFail
    record.Status = 'Failed';
    record.FirstFailure = struct('Detected', true, ...
        'Signature', 'RayTracing failed for map mode OSMBuildings', ...
        'Message', 'mock ray tracing failure');
elseif shouldSpectrumFail
    record.Status = 'Failed';
    record.FirstFailure = struct('Detected', true, ...
        'Signature', 'CSRD:Spectrum:NoUsableChannel', ...
        'Message', 'mock spectrum placement failure');
else
    record = localClassifyChunkRecord(record, chunk);
end
end

function record = localAuditChunk(record, chunk, settings)
record.LogAudit = localAuditLogs(chunk);
record.AnnotationAudit = localAuditAnnotations(chunk, settings);
record.OsmFileCoverageCounts = localCollectOsmCoverage(chunk);
record.PerformanceSummary = localCollectPerformanceSummary(chunk);
record.SlowScenarioSummary = localCollectSlowScenarioSummary(chunk);
localWriteSlowScenarioArtifacts(chunk, record.SlowScenarioSummary);
if record.LogAudit.TotalHardFailures > 0 || record.AnnotationAudit.InvalidMeasured > 0
    record.Status = 'Failed';
    if ~isfield(record.FirstFailure, 'Detected') || ~record.FirstFailure.Detected
        record.FirstFailure = record.LogAudit.FirstFailure;
    end
end
if strcmp(record.Status, 'Failed')
    record.FailureArtifact = localArchiveFailure(record, chunk, settings);
end
end

function record = localClassifyChunkRecord(record, chunk)
expected = chunk.NumScenarios;
if record.FailedScenarios == 0 && record.SkippedScenarios == 0 && ...
        record.SuccessfulScenarios == expected
    record.Status = 'Passed';
else
    record.Status = 'Failed';
    record.FirstFailure = struct('Detected', true, ...
        'Signature', 'IncompleteChunk', ...
        'Message', sprintf(['Chunk expected %d successes but observed ', ...
        '%d success, %d failed, %d skipped.'], expected, ...
        record.SuccessfulScenarios, record.FailedScenarios, record.SkippedScenarios));
end
end

function manifest = localApplyChunkRecord(manifest, record, settings)
manifest.UpdatedAtUtc = localUtcNow();
manifest.TotalChunks = manifest.TotalChunks + 1;
manifest.ChunkRecords(end + 1) = record;
if strcmp(record.Status, 'Passed')
    manifest.SuccessfulScenarios = manifest.SuccessfulScenarios + ...
        record.SuccessfulScenarios;
    manifest.LastConsecutiveFailureSignature = '';
    manifest.ConsecutiveFailureCount = 0;
elseif strcmp(record.Status, 'RecoveredStopped')
    manifest.LastConsecutiveFailureSignature = '';
    manifest.ConsecutiveFailureCount = 0;
else
    manifest.FailedChunks = manifest.FailedChunks + 1;
    sig = localFailureSignature(record);
    if strcmp(sig, manifest.LastConsecutiveFailureSignature)
        manifest.ConsecutiveFailureCount = manifest.ConsecutiveFailureCount + 1;
    else
        manifest.LastConsecutiveFailureSignature = sig;
        manifest.ConsecutiveFailureCount = 1;
    end
end
manifest.AttemptedScenarios = manifest.AttemptedScenarios + record.NumScenarios;
manifest.Settings = settings;
manifest.ActiveChunk = struct();
end

function tf = localShouldPause(manifest, settings)
tf = false;
if manifest.ConsecutiveFailureCount >= settings.MaxConsecutiveFailureSignature
    tf = true;
    return;
end
if manifest.TotalChunks > 0
    failureRate = manifest.FailedChunks / manifest.TotalChunks;
    tf = failureRate > settings.MaxFailureRate && manifest.FailedChunks >= 3;
end
if localDiskFreeBytes(settings.ProjectRoot) < settings.DiskFreePauseBytes
    tf = true;
end
end

function configPath = localWriteWorkerConfig(settings, chunkRoot, chunkId, ...
        workerId, numScenarios, seed, workerOutput)
configDir = fullfile(settings.ArtifactRoot, 'generated_configs');
localEnsureDirectory(configDir);
functionName = sprintf('massive_chunk_%06d_worker_%03d', chunkId, workerId);
configPath = fullfile(configDir, [functionName, '.m']);
fid = fopen(configPath, 'w');
if fid == -1
    error('CSRD:MassiveWatchdog:ConfigOpenFailed', ...
        'Could not write config: %s', configPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function config = %s()\n', functionName);
fprintf(fid, 'config.baseConfigs = {''%s''};\n', localEscape(settings.BaseConfig));
fprintf(fid, 'config.Runner.NumScenarios = %d;\n', numScenarios);
fprintf(fid, 'config.Runner.RandomSeed = %d;\n', seed);
fprintf(fid, 'config.Runner.Data.OutputDirectory = ''%s'';\n', localEscape(workerOutput));
fprintf(fid, 'config.Runner.Data.PrettyPrintAnnotations = false;\n');
fprintf(fid, 'config.Runner.Log.Policy = ''LargeMC'';\n');
fprintf(fid, 'config.Runner.Performance.EnableStageTiming = true;\n');
fprintf(fid, 'config.Runner.Performance.EnableHeartbeat = true;\n');
fprintf(fid, 'config.Runner.Performance.RawEventLimit = 2000;\n');
fprintf(fid, 'config.Runner.Performance.PartialWriteInterval = 50;\n');
fprintf(fid, 'config.Runner.Performance.ArtifactDirectory = ''%s'';\n', ...
    localEscape(fullfile(chunkRoot, 'performance', ...
    sprintf('worker_%03d', workerId))));
fprintf(fid, 'config.Log.Level = ''INFO'';\n');
fprintf(fid, 'config.Log.DisplayInConsole = false;\n');
fprintf(fid, 'config.Metadata.MassiveAudit.ChunkId = %d;\n', chunkId);
fprintf(fid, 'config.Metadata.MassiveAudit.WorkerId = %d;\n', workerId);
fprintf(fid, 'end\n');
clear cleanup;
end

function [pid, scriptPath] = localStartWorkerProcess(worker, settings, chunk)
scriptPath = fullfile(chunk.ChunkRoot, sprintf('start_worker_%03d.ps1', ...
    worker.WorkerId));
cmdPath = fullfile(chunk.ChunkRoot, sprintf('run_worker_%03d.cmd', ...
    worker.WorkerId));
matlabCommand = sprintf("cd('%s'); addpath(fullfile(pwd,'tools')); simulation(%d,%d,'%s');", ...
    localEscape(settings.ProjectRoot), worker.WorkerId, settings.NumWorkers, ...
    localEscape(worker.ConfigPath));
cmdFid = fopen(cmdPath, 'w');
if cmdFid == -1
    error('CSRD:MassiveWatchdog:LaunchScriptOpenFailed', ...
        'Could not write worker command script: %s', cmdPath);
end
cmdCleanup = onCleanup(@() fclose(cmdFid));
fprintf(cmdFid, '@echo off\r\n');
fprintf(cmdFid, 'cd /d "%s"\r\n', settings.ProjectRoot);
fprintf(cmdFid, 'matlab -batch "%s" > "%s" 2> "%s"\r\n', ...
    strrep(char(matlabCommand), '"', '\"'), worker.StdoutPath, worker.StderrPath);
fprintf(cmdFid, 'exit /b %%ERRORLEVEL%%\r\n');
clear cmdCleanup;
fid = fopen(scriptPath, 'w');
if fid == -1
    error('CSRD:MassiveWatchdog:LaunchScriptOpenFailed', ...
        'Could not write launch script: %s', scriptPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '$argsList = @(''/c'', ''%s'')\n', ...
    localPowerShellSingleQuoted(['"', cmdPath, '"']));
fprintf(fid, '$p = Start-Process -FilePath ''cmd.exe'' -ArgumentList $argsList ');
fprintf(fid, '-WindowStyle Hidden -PassThru\n');
fprintf(fid, 'Write-Output $p.Id\n');
clear cleanup;
[status, output] = system(sprintf(['powershell -NoProfile -ExecutionPolicy ', ...
    'Bypass -File "%s"'], scriptPath));
if status ~= 0
    error('CSRD:MassiveWatchdog:WorkerLaunchFailed', ...
        'Failed to launch worker %d: %s', worker.WorkerId, output);
end
pid = str2double(strtrim(output));
if ~isfinite(pid) || pid <= 0
    error('CSRD:MassiveWatchdog:WorkerPidMissing', ...
        'Worker %d did not return a process id. Output: %s', ...
        worker.WorkerId, output);
end
end

function tf = localIsWorkerRunning(worker)
tf = false;
if ~isempty(localFindWorkerProcessIds(worker))
    tf = true;
    return;
end
if isfield(worker, 'Pid') && isfinite(worker.Pid) && worker.Pid > 0 && ...
        localIsProcessRunning(worker.Pid) && ~localWorkerSummaryComplete(worker)
    tf = true;
end
end

function tf = localIsProcessRunning(pid)
if ~isfinite(pid) || pid <= 0
    tf = false;
    return;
end
[~, output] = system(sprintf(['powershell -NoProfile -Command ', ...
    '"$p = Get-Process -Id %d -ErrorAction SilentlyContinue; ', ...
    'if ($null -eq $p) { Write-Output 0 } else { Write-Output 1 }"'], pid));
tf = strcmp(strtrim(output), '1');
end

function localStopWorkers(workers)
for idx = 1:numel(workers)
    pids = [];
    if isfield(workers(idx), 'Pid') && isfinite(workers(idx).Pid) && ...
            workers(idx).Pid > 0
        pids(end + 1) = workers(idx).Pid; %#ok<AGROW>
    end
    pids = unique([pids, localFindWorkerProcessIds(workers(idx))]);
    for pidIdx = 1:numel(pids)
        pid = pids(pidIdx);
        system(sprintf(['powershell -NoProfile -Command ', ...
            '"Stop-Process -Id %d -Force -ErrorAction SilentlyContinue"'], pid));
    end
end
end

function pids = localFindWorkerProcessIds(worker)
pids = [];
if ~isstruct(worker) || ~isfield(worker, 'ConfigPath') || isempty(worker.ConfigPath)
    return;
end
needle = char(string(worker.ConfigPath));
ps = ['$needle = ''', localPowerShellSingleQuoted(needle), '''; ', ...
    'Get-CimInstance Win32_Process -Filter "Name = ''MATLAB.exe''" ', ...
    '| Where-Object { $_.CommandLine -and ', ...
    '$_.CommandLine.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 } ', ...
    '| ForEach-Object { $_.ProcessId }'];
[status, output] = system(['powershell -NoProfile -Command "', ...
    strrep(ps, '"', '\"'), '"']);
if status ~= 0 || isempty(strtrim(output))
    return;
end
tokens = regexp(output, '\d+', 'match');
if isempty(tokens)
    return;
end
pids = unique(str2double(tokens));
pids = pids(isfinite(pids));
end

function failure = localDetectHardFailure(chunk, settings)
failure = struct('Detected', false, 'Signature', '', 'Message', '');
audit = localAuditLogs(chunk);
if audit.TotalHardFailures > 0
    failure = audit.FirstFailure;
    return;
end
if localDiskFreeBytes(settings.ProjectRoot) < settings.DiskFreePauseBytes
    failure = struct('Detected', true, 'Signature', 'DiskFreeBelowGuard', ...
        'Message', 'Disk free space is below configured guard threshold.');
end
end

function audit = localAuditLogs(chunk)
patterns = {'ERROR', 'CSRD:SimulationFailed', 'FrameWindow', ...
    'detectBurstEnvelope', 'Measurement failed', 'CSRD:Annotation:', ...
    'CSRD:Construction:', 'CSRD:Spectrum:', ...
    'CSRD:RuntimeTruth:', 'CSRD:Channel:', 'CSRD:Receiver:', ...
    'CSRD:Modulation:', 'DeprecatedOsmSizeCap', ...
    'Transmitter frequency does not meet', 'Insufficient bandwidth', ...
    'RayTracing failed', 'Unable to find material', 'isvalid', ...
    'MissingExecutionBandwidth', 'NonPositiveCleanObw', ...
    'cannot fit bandwidth', 'Unable to access terrain', 'gmted2010'};
allowed = {'OSM file has no building data'};
files = [localListFiles(chunk.ChunkRoot, '*.log'); ...
    localListFiles(fullfile(chunk.ChunkRoot, 'worker_stdout'), '*.log')];
for workerIdx = 1:numel(chunk.Workers)
    files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, '*.log')]; %#ok<AGROW>
end
first = struct('Detected', false, 'Signature', '', 'Message', '');
count = 0;
for idx = 1:numel(files)
    text = localReadText(files{idx});
    lines = splitlines(string(text));
    for lineIdx = 1:numel(lines)
        line = char(lines(lineIdx));
        if isempty(line) || any(contains(line, allowed))
            continue;
        end
        if any(contains(line, patterns))
            count = count + 1;
            if ~first.Detected
                first = struct('Detected', true, ...
                    'Signature', localNormalizeFailureSignature(line), ...
                    'Message', line);
            end
        end
    end
end
audit = struct('FilesScanned', numel(files), ...
    'TotalHardFailures', count, 'FirstFailure', first);
end

function record = localCollectWorkerSummaries(record, chunk)
for idx = 1:numel(chunk.Workers)
    worker = chunk.Workers(idx);
    logs = localListFiles(worker.DataRoot, '*.log');
    summary = localParseCompletionSummary(logs);
    record.Workers(idx).WorkerId = worker.WorkerId;
    record.Workers(idx).SuccessfulScenarios = summary.Successful;
    record.Workers(idx).FailedScenarios = summary.Failed;
    record.Workers(idx).SkippedScenarios = summary.Skipped;
    record.Workers(idx).LogFiles = logs;
    record.SuccessfulScenarios = record.SuccessfulScenarios + summary.Successful;
    record.FailedScenarios = record.FailedScenarios + summary.Failed;
    record.SkippedScenarios = record.SkippedScenarios + summary.Skipped;
end
end

function summary = localParseCompletionSummary(logFiles)
summary = struct('Successful', 0, 'Failed', 0, 'Skipped', 0);
for idx = 1:numel(logFiles)
    text = localReadText(logFiles{idx});
    summary.Successful = max(summary.Successful, ...
        localParseLastInteger(text, 'Successful scenarios:\s*(\d+)'));
    summary.Failed = max(summary.Failed, ...
        localParseLastInteger(text, 'Failed scenarios:\s*(\d+)'));
    summary.Skipped = max(summary.Skipped, ...
        localParseLastInteger(text, 'Skipped scenarios:\s*(\d+)'));
end
end

function tf = localWorkerSummaryComplete(worker)
tf = false;
if ~isstruct(worker) || ~isfield(worker, 'ScenarioCount') || ...
        worker.ScenarioCount <= 0 || ~isfield(worker, 'DataRoot')
    return;
end
logs = localListFiles(worker.DataRoot, '*.log');
summary = localParseCompletionSummary(logs);
tf = summary.Successful + summary.Failed + summary.Skipped >= ...
    worker.ScenarioCount;
end

function value = localParseLastInteger(text, pattern)
tokens = regexp(text, pattern, 'tokens');
value = 0;
if ~isempty(tokens)
    value = str2double(tokens{end}{1});
end
end

function audit = localAuditAnnotations(chunk, settings)
files = {};
for workerIdx = 1:numel(chunk.Workers)
    files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, ...
        '*annotation.json')]; %#ok<AGROW>
end
invalid = 0;
checked = 0;
for idx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{idx}));
        checked = checked + 1;
        if localAnnotationHasInvalidMeasured(payload)
            invalid = invalid + 1;
        end
    catch
        invalid = invalid + 1;
    end
end
audit = struct('FilesScanned', numel(files), 'FilesChecked', checked, ...
    'InvalidMeasured', invalid);
end

function tf = localAnnotationHasInvalidMeasured(value)
tf = false;
if isstruct(value)
    for elemIdx = 1:numel(value)
        item = value(elemIdx);
        if isfield(item, 'MeasurementStatus') && ...
                strcmpi(char(string(item.MeasurementStatus)), 'Measured')
            fields = {'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
                'TimeOccupancy', 'FrequencyOccupancy'};
            for idx = 1:numel(fields)
                if isfield(item, fields{idx}) && ...
                        (~isnumeric(item.(fields{idx})) || ...
                        any(~isfinite(item.(fields{idx})(:))))
                    tf = true;
                    return;
                end
            end
        end
        names = fieldnames(item);
        for idx = 1:numel(names)
            if localAnnotationHasInvalidMeasured(item.(names{idx}))
                tf = true;
                return;
            end
        end
    end
elseif iscell(value)
    for idx = 1:numel(value)
        if localAnnotationHasInvalidMeasured(value{idx})
            tf = true;
            return;
        end
    end
end
end

function counts = localCollectOsmCoverage(chunk)
files = {};
for workerIdx = 1:numel(chunk.Workers)
    files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, ...
        '*annotation.json')]; %#ok<AGROW>
end
counts = struct('OSMFile', {}, 'Count', {});
for idx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{idx}));
        osmFiles = localExtractFieldValues(payload, 'OSMFile');
        for k = 1:numel(osmFiles)
            counts = localIncrementCount(counts, char(string(osmFiles{k})));
        end
    catch
    end
end
end

function summary = localCollectPerformanceSummary(chunk)
files = localListFiles(fullfile(chunk.ChunkRoot, 'performance'), '*.json');
summary = struct('TraceFiles', numel(files), 'StageCount', 0);
for idx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{idx}));
        if isfield(payload, 'Events')
            summary.StageCount = summary.StageCount + numel(payload.Events);
        end
    catch
    end
end
end

function summary = localCollectSlowScenarioSummary(chunk)
records = localParseScenarioProgressLogs(chunk);
records = localAttachAnnotationMetadata(records, chunk);
if ~isempty(records)
    [~, order] = sort([records.DurationSec], 'descend');
    records = records(order);
end
topCount = min(20, numel(records));
if topCount > 0
    topRecords = records(1:topCount);
else
    topRecords = localEmptySlowScenarioRecord();
    topRecords = topRecords([]);
end
if isempty(records)
    maxScenarioSec = 0;
    meanScenarioSec = 0;
else
    durations = [records.DurationSec];
    maxScenarioSec = max(durations);
    meanScenarioSec = mean(durations);
end
summary = struct( ...
    'Schema', 'csrd.phase28.slow-scenario-summary.v1', ...
    'GeneratedAtUtc', localUtcNow(), ...
    'ChunkId', chunk.ChunkId, ...
    'ChunkType', chunk.ChunkType, ...
    'ScenarioRecords', numel(records), ...
    'MaxScenarioSec', maxScenarioSec, ...
    'MeanScenarioSec', meanScenarioSec, ...
    'TopSlowScenarios', topRecords);
end

function records = localParseScenarioProgressLogs(chunk)
records = localEmptySlowScenarioRecord();
records = records([]);
files = [localListFiles(chunk.ChunkRoot, '*.log'); ...
    localListFiles(fullfile(chunk.ChunkRoot, 'worker_stdout'), '*.log')];
for workerIdx = 1:numel(chunk.Workers)
    files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, '*.log')]; %#ok<AGROW>
end
pattern = ['Worker\s+(\d+)\s+\[([A-Z]+)\]:\s+Scenario\s+(\d+)/(\d+)', ...
    '\s+\(ID:\s*(\d+)\)\s+\|\s+Time:\s*([0-9.]+)s'];
for fileIdx = 1:numel(files)
    text = localReadText(files{fileIdx});
    tokens = regexp(text, pattern, 'tokens');
    for tokenIdx = 1:numel(tokens)
        tok = tokens{tokenIdx};
        item = localEmptySlowScenarioRecord();
        item.WorkerId = str2double(tok{1});
        item.Status = tok{2};
        item.ScenarioIndex = str2double(tok{3});
        item.WorkerScenarioCount = str2double(tok{4});
        item.ScenarioId = str2double(tok{5});
        item.DurationSec = str2double(tok{6});
        item.LogFile = files{fileIdx};
        records(end + 1) = item; %#ok<AGROW>
    end
end
end

function records = localAttachAnnotationMetadata(records, chunk)
if isempty(records)
    return;
end
metadata = localCollectAnnotationScenarioMetadata(chunk);
for idx = 1:numel(records)
    metaIdx = find([metadata.ScenarioId] == records(idx).ScenarioId, 1);
    if ~isempty(metaIdx)
        records(idx).OSMFile = metadata(metaIdx).OSMFile;
        records(idx).MapMode = metadata(metaIdx).MapMode;
        records(idx).HasBuildings = metadata(metaIdx).HasBuildings;
        records(idx).OSMFileSizeMB = metadata(metaIdx).OSMFileSizeMB;
    end
end
end

function metadata = localCollectAnnotationScenarioMetadata(chunk)
metadata = localEmptyAnnotationScenarioMetadata();
metadata = metadata([]);
files = {};
for workerIdx = 1:numel(chunk.Workers)
    files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, ...
        '*annotation.json')]; %#ok<AGROW>
end
for idx = 1:numel(files)
    scenarioId = localScenarioIdFromAnnotationPath(files{idx});
    try
        payload = jsondecode(localReadText(files{idx}));
        if ~isfinite(scenarioId)
            scenarioId = localFirstNumericField(payload, {'ScenarioId', 'ScenarioID'});
        end
        profiles = localExtractFieldValues(payload, 'MapProfile');
        profile = struct();
        if ~isempty(profiles) && isstruct(profiles{1})
            profile = profiles{1};
        end
        item = localEmptyAnnotationScenarioMetadata();
        item.ScenarioId = scenarioId;
        item.OSMFile = localStructCharField(profile, 'OSMFile', '');
        item.MapMode = localStructCharField(profile, 'Mode', '');
        item.HasBuildings = localStructLogicalField(profile, 'HasBuildings', false);
        item.OSMFileSizeMB = localStructDoubleField(profile, 'OSMFileSizeMB', NaN);
        metadata(end + 1) = item; %#ok<AGROW>
    catch
    end
end
end

function scenarioId = localScenarioIdFromAnnotationPath(pathText)
scenarioId = NaN;
tokens = regexp(char(string(pathText)), ...
    'scenario_(\d+)_annotation\.json$', 'tokens', 'once');
if ~isempty(tokens)
    scenarioId = str2double(tokens{1});
end
end

function value = localFirstNumericField(payload, names)
value = NaN;
for idx = 1:numel(names)
    values = localExtractFieldValues(payload, names{idx});
    if ~isempty(values) && isnumeric(values{1}) && isscalar(values{1})
        value = double(values{1});
        return;
    end
end
end

function item = localEmptySlowScenarioRecord()
item = struct('WorkerId', NaN, 'Status', '', 'ScenarioIndex', NaN, ...
    'WorkerScenarioCount', NaN, 'ScenarioId', NaN, 'DurationSec', NaN, ...
    'OSMFile', '', 'MapMode', '', 'HasBuildings', false, ...
    'OSMFileSizeMB', NaN, 'LogFile', '');
end

function item = localEmptyAnnotationScenarioMetadata()
item = struct('ScenarioId', NaN, 'OSMFile', '', 'MapMode', '', ...
    'HasBuildings', false, 'OSMFileSizeMB', NaN);
end

function value = localStructCharField(source, fieldName, defaultValue)
value = defaultValue;
if isstruct(source) && isfield(source, fieldName) && ~isempty(source.(fieldName))
    value = char(string(source.(fieldName)));
end
end

function value = localStructLogicalField(source, fieldName, defaultValue)
value = logical(defaultValue);
if isstruct(source) && isfield(source, fieldName) && ~isempty(source.(fieldName))
    raw = source.(fieldName);
    if islogical(raw) && isscalar(raw)
        value = raw;
    elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
        value = raw ~= 0;
    elseif ischar(raw) || (isstring(raw) && isscalar(raw))
        value = any(strcmpi(char(string(raw)), {'true', 'yes', 'on', '1'}));
    end
end
end

function value = localStructDoubleField(source, fieldName, defaultValue)
value = defaultValue;
if isstruct(source) && isfield(source, fieldName) && ...
        isnumeric(source.(fieldName)) && isscalar(source.(fieldName)) && ...
        isfinite(source.(fieldName))
    value = double(source.(fieldName));
end
end

function localWriteSlowScenarioArtifacts(chunk, summary)
if isempty(summary)
    return;
end
if strcmpi(char(string(chunk.ChunkType)), 'Pilot')
    baseName = 'pilot_slow_scenarios';
else
    baseName = 'slow_scenarios';
end
localWriteJson(fullfile(chunk.ChunkRoot, [baseName, '.json']), summary);
localWriteText(fullfile(chunk.ChunkRoot, [baseName, '.md']), ...
    localSlowScenarioMarkdown(summary));
end

function text = localSlowScenarioMarkdown(summary)
lines = {};
lines{end + 1} = sprintf('# Phase 28 Slow Scenario Summary'); %#ok<AGROW>
lines{end + 1} = ''; %#ok<AGROW>
lines{end + 1} = sprintf('- Generated: `%s`', summary.GeneratedAtUtc); %#ok<AGROW>
lines{end + 1} = sprintf('- Chunk: `%d` (`%s`)', ...
    summary.ChunkId, summary.ChunkType); %#ok<AGROW>
lines{end + 1} = sprintf('- Scenario records: `%d`', summary.ScenarioRecords); %#ok<AGROW>
lines{end + 1} = sprintf('- Max scenario seconds: `%.3f`', summary.MaxScenarioSec); %#ok<AGROW>
lines{end + 1} = sprintf('- Mean scenario seconds: `%.3f`', summary.MeanScenarioSec); %#ok<AGROW>
lines{end + 1} = ''; %#ok<AGROW>
lines{end + 1} = '| Rank | Worker | ScenarioId | Status | Seconds | MapMode | Buildings | OSM MB | OSM file |'; %#ok<AGROW>
lines{end + 1} = '| ---: | ---: | ---: | :--- | ---: | :--- | :---: | ---: | :--- |'; %#ok<AGROW>
records = summary.TopSlowScenarios;
for idx = 1:numel(records)
    item = records(idx);
    lines{end + 1} = sprintf('| %d | %d | %d | %s | %.3f | %s | %s | %.3f | %s |', ...
        idx, item.WorkerId, item.ScenarioId, ...
        localMarkdownCell(item.Status), item.DurationSec, ...
        localMarkdownCell(item.MapMode), localBoolText(item.HasBuildings), ...
        item.OSMFileSizeMB, localMarkdownCell(item.OSMFile)); %#ok<AGROW>
end
text = strjoin(lines, newline);
end

function text = localBoolText(value)
if value
    text = 'true';
else
    text = 'false';
end
end

function text = localMarkdownCell(value)
text = char(string(value));
text = strrep(text, '|', '\|');
text = strrep(text, newline, ' ');
text = strrep(text, sprintf('\r'), ' ');
text = strrep(text, sprintf('\n'), ' ');
end

function [record, manifest] = localRetainReservoirSamples(record, manifest, chunk, settings)
scenarioFiles = {};
for workerIdx = 1:numel(chunk.Workers)
    scenarioFiles = [scenarioFiles; ...
        localListFiles(chunk.Workers(workerIdx).DataRoot, '*_data.mat')]; %#ok<AGROW>
end
if settings.ReservoirSampleLimit <= 0
    record.ReservoirSamplesAdded = 0;
    return;
end
rng(chunk.Seed, 'twister');
added = 0;
for idx = 1:numel(scenarioFiles)
    manifest.ReservoirSeen = manifest.ReservoirSeen + 1;
    take = manifest.ReservoirCount < settings.ReservoirSampleLimit;
    replaceIndex = NaN;
    if ~take
        j = randi(manifest.ReservoirSeen);
        if j <= settings.ReservoirSampleLimit
            take = true;
            replaceIndex = j;
        end
    end
    if take
        if isfinite(replaceIndex)
            slot = replaceIndex;
        else
            manifest.ReservoirCount = manifest.ReservoirCount + 1;
            slot = manifest.ReservoirCount;
        end
        localCopyScenarioPair(scenarioFiles{idx}, slot, chunk, settings);
        added = added + 1;
    end
end
record.ReservoirSamplesAdded = added;
end

function localCopyScenarioPair(dataPath, slot, chunk, settings)
sampleDir = fullfile(settings.ArtifactRoot, 'reservoir_samples', ...
    sprintf('sample_%05d', slot));
if isfolder(sampleDir)
    rmdir(sampleDir, 's');
end
mkdir(sampleDir);
copyfile(dataPath, fullfile(sampleDir, 'scenario_data.mat'));
[folder, name] = fileparts(dataPath);
annotationName = strrep(name, '_data', '_annotation.json');
annotationPath = fullfile(strrep(folder, [filesep 'scenarios'], ...
    [filesep 'annotations']), annotationName);
if isfile(annotationPath)
    copyfile(annotationPath, fullfile(sampleDir, 'scenario_annotation.json'));
end
meta = struct('ChunkId', chunk.ChunkId, 'SourceDataPath', dataPath, ...
    'CopiedAtUtc', localUtcNow());
localWriteJson(fullfile(sampleDir, 'sample_metadata.json'), meta);
end

function status = localCleanupSuccessfulOutputs(chunk, settings)
status = struct('RemovedScenarioDirs', 0, 'RemovedAnnotationDirs', 0, ...
    'Message', '');
root = chunk.DataChunkRoot;
if ~isfolder(root)
    status.Message = 'No chunk data root found.';
    return;
end
for idx = 1:numel(chunk.Workers)
    sessions = dir(fullfile(root, sprintf('worker_%03d', idx), 'session_*'));
    for sIdx = 1:numel(sessions)
        sessionRoot = fullfile(sessions(sIdx).folder, sessions(sIdx).name);
        scenarioDir = fullfile(sessionRoot, 'scenarios');
        annotationDir = fullfile(sessionRoot, 'annotations');
        if localSafeRemoveDir(scenarioDir, root)
            status.RemovedScenarioDirs = status.RemovedScenarioDirs + 1;
        end
        if localSafeRemoveDir(annotationDir, root)
            status.RemovedAnnotationDirs = status.RemovedAnnotationDirs + 1;
        end
    end
end
end

function tf = localSafeRemoveDir(targetDir, allowedRoot)
tf = false;
targetDir = char(string(targetDir));
allowedRoot = char(string(allowedRoot));
if isfolder(targetDir) && startsWith(lower(targetDir), lower(allowedRoot))
    rmdir(targetDir, 's');
    tf = true;
end
end

function artifact = localArchiveFailure(record, chunk, settings)
sig = regexprep(localFailureSignature(record), '[^A-Za-z0-9_]', '_');
failureDir = fullfile(settings.ArtifactRoot, 'failures', sig, ...
    sprintf('chunk_%06d', chunk.ChunkId));
localEnsureDirectory(failureDir);
copyfile(chunk.ChunkRoot, fullfile(failureDir, 'chunk_artifacts'));
artifact = failureDir;
end

function localWriteRepairQueue(manifest, settings, record)
pathText = fullfile(settings.ArtifactRoot, 'repair_queue.md');
fid = fopen(pathText, 'a');
if fid == -1
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '## %s\n\n', localUtcNow());
fprintf(fid, '- Status: %s\n', manifest.Status);
fprintf(fid, '- PauseReason: %s\n', manifest.PauseReason);
fprintf(fid, '- Last chunk: %d\n', record.ChunkId);
fprintf(fid, '- Failure signature: `%s`\n', localFailureSignature(record));
fprintf(fid, '- Message: %s\n\n', record.FirstFailure.Message);
clear cleanup;
end

function manifest = localLoadOrCreateManifest(pathText, settings, resume)
if resume && isfile(pathText)
    try
        manifest = jsondecode(localReadText(pathText));
        manifest = localNormalizeManifest(manifest);
        return;
    catch
    end
end
manifest = struct();
manifest.Schema = 'csrd.massive-watchdog.v1';
manifest.RunId = localRunId();
manifest.CreatedAtUtc = localUtcNow();
manifest.UpdatedAtUtc = manifest.CreatedAtUtc;
manifest.Status = 'Running';
manifest.StoppedAtUtc = '';
manifest.StopReason = '';
manifest.Settings = settings;
manifest.NextChunkId = 1;
manifest.LastSeed = localInitialSeed(settings);
manifest.TotalChunks = 0;
manifest.FailedChunks = 0;
manifest.SuccessfulScenarios = 0;
manifest.AttemptedScenarios = 0;
manifest.PilotCompleted = false;
manifest.Pilot = struct();
manifest.ActiveChunk = struct();
manifest.LastKnownActiveChunk = struct();
manifest.ChunkRecords = repmat(localEmptyChunkRecordStruct(), 0, 1);
manifest.LastConsecutiveFailureSignature = '';
manifest.ConsecutiveFailureCount = 0;
manifest.ReservoirSeen = 0;
manifest.ReservoirCount = 0;
end

function manifest = localNormalizeManifest(manifest)
if ~isfield(manifest, 'ChunkRecords') || isempty(manifest.ChunkRecords)
    manifest.ChunkRecords = repmat(localEmptyChunkRecordStruct(), 0, 1);
else
    manifest.ChunkRecords = localNormalizeChunkRecords(manifest.ChunkRecords);
end
defaults = localLoadOrCreateManifest('', struct(), false);
names = fieldnames(defaults);
for idx = 1:numel(names)
    if ~isfield(manifest, names{idx})
        manifest.(names{idx}) = defaults.(names{idx});
    end
end
end

function records = localNormalizeChunkRecords(records)
defaults = localEmptyChunkRecordStruct();
defaultNames = fieldnames(defaults);
for recIdx = 1:numel(records)
    for nameIdx = 1:numel(defaultNames)
        name = defaultNames{nameIdx};
        if ~isfield(records(recIdx), name)
            records(recIdx).(name) = defaults.(name);
        end
    end
end
end

function manifest = localWriteManifest(pathText, manifest)
manifest.UpdatedAtUtc = localUtcNow();
localWriteJson(pathText, manifest);
end

function localWriteChunkState(chunk, state)
payload = struct('ChunkId', chunk.ChunkId, 'State', state, ...
    'UpdatedAtUtc', localUtcNow());
localWriteJson(fullfile(chunk.ChunkRoot, 'chunk_state.json'), payload);
end

function localWriteChunkRecord(chunk, record)
localWriteJson(fullfile(chunk.ChunkRoot, 'chunk_record.json'), record);
end

function record = localEmptyChunkRecord(chunk)
record = localEmptyChunkRecordStruct();
record.ChunkId = chunk.ChunkId;
record.ChunkType = chunk.ChunkType;
record.ChunkName = chunk.ChunkName;
record.NumScenarios = chunk.NumScenarios;
record.Seed = chunk.Seed;
record.ChunkRoot = chunk.ChunkRoot;
record.DataChunkRoot = chunk.DataChunkRoot;
record.Workers = repmat(struct('WorkerId', NaN, 'SuccessfulScenarios', 0, ...
    'FailedScenarios', 0, 'SkippedScenarios', 0, 'LogFiles', {{}}), ...
    1, numel(chunk.Workers));
end

function record = localEmptyChunkRecordStruct()
record = struct('ChunkId', NaN, 'ChunkType', '', 'ChunkName', '', ...
    'NumScenarios', 0, 'Seed', NaN, 'Status', 'Pending', ...
    'StartedAtUtc', '', 'FinishedAtUtc', '', 'ChunkRoot', '', ...
    'DataChunkRoot', '', ...
    'SuccessfulScenarios', 0, 'FailedScenarios', 0, ...
    'SkippedScenarios', 0, 'Workers', [], ...
    'FirstFailure', struct('Detected', false, 'Signature', '', 'Message', ''), ...
    'LogAudit', struct(), 'AnnotationAudit', struct(), ...
    'OsmFileCoverageCounts', struct('OSMFile', {}, 'Count', {}), ...
    'PerformanceSummary', struct(), 'SlowScenarioSummary', struct(), ...
    'CleanupStatus', struct(), ...
    'ReservoirSamplesAdded', 0, 'FailureArtifact', '');
end

function active = localActiveChunkSummary(chunk)
active = struct('ChunkId', chunk.ChunkId, ...
    'ChunkType', chunk.ChunkType, ...
    'ChunkName', chunk.ChunkName, ...
    'ChunkRoot', chunk.ChunkRoot, ...
    'DataChunkRoot', chunk.DataChunkRoot, ...
    'NumScenarios', chunk.NumScenarios, ...
    'Seed', chunk.Seed, ...
    'StartedAtUtc', localUtcNow(), ...
    'Workers', chunk.Workers);
end

function worker = localEmptyWorker()
worker = struct('WorkerId', NaN, 'ConfigPath', '', 'OutputDirectory', '', ...
    'DataRoot', '', 'StdoutPath', '', 'StderrPath', '', 'Pid', NaN, ...
    'StartScenario', NaN, 'EndScenario', NaN, 'ScenarioCount', 0);
end

function summary = localPilotSummary(record)
summary = struct('ChunkId', record.ChunkId, ...
    'SuccessfulScenarios', record.SuccessfulScenarios, ...
    'ElapsedSec', localElapsedSec(record.StartedAtUtc, record.FinishedAtUtc), ...
    'AverageScenarioSec', localElapsedSec(record.StartedAtUtc, ...
    record.FinishedAtUtc) / max(1, record.SuccessfulScenarios));
end

function [startScenario, endScenario, scenarioCount] = localScenarioDistribution(totalScenarios, workerId, numWorkers)
if numWorkers > totalScenarios
    if workerId <= totalScenarios
        startScenario = workerId;
        endScenario = workerId;
        scenarioCount = 1;
    else
        startScenario = 1;
        endScenario = 0;
        scenarioCount = 0;
    end
else
    scenariosPerWorker = floor(totalScenarios / numWorkers);
    remainderScenarios = mod(totalScenarios, numWorkers);
    if workerId <= remainderScenarios
        startScenario = (workerId - 1) * (scenariosPerWorker + 1) + 1;
        endScenario = startScenario + scenariosPerWorker;
        scenarioCount = scenariosPerWorker + 1;
    else
        startScenario = remainderScenarios * (scenariosPerWorker + 1) + ...
            (workerId - remainderScenarios - 1) * scenariosPerWorker + 1;
        endScenario = startScenario + scenariosPerWorker - 1;
        scenarioCount = scenariosPerWorker;
    end
end
end

function seed = localNextSeed(manifest)
seed = mod(double(manifest.LastSeed) * 1103515245 + 12345, 2^31 - 1);
if seed <= 0
    seed = localInitialSeed(struct());
end
end

function settings = localSettingsStruct(input, projectRoot, artifactRoot)
settings = struct();
settings.TargetSuccessfulScenarios = double(input.TargetSuccessfulScenarios);
settings.NumWorkers = double(input.NumWorkers);
settings.RetentionMode = char(string(input.RetentionMode));
settings.BaseConfig = char(string(input.BaseConfig));
settings.ArtifactRoot = artifactRoot;
settings.ManifestPath = fullfile(artifactRoot, 'manifest.json');
settings.ProjectRoot = projectRoot;
settings.StopSignalFile = char(string(input.StopSignalFile));
if isempty(settings.StopSignalFile)
    settings.StopSignalFile = fullfile(artifactRoot, 'stop_requested.json');
elseif ~localIsAbsolutePath(settings.StopSignalFile)
    settings.StopSignalFile = fullfile(artifactRoot, settings.StopSignalFile);
end
settings.MonitorIntervalSec = double(input.MonitorIntervalSec);
settings.DiskFreePauseBytes = double(input.DiskFreePauseBytes);
settings.ReservoirSampleLimit = double(input.ReservoirSampleLimit);
settings.FailureSampleLimit = double(input.FailureSampleLimit);
settings.MaxConsecutiveFailureSignature = double(input.MaxConsecutiveFailureSignature);
settings.MaxFailureRate = double(input.MaxFailureRate);
if isempty(input.InitialSeed)
    settings.InitialSeed = NaN;
else
    settings.InitialSeed = double(input.InitialSeed);
end
settings.LaunchMode = char(string(input.LaunchMode));
settings.CleanupSuccessOutputs = logical(input.CleanupSuccessOutputs);
end

function seed = localInitialSeed(settings)
if isstruct(settings) && isfield(settings, 'InitialSeed') && ...
        isnumeric(settings.InitialSeed) && isscalar(settings.InitialSeed) && ...
        isfinite(settings.InitialSeed) && settings.InitialSeed > 0
    seed = mod(double(settings.InitialSeed), 2^31 - 1);
else
    pidValue = 0;
    try
        pidValue = double(feature('getpid'));
    catch
    end
    seed = mod(floor(now * 86400000) + pidValue * 9973, 2^31 - 1);
end
if seed <= 0
    seed = 20260508;
end
seed = floor(seed);
end

function files = localListFiles(rootDir, pattern)
files = {};
if ~isfolder(rootDir)
    return;
end
listing = dir(fullfile(rootDir, '**', pattern));
for idx = 1:numel(listing)
    if ~listing(idx).isdir
        files{end + 1} = fullfile(listing(idx).folder, listing(idx).name); %#ok<AGROW>
    end
end
files = files(:);
end

function localWriteMockScenarioFiles(worker)
for idx = worker.StartScenario:worker.EndScenario
    dataPath = fullfile(worker.DataRoot, 'session_mock', 'scenarios', ...
        sprintf('scenario_%06d_data.mat', idx));
    annotationPath = fullfile(worker.DataRoot, 'session_mock', 'annotations', ...
        sprintf('scenario_%06d_annotation.json', idx));
    mockSignal = idx; %#ok<NASGU>
    save(dataPath, 'mockSignal');
    measured = struct('SourcePlane', localMockMeasuredPlane(), ...
        'FramePlane', localMockMeasuredPlane());
    source = struct('Truth', struct('Measured', measured));
    payload = struct('Header', struct('ScenarioId', idx), ...
        'Sources', [source, source]);
    localWriteJson(annotationPath, payload);
end
end

function plane = localMockMeasuredPlane()
plane = struct('MeasurementStatus', 'Measured', ...
    'OccupiedBandwidthHz', 1, ...
    'CenterFrequencyHz', 0, ...
    'TimeOccupancy', 1, ...
    'FrequencyOccupancy', 0.1);
end

function values = localExtractFieldValues(value, fieldName)
values = {};
if isstruct(value)
    for elemIdx = 1:numel(value)
        item = value(elemIdx);
        if isfield(item, fieldName)
            values{end + 1} = item.(fieldName); %#ok<AGROW>
        end
        names = fieldnames(item);
        for idx = 1:numel(names)
            values = [values, localExtractFieldValues(item.(names{idx}), fieldName)]; %#ok<AGROW>
        end
    end
elseif iscell(value)
    for idx = 1:numel(value)
        values = [values, localExtractFieldValues(value{idx}, fieldName)]; %#ok<AGROW>
    end
end
end

function counts = localIncrementCount(counts, key)
if isempty(key)
    return;
end
for idx = 1:numel(counts)
    if strcmp(counts(idx).OSMFile, key)
        counts(idx).Count = counts(idx).Count + 1;
        return;
    end
end
counts(end + 1) = struct('OSMFile', key, 'Count', 1);
end

function sig = localFailureSignature(record)
sig = 'UnknownFailure';
if isfield(record, 'FirstFailure') && isstruct(record.FirstFailure) && ...
        isfield(record.FirstFailure, 'Signature') && ...
        ~isempty(record.FirstFailure.Signature)
    sig = char(string(record.FirstFailure.Signature));
end
end

function sig = localNormalizeFailureSignature(line)
sig = regexprep(char(string(line)), '\d+', '<n>');
sig = regexprep(sig, '\s+', ' ');
sig = strtrim(sig);
if strlength(sig) > 160
    sig = extractBefore(string(sig), 161);
    sig = char(sig);
end
end

function bytes = localDiskFreeBytes(projectRoot)
if ispc
    token = regexp(char(string(projectRoot)), '^([A-Za-z]):', 'tokens', 'once');
else
    token = {};
end
if ~isempty(token)
    driveName = token{1};
    [status, output] = system(sprintf(['powershell -NoProfile -Command ', ...
        '"(Get-PSDrive -Name %s).Free"'], driveName));
    if status == 0
        bytes = str2double(strtrim(output));
        if isfinite(bytes)
            return;
        end
    end
end
bytes = inf;
end

function elapsed = localElapsedSec(startUtc, finishUtc)
elapsed = NaN;
try
    t1 = datetime(startUtc, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', ...
        'TimeZone', 'UTC');
    t2 = datetime(finishUtc, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', ...
        'TimeZone', 'UTC');
    elapsed = seconds(t2 - t1);
catch
end
end

function localWriteText(pathText, text)
parent = fileparts(pathText);
if ~isempty(parent)
    localEnsureDirectory(parent);
end
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:MassiveWatchdog:WriteTextFailed', ...
        'Could not write %s', pathText);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text);
clear cleanup;
end

function text = localReadText(pathText)
fid = fopen(pathText, 'r');
if fid == -1
    text = '';
    return;
end
cleanup = onCleanup(@() fclose(fid));
text = fread(fid, '*char')';
clear cleanup;
end

function localWriteJson(pathText, payload)
parent = fileparts(pathText);
if ~isempty(parent)
    localEnsureDirectory(parent);
end
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:MassiveWatchdog:JsonWriteFailed', ...
        'Could not write JSON: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(payload));
clear cleanup;
end

function localEnsureDirectory(pathText)
if ~isfolder(pathText)
    mkdir(pathText);
end
end

function projectRoot = localProjectRoot()
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end

function tf = localIsAbsolutePath(pathText)
pathText = char(string(pathText));
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]|^[/\\]', 'once'));
end

function escaped = localEscape(text)
escaped = strrep(char(string(text)), '''', '''''');
end

function escaped = localPowerShellSingleQuoted(text)
escaped = strrep(char(string(text)), '''', '''''');
end

function stamp = localUtcNow()
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function runId = localRunId()
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
pidText = 'pid0';
try
    pidText = sprintf('pid%d', feature('getpid'));
catch
end
runId = ['run_', stamp, '_', pidText];
end

function tf = localPositiveInteger(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 1 && ...
    mod(value, 1) == 0;
end

function tf = localNonnegativeInteger(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0 && ...
    mod(value, 1) == 0;
end

function tf = localNonnegativeScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0;
end
