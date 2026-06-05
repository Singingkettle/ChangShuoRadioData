function results = run_csrd_release_readiness(varargin)
%RUN_CSRD_RELEASE_READINESS Read-only release readiness gate for CSRD.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
%   RESULTS = run_csrd_release_readiness() validates the frozen v0.4
%   baseline and release documentation without running a simulation.
%
%   run_csrd_release_readiness('EnforceGitClean', true) additionally
%   fails when the working tree contains uncommitted non-ignored changes.

p = inputParser;
addParameter(p, 'BaselineFilename', '2026-04-final-v04.json', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'EnforceGitClean', false, @islogical);
addParameter(p, 'IncludeDownstreamDocs', true, @islogical);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools', 'ci'));
addpath(fullfile(projectRoot, 'tools', 'release'));

baselinePath = fullfile(projectRoot, 'docs', 'baselines', ...
    char(p.Results.BaselineFilename));
payload = localReadJson(baselinePath);

metrics = payload.Metrics;
diagnostics = metrics.Diagnostics;

localAssertString(payload.SchemaVersion, 'baseline-v04', ...
    'CSRD:Release:UnexpectedBaselineSchema');
localAssertString(payload.Mode, 'full', ...
    'CSRD:Release:UnexpectedBaselineMode');
localAssertScalar(payload.Recipe.NumScenarios, 1000, @ge, ...
    'CSRD:Release:TooFewBaselineScenarios', ...
    'final-v04 must contain at least 1000 scenarios.');
localAssertScalar(metrics.BlueprintAcceptanceRate, 0.98, @ge, ...
    'CSRD:Release:BlueprintAcceptanceLow', ...
    'BlueprintAcceptanceRate below release threshold.');
localAssertScalar(metrics.ChannelFactoryFailureRate, 0, @eq, ...
    'CSRD:Release:ChannelFactoryFailures', ...
    'ChannelFactoryFailureRate must remain zero.');
localAssertScalar(metrics.ExecutionVsMeasuredBwAbsRelDiffP95, 0.03, @lt, ...
    'CSRD:Release:BandwidthDriftHigh', ...
    'Execution-vs-measured bandwidth P95 exceeds 3%%.');
localAssertScalar(metrics.EmptySignalSegmentRatio, 0, @eq, ...
    'CSRD:Release:EmptySignalSegments', ...
    'EmptySignalSegmentRatio must remain zero.');
localAssertScalar(metrics.BlueprintProvenanceCoverage, 1, @eq, ...
    'CSRD:Release:MissingBlueprintProvenance', ...
    'Blueprint provenance must be present for every scenario.');
localAssertScalar(diagnostics.JsonNanCount, 0, @eq, ...
    'CSRD:Release:JsonNaN', ...
    'Baseline JSON diagnostics contain NaN entries.');
localAssertScalar(diagnostics.JsonInfinityCount, 0, @eq, ...
    'CSRD:Release:JsonInfinity', ...
    'Baseline JSON diagnostics contain Infinity entries.');

localAssertScalar(payload.RunRecovery.Resume, true, @eq, ...
    'CSRD:Release:BaselineNotResumable', ...
    'final-v04 must record resumable MC recovery metadata.');
localAssertScalar(payload.RunRecovery.NumRecoveredScenarios, ...
    payload.Recipe.NumScenarios, @eq, ...
    'CSRD:Release:RecoveredScenarioMismatch', ...
    'RunRecovery.NumRecoveredScenarios must match Recipe.NumScenarios.');

documentation = localValidateRequiredDocs(projectRoot);
downstreamDocs = struct('Success', true, 'Skipped', true, ...
    'SkipReason', 'IncludeDownstreamDocs=false');
if p.Results.IncludeDownstreamDocs
    downstreamDocs = run_csrd_downstream_docs_readiness('Verbose', false);
    assert(downstreamDocs.Success, ...
        'CSRD:Release:DownstreamDocsFailed', ...
        'Downstream documentation readiness failed.');
end

run_csrd_static_gates();

gitStatus = localGitStatus(projectRoot);
if p.Results.EnforceGitClean
    assert(strlength(strtrim(gitStatus)) == 0, ...
        'CSRD:Release:DirtyGitTree', ...
        'Working tree is not clean:%s%s', newline, gitStatus);
