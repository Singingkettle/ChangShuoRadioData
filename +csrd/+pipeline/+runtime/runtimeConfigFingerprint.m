function fingerprint = runtimeConfigFingerprint(runnerConfig, factoryConfigs)
%RUNTIMECONFIGFINGERPRINT Stable fingerprint for runtime-plan provenance.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

if nargin < 1 || isempty(runnerConfig) || ~isstruct(runnerConfig)
    runnerConfig = struct();
end
if nargin < 2 || isempty(factoryConfigs) || ~isstruct(factoryConfigs)
    factoryConfigs = struct();
end

payload = struct( ...
    'Runner', localCanonicalize(runnerConfig), ...
    'Factories', localCanonicalize(factoryConfigs));
encoded = jsonencode(payload);
fingerprint = sprintf('fnv1a32:%08x', localFnv1a32(uint8(encoded)));
end

function value = localCanonicalize(value)
    % localCanonicalize - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(value)
    for idx = 1:numel(value)
        names = sort(fieldnames(value(idx)));
        out = struct();
        for k = 1:numel(names)
            name = names{k};
            out.(name) = localCanonicalize(value(idx).(name));
        end
        if idx == 1
            canonical = repmat(out, size(value));
        end
        canonical(idx) = out; %#ok<AGROW>
    end
    if isempty(value)
        value = struct();
    else
        value = canonical;
    end
elseif iscell(value)
    for k = 1:numel(value)
        value{k} = localCanonicalize(value{k});
    end
elseif isstring(value)
    value = cellstr(value);
elseif isa(value, 'datetime')
    value = char(value);
end
end

function hash = localFnv1a32(bytes)
    % localFnv1a32 - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
hash = uint32(2166136261);
prime = uint32(16777619);
for idx = 1:numel(bytes)
    hash = bitxor(hash, uint32(bytes(idx)));
    hash = uint32(mod(uint64(hash) * uint64(prime), uint64(2^32)));
end
end
