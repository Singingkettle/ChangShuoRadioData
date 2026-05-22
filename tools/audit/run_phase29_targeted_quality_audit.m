function summary = run_phase29_targeted_quality_audit(varargin)
%RUN_PHASE29_TARGETED_QUALITY_AUDIT Phase 29 high-risk quality audit.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

p = inputParser();
p.FunctionName = 'run_phase29_targeted_quality_audit';
addParameter(p, 'ArtifactRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'BaseConfig', 'csrd2025/csrd2025.m', @(x) ischar(x) || isstring(x));
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'CaseNames', {}, @(x) iscell(x) || ischar(x) || isstring(x));
addParameter(p, 'StopOnFailure', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools'));

artifactRoot = char(string(p.Results.ArtifactRoot));
if isempty(artifactRoot)
    artifactRoot = fullfile(projectRoot, 'artifacts', 'audits', ...
        'phase29_targeted_quality');
elseif ~localIsAbsolutePath(artifactRoot)
    artifactRoot = fullfile(projectRoot, artifactRoot);
end
localEnsureDirectory(artifactRoot);
localEnsureDirectory(fullfile(artifactRoot, 'generated_configs'));
localEnsureDirectory(fullfile(artifactRoot, 'cases'));

cases = localCaseMatrix(projectRoot, char(string(p.Results.BaseConfig)));
cases = localFilterCases(cases, p.Results.CaseNames);

summary = struct();
summary.Schema = 'csrd.phase29.targeted-quality-audit.v1';
summary.GeneratedAtUtc = localUtcNow();
summary.ProjectRoot = projectRoot;
summary.ArtifactRoot = artifactRoot;
summary.DryRun = p.Results.DryRun;
summary.Cases = repmat(localEmptyCaseResult(), 0, 1);
summary.Totals = struct('Planned', numel(cases), 'Passed', 0, ...
    'Failed', 0, 'Skipped', 0);

for idx = 1:numel(cases)
    result = localPrepareCase(projectRoot, artifactRoot, cases(idx), idx);
    if p.Results.DryRun
        result.Status = 'Planned';
    else
        result = localExecuteCase(projectRoot, result);
    end
    summary.Cases(end + 1) = result; %#ok<AGROW>
    summary.Totals = localUpdateTotals(summary.Cases);
    localWriteJson(fullfile(artifactRoot, 'phase29_targeted_quality_summary.json'), ...
        summary);
    if p.Results.Verbose
        fprintf('Phase29 case %-38s status=%s\n', result.Name, result.Status);
    end
    if p.Results.StopOnFailure && strcmp(result.Status, 'Failed')
        break;
    end
end

summary.Success = summary.Totals.Failed == 0 && ...
    (p.Results.DryRun || summary.Totals.Passed == numel(summary.Cases));
summary.CompletedAtUtc = localUtcNow();
localWriteJson(fullfile(artifactRoot, 'phase29_targeted_quality_summary.json'), ...
    summary);
localWriteMarkdown(fullfile(artifactRoot, 'phase29_targeted_quality_summary.md'), ...
    summary);
end

function cases = localCaseMatrix(projectRoot, baseConfig)
    % localCaseMatrix - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
northDakota = fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Open_Farmland_Flat', ...
    'Open_Farmland_Flat_Central_North_Dakota_Farmland_USA_47.0000_-100.0000.osm');
london = fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Urban_Canyon', ...
    'Urban_Canyon_Queen_Victoria_Street_London_51.5120_-0.0930.osm');
barcelonaBridge = fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Bridge_Crossing_Area', ...
    'Bridge_Crossing_Area_Pont_del_Treball_Digne_Barcelona_41.3980_2.1990.osm');

cases = repmat(localEmptyCase(), 1, 7);
cases(1) = localCase('statistical_baseline_smoke', baseConfig, 20262901, ...
    2, 'Pure Statistical baseline.', 'Statistical', '');
cases(2) = localCase('empty_osm_flatterrain_north_dakota', baseConfig, ...
    20262902, 1, 'Empty OSM FlatTerrain regression; Terrain must be none.', ...
    'OSMFlatTerrain', northDakota);
cases(3) = localCase('osm_building_medium_london', baseConfig, 20262903, ...
    1, 'Building OSM RayTracing with material override.', ...
    'OSMBuildings', london);
cases(4) = localCase('osm_building_large_barcelona_bridge', baseConfig, ...
    20262904, 1, 'Large OSM RayTracing long-tail evidence.', ...
    'OSMBuildings', barcelonaBridge);
cases(5) = localCase('multi_link_raytracing_dense', baseConfig, 20262905, ...
    1, 'Dense Tx/Rx RayTracing link matrix.', 'OSMDenseLinks', london);
