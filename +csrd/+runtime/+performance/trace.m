function out = trace(action, varargin)
%TRACE Low-overhead runtime performance counters for opt-in profiling.
% 中文说明：默认关闭；仅在 Runner.Performance.EnableStageTiming=true 时记录性能诊断。

persistent state

if isempty(state)
    state = localEmptyState(false);
end

if nargin < 1 || isempty(action)
    action = 'snapshot';
end

cmd = lower(char(string(action)));
out = [];

switch cmd
    case {'start', 'enable'}
        state = localEmptyState(true);
        if ~isempty(varargin)
            state.ArtifactDirectory = char(string(varargin{1}));
        end

    case {'stop', 'disable'}
        state.Enabled = false;

    case 'reset'
        state = localEmptyState(false);

    case 'isenabled'
        out = state.Enabled;

    case {'count', 'increment'}
        if ~state.Enabled
            return;
        end
        counterName = localCharArg(varargin, 1, 'UnnamedCounter');
        amount = localNumericArg(varargin, 2, 1);
        metadata = localStructArg(varargin, 3);
        counterKey = localCounterKey(counterName);
        if ~isfield(state.Counters, counterKey)
            state.Counters.(counterKey) = 0;
            state.CounterNames.(counterKey) = counterName;
        end
        state.Counters.(counterKey) = state.Counters.(counterKey) + amount;
        if numel(state.CounterEvents) < state.MaxCounterEvents
            state.CounterEvents(end + 1) = struct( ...
                'Name', counterName, ...
                'Amount', amount, ...
                'RecordedAtUtc', localNowUtc(), ...
                'Metadata', metadata);
        else
            state.DroppedCounterEventCount = state.DroppedCounterEventCount + 1;
        end

    case 'event'
        if ~state.Enabled
            return;
        end
        eventName = localCharArg(varargin, 1, 'UnnamedEvent');
        elapsedSec = localNumericArg(varargin, 2, NaN);
        metadata = localStructArg(varargin, 3);
        if numel(state.Events) < state.MaxEvents
            state.Events(end + 1) = struct( ...
                'Name', eventName, ...
                'ElapsedSec', elapsedSec, ...
                'RecordedAtUtc', localNowUtc(), ...
                'Metadata', metadata);
        else
            state.DroppedEventCount = state.DroppedEventCount + 1;
        end

    case 'heartbeat'
        if ~state.Enabled
            return;
        end
        stageName = localCharArg(varargin, 1, 'UnnamedStage');
        stageState = localCharArg(varargin, 2, 'update');
        metadata = localStructArg(varargin, 3);
        state.Heartbeat = struct( ...
            'Schema', 'csrd.phase28.runtime-heartbeat.v1', ...
            'StageName', stageName, ...
            'StageState', stageState, ...
            'UpdatedAtUtc', localNowUtc(), ...
            'Metadata', metadata);
        localWriteHeartbeat(state);

    case 'snapshot'
        out = state;

    otherwise
        error('CSRD:PerformanceTrace:UnknownAction', ...
            'Unknown performance trace action "%s".', cmd);
end

if nargout == 0
    clear out;
end
end

function state = localEmptyState(enabled)
state = struct( ...
    'Schema', 'csrd.runtime.performance-trace.v1', ...
    'Enabled', logical(enabled), ...
    'StartedAtUtc', localNowUtc(), ...
    'ArtifactDirectory', '', ...
    'MaxEvents', 5000, ...
    'MaxCounterEvents', 5000, ...
    'DroppedEventCount', 0, ...
    'DroppedCounterEventCount', 0, ...
    'Counters', struct(), ...
    'CounterNames', struct(), ...
    'Heartbeat', struct(), ...
    'CounterEvents', struct('Name', {}, 'Amount', {}, ...
        'RecordedAtUtc', {}, 'Metadata', {}), ...
    'Events', struct('Name', {}, 'ElapsedSec', {}, ...
        'RecordedAtUtc', {}, 'Metadata', {}));
end

function localWriteHeartbeat(state)
if ~isstruct(state) || ~isfield(state, 'ArtifactDirectory') || ...
        isempty(state.ArtifactDirectory) || ~isstruct(state.Heartbeat)
    return;
end
try
    if ~isfolder(state.ArtifactDirectory)
        mkdir(state.ArtifactDirectory);
    end
    heartbeatPath = fullfile(state.ArtifactDirectory, ...
        'phase28-runtime-heartbeat.json');
    fid = fopen(heartbeatPath, 'w');
    if fid == -1
        return;
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', jsonencode(state.Heartbeat));
    clear cleanup;
catch
end
end

function value = localCharArg(args, idx, defaultValue)
value = defaultValue;
if numel(args) >= idx && ~isempty(args{idx})
    value = char(string(args{idx}));
end
end

function value = localNumericArg(args, idx, defaultValue)
value = defaultValue;
if numel(args) >= idx && isnumeric(args{idx}) && isscalar(args{idx}) && ...
        isfinite(args{idx})
    value = double(args{idx});
end
end

function value = localStructArg(args, idx)
value = struct();
if numel(args) >= idx && isstruct(args{idx})
    value = args{idx};
end
end

function key = localCounterKey(counterName)
key = regexprep(char(string(counterName)), '[^A-Za-z0-9_]', '_');
if isempty(key)
    key = 'UnnamedCounter';
elseif ~isletter(key(1))
    key = ['Counter_', key];
end
end

function stamp = localNowUtc()
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
