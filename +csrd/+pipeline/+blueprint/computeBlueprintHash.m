function hashHex16 = computeBlueprintHash(blueprint)
%COMPUTEBLUEPRINTHASH Canonical SHA-256 hash (first 16 hex chars) of a blueprint.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 computeBlueprintHash 实现。
%
% Phase 2 §3.2 implementation. Algorithm:
%   1. Recursively canonicalize the blueprint to a typed-JSON string with
%      lexicographically sorted struct fields, fully-qualified numeric
%      formatting (single -> %.7g, double -> %.17g), and explicit cell vs
%      vector distinction.
%   2. UTF-8 encode the canonical string and feed it to Java SHA-256.
%   3. Return the lowercase hex digest's first 16 characters.
%
% Inputs:
%   blueprint : any (struct / numeric / char / logical / cell / nested)
%
% Outputs:
%   hashHex16 : 1x16 char lowercase hex digest
%
% Throws:
%   CSRD:Blueprint:HashFailed - blueprint contains NaN, Inf, complex,
%       containers.Map, function_handle, or any other unsupported type.
%
% Determinism guarantees:
%   - Field insertion order does NOT affect the result (see
%     ComputeBlueprintHashTest.m / orderInvariantTest).
%   - Same struct hashed twice in any process returns the same digest.
%
% NOT supported (will throw HashFailed):
%   - NaN / Inf
%   - complex numbers
%   - containers.Map (use struct or cell of pairs)
%   - function_handle
%   - object instances of user-defined classes
%
% See also: csrd.pipeline.blueprint.BlueprintFeasibilityValidator

    canonical = canonicalize(blueprint);

    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(uint8(canonical));
    digestBytes = typecast(md.digest(), 'uint8');

    fullHex = lower(reshape(dec2hex(digestBytes, 2)', 1, []));
    hashHex16 = fullHex(1:16);
end


% =====================================================================
% Internal: typed-JSON canonicalization
% =====================================================================

function s = canonicalize(value)
%CANONICALIZE Recursively serialize VALUE to a typed-JSON char vector.
% 中文说明：canonicalize 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
%
% The output is *not* RFC-8259 JSON; it embeds type tags so that
%   numeric 1   vs   logical true   vs   char '1'   vs   {1}
% all serialize differently and never collide.

    if isstruct(value)
        s = canonicalizeStruct(value);
        return;
    end
    if iscell(value)
        s = canonicalizeCell(value);
        return;
    end
    if ischar(value) || isstring(value)
        s = canonicalizeString(value);
        return;
    end
    if islogical(value)
        s = canonicalizeLogical(value);
        return;
    end
    if isnumeric(value)
        s = canonicalizeNumeric(value);
        return;
    end
    if isa(value, 'containers.Map')
        error('CSRD:Blueprint:HashFailed', ...
            ['containers.Map is not allowed in a hashable blueprint. ', ...
             'Convert to a struct or cell-of-pairs first.']);
    end
    if isa(value, 'function_handle')
        error('CSRD:Blueprint:HashFailed', ...
            'function_handle is not allowed in a hashable blueprint.');
    end

    error('CSRD:Blueprint:HashFailed', ...
        'Unsupported value type "%s" in blueprint canonicalization.', class(value));
end


function s = canonicalizeStruct(value)
%CANONICALIZESTRUCT Handle scalar struct OR struct array.
% 中文说明：canonicalizeStruct 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.

    if isscalar(value)
        fields = sort(fieldnames(value));
        parts = cell(1, numel(fields));
        for i = 1:numel(fields)
            f = fields{i};
            parts{i} = sprintf('"%s":%s', f, canonicalize(value.(f)));
        end
        s = ['{' strjoin(parts, ',') '}'];
        return;
    end

    if isempty(value)
        s = '<sarr:empty>[]';
        return;
    end

    items = cell(1, numel(value));
    for k = 1:numel(value)
        items{k} = canonicalize(value(k));
    end
    s = ['<sarr>[' strjoin(items, ',') ']'];
end


function s = canonicalizeCell(value)
    % canonicalizeCell - Production declaration in CSRD.
    % 中文说明：canonicalizeCell 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isempty(value)
        s = '<cell:empty>[]';
        return;
    end
    items = cell(1, numel(value));
    for k = 1:numel(value)
        items{k} = canonicalize(value{k});
    end
    s = ['<cell>[' strjoin(items, ',') ']'];
end


function s = canonicalizeString(value)
    % canonicalizeString - Production declaration in CSRD.
    % 中文说明：canonicalizeString 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isstring(value)
        if ~isscalar(value)
            error('CSRD:Blueprint:HashFailed', ...
                'string arrays of length > 1 are not supported in blueprint hash; wrap in a cell.');
        end
        value = char(value);
    end
    if isempty(value)
        s = '<str>""';
        return;
    end
    escaped = jsonEscape(value);
    s = ['<str>"' escaped '"'];
end


function s = canonicalizeLogical(value)
    % canonicalizeLogical - Production declaration in CSRD.
    % 中文说明：canonicalizeLogical 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isscalar(value)
        if value
            s = '<bool>true';
        else
            s = '<bool>false';
        end
        return;
    end
    items = cell(1, numel(value));
    for k = 1:numel(value)
        if value(k)
            items{k} = 'true';
        else
            items{k} = 'false';
        end
    end
    s = ['<barr>[' strjoin(items, ',') ']'];
end


function s = canonicalizeNumeric(value)
    % canonicalizeNumeric - Production declaration in CSRD.
    % 中文说明：canonicalizeNumeric 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isempty(value)
        s = '<num:empty>[]';
        return;
    end

    if any(~isfinite(value(:)))
        error('CSRD:Blueprint:HashFailed', ...
            'Blueprint contains NaN or Inf; not allowed in hashable blueprints.');
    end
    if ~isreal(value)
        error('CSRD:Blueprint:HashFailed', ...
            'Blueprint contains complex numbers; not allowed in hashable blueprints.');
    end

    sz = size(value);
    sizeTag = ['[' strjoin(arrayfun(@(d) sprintf('%d', d), sz, 'UniformOutput', false), 'x') ']'];

    cls = class(value);
    items = cell(1, numel(value));
    flat = value(:);

    switch cls
        case {'double'}
            for k = 1:numel(flat)
                items{k} = sprintf('%.17g', flat(k));
            end
        case {'single'}
            for k = 1:numel(flat)
                items{k} = sprintf('%.7g', flat(k));
            end
        case {'int8','int16','int32','int64'}
            for k = 1:numel(flat)
                items{k} = sprintf('%d', int64(flat(k)));
            end
        case {'uint8','uint16','uint32','uint64'}
            for k = 1:numel(flat)
                items{k} = sprintf('%u', uint64(flat(k)));
            end
        otherwise
            error('CSRD:Blueprint:HashFailed', ...
                'Unsupported numeric class "%s" in blueprint.', cls);
    end

    s = sprintf('<%s%s>[%s]', cls, sizeTag, strjoin(items, ','));
end


function escaped = jsonEscape(str)
%JSONESCAPE Minimal JSON-string escaping (sufficient for hash determinism).
% 中文说明：jsonEscape 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.

    escaped = strrep(str, '\', '\\');
    escaped = strrep(escaped, '"', '\"');
    escaped = strrep(escaped, char(10), '\n');
    escaped = strrep(escaped, char(13), '\r');
    escaped = strrep(escaped, char(9),  '\t');
end
