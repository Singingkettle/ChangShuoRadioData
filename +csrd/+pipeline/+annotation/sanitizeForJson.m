function [clean, manifest] = sanitizeForJson(value, options)
%SANITIZEFORJSON Recursively coerce a value into a jsonencode-safe form.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 sanitizeForJson 实现。
%
%   [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(value)
%   [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(value, options)
%
%   Phase 0 (audit §16.10 / phase-0-baseline.md §2.3):
%     `jsonencode` ships with a long list of values it cannot represent:
%       * NaN, +Inf, -Inf
%       * complex numbers
%       * datetime / duration / categorical / containers.Map
%       * function_handle, table, timetable, MException
%     CSRD annotation structs accumulated all of these over time and
%     produced silently-corrupt JSON files (e.g. raw `NaN` literals
%     that violate RFC 8259). This helper applies a single, audited
%     coercion table and returns BOTH the cleaned value AND a manifest
%     of every coercion performed so the caller can store provenance
%     under Header.Runtime.SanitizeManifest.
%
%   Coercion rules (default policy, see options to override):
%
%     numeric NaN          -> null  (string 'NaN' if .NumericPolicy='string')
%     numeric +Inf         -> null  (or 'Infinity')
%     numeric -Inf         -> null  (or '-Infinity')
%     complex numeric      -> struct('Real', re, 'Imag', im)
%     datetime scalar      -> ISO 8601 UTC char
%     datetime array       -> cellstr of ISO 8601 UTC
%     duration scalar      -> seconds (double)
%     categorical          -> char / cellstr
%     containers.Map       -> scalar struct  (keys forced to char)
%     string               -> char (jsonencode handles it, but we
%                              normalise so equality tests are simple)
%     function_handle      -> char( func2str )
%     missing              -> null
%     table / timetable    -> struct array (one elem per row)
%     MException           -> struct('Identifier', 'Message', 'Stack')
%     other unknown class  -> char( class(value) ) + manifest entry
%
%   options (struct, all fields optional):
%       .NumericPolicy   'null' (default) | 'string'
%       .MaxDepth        scalar uint32, default 64
%       .ManifestPath    internal, used to make the manifest legible
%
%   The function is fully self-contained: no external dependencies, no
%   side effects, safe to call from inside a parfor body.

if nargin < 2 || isempty(options)
    options = struct();
end
options = localFillDefaults(options);

state = struct();
state.path = '';
state.depth = uint32(0);
state.opts = options;
state.entries = repmat(struct( ...
    'Path', '', ...
    'OriginalClass', '', ...
    'Reason', '', ...
    'NewType', ''), 0, 1);

[clean, state] = localSanitize(value, state);

manifest = struct( ...
    'Schema', 'csrd.sanitize-manifest.v1', ...
    'NumericPolicy', state.opts.NumericPolicy, ...
    'Entries', {state.entries});
end

% =========================================================================
function opts = localFillDefaults(opts)
    % localFillDefaults - Production declaration in CSRD.
    % 中文说明：localFillDefaults 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
defaults = struct( ...
    'NumericPolicy', 'null', ...
    'MaxDepth', uint32(64));
fns = fieldnames(defaults);
for k = 1:numel(fns)
    if ~isfield(opts, fns{k}) || isempty(opts.(fns{k}))
        opts.(fns{k}) = defaults.(fns{k});
    end
end
if ~ischar(opts.NumericPolicy) && ~isstring(opts.NumericPolicy)
    error('CSRD:Phase0:SanitizeBadOption', ...
        'options.NumericPolicy must be ''null'' or ''string''.');
end
opts.NumericPolicy = lower(char(opts.NumericPolicy));
if ~ismember(opts.NumericPolicy, {'null', 'string'})
    error('CSRD:Phase0:SanitizeBadOption', ...
        'options.NumericPolicy must be ''null'' or ''string'', got "%s".', ...
        opts.NumericPolicy);
end
opts.MaxDepth = uint32(opts.MaxDepth);
end

% =========================================================================
function [out, state] = localSanitize(in, state)
    % localSanitize - Production declaration in CSRD.
    % 中文说明：localSanitize 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
state.depth = state.depth + 1;
if state.depth > state.opts.MaxDepth
    out = sprintf('<truncated:depth>%u', state.opts.MaxDepth);
    state = localRecord(state, 'depth-cap', class(in), 'string');
    state.depth = state.depth - 1;
    return;
end

% Order matters: handle most specific classes before generic ones.
if isempty(in) && ~isstruct(in) && ~iscell(in) && ~ischar(in)
    % Empty non-struct/cell -> represent as []. jsonencode([]) = "[]"
    out = [];
    state.depth = state.depth - 1;
    return;
end

if isa(in, 'datetime')
    [out, state] = localSanitizeDatetime(in, state);

elseif isa(in, 'duration')
    out = seconds(in);
    state = localRecord(state, 'duration->seconds', 'duration', class(out));

elseif isa(in, 'categorical')
    if isscalar(in)
        out = char(in);
    else
        out = cellstr(in);
    end
    state = localRecord(state, 'categorical->text', 'categorical', class(out));

elseif isa(in, 'containers.Map')
    [out, state] = localSanitizeMap(in, state);

elseif isa(in, 'function_handle')
    out = func2str(in);
    state = localRecord(state, 'function_handle->char', ...
        'function_handle', 'char');

elseif isa(in, 'MException')
    % Wrap the cell-valued Stack in {} so struct() does not broadcast
    % across stack frames and produce an N-element struct array
    % (jsonencode would emit that as a JSON array of N copies of
    % Identifier/Message, which is wrong).
    out = struct( ...
        'Identifier', in.identifier, ...
        'Message', in.message, ...
        'Stack', {localStackToCell(in.stack)});
    state = localRecord(state, 'mexception->struct', 'MException', 'struct');

elseif istable(in) || (exist('istimetable', 'builtin') && istimetable(in))
    [out, state] = localSanitizeTable(in, state);

elseif isstring(in)
    if isscalar(in)
        if ismissing(in)
            out = localMissingValue(state.opts);
            state = localRecord(state, 'missing->null', 'string', 'null');
        else
            out = char(in);
        end
    else
        out = cell(size(in));
        for k = 1:numel(in)
            if ismissing(in(k))
                out{k} = localMissingValue(state.opts);
            else
                out{k} = char(in(k));
            end
        end
        state = localRecord(state, 'string-array->cellstr', 'string', 'cell');
    end

elseif isstruct(in)
    [out, state] = localSanitizeStruct(in, state);

elseif iscell(in)
    [out, state] = localSanitizeCell(in, state);

elseif isnumeric(in) || islogical(in)
    [out, state] = localSanitizeNumeric(in, state);

elseif ischar(in)
    out = in;

else
    out = sprintf('<unsupported:%s>', class(in));
    state = localRecord(state, 'unsupported-class', class(in), 'char');
end

state.depth = state.depth - 1;
end

% =========================================================================
function [out, state] = localSanitizeStruct(in, state)
    % localSanitizeStruct - Production declaration in CSRD.
    % 中文说明：localSanitizeStruct 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isscalar(in)
    out = struct();
    fns = fieldnames(in);
    parentPath = state.path;
    for k = 1:numel(fns)
        state.path = localJoinPath(parentPath, fns{k});
        [out.(fns{k}), state] = localSanitize(in.(fns{k}), state);
    end
    state.path = parentPath;
else
    % Struct array: per-element sanitisation can produce heterogeneous
    % field sets (e.g. one element drops a NaN field, another keeps a
    % complex coercion). Stage the cleaned elements in a cell and rebuild
    % a homogeneous struct array at the end by taking the union of all
    % field names. This keeps the JSON output as an array of objects
    % while never tripping the `out(k)=tmp` heterogeneous-assignment
    % failure.
    parentPath = state.path;
    pieces = cell(numel(in), 1);
    for k = 1:numel(in)
        state.path = sprintf('%s[%d]', parentPath, k);
        [pieces{k}, state] = localSanitizeStruct(in(k), state);
    end
    state.path = parentPath;

    allFields = {};
    for k = 1:numel(pieces)
        allFields = union(allFields, fieldnames(pieces{k}), 'stable');
    end
    out = repmat(localBlankStruct(allFields), size(in));
    for k = 1:numel(pieces)
        fns = fieldnames(pieces{k});
        for f = 1:numel(fns)
            out(k).(fns{f}) = pieces{k}.(fns{f});
        end
    end
end
end


function s = localBlankStruct(fields)
    % localBlankStruct - Production declaration in CSRD.
    % 中文说明：localBlankStruct 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
s = struct();
for k = 1:numel(fields)
    s.(fields{k}) = [];
end
end

% =========================================================================
function [out, state] = localSanitizeCell(in, state)
    % localSanitizeCell - Production declaration in CSRD.
    % 中文说明：localSanitizeCell 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
out = cell(size(in));
parentPath = state.path;
for k = 1:numel(in)
    state.path = sprintf('%s{%d}', parentPath, k);
    [out{k}, state] = localSanitize(in{k}, state);
end
state.path = parentPath;
end

% =========================================================================
function [out, state] = localSanitizeNumeric(in, state)
% Logical arrays go through unchanged.
% 中文说明：localSanitizeNumeric 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
if islogical(in)
    out = in;
    return;
end

if isreal(in)
    if isscalar(in)
        if isnan(in)
            out = localNumericReplacement('NaN', state.opts);
            state = localRecord(state, 'NaN->null', class(in), 'null');
            return;
        end
        if isinf(in)
            if in > 0
                out = localNumericReplacement('+Inf', state.opts);
                state = localRecord(state, '+Inf->null', class(in), 'null');
            else
                out = localNumericReplacement('-Inf', state.opts);
                state = localRecord(state, '-Inf->null', class(in), 'null');
            end
            return;
        end
        out = in;
        return;
    end
    badNan = isnan(in);
    badInf = isinf(in);
    if ~any(badNan(:)) && ~any(badInf(:))
        out = in;
        return;
    end
    % Need to replace selectively. jsonencode for arrays cannot mix
    % types, so when the policy is 'null' we must convert the whole
    % array to a cell to preserve scalar replacements.
    out = num2cell(in);
    for k = 1:numel(in)
        if badNan(k)
            out{k} = localNumericReplacement('NaN', state.opts);
        elseif badInf(k) && in(k) > 0
            out{k} = localNumericReplacement('+Inf', state.opts);
        elseif badInf(k)
            out{k} = localNumericReplacement('-Inf', state.opts);
        end
    end
    state = localRecord(state, 'NaN/Inf-array->cell', class(in), 'cell');
    return;
end

% Complex path: jsonencode handles struct of arrays natively, so a
% scalar and an array are coerced to the same shape.
out = struct('Real', real(in), 'Imag', imag(in));
state = localRecord(state, 'complex->struct(Real,Imag)', class(in), 'struct');
end

% =========================================================================
function [out, state] = localSanitizeDatetime(in, state)
    % localSanitizeDatetime - Production declaration in CSRD.
    % 中文说明：localSanitizeDatetime 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
in.TimeZone = 'UTC';
fmt = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
if isscalar(in)
    if isnat(in)
        out = localMissingValue(state.opts);
        state = localRecord(state, 'NaT->null', 'datetime', 'null');
        return;
    end
    out = char(datestr(in, 'yyyy-mm-ddTHH:MM:SSZ')); %#ok<DATST>
    try
        out = char(string(in, fmt));
    catch
        % MATLAB < R2019b fallback already handled by datestr above.
    end
    state = localRecord(state, 'datetime->iso8601', 'datetime', 'char');
    return;
end

out = cell(size(in));
for k = 1:numel(in)
    if isnat(in(k))
        out{k} = localMissingValue(state.opts);
    else
        try
            out{k} = char(string(in(k), fmt));
        catch
            out{k} = char(datestr(in(k), 'yyyy-mm-ddTHH:MM:SSZ')); %#ok<DATST>
        end
    end
end
state = localRecord(state, 'datetime-array->cellstr', 'datetime', 'cell');
end

% =========================================================================
function [out, state] = localSanitizeMap(in, state)
    % localSanitizeMap - Production declaration in CSRD.
    % 中文说明：localSanitizeMap 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
out = struct();
keys = in.keys;
parentPath = state.path;
for k = 1:numel(keys)
    keyText = localKeyToFieldName(keys{k});
    state.path = localJoinPath(parentPath, keyText);
    [out.(keyText), state] = localSanitize(in(keys{k}), state);
end
state.path = parentPath;
state = localRecord(state, 'containers.Map->struct', 'containers.Map', 'struct');
end

% =========================================================================
function [out, state] = localSanitizeTable(in, state)
% Convert table/timetable to struct array; preserves row order.
% 中文说明：localSanitizeTable 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
parentPath = state.path;
if exist('istimetable', 'builtin') == 5 && istimetable(in)
    in = timetable2table(in);
end
nRows = height(in);
varNames = in.Properties.VariableNames;
out = repmat(struct(), nRows, 1);
for r = 1:nRows
    state.path = sprintf('%s[%d]', parentPath, r);
    rowStruct = struct();
    for c = 1:numel(varNames)
        cellVal = in.(varNames{c});
        if iscell(cellVal)
            elem = cellVal{r};
        else
            elem = cellVal(r, :);
        end
        state.path = localJoinPath( ...
            sprintf('%s[%d]', parentPath, r), varNames{c});
        [rowStruct.(varNames{c}), state] = localSanitize(elem, state);
    end
    out(r) = rowStruct; %#ok<AGROW>
end
state.path = parentPath;
state = localRecord(state, 'table->struct-array', 'table', 'struct');
end

% =========================================================================
function out = localNumericReplacement(kind, opts)
    % localNumericReplacement - Production declaration in CSRD.
    % 中文说明：localNumericReplacement 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
switch opts.NumericPolicy
    case 'null'
        out = []; % jsonencode([]) -> "null" (per MathWorks docs)
    case 'string'
        switch kind
            case 'NaN'
                out = 'NaN';
            case '+Inf'
                out = 'Infinity';
            case '-Inf'
                out = '-Infinity';
        end
end
end

% =========================================================================
function out = localMissingValue(opts)
    % localMissingValue - Production declaration in CSRD.
    % 中文说明：localMissingValue 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
out = localNumericReplacement('NaN', opts);
end

% =========================================================================
function name = localKeyToFieldName(key)
    % localKeyToFieldName - Production declaration in CSRD.
    % 中文说明：localKeyToFieldName 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isnumeric(key)
    name = sprintf('k_%g', key);
else
    name = matlab.lang.makeValidName(char(key));
end
end

% =========================================================================
function p = localJoinPath(parent, child)
    % localJoinPath - Production declaration in CSRD.
    % 中文说明：localJoinPath 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isempty(parent)
    p = child;
else
    p = sprintf('%s.%s', parent, child);
end
end

% =========================================================================
function state = localRecord(state, reason, originalClass, newType)
    % localRecord - Production declaration in CSRD.
    % 中文说明：localRecord 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
entry = struct( ...
    'Path', state.path, ...
    'OriginalClass', originalClass, ...
    'Reason', reason, ...
    'NewType', newType);
state.entries(end + 1) = entry;
end

% =========================================================================
function out = localStackToCell(stack)
% Compact MException stack into a cell of {file:line:name} chars; this is
% 中文说明：localStackToCell 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% what we want stored in JSON, NOT a struct array (which jsonencode would
% nest awkwardly).
if isempty(stack)
    out = {};
    return;
end
out = cell(numel(stack), 1);
for k = 1:numel(stack)
    out{k} = sprintf('%s:%d:%s', stack(k).file, stack(k).line, stack(k).name);
end
end
