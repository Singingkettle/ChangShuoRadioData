function summary = write_massive_pilot_slow_summary(artifactRoot, varargin)
%WRITE_MASSIVE_PILOT_SLOW_SUMMARY Summarize slow scenarios from live logs.
% 中文说明：只读取 massive watchdog artifacts，写 ignored 慢场景摘要，不影响仿真进程。

if nargin < 1
    artifactRoot = '';
end
p = inputParser();
p.FunctionName = 'write_massive_pilot_slow_summary';
addOptional(p, 'ArtifactRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'TopN', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ChunkId', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x)));
parse(p, artifactRoot, varargin{:});

root = char(string(p.Results.ArtifactRoot));
if isempty(root)
    projectRoot = localProjectRoot();
    root = fullfile(projectRoot, 'artifacts', 'massive_audit');
elseif ~localIsAbsolutePath(root)
    root = fullfile(localProjectRoot(), root);
end
manifestPath = fullfile(root, 'manifest.json');
if ~isfile(manifestPath)
    error('CSRD:MassiveSlowSummary:ManifestMissing', ...
        'Could not find massive watchdog manifest: %s', manifestPath);
end

manifest = jsondecode(localReadText(manifestPath));
chunk = localResolveChunk(manifest, p.Results.ChunkId);
summary = localCollectSlowScenarioSummary(chunk, floor(double(p.Results.TopN)));

if strcmpi(char(string(chunk.ChunkType)), 'Pilot')
    baseName = 'pilot_slow_scenarios';
else
    baseName = 'slow_scenarios';
end
summary.OutputJson = fullfile(chunk.ChunkRoot, [baseName, '.json']);
summary.OutputMarkdown = fullfile(chunk.ChunkRoot, [baseName, '.md']);
summary.LatestJson = fullfile(root, 'latest_slow_scenarios.json');
summary.LatestMarkdown = fullfile(root, 'latest_slow_scenarios.md');
localWriteJson(summary.OutputJson, summary);
localWriteText(summary.OutputMarkdown, localSlowScenarioMarkdown(summary));
localWriteJson(summary.LatestJson, summary);
localWriteText(summary.LatestMarkdown, localSlowScenarioMarkdown(summary));
end

function chunk = localResolveChunk(manifest, requestedChunkId)
chunk = struct();
if ~isempty(requestedChunkId)
    chunk = localFindChunkById(manifest, double(requestedChunkId));
elseif isfield(manifest, 'ActiveChunk') && isstruct(manifest.ActiveChunk) && ...
        isfield(manifest.ActiveChunk, 'ChunkRoot') && ...
        ~isempty(manifest.ActiveChunk.ChunkRoot)
    chunk = manifest.ActiveChunk;
elseif isfield(manifest, 'ChunkRecords') && ~isempty(manifest.ChunkRecords)
    chunk = manifest.ChunkRecords(end);
end
if isempty(fieldnames(chunk)) || ~isfield(chunk, 'ChunkRoot') || ...
        isempty(chunk.ChunkRoot)
    error('CSRD:MassiveSlowSummary:ChunkMissing', ...
        'Manifest does not contain an active chunk or chunk record.');
end
if ~isfield(chunk, 'Workers')
    chunk.Workers = localInferWorkers(chunk);
end
if ~isfield(chunk, 'ChunkType')
    chunk.ChunkType = 'Unknown';
end
if ~isfield(chunk, 'ChunkId')
    chunk.ChunkId = NaN;
end
end

function chunk = localFindChunkById(manifest, requestedChunkId)
chunk = struct();
if isfield(manifest, 'ActiveChunk') && isstruct(manifest.ActiveChunk) && ...
        isfield(manifest.ActiveChunk, 'ChunkId') && ...
        double(manifest.ActiveChunk.ChunkId) == requestedChunkId
    chunk = manifest.ActiveChunk;
    return;
end
if isfield(manifest, 'ChunkRecords') && ~isempty(manifest.ChunkRecords)
    records = manifest.ChunkRecords;
    for idx = 1:numel(records)
        if isfield(records(idx), 'ChunkId') && ...
                double(records(idx).ChunkId) == requestedChunkId
            chunk = records(idx);
            return;
        end
    end
end
error('CSRD:MassiveSlowSummary:ChunkIdMissing', ...
    'Manifest does not contain chunk id %.0f.', requestedChunkId);
end

function workers = localInferWorkers(chunk)
workers = struct('WorkerId', {}, 'DataRoot', {});
if ~isfield(chunk, 'DataChunkRoot') || ~isfolder(chunk.DataChunkRoot)
    return;
end
listing = dir(fullfile(chunk.DataChunkRoot, 'worker_*'));
for idx = 1:numel(listing)
    if ~listing(idx).isdir
        continue;
    end
    token = regexp(listing(idx).name, 'worker_(\d+)$', 'tokens', 'once');
    workerId = idx;
    if ~isempty(token)
        workerId = str2double(token{1});
    end
    workers(end + 1) = struct('WorkerId', workerId, ...
        'DataRoot', fullfile(listing(idx).folder, listing(idx).name)); %#ok<AGROW>
