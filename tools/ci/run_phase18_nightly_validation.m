function summary = run_phase18_nightly_validation(varargin)
%RUN_PHASE18_NIGHTLY_VALIDATION Execute Phase 18 full validation.
% 中文说明：Phase 18 夜跑入口；默认执行 69-case 非 dry-run 验证。

p = inputParser;
addParameter(p, 'DryRun', false, @islogical);
addParameter(p, 'WorkerId', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'NumWorkers', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

configName = 'csrd2025/csrd2025_osm_raytracing_validation.m';
cfg = csrd.runtime.config_loader(configName);

fprintf('[Phase18] Starting full runtime-truth validation. DryRun=%d\n', ...
    p.Results.DryRun);
summary = csrd.support.validation.runFullCoverageValidation( ...
    cfg, configName, projectRoot, p.Results.WorkerId, p.Results.NumWorkers, ...
    'DryRun', p.Results.DryRun);

if ~p.Results.DryRun
    records = summary.Records;
    statuses = strings(1, numel(records));
    for k = 1:numel(records)
        statuses(k) = string(records(k).Status);
    end
    if any(statuses == "Failed")
        error('CSRD:Phase18:NightlyValidationFailed', ...
            'Phase 18 nightly validation completed with failed records.');
    end
end

fprintf('[Phase18] Validation finished. Cases=%d Passed=%d Skipped=%d Failed=%d\n', ...
    summary.CasesBuilt, summary.CasesPassed, summary.CasesSkipped, ...
    summary.CasesFailed);
end
