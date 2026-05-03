function summary = validateOsmRayTracingRun(dataRoot, varargin)
%VALIDATEOSMRAYTRACINGRUN Validate generated OSM RayTracing annotations.
% 中文说明：扫描正式生成目录，验证 OSM RayTracing、building/flat MapProfile 和标注执行事实一致。
%
% Inputs / 输入:
%   dataRoot - dataset or run root containing session annotations.
%   'RequireBuilding' - require at least one building OSM source.
%   'RequireFlat' - require at least one empty/no-building flat-terrain source.
%
% Outputs / 输出:
%   summary - counts and coverage labels for the scanned run.

p = inputParser;
addRequired(p, 'dataRoot', @(x) ischar(x) || isstring(x));
addParameter(p, 'RequireBuilding', true, @islogical);
addParameter(p, 'RequireFlat', true, @islogical);
parse(p, dataRoot, varargin{:});

root = char(string(p.Results.dataRoot));
assert(exist(root, 'dir') == 7, ...
    'CSRD:Validation:MissingDataRoot', ...
    'OSM RayTracing validation root does not exist: %s', root);

annotationFiles = dir(fullfile(root, '**', 'annotations', ...
    'scenario_*_annotation.json'));
assert(~isempty(annotationFiles), ...
    'CSRD:Validation:NoAnnotations', ...
    'No annotation files found under %s.', root);

summary = struct();
summary.DataRoot = string(root);
summary.AnnotationFiles = numel(annotationFiles);
summary.SourceCount = 0;
summary.OsmSourceCount = 0;
summary.BuildingSourceCount = 0;
summary.FlatSourceCount = 0;
summary.RayTracingSourceCount = 0;
summary.FallbackSourceCount = 0;
summary.MapModes = strings(0, 1);
summary.ChannelModels = strings(0, 1);

for k = 1:numel(annotationFiles)
    annotationPath = fullfile(annotationFiles(k).folder, annotationFiles(k).name);
    result = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
        'RequireSources', true, 'RequireRuntimeHeader', true);
    for s = 1:numel(result.Sources)
        source = result.Sources{s};
        summary.SourceCount = summary.SourceCount + 1;
        execution = source.Truth.Execution;
        channelModel = string(getTextField(execution, 'ChannelModel', ''));
        summary.ChannelModels(end + 1, 1) = channelModel; %#ok<AGROW>
        if channelModel == "RayTracing"
            summary.RayTracingSourceCount = summary.RayTracingSourceCount + 1;
        end

        if ~isfield(execution, 'MapProfile') || ~isstruct(execution.MapProfile)
            continue;
        end
        profile = execution.MapProfile;
        mode = string(getTextField(profile, 'Mode', ''));
        summary.MapModes(end + 1, 1) = mode; %#ok<AGROW>
        summary.OsmSourceCount = summary.OsmSourceCount + 1;

        assert(channelModel == "RayTracing", ...
            'CSRD:Validation:OsmNotRayTracing', ...
            'OSM source in %s did not report ChannelModel=RayTracing.', annotationPath);
        assert(isfield(profile, 'ChannelModel') && ...
            strcmp(char(profile.ChannelModel), 'RayTracing'), ...
            'CSRD:Validation:MapProfileModelMismatch', ...
            'OSM source in %s has non-RayTracing MapProfile.ChannelModel.', annotationPath);

        if mode == "OSMBuildings"
            assert(isfield(profile, 'HasBuildings') && logical(profile.HasBuildings), ...
                'CSRD:Validation:BuildingFlagMismatch', ...
                'Building OSM source in %s did not publish HasBuildings=true.', annotationPath);
            summary.BuildingSourceCount = summary.BuildingSourceCount + 1;
        elseif mode == "FlatTerrain"
            assert(isfield(profile, 'HasBuildings') && ~logical(profile.HasBuildings), ...
                'CSRD:Validation:FlatFlagMismatch', ...
                'Flat OSM source in %s did not publish HasBuildings=false.', annotationPath);
            assert(isfield(execution, 'ChannelFallback'), ...
                'CSRD:Validation:MissingFlatFallback', ...
                'Flat OSM source in %s did not publish ChannelFallback.', annotationPath);
            if strlength(string(execution.ChannelFallback)) > 0
                summary.FallbackSourceCount = summary.FallbackSourceCount + 1;
            end
            summary.FlatSourceCount = summary.FlatSourceCount + 1;
        end

        if isfield(execution, 'RayCount') && ~isempty(execution.RayCount)
            assert(isnumeric(execution.RayCount) && isscalar(execution.RayCount) && ...
                isfinite(execution.RayCount) && execution.RayCount >= 0, ...
                'CSRD:Validation:InvalidRayCount', ...
                'OSM source in %s has invalid RayCount.', annotationPath);
        end
    end
end

if p.Results.RequireBuilding
    assert(summary.BuildingSourceCount > 0, ...
        'CSRD:Validation:MissingBuildingCoverage', ...
        'No building OSM RayTracing sources were found under %s.', root);
end
if p.Results.RequireFlat
    assert(summary.FlatSourceCount > 0, ...
        'CSRD:Validation:MissingFlatCoverage', ...
        'No flat/no-building OSM RayTracing sources were found under %s.', root);
end
assert(summary.RayTracingSourceCount > 0, ...
    'CSRD:Validation:MissingRayTracingCoverage', ...
    'No RayTracing sources were found under %s.', root);
end


function value = getTextField(s, fieldName, fallback)
% getTextField - Read a text field from a struct with a safe fallback.
% 中文说明：从结构体读取文本字段，缺失时返回指定默认值。
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = fallback;
end
end
