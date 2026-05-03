function results = run_csrd_release_ci_readiness(varargin)
%RUN_CSRD_RELEASE_CI_READINESS Aggregate Phase 6 release/CI gates.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 run_csrd_release_ci_readiness 实现。
%
%   RESULTS = run_csrd_release_ci_readiness() runs the release-owner gate:
%   frozen baseline readiness, Phase 6 curated suite, performance
%   diagnostics, and local CI smoke. It does not run the 1000-scenario MC.
%
%   RESULTS = run_csrd_release_ci_readiness('RunCiSmoke', false) skips the
%   long smoke-scale simulation and records that skip explicitly. This mode
%   is for cheap regression testing of the aggregator itself.

p = inputParser;
addParameter(p, 'RunCiSmoke', true, @islogical);
addParameter(p, 'CiIncludePhase4', true, @islogical);
addParameter(p, 'CiBaselineScenarios', 12, @isPositiveInteger);
addParameter(p, 'MaxCiSmokeSeconds', 1800, @isPositiveScalar);
addParameter(p, 'IncludePhase6Suite', true, @islogical);
addParameter(p, 'IncludePerformanceDiagnostics', true, @islogical);
addParameter(p, 'EnforceGitClean', false, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tests'));
addpath(fullfile(projectRoot, 'tools', 'ci'));
addpath(fullfile(projectRoot, 'tools', 'phase5'));
addpath(fullfile(projectRoot, 'tools', 'phase6'));
addpath(fullfile(projectRoot, 'tools', 'release'));

if p.Results.Verbose
    fprintf('=== CSRD release CI readiness ===\n');
    fprintf('Project root: %s\n', projectRoot);
end

releaseReadiness = runTimedGate('release_readiness', ...
    @() run_csrd_release_readiness( ...
        'EnforceGitClean', p.Results.EnforceGitClean), ...
    p.Results.Verbose);

phase6Suite = makeSkippedGate('phase6_suite', ...
    'IncludePhase6Suite=false');
if p.Results.IncludePhase6Suite
    phase6Suite = runTimedGate('phase6_suite', ...
        @() localRunPhase6Suite(), p.Results.Verbose);
end

performanceDiagnostics = makeSkippedGate('performance_diagnostics', ...
    'IncludePerformanceDiagnostics=false');
if p.Results.IncludePerformanceDiagnostics
    performanceDiagnostics = runTimedGate('performance_diagnostics', ...
        @() run_phase6_performance_diagnostics('Verbose', false), ...
        p.Results.Verbose);
end

ciSmoke = makeSkippedGate('ci_smoke', 'RunCiSmoke=false');
if p.Results.RunCiSmoke
    ciSmoke = runTimedGate('ci_smoke', ...
        @() run_csrd_ci_smoke( ...
            'IncludePhase4', p.Results.CiIncludePhase4, ...
            'BaselineScenarios', p.Results.CiBaselineScenarios), ...
        p.Results.Verbose);
    assert(ciSmoke.ElapsedSeconds <= p.Results.MaxCiSmokeSeconds, ...
        'CSRD:ReleaseCI:CiSmokeTimeout', ...
        ['CI smoke elapsed %.2f s, exceeding the %.2f s release ', ...
         'readiness limit.'], ...
        ciSmoke.ElapsedSeconds, p.Results.MaxCiSmokeSeconds);
end

gates = [releaseReadiness, phase6Suite, performanceDiagnostics, ciSmoke];
results = struct();
results.Success = all([gates.Success]);
results.ProjectRoot = projectRoot;
results.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
results.Schema = 'csrd.phase6.release-ci-readiness.v1';
results.Gates = gates;
results.ReleaseReadiness = releaseReadiness.Payload;
results.Phase6Suite = phase6Suite.Payload;
results.PerformanceDiagnostics = performanceDiagnostics.Payload;
results.CiSmoke = ciSmoke.Payload;
results.ReleaseReadinessSkipped = releaseReadiness.Skipped;
results.Phase6SuiteSkipped = phase6Suite.Skipped;
results.PerformanceDiagnosticsSkipped = performanceDiagnostics.Skipped;
results.CiSmokeSkipped = ciSmoke.Skipped;
results.CiSmokeElapsedSeconds = ciSmoke.ElapsedSeconds;
results.CiSmokeLimitSeconds = double(p.Results.MaxCiSmokeSeconds);
results.CanonicalFullMcPolicy = 'not-run-by-release-ci-readiness';
results.SkippedLongChecksExplicit = ~p.Results.RunCiSmoke;

if p.Results.Verbose
    fprintf('=== CSRD release CI readiness %s ===\n', passFail(results.Success));
end
end


function tf = isPositiveInteger(value)
    % isPositiveInteger - Production declaration in CSRD.
    % 中文说明：isPositiveInteger 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 1 ...
    && floor(value) == value;
end


function tf = isPositiveScalar(value)
    % isPositiveScalar - Production declaration in CSRD.
    % 中文说明：isPositiveScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end


function gate = runTimedGate(name, fn, verbose)
    % runTimedGate - Production declaration in CSRD.
    % 中文说明：runTimedGate 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if verbose
    fprintf('  %s ...\n', name);
end
t0 = tic;
payload = fn();
elapsed = toc(t0);
gate = struct( ...
    'Name', name, ...
    'Success', true, ...
    'Skipped', false, ...
    'SkipReason', '', ...
    'ElapsedSeconds', elapsed, ...
    'Payload', payload);
if verbose
    fprintf('  %s PASS (%.2fs)\n', name, elapsed);
end
end


function gate = makeSkippedGate(name, reason)
    % makeSkippedGate - Production declaration in CSRD.
    % 中文说明：makeSkippedGate 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
gate = struct( ...
    'Name', name, ...
    'Success', true, ...
    'Skipped', true, ...
    'SkipReason', reason, ...
    'ElapsedSeconds', 0, ...
    'Payload', struct('Success', true, 'Skipped', true, ...
        'SkipReason', reason));
end


function results = localRunPhase6Suite()
    % localRunPhase6Suite - Production declaration in CSRD.
    % 中文说明：localRunPhase6Suite 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
results = run_all_tests('phase6');
assert(results.Success, ...
    'CSRD:ReleaseCI:Phase6SuiteFailed', ...
    'run_all_tests(''phase6'') failed.');
end


function text = passFail(tf)
    % passFail - Production declaration in CSRD.
    % 中文说明：passFail 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if tf
    text = 'PASSED';
else
    text = 'FAILED';
end
end
