function test_phase6_performance_diagnostics()
%TEST_PHASE6_PERFORMANCE_DIAGNOSTICS Read-only S6 diagnostics regression.

here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools', 'phase6'));

outDir = tempname;
cleanup = onCleanup(@() localRemoveDir(outDir));
outPath = fullfile(outDir, 'phase6-performance.json');

results = run_phase6_performance_diagnostics( ...
    'Verbose', false, ...
    'OutputJsonPath', outPath);

assert(results.Success, 'Phase 6 performance diagnostics did not pass.');
assert(isfile(outPath), ...
    'Phase 6 performance diagnostics JSON output was not written.');
decoded = jsondecode(fileread(outPath));
assert(decoded.Success, ...
    'Written Phase 6 performance diagnostics JSON did not preserve Success.');
assert(~results.Microbench.Ran, ...
    'Microbench must be opt-in so phase6 tests stay cheap.');

wallP95 = results.BaselineComparison.WallclockSecPerScenarioP95;
assert(strcmp(wallP95.Diagnostic, 'watch'), ...
    'Wallclock P95 increase should be reported as diagnostic watch.');
assert(wallP95.Final > wallP95.Reference, ...
    'Expected final-v04 P95 wallclock to exceed Phase 4 baseline.');

bw = results.BaselineComparison.ExecutionVsMeasuredBwAbsRelDiffP95;
assert(bw.Final < 0.03, ...
    'S6 must preserve the frozen BW correctness metric.');

checks = results.FrozenContracts.Checks;
assert(all([checks.Passed]), ...
    'S6 diagnostics must not weaken frozen correctness contracts.');

hotspots = results.StaticHotspots.Items;
names = {hotspots.Name};
assert(any(strcmp(names, 'obwActualUsesPwelch')), ...
    'S6 hotspot report must include obwActual/pwelch.');
assert(any(strcmp(names, 'FramePlaneCachePresent')), ...
    'S6 hotspot report must include FramePlane cache.');

delete(cleanup);
end


function localRemoveDir(path)
if exist(path, 'dir') == 7
    rmdir(path, 's');
end
end
