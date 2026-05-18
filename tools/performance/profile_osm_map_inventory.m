function summary = profile_osm_map_inventory(varargin)
%PROFILE_OSM_MAP_INVENTORY Inventory OSM files and balanced coverage order.
% 中文说明：只扫描 data/map/osm 下的 .osm 元数据和 building 标签，不做大小分级。

p = inputParser();
p.FunctionName = 'profile_osm_map_inventory';
addParameter(p, 'OsmRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ArtifactDirectory', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'CoverageSeed', 0, @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'WriteFiles', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);

osmRoot = char(string(p.Results.OsmRoot));
if isempty(osmRoot)
    osmRoot = fullfile(projectRoot, 'data', 'map', 'osm');
end
if ~isfolder(osmRoot)
    error('CSRD:OSMInventory:MissingOsmRoot', ...
        'OSM inventory root does not exist: %s', osmRoot);
end

artifactDir = char(string(p.Results.ArtifactDirectory));
if isempty(artifactDir)
    artifactDir = fullfile(projectRoot, 'artifacts', 'performance', ...
        'osm_inventory');
end

files = dir(fullfile(osmRoot, '**', '*.osm'));
relativePaths = arrayfun(@(f) localRelativePath(osmRoot, ...
    fullfile(f.folder, f.name)), files, 'UniformOutput', false);
[~, sortedOrder] = sort(string(relativePaths));
files = files(sortedOrder);
relativePaths = relativePaths(sortedOrder);

entries = repmat(localEmptyEntry(), numel(files), 1);
for idx = 1:numel(files)
    pathText = fullfile(files(idx).folder, files(idx).name);
    relPath = relativePaths{idx};
    category = localCategoryFromRelativePath(relPath);
    sizeMB = double(files(idx).bytes) / 1024 / 1024;
    hasBuildings = false;
    checkError = '';
    try
        hasBuildings = csrd.runtime.map.osmHasBuildings(pathText);
    catch ME
        checkError = sprintf('%s: %s', ME.identifier, ME.message);
    end
    entries(idx) = struct( ...
        'Path', pathText, ...
        'RelativePath', relPath, ...
        'Category', category, ...
        'SizeMB', sizeMB, ...
        'HasBuildings', hasBuildings, ...
        'CoverageIndex', NaN, ...
        'BuildingCheckError', checkError);
end

if ~isempty(entries)
    coverageOrder = localDeterministicOrder({entries.RelativePath}, ...
        p.Results.CoverageSeed, 'osm-file-coverage');
    for rank = 1:numel(coverageOrder)
        entries(coverageOrder(rank)).CoverageIndex = rank;
    end
end

summary = struct();
summary.Schema = 'csrd.osm-inventory.v2';
summary.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
summary.OsmRoot = osmRoot;
summary.CoverageSeed = p.Results.CoverageSeed;
summary.TotalFiles = numel(entries);
summary.BuildingFiles = sum([entries.HasBuildings]);
summary.FlatOrEmptyFiles = sum(~[entries.HasBuildings]);
summary.Entries = entries;
summary.TopBySize = localTopBySize(entries, min(20, numel(entries)));

if p.Results.WriteFiles
    if ~isfolder(artifactDir)
        mkdir(artifactDir);
    end
    ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    summary.MatPath = fullfile(artifactDir, sprintf('osm-inventory-%s.mat', ts));
    summary.JsonPath = fullfile(artifactDir, sprintf('osm-inventory-%s.json', ts));
    save(summary.MatPath, 'summary');
    localWriteJson(summary.JsonPath, summary);
else
    summary.MatPath = '';
    summary.JsonPath = '';
end

if p.Results.Verbose
    fprintf('OSM inventory: %d files, %d with buildings, coverage seed %.0f.\n', ...
        summary.TotalFiles, summary.BuildingFiles, summary.CoverageSeed);
    if p.Results.WriteFiles
        fprintf('  %s\n  %s\n', summary.MatPath, summary.JsonPath);
    end
end
end

function entry = localEmptyEntry()
entry = struct('Path', '', 'RelativePath', '', 'Category', '', ...
    'SizeMB', NaN, 'HasBuildings', false, 'CoverageIndex', NaN, ...
    'BuildingCheckError', '');
end

function topEntries = localTopBySize(entries, count)
topEntries = entries([]);
if isempty(entries) || count <= 0
    return;
end
[~, order] = sort([entries.SizeMB], 'descend');
topEntries = entries(order(1:count));
end

function category = localCategoryFromRelativePath(relPath)
parts = split(string(strrep(relPath, '\', '/')), '/');
if numel(parts) >= 2
    category = char(parts(1));
else
    category = '';
end
end

function localWriteJson(pathText, payload)
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:OSMInventory:JsonOpenFailed', ...
        'Could not write OSM inventory JSON: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(payload));
end

function projectRoot = localProjectRoot()
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end

function order = localDeterministicOrder(items, seedValue, label)
n = numel(items);
keys = zeros(n, 1);
for idx = 1:n
    keys(idx) = localStableHash(sprintf('%s|%.0f|%d|%s', ...
        label, seedValue, idx, char(string(items{idx}))));
end
[~, order] = sortrows([keys, (1:n)']);
order = order(:)';
end

function value = localStableHash(text)
bytes = uint8(unicode2native(char(string(text)), 'UTF-8'));
hash = 5381;
modulus = 2^31 - 1;
for idx = 1:numel(bytes)
    hash = mod(hash * 33 + double(bytes(idx)), modulus);
end
value = double(hash);
end

function relPath = localRelativePath(baseDir, fullPath)
baseDir = localNormalizePath(baseDir);
fullPath = localNormalizePath(fullPath);
baseForMatch = baseDir;
if ~endsWith(baseForMatch, '/')
    baseForMatch = [baseForMatch '/'];
end
if startsWith(lower(fullPath), lower(baseForMatch))
    relPath = char(extractAfter(fullPath, strlength(baseForMatch)));
else
    relPath = fullPath;
end
end

function pathText = localNormalizePath(pathText)
pathText = strrep(char(string(pathText)), '\', '/');
pathText = regexprep(pathText, '/+', '/');
if strlength(pathText) > 1
    pathText = regexprep(pathText, '/$', '');
end
end
