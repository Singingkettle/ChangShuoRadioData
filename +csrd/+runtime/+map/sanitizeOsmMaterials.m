function info = sanitizeOsmMaterials(osmFile)
%SANITIZEOSMMATERIALS Create ignored OSM copy with material tags normalized.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

info = struct('OriginalFile', char(string(osmFile)), ...
    'SanitizedFile', char(string(osmFile)), ...
    'Changed', false, ...
    'Policy', 'UnsupportedMaterialTagsBecomeConcrete');

if nargin < 1 || isempty(osmFile) || ~isfile(osmFile)
    return;
end

srcInfo = dir(osmFile);
cacheDir = fullfile(localProjectRoot(), 'artifacts', 'runtime', ...
    'osm-material-cache');
if ~isfolder(cacheDir)
    mkdir(cacheDir);
end
[~, baseName, ext] = fileparts(osmFile);
safeBase = regexprep(baseName, '[^A-Za-z0-9_-]', '_');
stamp = round(srcInfo.datenum * 86400);
sanitizedFile = fullfile(cacheDir, sprintf('%s_%d_%d%s', ...
    [safeBase, '_unsupported_material_v5'], srcInfo.bytes, stamp, ext));

if isfile(sanitizedFile)
    info.SanitizedFile = sanitizedFile;
    info.Changed = true;
    return;
end

inFid = fopen(osmFile, 'r');
if inFid == -1
    return;
end
rawBytes = fread(inFid, '*uint8').';
fclose(inFid);

text = native2unicode(rawBytes, 'UTF-8');
[lines, separators] = regexp(text, '\r\n|\n|\r', 'split', 'match');

changed = false;
for idx = 1:numel(lines)
    line = lines{idx};
    if contains(line, 'material', 'IgnoreCase', true) && ...
            contains(line, '<tag', 'IgnoreCase', true)
        nextLine = localNormalizeMaterialValue(line);
        if ~strcmp(nextLine, line)
            changed = true;
            lines{idx} = nextLine;
        end
    end
end

if ~changed
    return;
end

text = localJoinLines(lines, separators);
outBytes = unicode2native(text, 'UTF-8');
outFid = fopen(sanitizedFile, 'w');
if outFid == -1
    return;
end
writeCount = fwrite(outFid, outBytes, 'uint8');
fclose(outFid);
if writeCount ~= numel(outBytes)
    try
        delete(sanitizedFile);
    catch
    end
    return;
end

info.SanitizedFile = sanitizedFile;
info.Changed = true;
end

function line = localNormalizeMaterialValue(line)
    % localNormalizeMaterialValue - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
doubleMatch = regexp(line, 'v="([^"]*)"', 'tokens', 'once');
if ~isempty(doubleMatch)
    value = strtrim(doubleMatch{1});
    if localMustNormalizeMaterial(value)
        line = regexprep(line, 'v="[^"]*"', 'v="concrete"', 'once');
    end
    return;
end

singleMatch = regexp(line, "v='([^']*)'", 'tokens', 'once');
if ~isempty(singleMatch)
    value = strtrim(singleMatch{1});
    if localMustNormalizeMaterial(value)
        line = regexprep(line, "v='[^']*'", "v='concrete'", 'once');
    end
end
end

function tf = localMustNormalizeMaterial(value)
    % localMustNormalizeMaterial - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(value)
    tf = true;
    return;
end

supported = ["auto", "custom", "FR4", "Invar", "PEC", "Teflon", ...
    "acrylic", "air", "aluminum", "brass", "brick", "ceiling-board", ...
    "chipboard", "concrete", "copper", "floorboard", "foam", "glass", ...
    "gold", "ice", "iron", "lead", "loam", "marble", "metal", ...
    "perfect-reflector", "plasterboard", "plywood", "polystyrene", ...
    "seawater", "silver", "snow", "steel", "tree", "tungsten", ...
    "vacuum", "vegetation", "water", "wood", "zinc"];
tf = ~any(strcmpi(string(value), supported));
end

function text = localJoinLines(lines, separators)
    % localJoinLines - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(lines)
    text = '';
    return;
end
pieces = cell(1, numel(lines) + numel(separators));
cursor = 0;
for idx = 1:numel(lines)
    cursor = cursor + 1;
    pieces{cursor} = lines{idx};
    if idx <= numel(separators)
        cursor = cursor + 1;
        pieces{cursor} = separators{idx};
    end
end
text = [pieces{1:cursor}];
end

function root = localProjectRoot()
    % localProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(fileparts(here)));
end
