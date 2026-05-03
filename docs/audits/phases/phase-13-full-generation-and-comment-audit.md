# Phase 13: Full Generation Config And Production Comment Audit
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

## Scope

Phase 13 moves from phase-gate testing to validation-grade data generation
through the public entrypoint `tools/simulation.m`. The default
`config/csrd2025/csrd2025.m` remains a normal steady-state configuration.
The heavy validation profile is isolated in
`config/csrd2025/csrd2025_full_coverage_validation.m`.

The same phase also audits production MATLAB files under `+csrd/`, `config/`,
and `tools/`. Tests are not part of the bilingual-comment normalization scope.

## Design Decisions

| Area | Decision |
| --- | --- |
| Entrypoint | All validation-grade generation starts from `simulation.m`. |
| Config strategy | Add a sibling full-coverage config instead of making `csrd2025.m` heavy by default. |
| Coverage execution | `simulation.m` detects `CoverageValidation.Enable=true` and delegates to `csrd.support.validation.runFullCoverageValidation`. |
| Generated configs | Per-case configs are generated under `data/CSRD2025_full_coverage_validation/generated_configs`. |
| Generated data | Per-case outputs are stored under `data/CSRD2025_full_coverage_validation/runs/<case>`. |
| Worker sharding | Case index modulo `num_workers`, so the same config can be split across workers. |
| Comment policy | One concise English responsibility line plus one concise Chinese responsibility line near the file header. |
| Reference policy | Files that cite external material use a unified `References / 参考资料` heading. Files without external references do not get empty reference blocks. |

## Coverage Matrix

The validation profile builds deterministic cases for:

- Regulatory regions and Tier 1 bands: CN, US, EU, JP, KR.
- Map modes: statistical, OSM flat-terrain fallback, and building OSM when local MATLAB support is available.
- Channel models: AWGN, Rayleigh, Rician, MultiPath, and RayTracing through OSM.
- All configured modulation factory handles discovered from `modulation_factory.m`.
- All configured Tx/Rx memoryless nonlinearity methods.
- Multi-Tx, multi-Rx, and varied Tx/Rx antenna counts.

Every generated annotation is read with `readAnnotationV2` and checked for
design/execution/measured consistency. Regulatory cases are checked against the
region catalog so frequency, bandwidth, modulation family, and radar exclusion
stay real instead of drifting back to random sampling.

## Implementation Notes

- `tools/simulation.m` now has a narrow Phase 13 dispatch branch gated only by
  `CoverageValidation.Enable=true`.
- `csrd.support.validation.runFullCoverageValidation` owns matrix construction,
  per-case config generation, public-entry simulation calls, annotation checks,
  worker sharding, and JSON summary output.
- `csrd.support.docs.auditProductionComments` owns production file enumeration,
  bilingual header checks, reference heading normalization, and optional
  manifest output.
- The generated production comment audit manifest is no longer committed. It can
  be regenerated with `WriteManifest=true`; the default output path is under
  ignored `artifacts/audits/reports/`.

## Verification Log

- 2026-04-30 initial audit:
  - Production `.m` files audited: 234.
  - Files needing bilingual header normalization before fixes: 230.
  - Files needing reference heading normalization before fixes: 8.
- 2026-04-30 normalization:
  - Added concise Chinese header lines where missing.
  - Normalized existing external-reference headings to
    `References / 参考资料`.
  - Final audit: 234 files audited, 0 missing bilingual headers, 0 reference
    heading issues.

The full generation and test results are appended as commands are run during
Phase 13 closure.

## Closure Results

- `test_phase13_full_coverage_config_load`: passed.
  - Dry-run matrix built 47 cases.
  - Building OSM was marked as an environment skip on this machine because
    local RF propagation/site functions are unavailable.
- `test_phase13_production_comment_audit`: passed.
  - Production files audited: 234.
  - Missing bilingual headers: 0.
  - Reference heading issues: 0.
- Formal generation entrypoint:
  - Command:
    `simulation(1, 1, 'csrd2025/csrd2025_full_coverage_validation.m')`.
  - Result: 47 selected cases, 46 passed, 1 skipped, 0 failed.
  - Coverage observed: 5 regions, 8 bands, 23 modulation families, 6 RF
    nonlinearity methods, 5 channel models, and 6 antenna combinations.
  - Output root:
    `data/CSRD2025_full_coverage_validation`.
  - Summary:
    `data/CSRD2025_full_coverage_validation/summaries/phase13_full_coverage_summary.json`.
- Phase gates after the full-generation and comment-audit changes:
  - `run_all_tests('phase2')`: 9 / 9 passed.
  - `run_all_tests('phase3')`: 9 / 9 passed.
  - `run_all_tests('phase4')`: 10 / 10 passed.
  - `run_all_tests('phase8')`: 10 / 10 passed.
  - `run_all_tests('phase9')`: 2 / 2 passed.
  - `run_all_tests('unit')`: 53 / 53 passed.
  - `run_all_tests('regression')`: 30 / 30 passed.

## Issue Found And Fixed

The first formal generation attempt failed before scenario execution because
the mechanical bilingual-comment pass inserted a Chinese header line inside a
continued `classdef` declaration in `Logger.m`. The audit tool was corrected to
move header comments after continued `function` / `classdef` signatures and to
keep the English help line before the Chinese line. The production comment
audit and all follow-up gates passed after that fix.
