function varargout = osmSiteViewerCache(action, osmFile)
%OSMSITEVIEWERCACHE Process-local shared OSM siteviewer cache.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

persistent cache
persistent retainAcrossReleases

if isempty(cache) || ~isa(cache, 'containers.Map')
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
if isempty(retainAcrossReleases)
    retainAcrossReleases = false;
end

if nargin < 1 || isempty(action)
    action = 'snapshot';
end

cmd = lower(char(string(action)));
switch cmd
    case 'get'
        if nargin < 2 || isempty(osmFile)
            error('CSRD:Map:MissingOSMFile', ...
                'osmSiteViewerCache get requires an OSM file.');
        end
        key = char(string(osmFile));
        osmFileSizeMB = localFileSizeMB(key);
        if isKey(cache, key)
            entry = cache(key);
            if localIsCacheEntryUsable(entry)
                viewer = entry.Viewer;
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.SiteviewerCacheHit', 1, ...
                    struct('OSMFile', key, ...
                        'OSMFileSizeMB', osmFileSizeMB, ...
                        'Scope', 'process'));
                info = struct('CacheHit', true, 'OSMFile', key, ...
                    'OSMFileSizeMB', osmFileSizeMB);
                varargout = {viewer, info};
                return;
            end

            localDeleteViewer(getStructField(entry, 'Viewer', []));
            remove(cache, key);
            csrd.runtime.performance.trace('event', ...
                'RayTracing.SiteviewerCacheInvalidated', 0, ...
                struct('OSMFile', key, ...
                    'OSMFileSizeMB', osmFileSizeMB, ...
                    'Scope', 'process'));
        end

        sanitizeInfo = csrd.runtime.map.sanitizeOsmMaterials(key);
        mapFileUsed = sanitizeInfo.SanitizedFile;
        materialSanitized = sanitizeInfo.Changed;
        t = tic;
        try
            % Use a UTF-8-preserving copy only when unsupported OSM material
            % tags must be normalized for MATLAB's raytracing material table.
            % Geometry, coordinates, and non-material metadata remain intact.
            % Keep batch RayTracing deterministic and offline-safe. MATLAB
            % siteviewer defaults Terrain to gmted2010, which requires an
            % external terrain resource and can fail during long runs.
            viewer = siteviewer('Basemap', 'openstreetmap', ...
                'Terrain', 'none', ...
                'Buildings', mapFileUsed, 'Hidden', true);
            if ~localIsUsableViewer(viewer)
                error('CSRD:Map:InvalidSiteViewerHandle', ...
                    ['siteviewer returned %s for "%s"; RayTracing Map ', ...
                     'requires a valid siteviewer object.'], ...
                    class(viewer), mapFileUsed);
            end
        catch ME
            elapsedSec = toc(t);
            csrd.runtime.performance.trace('event', ...
                'RayTracing.SiteviewerConstructFailed', elapsedSec, ...
                struct('OSMFile', key, ...
                    'OSMFileSizeMB', osmFileSizeMB, ...
                    'MapFileUsed', mapFileUsed, ...
                    'MaterialSanitized', materialSanitized, ...
                    'Scope', 'process', ...
                    'ErrorIdentifier', ME.identifier, ...
                    'ErrorMessage', ME.message));
            rethrow(ME);
        end
        elapsedSec = toc(t);
        entry = struct('Viewer', viewer, ...
            'CreatedAtUtc', localNowUtc(), ...
            'OSMFile', key, ...
            'OSMFileSizeMB', osmFileSizeMB, ...
            'MapFileUsed', mapFileUsed, ...
            'MaterialSanitized', materialSanitized, ...
            'Terrain', 'none');
        cache(key) = entry;
        csrd.runtime.performance.trace('count', ...
            'RayTracing.SiteviewerConstruct', 1, ...
            struct('OSMFile', key, ...
                'OSMFileSizeMB', osmFileSizeMB, ...
                'Scope', 'process'));
        csrd.runtime.performance.trace('event', ...
            'RayTracing.SiteviewerConstruct', elapsedSec, ...
            struct('OSMFile', key, ...
                'OSMFileSizeMB', osmFileSizeMB, ...
                'MapFileUsed', mapFileUsed, ...
                'MaterialSanitized', materialSanitized, ...
                'Terrain', 'none', ...
                'Scope', 'process'));
        info = struct('CacheHit', false, 'OSMFile', key, ...
            'OSMFileSizeMB', osmFileSizeMB, ...
            'MapFileUsed', mapFileUsed, ...
            'MaterialSanitized', materialSanitized, ...
            'Terrain', 'none', ...
            'ElapsedSec', elapsedSec);
        varargout = {viewer, info};

    case 'clear'
        keysList = keys(cache);
        for idx = 1:numel(keysList)
            entry = cache(keysList{idx});
            if isstruct(entry) && isfield(entry, 'Viewer')
                localDeleteViewer(entry.Viewer);
            end
        end
        cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        varargout = {struct('Cleared', numel(keysList))};

    case 'retain'
        if nargin < 2 || isempty(osmFile)
            retainAcrossReleases = true;
        else
            retainAcrossReleases = logical(osmFile);
        end
        varargout = {struct('RetainAcrossReleases', retainAcrossReleases)};

    case 'release'
        if retainAcrossReleases
            varargout = {struct('Cleared', 0, ...
                'RetainedAcrossRunner', true)};
        else
            varargout = {csrd.runtime.map.osmSiteViewerCache('clear')};
        end

    case 'snapshot'
        keysList = keys(cache);
        varargout = {struct('Count', numel(keysList), ...
            'OSMFiles', {keysList}, ...
            'RetainAcrossReleases', retainAcrossReleases)};

    otherwise
        error('CSRD:Map:UnknownSiteViewerCacheAction', ...
            'Unknown osmSiteViewerCache action "%s".', cmd);
end
end

function localDeleteViewer(viewer)
    % localDeleteViewer - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(viewer)
    return;
end
if ~isobject(viewer)
    return;
end
try
    canDelete = true;
    try
        canDelete = isvalid(viewer);
    catch
        canDelete = true;
    end
    if canDelete
        delete(viewer);
    end
catch
end
end

function tf = localIsCacheEntryUsable(entry)
    % localIsCacheEntryUsable - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isstruct(entry) && isfield(entry, 'Viewer') && ...
    localIsUsableViewer(entry.Viewer);
end

function tf = localIsUsableViewer(viewer)
    % localIsUsableViewer - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = ~isempty(viewer) && isobject(viewer);
if ~tf
    return;
end
try
    tf = isvalid(viewer);
catch
    % Some MATLAB value objects accepted by raytrace do not implement
    % isvalid. They are still usable as long as they are real objects; the
    % important guard here is rejecting structs and other non-map handles.
    tf = true;
end
end

function value = getStructField(s, fieldName, defaultValue)
    % getStructField - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function stamp = localNowUtc()
    % localNowUtc - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function sizeMB = localFileSizeMB(pathText)
    % localFileSizeMB - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
sizeMB = NaN;
if isempty(pathText)
    return;
end
info = dir(char(string(pathText)));
if ~isempty(info)
    sizeMB = double(info.bytes) / 1024 / 1024;
end
end