cases(6) = localCase('short_frame_measurement', baseConfig, 20262906, ...
    2, 'Short-frame measurement envelope and OBW contract.', ...
    'StatisticalShortFrame', '');
cases(7) = localCase('frequency_no_overlap_default', baseConfig, 20262907, ...
    4, 'Default planning must not need overlap allocation.', 'Default', '');
end

function rec = localCase(name, baseConfig, seed, numScenarios, description, mode, osmFile)
    % localCase - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = localEmptyCase();
rec.Name = name;
rec.Description = description;
rec.BaseConfig = baseConfig;
rec.Seed = seed;
rec.NumScenarios = numScenarios;
rec.Mode = mode;
rec.OSMFile = osmFile;
end

function rec = localEmptyCase()
    % localEmptyCase - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct('Name', '', 'Description', '', 'BaseConfig', '', ...
    'Seed', NaN, 'NumScenarios', 0, 'Mode', '', 'OSMFile', '');
end

function result = localPrepareCase(projectRoot, artifactRoot, c, index)
    % localPrepareCase - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
caseDir = fullfile(artifactRoot, 'cases', c.Name);
localEnsureDirectory(caseDir);
configPath = fullfile(artifactRoot, 'generated_configs', ...
    sprintf('phase29_%02d_%s.m', index, c.Name));
functionName = sprintf('phase29_%02d_%s', index, c.Name);
outputDirectory = sprintf('CSRD2025_phase29/%s', c.Name);
perfDir = fullfile(caseDir, 'performance');

localWriteCaseConfig(configPath, functionName, c, outputDirectory, perfDir);

result = localEmptyCaseResult();
result.Name = c.Name;
result.Description = c.Description;
result.Seed = c.Seed;
result.NumScenarios = c.NumScenarios;
result.Mode = c.Mode;
result.OSMFile = c.OSMFile;
result.OSMFileSizeMB = localFileSizeMB(c.OSMFile);
result.ConfigPath = configPath;
result.OutputDirectory = outputDirectory;
result.OutputRoot = fullfile(projectRoot, 'data', outputDirectory);
result.ArtifactDirectory = caseDir;
end

function localWriteCaseConfig(configPath, functionName, c, outputDirectory, perfDir)
    % localWriteCaseConfig - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
localEnsureDirectory(fileparts(configPath));
fid = fopen(configPath, 'w');
if fid == -1
    error('CSRD:Phase29Audit:ConfigOpenFailed', ...
        'Could not write case config: %s', configPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function config = %s()\n', functionName);
fprintf(fid, 'config.baseConfigs = {''%s''};\n', localEscape(c.BaseConfig));
fprintf(fid, 'config.Runner.NumScenarios = %d;\n', c.NumScenarios);
fprintf(fid, 'config.Runner.RandomSeed = %d;\n', c.Seed);
fprintf(fid, 'config.Runner.Data.OutputDirectory = ''%s'';\n', localEscape(outputDirectory));
fprintf(fid, 'config.Runner.Data.PrettyPrintAnnotations = false;\n');
fprintf(fid, 'config.Logging.Policy = ''LargeMC'';\n');
fprintf(fid, 'config.Logging.File.Enabled = true;\n');
fprintf(fid, 'config.Logging.Console.Enabled = false;\n');
fprintf(fid, 'config.Logging.Progress.Mode = ''Summary'';\n');
fprintf(fid, 'config.Runner.Performance.EnableStageTiming = true;\n');
fprintf(fid, 'config.Runner.Performance.EnableHeartbeat = true;\n');
fprintf(fid, 'config.Runner.Performance.RawEventLimit = 2000;\n');
fprintf(fid, 'config.Runner.Performance.PartialWriteInterval = 10;\n');
fprintf(fid, 'config.Runner.Performance.ArtifactDirectory = ''%s'';\n', ...
    localEscape(perfDir));
fprintf(fid, 'config.Metadata.Phase29Audit.CaseName = ''%s'';\n', ...
    localEscape(c.Name));
fprintf(fid, 'config.Metadata.Phase29Audit.RiskMode = ''%s'';\n', ...
    localEscape(c.Mode));

switch c.Mode
    case 'Statistical'
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''Statistical''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
    case 'Default'
        % Keep default config shape; log audit catches overlap warnings.
    case 'StatisticalShortFrame'
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''Statistical''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = ''Fixed'';\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = 1024;\n');
    otherwise
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''OSM''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = ''%s'';\n', ...
            localEscape(c.OSMFile));
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.EmptyGeometryPolicy = ''FlatTerrain'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Terrain = ''none'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Material = ''seawater'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.MaxNumReflections = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;\n');
        if strcmp(c.Mode, 'OSMDenseLinks')
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 3;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 3;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 2;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 2;\n');
        end
end
fprintf(fid, 'end\n');
clear cleanup;
end

function result = localExecuteCase(projectRoot, result)
    % localExecuteCase - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
