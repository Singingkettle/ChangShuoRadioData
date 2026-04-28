function test_phase6_release_ci_readiness()
%TEST_PHASE6_RELEASE_CI_READINESS Cheap S7 aggregator regression.
%
% The full release-owner command runs CI smoke and is validated manually in
% S7. This regression keeps RunCiSmoke=false and IncludePhase6Suite=false so
% run_all_tests('phase6') does not recursively invoke itself.

here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools', 'release'));
addpath(fullfile(projectRoot, 'tools', 'phase6'));
addpath(fullfile(projectRoot, 'tools', 'ci'));

results = run_csrd_release_ci_readiness( ...
    'RunCiSmoke', false, ...
    'IncludePhase6Suite', false, ...
    'Verbose', false);

assert(results.Success, 'Release CI readiness quick regression failed.');
assert(results.SkippedLongChecksExplicit, ...
    'RunCiSmoke=false must be recorded as an explicit long-check skip.');
assert(results.ReleaseReadiness.Success, ...
    'Release readiness payload must pass.');
assert(results.PerformanceDiagnostics.Success, ...
    'Performance diagnostics payload must pass.');
assert(results.CiSmokeSkipped, ...
    'CI smoke payload must record the explicit skip.');
assert(results.CiSmoke.Skipped, ...
    'Skipped CI smoke payload should still carry a Skipped flag.');

gateNames = {results.Gates.Name};
assert(any(strcmp(gateNames, 'release_readiness')), ...
    'Aggregator must include release_readiness gate.');
assert(any(strcmp(gateNames, 'performance_diagnostics')), ...
    'Aggregator must include performance_diagnostics gate.');
assert(any(strcmp(gateNames, 'ci_smoke')), ...
    'Aggregator must include ci_smoke gate even when skipped.');
end
