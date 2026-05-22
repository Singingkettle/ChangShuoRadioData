function summary = run_phase34_boundary_quality_audit(varargin)
%RUN_PHASE34_BOUNDARY_QUALITY_AUDIT High-risk boundary audit for Phase 34.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

p = inputParser();
p.FunctionName = 'run_phase34_boundary_quality_audit';
addParameter(p, 'ArtifactRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'BaseConfig', 'csrd2025/csrd2025.m', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunTargeted', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunStress', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'StressCount', 100, @localNonnegativeInteger);
addParameter(p, 'StopOnFailure', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools'));
addpath(fullfile(projectRoot, 'tools', 'audit'));

artifactRoot = char(string(p.Results.ArtifactRoot));
if isempty(artifactRoot)
    artifactRoot = fullfile(projectRoot, 'artifacts', 'audits', ...
        'phase34_boundary_quality');
elseif ~localIsAbsolutePath(artifactRoot)
    artifactRoot = fullfile(projectRoot, artifactRoot);
end
localEnsureDirectory(artifactRoot);

summary = struct();
summary.Schema = 'csrd.phase34.boundary-quality-audit.v1';
summary.GeneratedAtUtc = localUtcNow();
summary.ProjectRoot = projectRoot;
summary.ArtifactRoot = artifactRoot;
summary.DryRun = p.Results.DryRun;
summary.StaticAudit = localStaticAudit(projectRoot);
summary.Targeted = struct('Ran', false, 'Summary', struct());
summary.Stress = struct('Ran', false, 'Cases', repmat(localEmptyRunResult(), 0, 1));

if p.Results.RunTargeted
    targetedRoot = fullfile(artifactRoot, 'targeted');
    summary.Targeted.Ran = true;
    summary.Targeted.Summary = run_phase29_targeted_quality_audit( ...
        'ArtifactRoot', targetedRoot, ...
        'BaseConfig', p.Results.BaseConfig, ...
        'DryRun', p.Results.DryRun, ...
        'StopOnFailure', p.Results.StopOnFailure, ...
        'Verbose', p.Results.Verbose);
end

if p.Results.RunStress && p.Results.StressCount > 0 && ...
        localTargetedAllowsStress(summary.Targeted, p.Results.StopOnFailure)
    stressRoot = fullfile(artifactRoot, 'stress');
    summary.Stress.Ran = true;
    summary.Stress.Cases = localRunStress(projectRoot, stressRoot, ...
        char(string(p.Results.BaseConfig)), p.Results.StressCount, ...
        p.Results.DryRun, p.Results.StopOnFailure, p.Results.Verbose);
end

summary.Totals = localComputeTotals(summary);
summary.Success = summary.StaticAudit.NumBlockers == 0 && ...
    summary.Totals.Failed == 0 && ...
    (summary.DryRun || summary.Totals.Passed > 0 || summary.Totals.Planned > 0);
summary.CompletedAtUtc = localUtcNow();
localWriteJson(fullfile(artifactRoot, 'phase34_boundary_quality_summary.json'), ...
    summary);
localWriteMarkdown(fullfile(artifactRoot, 'phase34_boundary_quality_summary.md'), ...
    summary);

if p.Results.Verbose
    localPrintSummary(summary);
end
end

function cases = localRunStress(projectRoot, stressRoot, baseConfig, ...
        stressCount, dryRun, stopOnFailure, verbose)
            % localRunStress - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
localEnsureDirectory(stressRoot);
localEnsureDirectory(fullfile(stressRoot, 'generated_configs'));
localEnsureDirectory(fullfile(stressRoot, 'cases'));
cases = repmat(localEmptyRunResult(), stressCount, 1);
modes = {'Default', 'Statistical', 'StatisticalShortFrame', ...
    'OSMFlatTerrain', 'OSMBuildings', 'OSMDenseLinks'};
for idx = 1:stressCount
    mode = modes{mod(idx - 1, numel(modes)) + 1};
    seed = 20263400 + idx * 7919;
    rec = localPrepareStressCase(projectRoot, stressRoot, baseConfig, ...
        idx, seed, mode);
    if dryRun
        rec.Status = 'Planned';
    else
        rec = localExecuteCase(rec);
    end
    cases(idx) = rec;
    localWriteJson(fullfile(stressRoot, 'phase34_stress_partial.json'), ...
        cases(1:idx));
    if verbose
        fprintf('Phase34 stress %03d/%03d mode=%s status=%s\n', ...
            idx, stressCount, mode, rec.Status);
    end
    if stopOnFailure && strcmp(rec.Status, 'Failed')
        cases = cases(1:idx);
        break;
    end
end
end

function rec = localPrepareStressCase(projectRoot, stressRoot, baseConfig, ...
        index, seed, mode)
            % localPrepareStressCase - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
name = sprintf('stress_%03d_%s', index, lower(mode));
caseDir = fullfile(stressRoot, 'cases', name);
localEnsureDirectory(caseDir);
configPath = fullfile(stressRoot, 'generated_configs', ...
    sprintf('phase34_%s.m', name));
functionName = sprintf('phase34_%s', name);
outputDirectory = sprintf('CSRD2025_phase34/%s', name);
perfDir = fullfile(caseDir, 'performance');
osmFile = localOsmFileForMode(projectRoot, mode);
localWriteCaseConfig(configPath, functionName, baseConfig, outputDirectory, ...
    perfDir, mode, osmFile, seed);

rec = localEmptyRunResult();
rec.Name = name;
rec.Seed = seed;
rec.Mode = mode;
rec.NumScenarios = 1;
rec.OSMFile = osmFile;
rec.OSMFileSizeMB = localFileSizeMB(osmFile);
rec.ConfigPath = configPath;
rec.OutputDirectory = outputDirectory;
rec.OutputRoot = fullfile(projectRoot, 'data', outputDirectory);
rec.ArtifactDirectory = caseDir;
end

function result = localExecuteCase(result)
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
if localAnnotationAuditFailed(result.AnnotationAudit)
    result.Status = 'Failed';
    if ~result.FirstFailure.Detected
        result.FirstFailure = struct('Detected', true, ...
            'Signature', 'AnnotationContractFailure', ...
            'Message', 'Annotation audit found invalid measured/sample-grid/ScenarioPlan fields.');
    end
end
localWriteJson(fullfile(result.ArtifactDirectory, 'case_result.json'), result);
end

function localWriteCaseConfig(configPath, functionName, baseConfig, ...
        outputDirectory, perfDir, mode, osmFile, seed)
            % localWriteCaseConfig - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
localEnsureDirectory(fileparts(configPath));
fid = fopen(configPath, 'w');
if fid == -1
    error('CSRD:Phase34Audit:ConfigOpenFailed', ...
        'Could not write case config: %s', configPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function config = %s()\n', functionName);
fprintf(fid, 'config.baseConfigs = {''%s''};\n', localEscape(baseConfig));
fprintf(fid, 'config.Runner.NumScenarios = 1;\n');
fprintf(fid, 'config.Runner.RandomSeed = %d;\n', seed);
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
fprintf(fid, 'config.Metadata.Phase34Audit.Mode = ''%s'';\n', localEscape(mode));

switch mode
    case 'Default'
        % Keep inherited defaults.
    case 'Statistical'
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''Statistical''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
    case 'StatisticalShortFrame'
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''Statistical''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = ''Fixed'';\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = 1024;\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = ''Fixed'';\n');
        fprintf(fid, 'config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Value = 2;\n');
    otherwise
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''OSM''};\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = ''%s'';\n', ...
            localEscape(osmFile));
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.EmptyGeometryPolicy = ''FlatTerrain'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Terrain = ''none'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Material = ''seawater'';\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.MaxNumReflections = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;\n');
        fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;\n');
        if strcmp(mode, 'OSMDenseLinks')
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 3;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 3;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 2;\n');
            fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 2;\n');
        end
end
fprintf(fid, 'end\n');
clear cleanup;
end

function pathText = localOsmFileForMode(projectRoot, mode)
    % localOsmFileForMode - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
pathText = '';
switch mode
    case 'OSMFlatTerrain'
        pathText = fullfile(projectRoot, 'data', 'map', 'osm', ...
            'Open_Farmland_Flat', ...
            'Open_Farmland_Flat_Central_North_Dakota_Farmland_USA_47.0000_-100.0000.osm');
    case {'OSMBuildings', 'OSMDenseLinks'}
        pathText = fullfile(projectRoot, 'data', 'map', 'osm', ...
            'Urban_Canyon', ...
            'Urban_Canyon_Queen_Victoria_Street_London_51.5120_-0.0930.osm');
end
end

function audit = localStaticAudit(projectRoot)
    % localStaticAudit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
audit = struct('NumBlockers', 0, 'Findings', {{}});
rules = { ...
    struct('FilePattern', '+csrd/**/*.m', 'Pattern', ['normalize' 'RuntimeContracts'], ...
        'Message', 'Production code calls legacy runtime normalizer.'), ...
    struct('FilePattern', '+csrd/**/*.m', 'Pattern', 'RuntimePlan\.Frame\.', ...
        'Message', 'Production code reads resolved RuntimePlan.Frame facts.'), ...
    struct('FilePattern', '+csrd/**/*.m', 'Pattern', ['Global' '\.FrameLength'], ...
        'Message', 'Production code reads/writes legacy frame length.'), ...
    struct('FilePattern', '+csrd/**/*.m', 'Pattern', ['Global' '\.ObservationDuration'], ...
        'Message', 'Production code reads/writes legacy observation duration.')};
for idx = 1:numel(rules)
    files = dir(fullfile(projectRoot, rules{idx}.FilePattern));
    for fileIdx = 1:numel(files)
        pathText = fullfile(files(fileIdx).folder, files(fileIdx).name);
        relPath = localRelativePath(projectRoot, pathText);
        if contains(relPath, '+pipeline\+runtime\buildRuntimePlan.m') || ...
                contains(relPath, '+pipeline/+runtime/buildRuntimePlan.m')
            continue;
        end
        text = localReadText(pathText);
        if ~isempty(regexp(text, rules{idx}.Pattern, 'once'))
            audit.NumBlockers = audit.NumBlockers + 1;
            audit.Findings{end + 1} = struct( ... %#ok<AGROW>
                'File', relPath, ...
                'Pattern', rules{idx}.Pattern, ...
                'Message', rules{idx}.Message);
        end
    end
end

frameLoopFiles = { ...
    fullfile(projectRoot, '+csrd', '+core', '@ChangShuo', 'private', 'generateSingleFrame.m'), ...
    fullfile(projectRoot, '+csrd', '+core', '@ChangShuo', 'private', 'processReceiverProcessing.m')};
for idx = 1:numel(frameLoopFiles)
    if ~isfile(frameLoopFiles{idx})
        continue;
    end
    text = localReadText(frameLoopFiles{idx});
    if ~isempty(regexp(text, 'buildScenarioPlan\s*\(|planScenario\s*\(', 'once'))
        audit.NumBlockers = audit.NumBlockers + 1;
        audit.Findings{end + 1} = struct( ...
            'File', localRelativePath(projectRoot, frameLoopFiles{idx}), ...
            'Pattern', 'buildScenarioPlan|planScenario', ...
            'Message', 'Frame loop must not resample scenario-level facts.');
    end
end
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
audit = struct('FilesScanned', numel(files), ...
    'InvalidMeasured', 0, ...
    'NoSignalNaNAllowed', 0, ...
    'MissingTruthSplit', 0, ...
    'FrameContractMismatches', 0, ...
    'ExecutionGridMismatches', 0, ...
    'ExecutionOutsideFrame', 0, ...
    'ScenarioPlanMissing', 0);
for idx = 1:numel(files)
    try
        payload = jsondecode(localReadText(files{idx}));
        audit = localAccumulateAnnotationAudit(audit, payload);
    catch
        audit.InvalidMeasured = audit.InvalidMeasured + 1;
    end
end
end

function audit = localAccumulateAnnotationAudit(audit, value)
    % localAccumulateAnnotationAudit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(value)
    if numel(value) > 1
        for elemIdx = 1:numel(value)
            audit = localAccumulateAnnotationAudit(audit, value(elemIdx));
        end
        return;
    end
    if localIsFrameAnnotationStruct(value)
        if ~isfield(value, 'ScenarioPlan') || ~isstruct(value.ScenarioPlan) || ...
                ~isfield(value.ScenarioPlan, 'Frame') || ...
                ~isfield(value.ScenarioPlan.Frame, 'FrameNumSamples')
            audit.ScenarioPlanMissing = audit.ScenarioPlanMissing + 1;
        elseif double(value.FrameLengthSamples) ~= ...
                double(value.ScenarioPlan.Frame.FrameNumSamples)
            audit.FrameContractMismatches = audit.FrameContractMismatches + 1;
        end
    end
    if isfield(value, 'Truth') && isstruct(value.Truth)
        audit = localAuditTruthStruct(audit, value.Truth);
    end
    if isfield(value, 'MeasurementStatus')
        status = char(string(value.MeasurementStatus));
        if strcmpi(status, 'NoSignal')
            if localStructHasNan(value)
                audit.NoSignalNaNAllowed = audit.NoSignalNaNAllowed + 1;
            end
            return;
        elseif strcmpi(status, 'Measured') && localStructHasNan(value)
            audit.InvalidMeasured = audit.InvalidMeasured + 1;
        end
    end
    names = fieldnames(value);
    for idx = 1:numel(names)
        audit = localAccumulateAnnotationAudit(audit, value.(names{idx}));
    end
elseif iscell(value)
    for idx = 1:numel(value)
        audit = localAccumulateAnnotationAudit(audit, value{idx});
    end
end
end

function tf = localIsFrameAnnotationStruct(value)
    % localIsFrameAnnotationStruct - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isfield(value, 'FrameId') && ...
    isfield(value, 'ReceiverID') && ...
    isfield(value, 'FrameLengthSamples');
end

function audit = localAuditTruthStruct(audit, truth)
    % localAuditTruthStruct - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
required = {'Design', 'Execution', 'Measured'};
for idx = 1:numel(required)
    if ~isfield(truth, required{idx})
        audit.MissingTruthSplit = audit.MissingTruthSplit + 1;
        return;
    end
end
ex = truth.Execution;
needed = {'SampleRate', 'StartTimeSec', 'EndTimeSec', ...
    'FrameStartSample', 'FrameEndSample', 'FrameLengthSamples'};
for idx = 1:numel(needed)
    if ~isfield(ex, needed{idx}) || ~isnumeric(ex.(needed{idx})) || ...
            ~isscalar(ex.(needed{idx})) || ~isfinite(ex.(needed{idx}))
        audit.ExecutionGridMismatches = audit.ExecutionGridMismatches + 1;
        return;
    end
end
sampleRate = double(ex.SampleRate);
startTime = double(ex.StartTimeSec);
endTime = double(ex.EndTimeSec);
startSample = double(ex.FrameStartSample);
endSample = double(ex.FrameEndSample);
frameSamples = double(ex.FrameLengthSamples);
tol = max(1e-12, 0.5 / sampleRate);
if abs(startTime - startSample / sampleRate) > tol || ...
        abs(endTime - endSample / sampleRate) > tol
    audit.ExecutionGridMismatches = audit.ExecutionGridMismatches + 1;
end
if startSample < 0 || endSample < startSample || endSample > frameSamples || ...
        startTime < -tol || endTime > frameSamples / sampleRate + tol
    audit.ExecutionOutsideFrame = audit.ExecutionOutsideFrame + 1;
end
end

function tf = localAnnotationAuditFailed(audit)
    % localAnnotationAuditFailed - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = audit.InvalidMeasured > 0 || ...
    audit.MissingTruthSplit > 0 || ...
    audit.FrameContractMismatches > 0 || ...
    audit.ExecutionGridMismatches > 0 || ...
    audit.ExecutionOutsideFrame > 0 || ...
    audit.ScenarioPlanMissing > 0;
end

function totals = localComputeTotals(summary)
    % localComputeTotals - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
totals = struct('Planned', 0, 'Passed', 0, 'Failed', 0, 'Skipped', 0);
if summary.Targeted.Ran && isfield(summary.Targeted.Summary, 'Totals')
    t = summary.Targeted.Summary.Totals;
    totals.Planned = totals.Planned + t.Planned;
    totals.Passed = totals.Passed + t.Passed;
    totals.Failed = totals.Failed + t.Failed;
    totals.Skipped = totals.Skipped + t.Skipped;
end
if summary.Stress.Ran
    status = string({summary.Stress.Cases.Status});
    totals.Planned = totals.Planned + sum(status == "Planned");
    totals.Passed = totals.Passed + sum(status == "Passed");
    totals.Failed = totals.Failed + sum(status == "Failed");
    totals.Skipped = totals.Skipped + sum(status == "Skipped");
end
if summary.StaticAudit.NumBlockers > 0
    totals.Failed = totals.Failed + summary.StaticAudit.NumBlockers;
end
end

function tf = localTargetedAllowsStress(targeted, stopOnFailure)
    % localTargetedAllowsStress - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = true;
if ~stopOnFailure || ~targeted.Ran || ~isfield(targeted.Summary, 'Totals')
    return;
end
tf = targeted.Summary.Totals.Failed == 0;
end

function rec = localEmptyRunResult()
    % localEmptyRunResult - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct();
rec.Name = '';
rec.Seed = NaN;
rec.Mode = '';
rec.NumScenarios = 0;
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

function localWriteMarkdown(pathText, summary)
    % localWriteMarkdown - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
lines = strings(0, 1);
lines(end + 1) = "# Phase 34 Boundary Quality Audit";
lines(end + 1) = "";
lines(end + 1) = sprintf("- Generated: %s", summary.GeneratedAtUtc);
lines(end + 1) = sprintf("- DryRun: %s", mat2str(summary.DryRun));
lines(end + 1) = sprintf("- Static blockers: %d", summary.StaticAudit.NumBlockers);
lines(end + 1) = sprintf("- Passed: %d", summary.Totals.Passed);
lines(end + 1) = sprintf("- Failed: %d", summary.Totals.Failed);
lines(end + 1) = sprintf("- Planned: %d", summary.Totals.Planned);
lines(end + 1) = "";
if summary.Stress.Ran
    lines(end + 1) = "## Stress Cases";
    lines(end + 1) = "";
    lines(end + 1) = "| Case | Mode | Status | Seed | Failure |";
    lines(end + 1) = "| --- | --- | --- | ---: | --- |";
    for idx = 1:numel(summary.Stress.Cases)
        c = summary.Stress.Cases(idx);
        lines(end + 1) = sprintf("| %s | %s | %s | %d | %s |", ...
            c.Name, c.Mode, c.Status, c.Seed, ...
            localMarkdownCell(c.FirstFailure.Signature));
    end
end
localWriteText(pathText, strjoin(lines, newline));
end

function localPrintSummary(summary)
    % localPrintSummary - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fprintf('=== Phase 34 Boundary Quality Audit ===\n');
fprintf('Artifact root: %s\n', summary.ArtifactRoot);
fprintf('Static blockers: %d\n', summary.StaticAudit.NumBlockers);
fprintf('Passed=%d Failed=%d Planned=%d\n', ...
    summary.Totals.Passed, summary.Totals.Failed, summary.Totals.Planned);
fprintf('Success: %s\n', mat2str(summary.Success));
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
    error('CSRD:Phase34Audit:WriteFailed', 'Could not write %s', pathText);
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

function relPath = localRelativePath(root, pathText)
    % localRelativePath - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
relPath = char(string(pathText));
root = char(string(root));
if startsWith(lower(relPath), lower(root))
    relPath = relPath(numel(root) + 1:end);
    if startsWith(relPath, filesep)
        relPath = relPath(2:end);
    end
end
end

function stamp = localUtcNow()
    % localUtcNow - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function localNonnegativeInteger(x)
    % localNonnegativeInteger - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x < 0 || floor(x) ~= x
    error('CSRD:Phase34Audit:InvalidInteger', ...
        'Value must be a nonnegative integer.');
end
end