result.StartedAtUtc = localUtcNow();
try
    simulation(1, 1, result.ConfigPath);
    result.Status = 'Passed';
catch ME
    result.Status = 'Failed';
    result.FirstFailure = struct('Detected', true, ...
        'Signature', ME.identifier, ...
        'Message', ME.message);
end
result.FinishedAtUtc = localUtcNow();
result.LogAudit = localAuditLogs(result.OutputRoot, result.ArtifactDirectory);
result.AnnotationAudit = localAuditAnnotations(result.OutputRoot);
if result.LogAudit.TotalHardFailures > 0
    result.Status = 'Failed';
    if ~result.FirstFailure.Detected
        result.FirstFailure = result.LogAudit.FirstFailure;
    end
end
if result.AnnotationAudit.InvalidMeasured > 0
    result.Status = 'Failed';
    if ~result.FirstFailure.Detected
        result.FirstFailure = struct('Detected', true, ...
            'Signature', 'InvalidMeasuredAnnotation', ...
            'Message', 'Measured annotation fields contain NaN/Inf.');
    end
end
localWriteJson(fullfile(result.ArtifactDirectory, 'case_result.json'), result);
end

function audit = localAuditLogs(outputRoot, artifactDir)
    % localAuditLogs - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
patterns = {'ERROR', '[FAILED]', 'CSRD:', 'FrameWindow', ...
    'detectBurstEnvelope', 'Measurement failed', 'RayTracing failed', ...
    'Insufficient bandwidth', 'Unable to access terrain', 'gmted2010', ...
    'Unable to find material', 'isvalid', 'DeprecatedOsmSizeCap'};
allowed = {'OSM file has no building data'};
files = [localListFiles(outputRoot, '*.log'); localListFiles(artifactDir, '*.log')];
first = struct('Detected', false, 'Signature', '', 'Message', '');
count = 0;
for idx = 1:numel(files)
    lines = splitlines(string(localReadText(files{idx})));
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

function audit = localAuditAnnotations(outputRoot)
    % localAuditAnnotations - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
files = localListFiles(outputRoot, '*_annotation.json');
invalidMeasured = 0;
noSignalNan = 0;
for idx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{idx}));
        [invalid, noSignal] = localAnnotationInvalidMeasured(payload);
        invalidMeasured = invalidMeasured + invalid;
        noSignalNan = noSignalNan + noSignal;
    catch
        invalidMeasured = invalidMeasured + 1;
    end
end
audit = struct('FilesScanned', numel(files), ...
    'InvalidMeasured', invalidMeasured, ...
    'NoSignalNaNAllowed', noSignalNan);
end

function [invalid, noSignal] = localAnnotationInvalidMeasured(value)
    % localAnnotationInvalidMeasured - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
invalid = 0;
noSignal = 0;
if isstruct(value)
    if numel(value) > 1
        for elemIdx = 1:numel(value)
            [childInvalid, childNoSignal] = ...
                localAnnotationInvalidMeasured(value(elemIdx));
            invalid = invalid + childInvalid;
            noSignal = noSignal + childNoSignal;
        end
        return;
    end
    if isfield(value, 'MeasurementStatus') && ...
            strcmpi(char(string(value.MeasurementStatus)), 'NoSignal')
        if localStructHasNan(value)
            noSignal = noSignal + 1;
        end
        return;
    end
    if isfield(value, 'MeasurementStatus') && ...
            strcmpi(char(string(value.MeasurementStatus)), 'Measured') && ...
            localStructHasNan(value)
        invalid = invalid + 1;
    end
    names = fieldnames(value);
    for idx = 1:numel(names)
        [childInvalid, childNoSignal] = localAnnotationInvalidMeasured(value.(names{idx}));
        invalid = invalid + childInvalid;
        noSignal = noSignal + childNoSignal;
    end
elseif iscell(value)
    for idx = 1:numel(value)
        [childInvalid, childNoSignal] = localAnnotationInvalidMeasured(value{idx});
        invalid = invalid + childInvalid;
        noSignal = noSignal + childNoSignal;
    end
end
end

function tf = localStructHasNan(value)
    % localStructHasNan - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = false;
if isnumeric(value)
    tf = any(~isfinite(value(:)));
elseif isstruct(value)
    if numel(value) > 1
        for elemIdx = 1:numel(value)
            if localStructHasNan(value(elemIdx))
                tf = true;
                return;
            end
        end
        return;
    end
    names = fieldnames(value);
    for idx = 1:numel(names)
        if localStructHasNan(value.(names{idx}))
            tf = true;
            return;
        end
    end
elseif iscell(value)
    for idx = 1:numel(value)
        if localStructHasNan(value{idx})
            tf = true;
            return;
        end
    end
end
end

function cases = localFilterCases(cases, names)
    % localFilterCases - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(names)
    return;