end
end

function summary = localCollectSlowScenarioSummary(chunk, topN)
records = localParseScenarioProgressLogs(chunk);
records = localAttachAnnotationMetadata(records, chunk);
if ~isempty(records)
    [~, order] = sort([records.DurationSec], 'descend');
    records = records(order);
end
topCount = min(topN, numel(records));
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
if isfield(chunk, 'Workers')
    for workerIdx = 1:numel(chunk.Workers)
        if isfield(chunk.Workers(workerIdx), 'DataRoot')
            files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, '*.log')]; %#ok<AGROW>
        end
    end
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
performanceRecords = localParseScenarioPerformanceTrace(chunk);
if isempty(records)
    records = performanceRecords;
elseif ~isempty(performanceRecords)
    records = localAppendMissingScenarioRecords(records, performanceRecords);
end
end

function records = localParseScenarioPerformanceTrace(chunk)
records = localEmptySlowScenarioRecord();
records = records([]);
files = localListFiles(fullfile(chunk.ChunkRoot, 'performance'), ...
    '*stage-timing*-final.json');
if isempty(files)
    files = localListFiles(fullfile(chunk.ChunkRoot, 'performance'), ...
        '*stage-timing*.json');
end
for fileIdx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{fileIdx}));
    catch
        continue;
    end
    if ~isfield(payload, 'Events') || isempty(payload.Events)
        continue;
    end
    events = payload.Events;
    for idx = 1:numel(events)
        event = events(idx);
        if ~isfield(event, 'Stage') || ...
                ~strcmpi(char(string(event.Stage)), 'Scenario.Total')
            continue;
        end
        item = localEmptySlowScenarioRecord();
        item.DurationSec = localStructDoubleField(event, 'ElapsedSec', NaN);
        item.LogFile = files{fileIdx};
        if isfield(event, 'Metadata') && isstruct(event.Metadata)
            item.WorkerId = localStructDoubleField(event.Metadata, 'WorkerId', NaN);
            item.ScenarioId = localStructDoubleField(event.Metadata, 'ScenarioId', NaN);
            item.Status = localStructCharField(event.Metadata, 'Status', '');
        end
        records(end + 1) = item; %#ok<AGROW>
    end
end
end

function records = localAppendMissingScenarioRecords(records, extraRecords)
existingKeys = strings(1, numel(records));
for idx = 1:numel(records)
    existingKeys(idx) = localScenarioRecordKey(records(idx));
end
for idx = 1:numel(extraRecords)
    key = localScenarioRecordKey(extraRecords(idx));
    if ~any(existingKeys == key)
        records(end + 1) = extraRecords(idx); %#ok<AGROW>
        existingKeys(end + 1) = key; %#ok<AGROW>
    end
end
end

function key = localScenarioRecordKey(record)
key = sprintf('w%.0f-s%.0f', record.WorkerId, record.ScenarioId);
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
if isfield(chunk, 'Workers')
    for workerIdx = 1:numel(chunk.Workers)
        if isfield(chunk.Workers(workerIdx), 'DataRoot')
            files = [files; localListFiles(chunk.Workers(workerIdx).DataRoot, ...
                '*annotation.json')]; %#ok<AGROW>
        end
    end
end
artifactRoot = localArtifactRootFromChunk(chunk);
if ~isempty(artifactRoot)
    files = [files; localListFiles(fullfile(artifactRoot, 'reservoir_samples'), ...
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

function artifactRoot = localArtifactRootFromChunk(chunk)
artifactRoot = '';
if ~isfield(chunk, 'ChunkRoot') || isempty(chunk.ChunkRoot)
    return;
end
chunksRoot = fileparts(chunk.ChunkRoot);
if strcmpi(getLastPathPart(chunksRoot), 'chunks')
    artifactRoot = fileparts(chunksRoot);
end
end

function part = getLastPathPart(pathText)
[~, part] = fileparts(char(string(pathText)));
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

function text = localSlowScenarioMarkdown(summary)
lines = {};
lines{end + 1} = '# Phase 28 Slow Scenario Summary'; %#ok<AGROW>
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
text = strrep(text, sprintf('\r'), ' ');
text = strrep(text, sprintf('\n'), ' ');
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

function localWriteText(pathText, text)
parent = fileparts(pathText);
if ~isempty(parent) && ~isfolder(parent)
    mkdir(parent);
end
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:MassiveSlowSummary:WriteTextFailed', ...
        'Could not write %s', pathText);
end
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
if fid == -1
    error('CSRD:MassiveSlowSummary:JsonWriteFailed', ...
        'Could not write JSON: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(payload));
clear cleanup;
end

function stamp = localUtcNow()
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function tf = localIsAbsolutePath(pathText)
pathText = char(string(pathText));
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]|^[/\\]', 'once'));
end

function projectRoot = localProjectRoot()
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end
