function test_phase13_full_coverage_config_load()
%TEST_PHASE13_FULL_COVERAGE_CONFIG_LOAD Validate the Phase 13 formal config.

fprintf('=== Phase 13 full coverage config load test ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

cfg = csrd.runtime.config_loader('csrd2025/csrd2025_full_coverage_validation.m');
assert(isfield(cfg, 'CoverageValidation') && cfg.CoverageValidation.Enable, ...
    'Phase 13 config must enable CoverageValidation.');
assert(strcmp(cfg.Runner.Data.OutputDirectory, ...
    'CSRD2025_full_coverage_validation'), ...
    'Phase 13 config must write to the formal validation output directory.');
assert(cfg.Runner.RandomSeed == 20260430, ...
    'Phase 13 config must use a fixed seed for reproducibility.');

summary = csrd.support.validation.runFullCoverageValidation(cfg, ...
    'csrd2025/csrd2025_full_coverage_validation.m', projectRoot, ...
    1, 1, 'DryRun', true);

assert(summary.DryRun, 'Expected a dry-run summary.');
assert(summary.CasesBuilt >= 40, ...
    'Phase 13 coverage matrix should include at least 40 validation cases.');
assert(summary.CasesSelected == summary.CasesBuilt, ...
    'Single-worker dry run should select the whole matrix.');

names = string({summary.Records.Name});
requiredCases = ["reg_CN_CN_FM_BROADCAST", "reg_US_US_ISM_915", ...
    "reg_EU_EU_DAB_VHF", "reg_JP_JP_ISDB_UHF", "reg_KR_KR_SRD_920", ...
    "channel_Rayleigh", "channel_Rician", "channel_MultiPath", ...
    "rf_cubic_polynomial", "multi_3tx_2rx_4txant_4rxant"];
for k = 1:numel(requiredCases)
    assert(any(names == requiredCases(k)), ...
        'Phase 13 matrix missing required case: %s.', requiredCases(k));
end

buildingIdx = find(names == "osm_building_CN_ISM_24", 1);
assert(~isempty(buildingIdx), ...
    'Phase 13 matrix must include the building OSM RayTracing case.');
buildingRecord = summary.Records(buildingIdx);
caps = csrd.runtime.capabilities.rfPropagationCapabilities();
if caps.CanUseBuildingOsmRayTracing
    assert(buildingRecord.Status == "DryRun", ...
        'Building OSM case must not be pre-skipped when RF propagation capabilities are available.');
    assert(strlength(buildingRecord.SkipReason) == 0, ...
        'Building OSM skip reason should be empty when capabilities are available.');
end

fprintf('  [OK] cases built: %d\n', summary.CasesBuilt);
fprintf('=== Phase 13 full coverage config load test PASSED ===\n');
end