end
names = cellstr(string(names));
keep = false(1, numel(cases));
for idx = 1:numel(cases)
    keep(idx) = any(strcmp(cases(idx).Name, names));
end
missing = setdiff(names, {cases.Name});
if ~isempty(missing)
    error('CSRD:Phase29Audit:UnknownCase', ...
        'Unknown Phase 29 audit case(s): %s', strjoin(missing, ', '));
end
cases = cases(keep);
end

function totals = localUpdateTotals(results)
    % localUpdateTotals - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
status = string({results.Status});
totals = struct('Planned', sum(status == "Planned"), ...
    'Passed', sum(status == "Passed"), ...
    'Failed', sum(status == "Failed"), ...
    'Skipped', sum(status == "Skipped"));
end

function rec = localEmptyCaseResult()
    % localEmptyCaseResult - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct();
rec.Name = '';
rec.Description = '';
rec.Seed = NaN;
rec.NumScenarios = 0;
rec.Mode = '';
rec.OSMFile = '';
rec.OSMFileSizeMB = NaN;
rec.ConfigPath = '';
rec.OutputDirectory = '';
rec.OutputRoot = '';
rec.ArtifactDirectory = '';
rec.Status = 'Pending';
rec.StartedAtUtc = '';
rec.FinishedAtUtc = '';
rec.FirstFailure = struct('Detected', false, 'Signature', '', 'Message', '');
rec.LogAudit = struct();
rec.AnnotationAudit = struct();
end

function localWriteMarkdown(pathText, summary)
    % localWriteMarkdown - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
lines = strings(0, 1);
lines(end + 1) = "# Phase 29 Targeted Quality Audit";
lines(end + 1) = "";
lines(end + 1) = sprintf("- Generated: %s", summary.GeneratedAtUtc);
lines(end + 1) = sprintf("- DryRun: %s", mat2str(summary.DryRun));
lines(end + 1) = sprintf("- Passed: %d", summary.Totals.Passed);
lines(end + 1) = sprintf("- Failed: %d", summary.Totals.Failed);
lines(end + 1) = "";
lines(end + 1) = "| Case | Status | Seed | OSM File | Failure |";
lines(end + 1) = "| --- | --- | ---: | --- | --- |";
for idx = 1:numel(summary.Cases)
    c = summary.Cases(idx);
    lines(end + 1) = sprintf("| %s | %s | %d | %s | %s |", ...
        c.Name, c.Status, c.Seed, localMarkdownCell(c.OSMFile), ...
        localMarkdownCell(c.FirstFailure.Signature));
end
localWriteText(pathText, strjoin(lines, newline));
end

function value = localFileSizeMB(pathText)
    % localFileSizeMB - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = NaN;
if isempty(pathText) || ~isfile(pathText)
    return;
end
info = dir(pathText);
value = info.bytes / 1024^2;
end

function files = localListFiles(rootDir, pattern)
    % localListFiles - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
end

function sig = localNormalizeFailureSignature(line)
    % localNormalizeFailureSignature - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
sig = char(string(line));
sig = regexprep(sig, '^\d+/\d+\s+\d+:\d+:\d+\s+-\s+[^-]+-\s+', '');
sig = regexprep(sig, '\s+', ' ');
if strlength(string(sig)) > 240
    sig = char(extractBefore(string(sig), 241));
end
end

function text = localReadText(pathText)
    % localReadText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fid = fopen(pathText, 'r');
if fid == -1
    text = '';
    return;
end
cleanup = onCleanup(@() fclose(fid));
text = fread(fid, '*char').';
clear cleanup;
end

function localWriteText(pathText, text)
    % localWriteText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
localEnsureDirectory(fileparts(pathText));
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:Phase29Audit:WriteFailed', 'Could not write %s', pathText);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text);
clear cleanup;
end

function localWriteJson(pathText, payload)
    % localWriteJson - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
try
    text = jsonencode(payload, 'PrettyPrint', true);
catch
    text = jsonencode(payload);
end
localWriteText(pathText, text);
end

function localEnsureDirectory(pathText)
    % localEnsureDirectory - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(pathText)
    return;
end
if ~isfolder(pathText)
    mkdir(pathText);
end
end

function projectRoot = localProjectRoot()
    % localProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function tf = localIsAbsolutePath(pathText)
    % localIsAbsolutePath - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
pathText = char(string(pathText));
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || ...
    startsWith(pathText, filesep);
end

function escaped = localEscape(text)
    % localEscape - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
escaped = strrep(char(string(text)), '''', '''''');
end

function value = localMarkdownCell(value)
    % localMarkdownCell - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = char(string(value));
value = strrep(value, '|', '\|');
if isempty(value)
    value = '';
end
end

function stamp = localUtcNow()
    % localUtcNow - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