end

results = struct( ...
    'Success', true, ...
    'BaselinePath', baselinePath, ...
    'NumScenarios', double(payload.Recipe.NumScenarios), ...
    'ExecutionVsMeasuredBwAbsRelDiffP95', ...
        double(metrics.ExecutionVsMeasuredBwAbsRelDiffP95), ...
    'JsonNanCount', double(diagnostics.JsonNanCount), ...
    'JsonInfinityCount', double(diagnostics.JsonInfinityCount), ...
    'RunRecovery', payload.RunRecovery, ...
    'Documentation', documentation, ...
    'DownstreamDocs', downstreamDocs, ...
    'GitStatusShort', gitStatus);

fprintf('=== CSRD release readiness PASSED ===\n');
fprintf('Baseline: %s\n', baselinePath);
fprintf('Scenarios: %d\n', results.NumScenarios);
fprintf('BW P95 diff: %.6f\n', results.ExecutionVsMeasuredBwAbsRelDiffP95);
end


function payload = localReadJson(path)
    % localReadJson - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
assert(exist(path, 'file') == 2, ...
    'CSRD:Release:MissingBaseline', ...
    'Baseline JSON does not exist: %s', path);
payload = jsondecode(fileread(path));
end


function docs = localRequiredDocs(projectRoot)
    % localRequiredDocs - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
phaseDir = fullfile(projectRoot, 'docs', 'audits', 'phases');
reportDir = fullfile(projectRoot, 'docs', 'audits', 'reports');
docs = {
    fullfile(projectRoot, 'README.md'), ...
        {'Phase 6 Frozen', 'run_csrd_release_ci_readiness'};
    fullfile(projectRoot, 'docs', 'audits', ...
        '2026-04-spectrum-blueprint-construction-refactor.md'), ...
        {'Phase 6 Frozen', 'Draft v0.6.0'};
    fullfile(projectRoot, 'docs', 'audits', 'HANDOVER_2026-04-26.md'), ...
        {'Phase 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7 已 Frozen', ...
         'Phase 7 downstream release materials'};
    fullfile(phaseDir, 'phase-0-baseline.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-1-dataflow.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-2-blueprint.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-3-construction.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-4-measurement.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-5-mc-validation.md'), {'Frozen'};
    fullfile(phaseDir, 'phase-6-release-hardening.md'), ...
        {'Frozen', 'S8'};
    fullfile(reportDir, 'phase-6-performance-diagnostics.md'), ...
        {'Frozen', 'diagnostic-only-no-threshold'};
    fullfile(reportDir, 'phase-6-ci-readiness.md'), ...
        {'Frozen', '933.55 s'};
    fullfile(reportDir, 'phase-6-release-freeze.md'), ...
        {'Frozen', 'run_csrd_release_readiness'}};
end


function checks = localValidateRequiredDocs(projectRoot)
    % localValidateRequiredDocs - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
docs = localRequiredDocs(projectRoot);
checks = repmat( ...
    struct('Path', '', 'Needles', {{}}, 'Matched', false), ...
    size(docs, 1), 1);
for k = 1:size(docs, 1)
    path = docs{k, 1};
    needles = docs{k, 2};
    assert(exist(path, 'file') == 2, ...
        'CSRD:Release:MissingDocument', ...
        'Required release document is missing: %s', path);
    text = fileread(path);
    for j = 1:numel(needles)
        assert(contains(text, needles{j}), ...
            'CSRD:Release:DocumentContentMismatch', ...
            'Required release document %s does not contain "%s".', ...
            path, needles{j});
    end
    checks(k).Path = path;
    checks(k).Needles = needles;
    checks(k).Matched = true;
end
end


function status = localGitStatus(projectRoot)
    % localGitStatus - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
[code, out] = system(sprintf('git -C "%s" status --short', projectRoot));
if code ~= 0
    status = "";
    return;
end
status = string(strtrim(out));
end


function localAssertString(actual, expected, id)
    % localAssertString - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
assert(strcmp(char(actual), expected), id, ...
    'Expected "%s", got "%s".', expected, char(actual));
end


function localAssertScalar(actual, expected, predicate, id, message)
    % localAssertScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
assert(predicate(actual, expected), id, '%s', message);
end
