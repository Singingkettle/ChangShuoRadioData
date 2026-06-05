function test_phase16_artifact_governance()
%TEST_PHASE16_ARTIFACT_GOVERNANCE Ensure generated outputs stay untracked.

fprintf('=== Phase 16 Artifact Governance Test ===\n');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
ignoreText = fileread(fullfile(projectRoot, '.gitignore'));
assert(contains(ignoreText, "artifacts/"), ...
    '.gitignore must ignore the generated artifacts root.');
assert(contains(ignoreText, "data/"), ...
    '.gitignore must ignore generated/formal data output.');

[status, tracked] = system('git ls-files artifacts data');
assert(status == 0, 'git ls-files artifacts data failed.');
tracked = strtrim(tracked);
assert(isempty(tracked), ...
    'Generated data/artifacts must not be tracked by git: %s', tracked);

legacyDirs = dir(fullfile(projectRoot, '**', 'csrd_simulation_output'));
legacyDirs = legacyDirs([legacyDirs.isdir]);
assert(isempty(legacyDirs), ...
    'csrd_simulation_output directories must not remain in the project.');

addpath(fullfile(projectRoot, 'tools', 'maintenance'));
report = clean_csrd_artifacts('DryRun', true, 'IncludeVisualChecks', true);
assert(isfield(report, 'Records') && report.Candidates > 0, ...
    'Artifact cleanup dry-run should report managed generated roots.');

fprintf('  [OK] artifacts/data are ignored and untracked; cleanup dry-run candidates=%d.\n', ...
    report.Candidates);
fprintf('=== Phase 16 Artifact Governance Test Passed ===\n');
end
