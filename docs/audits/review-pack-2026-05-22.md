# Review Pack 2026-05-22

This review pack summarizes the current local branch after the runtime-plan,
scenario-plan, logger, and documentation cleanup work. It is a guide for human
review, not an additional runtime contract.

## Branch

- Branch: `codex/phase35-review-curation-20260522`
- Purpose: make the Phase 33-35 refactoring reviewable in local commits.
- Generated data policy: no generated samples, logs, `.mat` files, or
  `artifacts/` outputs are committed.

## Commit Reading Order

1. `refactor: align runtime plans and logging authorities`
   - Focus: production code and config.
   - Review first:
     - `+csrd/+pipeline/+runtime/buildRuntimePlan.m`
     - `+csrd/+pipeline/+runtime/buildScenarioPlan.m`
     - `+csrd/SimulationRunner.m`
     - `+csrd/+factories/ScenarioFactory.m`
     - `tools/simulation.m`
     - logger files under `+csrd/+runtime/+logger/`
   - Key questions:
     - Does `RuntimePlan` stay run-level policy only?
     - Is each `ScenarioPlan` built before frame execution and then frozen?
     - Does `RuntimePlan.Logging` fully replace `config.Log` and `Runner.Log`?
     - Do progress messages remain visible under `LargeMC` without restoring
       console `INFO` spam?

2. `test: cover runtime plans logging and language gates`
   - Focus: contract and regression coverage.
   - Review first:
     - `tests/unit/ScenarioPlanBuildTest.m`
     - `tests/unit/ScenarioPlanFrozenBeforeFrameExecutionTest.m`
     - `tests/unit/LoggingPlanBuildTest.m`
     - `tests/unit/DeprecatedLoggingFieldsRejectedTest.m`
     - `tests/regression/test_phase14_production_english_comment_audit.m`
     - `tests/regression/test_no_chinese_comments_in_matlab_sources.m`
   - Key questions:
     - Do tests verify behavior through the real pipeline where risk is high?
     - Are legacy fields rejected at the config boundary rather than tolerated
       downstream?

3. `docs: align current docs with runtime contracts`
   - Focus: current documentation and historical archive boundaries.
   - Review first:
     - `README.md`
     - `README.zh-CN.md`
     - `docs/README.md`
     - `docs/configuration.md`
     - `docs/architecture/source-layout.md`
     - `docs/annotation-v2-schema.md`
   - Key questions:
     - Do current docs describe the code as it exists now?
     - Are historical audits clearly marked as snapshots rather than current
       operating instructions?

## Verified Commands

The following checks passed before this pack was written:

```matlab
test_phase13_production_comment_audit
test_phase14_production_english_comment_audit
test_no_chinese_comments_in_matlab_sources
test_current_docs_language_policy
runtests({'tests/unit/LoggingPlanBuildTest.m', ...
          'tests/unit/DeprecatedLoggingFieldsRejectedTest.m', ...
          'tests/unit/GlobalLoggerSingleInitializationTest.m', ...
          'tests/unit/LoggerProgressVisibilityTest.m'})
runtests({'tests/unit/RuntimePlanBuildTest.m', ...
          'tests/unit/RuntimePlanRequiredByRunnerTest.m', ...
          'tests/unit/RuntimePlanPropagationTest.m', ...
          'tests/unit/DerivedFieldsRejectedInRawConfigTest.m'})
test_no_dead_code_phase17_config_contracts
test_no_dead_code_phase21_performance_contracts
test_simulation_runner_startup_hooks
test_phase21_stage_timing_runner_hook
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
simulation(1, 1, 'csrd2025/csrd2025.m')
```

The default `simulation.m` run completed with 4 successful scenarios, 0 failed,
and 0 skipped. The generated `data/CSRD2025` output was removed after
verification; `data/map/` was preserved.

## Remaining Review Risks

- Many production files changed only because MATLAB comments were converted to
  English-only comments. Use `git show --stat` and file-level diffs to separate
  mechanical comment cleanup from behavior changes.
- Large OSM maps may still be slow. This is treated as a performance fact, not
  a correctness failure, unless annotation, RayTracing, or frame contracts fail.
- Legacy `LogPolicy.apply/restore` still exists for older unit fixtures, but
  production startup no longer uses it.
