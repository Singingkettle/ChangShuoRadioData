function results = run_csrd_ci_smoke(varargin)
%RUN_CSRD_CI_SMOKE Local entry point for the Phase 5 CI smoke gate.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：提供 CSRD 生产链路中的 run_csrd_ci_smoke 实现。

p = inputParser;
addParameter(p, 'IncludePhase4', true, @islogical);
addParameter(p, 'BaselineScenarios', 12, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tests'));
addpath(fullfile(projectRoot, 'tests', 'regression'));
addpath(fullfile(projectRoot, 'tools', 'ci'));
addpath(fullfile(projectRoot, 'tools', 'phase5'));

fprintf('=== CSRD CI smoke ===\n');
fprintf('Project root: %s\n', projectRoot);

fprintf('  Static gates ... ');
run_csrd_static_gates();
fprintf('PASS\n');

phase4 = struct('Success', true, 'Skipped', true);
if p.Results.IncludePhase4
    fprintf('  Phase 4 curated suite ...\n');
    phase4 = run_all_tests('phase4');
    assert(phase4.Success, ...
        'CSRD:CI:Phase4Failed', ...
        'run_all_tests(''phase4'') failed.');
else
    fprintf('  Phase 4 curated suite ... SKIP\n');
end

fprintf('  Phase 5 MC wrapper smoke ...\n');
baselinePath = run_phase5_mc_validation(p.Results.BaselineScenarios, ...
    'Mode', 'smoke');

results = struct( ...
    'Success', true, ...
    'Phase4', phase4, ...
    'BaselinePath', baselinePath, ...
    'BaselineScenarios', double(p.Results.BaselineScenarios));

fprintf('=== CSRD CI smoke PASSED ===\n');
end
