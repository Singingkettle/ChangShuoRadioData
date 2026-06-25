# CSRD Review Handoff - 2026-06-18

> Purpose: hand this document to the next AI group or human reviewer before
> they start bug hunting. It summarizes the two refactoring conversations, the
> current repository state, the contracts that must not drift, and the risk
> areas where review should be strict.

本文是面向下一组 AI / reviewer 的交接文档。它不是新的重构计划，也不是
历史 phase 文档的替代品。它的目标是让下一位 reviewer 快速理解：

- 项目为什么被重构成现在这样。
- 哪些 bug 和设计问题已经修过。
- 当前代码最重要的合同是什么。
- 下一轮 review 应该优先怀疑哪些地方。
- 哪些旧设计绝对不要恢复。

## 1. Current Baseline

当前代码基线以远端 `main` 为准。

| Item | Current value |
| --- | --- |
| Repository root | `C:\Users\lenovo\ChangShuoRadioData` |
| Current branch at handoff | `main` |
| Local / remote state | `main...origin/main` clean at the last check |
| Latest commit | `dbff9c1 Merge pull request #8 from Singingkettle/codex/github-actions-maintenance-20260605` |
| Main PR merged | PR #7, `[codex] Harden runtime contracts and scenario planning` |
| CI maintenance PR merged | PR #8, `ci: update checkout action runtime` |
| Open PRs at handoff | 0 |
| Open issues at handoff | 0 |
| Last main CI | `CSRD CI Smoke / MATLAB Phase 5 Smoke`, success |

The most recent relevant commits are:

```text
dbff9c1 Merge pull request #8 from Singingkettle/codex/github-actions-maintenance-20260605
27a3498 ci: update checkout action runtime
b6a227d Merge pull request #7 from Singingkettle/codex/phase35-review-curation-20260522
45831fb fix: fail fast on invalid scenario map timing
9051d93 test: cover scenario plan and midpoint geometry contracts
df811ae refactor: make scenario planning independent from frame execution
9d35962 docs: align current docs with runtime contracts
e6ff76b test: cover runtime plans logging and language gates
3e34f06 refactor: align runtime plans and logging authorities
e1b72a8 chore: align docs and profiling tool with runtime contract
cb32861 test: update runtime contract and ray tracing coverage
51abe51 perf: harden ray tracing cache and slow-stage visibility
```

Important current docs:

- `README.md`: current project overview and entry points.
- `README.zh-CN.md`: current Chinese overview.
- `docs/configuration.md`: current raw config / RuntimePlan / ScenarioPlan contract.
- `docs/architecture/source-layout.md`: current source package layout.
- `docs/annotation-v2-schema.md`: annotation truth-plane contract.
- `docs/audits/manual-full-code-review-guide.md`: human full-code-review workflow.
- `docs/audits/review-pack-2026-05-22.md`: previous review pack for Phase 33-35.

## 2. Source Sessions And Evidence

This handoff combines two conversation tracks.

### 2.1 Historical session

Session id:

```text
019dc92e-ed31-7723-bf4b-17fd0744aa6e
```

Local JSONL source:

```text
C:\Users\lenovo\.codex\sessions\2026\04\26\rollout-2026-04-26T17-46-29-019dc92e-ed31-7723-bf4b-17fd0744aa6e.jsonl
```

The historical session covered the first heavy refactoring continuation after
the two original handover documents:

- `docs/audits/HANDOVER_2026-04-26.md`
- `docs/audits/HANDOVER_2026-05-03.md`

Key plan blocks found in that session include:

- Phase 8: regional regulatory spectrum planning.
- Phase 10: full-flow large coverage validation.
- Phase 11: config and dead-code cleanup.
- Phase 12: channel config field consumption audit and a channel-model hotfix.
- Phase 13: formal full coverage generation config and production comment/reference audit.
- Phase 14: historical bilingual comment remediation plan.
- Phase 15: building OSM RayTracing fix and package reorganization.
- Phase 16: OSM RayTracing stress validation, artifact governance, and spectrogram visual checks.

The raw JSONL should not be committed. It is an evidence source only.

### 2.2 Current session

The current conversation continued from Phase 16 through GitHub closure. It
includes:

- Phase 16 final multi-Tx / multi-burst / overlay consistency closure.
- Phase 17-18 runtime contract and truth-plane hardening.
- Phase 20-24 default simulation bug fixing and OSM/RayTracing performance work.
- Phase 25-29 deep audit tooling, watchdog work, and targeted quality audit.
- Phase 30-33 runtime plan and scenario plan restructuring.
- Phase 34-36 boundary testing and pure `ScenarioPlan -> FramePlan -> SegmentPlan` execution.
- Phase 35 logger authority and English-only MATLAB source comment policy.
- GitHub PR #7 and PR #8 publication and merge.

## 3. Refactoring Timeline

### 3.1 Before Phase 13

The project had already gone through multiple refactoring waves. The important
background for reviewers is that the repository used to contain many implicit
runtime facts in multiple places:

- Frame length and observation timing existed in runner config, scenario global
  config, blueprint metadata, execution structs, and annotation output.
- Channel model and carrier frequency could drift between map profile,
  channel config, receiver config, and annotation.
- Some paths used warning/fallback behavior where a hard error was safer.
- Old compatibility aliases such as `SegmentID`, `SeedValue`, or frame fields
  could hide broken producer/consumer contracts.

The entire later refactor should be judged against one invariant:

```text
generated signal == simulated scene state == exported annotation
```

If a field makes these diverge silently, it is a correctness bug.

### 3.2 Phase 13 - full coverage config and comment/reference audit

Historical goal:

- Use `tools/simulation.m` as the formal generation entry.
- Add a validation-grade full coverage config, not by changing the default
  `csrd2025.m` into a huge training run.
- Cover regions, modulation types, RF impairments, channel models, Tx/Rx counts,
  and antenna combinations.
- Audit production `.m` files for documentation and external references.

Current status:

- The current default docs no longer present Phase 13's bilingual comment policy
  as active.
- Generated audit JSON manifests were removed from tracked docs.
- Regeneratable reports belong under ignored `artifacts/`.

Review risk:

- Some tests may still encode old assumptions from full coverage validation.
  Verify they test current contracts rather than old config field names.

### 3.3 Phase 14 - historical bilingual comments

Historical goal:

- Add function/method-level bilingual comments to production MATLAB files.
- Require `References / 参考资料` for files with external references.

Current final rule:

- This was later reversed.
- Current production MATLAB source comments are English-only.
- Chinese comments in current MATLAB source are rejected by static gates.
- `README.zh-CN.md` is the Chinese current overview.
- Historical audit docs may contain Chinese because they are archive material.

Do not restore Phase 14 bilingual source comments. It was a historical
requirement, not the current standard.

### 3.4 Phase 15 - OSM RayTracing and architecture reorganization

Historical goal:

- Fix an incorrect capability probe where `siteviewer` was a `.p` file and
  `exist('siteviewer','file')` returned `6`, while older code accepted only `2`.
- Treat `raytrace` as a `txsite` method path rather than a plain top-level
  function.
- Reorganize the old broad `+csrd/+utils` area into clearer packages:
  `+runtime`, `+catalog`, `+pipeline`, and `+support`.

Current status:

- The old production `csrd.utils.*` path should not be reintroduced.
- Runtime map and capability helpers live under `+csrd/+runtime`.
- Spectrum catalogs live under `+csrd/+catalog`.
- Cross-module contracts live under `+csrd/+pipeline`.
- Internal validation/support helpers live under `+csrd/+support`.

Review risk:

- Look for any newly added production code that imports or mentions
  `csrd.utils.*`.
- Check RayTracing code paths for GUI/resource cleanup and explicit fallback
  metadata.

### 3.5 Phase 16 - OSM RayTracing stress and visual validation

Historical goal:

- Use `tools/simulation.m` to run OSM RayTracing validation.
- Cover building OSM, empty OSM flat fallback, multi Tx/Rx, multi antenna,
  modulation diversity, and regulatory spectrum fields.
- Render spectrogram overlays and verify annotation rectangles match the signal.
- Keep generated data and visual artifacts out of git.

Later Phase 16 closure:

- Special sample target: `3 Tx x 3 burst = 9` annotation sources.
- Fixed receiver frame length expectation: `262144` samples for that sample.
- `BurstId` became required and non-empty.
- Annotation execution timing had to come from actual inserted sample grid.
- Spectrogram GT rectangles had to align without relying on out-of-bounds clipping.

Review risk:

- Multi-burst and clipped segment paths are still high risk.
- Check any code that creates `Truth.Execution.StartTimeSec`,
  `EndTimeSec`, or `DurationSec`.
- Ensure `BurstId` is never empty on live sources.

### 3.6 Phase 17-18 - runtime truth contracts

Goals:

- Stop treating `FrameLength` as an isolated duplicate-definition bug.
- Audit all runtime facts: frame/time, sample rate, carrier frequency,
  bandwidth, antenna count, seed, channel model, power/noise.
- Make invalid or missing runtime facts fail fast.
- Remove or isolate downstream backfills.

Important current rule:

- Raw config stores authorities and policies.
- Derived facts are not scattered back into raw config.
- Live source measured fields must be finite.
- Empty or clipped-out sources may use NaN only with explicit
  `MeasurementStatus='NoSignal'`.

Review risk:

- Search for warning-based fallback around sample rate, bandwidth, carrier,
  message length, antenna count, and channel seed.
- If a block invents a default execution fact, treat it as suspect.

### 3.7 Phase 20 - default simulation hard failures

The default run exposed multiple real bugs:

- Continuous transmission used an observation-length window as if it were one
  frame window, causing frame-shape mismatches such as `10240` vs `1024`.
- Short-frame measurement used a default envelope window too large for the
  actual signal duration.
- RayTracing was attempted for carriers below MATLAB's supported range.
- Some hard failures were counted as scenario skips or successes.
- Physical environment time resolution could diverge from canonical frame
  duration.

Current expectation:

- Frame windows are scenario/frame facts, not guessed from full observation
  duration.
- Measurement window defaults are safe for short frames.
- RayTracing frequency support is planned or validated before execution.
- `CSRD:Measurement:*`, `CSRD:Annotation:*`, and construction errors should
  not be treated as ordinary skips.

Review risk:

- Any code that catches broad exceptions and returns success/skip needs close
  inspection.

### 3.8 Phase 21-24 - performance and OSM policy

Performance work focused on MATLAB usage rather than physical simplification:

- Reduce logger hot-path overhead.
- Respect System object lifecycle for TRF/RRF.
- Add runtime performance/stage tracing.
- Batch or cache RayTracing resources where the cache is valid.
- Record slow OSM/RayTracing stages.

There was a temporary idea to classify large OSM maps by size and exclude them
from default random generation. The user later rejected that policy.

Current OSM policy:

- No OSM size cap.
- No default large-map exclusion.
- OSM selection should be file-level balanced coverage.
- Large maps being slow is a performance fact, not a correctness failure.

Review risk:

- Do not reintroduce `Map.OSM.MaxFileSizeMB`.
- Do not silently downgrade large OSM maps to Statistical just to make tests
  fast.
- Slow `siteviewer` / `raytrace` cases should be measured and reported, not
  hidden.

### 3.9 Phase 25-29 - deep audit, watchdog, and targeted quality

The project briefly explored a massive watchdog target of `100,000,000`
successful scenarios. This was later judged not useful for ordinary review.

Final direction:

- Prefer high-risk targeted quality audits over huge undirected pressure tests.
- Use deterministic small matrices that expose known risk surfaces.
- Keep failure artifacts for reproducibility.
- Do not count hard failures as skipped or successful.

Important tools:

- `tools/audit/run_phase29_targeted_quality_audit.m`
- `tools/audit/run_phase34_boundary_quality_audit.m`
- `tools/massive/run_massive_simulation_watchdog.m` remains a tool, not the
  default review strategy.

Review risk:

- Make sure audit tools do not become a second, divergent simulation entry.
  They should call through `tools/simulation.m` or the same production path
  where required.

### 3.10 Phase 30-33 - runtime plan and scenario plan redesign

The important architectural change:

- `RuntimePlan` is now run-level policy and provenance.
- It must not contain resolved scenario frame facts.
- Concrete `FrameNumSamples`, `NumFramesPerScenario`,
  `FrameDurationSec`, and `ObservationDurationSec` belong in
  `ScenarioPlan.Frame`.

The user explicitly rejected a single global frame shape:

- A run decides how many scenarios to generate and the policies for diversity.
- Each scenario may resolve different frame samples and frame counts.
- Dataset items are receiver-frames:
  `NumFramesPerScenario * NumReceiversInScenario`.

Review risk:

- Any production path reading resolved facts from `RuntimePlan.Frame` is wrong.
- Any production path reading old raw global frame fields is wrong.
- Any code that resamples map, Tx/Rx count, frame shape, or communication
  schedule inside the frame loop is suspect.

### 3.11 Phase 34-36 - pure ScenarioPlan and segment midpoint geometry

Earlier transitional code built a scenario plan by calling frame-level
`step(obj,1)`. The user correctly objected: a scenario plan should be a
scenario drawing, not frame 1 execution repackaged as a plan.

Current design:

- `ScenarioFactory.planScenario(scenarioId)` builds scenario-level facts before
  frame generation.
- It must not call `step(obj,1)` to fill the plan.
- `FramePlan` is derived from `ScenarioPlan.Frame` and `frameId`.
- `SegmentPlan` is derived from the frozen transmission schedule and frame
  overlap.
- Geometry is evaluated at the segment midpoint.
- Dynamic movement is not pre-written per frame; it is evaluated from the
  initial state and mobility model at a requested time.

Important current helper concepts:

- `csrd.pipeline.runtime.buildScenarioPlan`
- `csrd.pipeline.runtime.buildFramePlan`
- `csrd.pipeline.scenario.evaluateEntityState`
- `SegmentMidpoint` geometry policy

Review risk:

- Verify every channel/Doppler/RayTracing/annotation design geometry path uses
  the same midpoint state.
- Verify unsupported stateful mobility models fail fast rather than silently
  approximating.

### 3.12 Phase 35 - logger and English-only policy

Logger issue found by the user:

- Some logger messages appeared in logs but not in the command window because
  configuration initialized the logger first and runner policy later mutated
  thresholds.

Current design:

- `config.Logging` is the logging authority.
- `RuntimePlan.Logging` carries the resolved logging plan.
- `simulation.m` initializes the global logger once.
- `SimulationRunner` should not mutate logger thresholds during production.
- Operator-visible progress should use progress logging, not ordinary `INFO`
  assumptions.

Source comment policy:

- Production MATLAB comments are English-only.
- Chinese current project overview is in `README.zh-CN.md`.
- Historical audit documents can remain Chinese or bilingual.

Review risk:

- Look for old `config.Log` or `Runner.Log.Policy`.
- Look for production comments with CJK characters.

### 3.13 Final GitHub closure

PR #7 merged:

- Runtime plans.
- Logging authority.
- RayTracing/OSM hardening.
- Pure ScenarioPlan / FramePlan / SegmentPlan model.
- Tests and docs.

PR #8 merged:

- Updated GitHub Actions `actions/checkout` to `v6`.
- Main CI passed.

No open PRs or issues remained at handoff.

## 4. Current Runtime Architecture

The current production flow should be understood as:

```text
tools/simulation.m
  -> csrd.runtime.config_loader
     -> raw config validation
     -> RuntimePlan
  -> csrd.SimulationRunner
     -> scenario dispatch and output accounting
  -> csrd.core.ChangShuo
     -> ScenarioFactory.planScenario
        -> ScenarioPlan
     -> frame loop
        -> FramePlan
        -> SegmentPlan
        -> waveform/message/modulation/TRF/channel/RRF
        -> receiver frame buffers
     -> annotation v2
```

### 4.1 Raw config

Raw config should contain:

- User intent.
- Authorities such as receiver sample rate and carrier.
- Sampling policies such as `Factories.Scenario.FramePolicy`.
- Logging policy.
- Map/channel selection policy.

Raw config should not contain derived scenario facts such as:

- Frame duration.
- Observation duration.
- Resolved frame length for a concrete scenario.

### 4.2 RuntimePlan

`RuntimePlan` is a run-level contract object.

It should contain:

- Frame policy.
- Map policy.
- Seed policy.
- Receiver policy.
- Logging plan.
- Config fingerprint/provenance.

It should not contain:

- Concrete `FrameNumSamples`.
- Concrete `NumFramesPerScenario`.
- Concrete scenario observation duration.

### 4.3 ScenarioPlan

`ScenarioPlan` is the construction drawing for one scenario.

It should be complete before frame generation starts and should include:

- `ScenarioId`
- `Frame.FrameNumSamples`
- `Frame.NumFramesPerScenario`
- `Frame.SampleRateHz`
- `Frame.FrameDurationSec`
- `Frame.ObservationDurationSec`
- map type, OSM file, channel model, fallback policy metadata
- initial Tx/Rx/entity state at `t = 0`
- transmitter and receiver plans
- communication transmission schedule
- dataset accounting, including receiver-frame count

After `ScenarioPlan` is built, the frame loop must not resample scenario-level
facts.

### 4.4 FramePlan

`FramePlan` is a per-frame derived object. It should include:

- `FrameId`
- frame start/end in scenario time
- frame duration
- sample rate
- frame sample count

It is derived from `ScenarioPlan.Frame` plus `FrameId`.

### 4.5 SegmentPlan

`SegmentPlan` is derived from:

- the frozen transmission schedule
- `FramePlan`
- overlap/clipping rules

It should include:

- Tx id
- Burst id
- segment start/end
- segment midpoint
- planned frequency/bandwidth/modulation fields
- frame-local sample start/end

### 4.6 Geometry evaluation

Current rule:

```text
GeometryPolicy.Evaluation = 'SegmentMidpoint'
```

Channel propagation, Doppler, RayTracing metadata, and annotation design
geometry should all use entity states evaluated at the segment midpoint.

If a mobility model cannot be evaluated as a deterministic function of time, it
should fail fast until it is implemented correctly.

### 4.7 Annotation truth planes

Annotation v2 should keep three truth planes separate:

- `Truth.Design`: scenario plan and design-time facts.
- `Truth.Execution`: actual waveform insertion, RF/channel execution, sample
  grid, geometry execution, and model fallback metadata.
- `Truth.Measured`: measurements from the generated receiver-side signal.

Never fill `Measured` from design values just to avoid NaN. Never fill
`Execution` from intended design if actual sample-grid insertion differs.

## 5. Contracts That Must Not Drift

### 5.1 Time and frame contract

Review questions:

- Is `FrameWindow` the current frame window in absolute scenario time?
- Are active intervals clipped to the current frame?
- Does every receiver frame signal length equal `ScenarioPlan.Frame.FrameNumSamples`?
- Do `Truth.Execution` times match inserted sample indices?
- Are `StartTimeSec`, `EndTimeSec`, and `DurationSec` sample-grid consistent?

Known danger:

- Returning inactive on missing timing hides broken scenario plans.
- Out-of-range frames should fail fast.

### 5.2 Frequency and sample-rate contract

Review questions:

- Is receiver sample rate the authority for receiver frame shape?
- Is carrier frequency owned by receiver/scenario plan, not backfilled by channel?
- Does planned bandwidth stay separate from execution and measured bandwidth?
- Is RayTracing frequency support checked before calling MATLAB RayTracing?

Known danger:

- Planned bandwidth, execution bandwidth, and measured occupied bandwidth are
  different truth planes. Do not collapse them.

### 5.3 Spatial contract

Review questions:

- Does RayTracing use geographic site coordinates where required?
- Do Doppler, distance, velocity, and mobility use meter-space coordinates?
- Are `GeoPositionDeg`, `PositionM`, and `VelocityMps` named and consumed
  consistently?

Known danger:

- Latitude/longitude degrees must never be combined directly with meters per
  second.

### 5.4 Channel and fallback contract

Review questions:

- Is channel model selection explicit?
- Does `MapProfile.ChannelModel` reach execution metadata and annotation?
- Are OSM empty/flat fallbacks visible in metadata?
- Are `NoValidPaths` and internal RayTracing errors distinguished?

Known danger:

- Internal RayTracing errors such as type errors must not be treated as valid
  no-path fallbacks.

### 5.5 Annotation and measurement contract

Review questions:

- Are live source measured fields finite?
- Is `NoSignal` the only accepted reason for NaN measured fields?
- Does annotation reflect the actual receiver buffer, not just design intent?
- Are multi-antenna signals measured consistently without corrupting the time
  axis?

Known danger:

- Measurement helper failures must be visible as `CSRD:Measurement:*`, not
  silently converted to NaN.

### 5.6 Randomness and replay contract

Review questions:

- Does fixed `Runner.RandomSeed + ScenarioId` reproduce the same scenario plan?
- Does OSM balanced selection remain deterministic?
- Do helper functions introduce hidden RNG draws?
- Are burst/channel seeds stable and based on non-empty `BurstId`?

Known danger:

- Adding a random draw inside a helper can shift every downstream scenario.

### 5.7 Logger contract

Review questions:

- Is `config.Logging` the only logging authority?
- Does `RuntimePlan.Logging` describe the effective logging plan?
- Does `SimulationRunner` avoid mutating global logger thresholds?
- Are progress messages visible under `LargeMC` without restoring noisy `INFO`
  output?

## 6. Known Historical Bugs And Fixes

These are useful review seeds. If similar patterns reappear, treat them as high
risk.

| Bug class | Historical symptom | Intended fix direction |
| --- | --- | --- |
| Frame window mismatch | `SignalComponents.FrameWindow resolves to 10240 samples but FrameNumSamples is 1024` | Frame window comes from per-frame plan; receiver buffer length is fixed by scenario plan. |
| Short measurement window | `detectBurstEnvelope: WindowSec=0.0001 must be in ...` | Default measurement window adapts to signal duration; explicit invalid window fails. |
| RayTracing low frequency | MATLAB RayTracing attempted below 100 MHz | Plan/validate supported carrier before RayTracing. |
| Hard failure counted as skip | Measurement/construction errors treated as skipped scenario | `CSRD:*` hard failures must count failed. |
| Time resolution drift | Physical environment used a fixed `0.001 s` step while frames were much shorter | Physical time step comes from scenario frame duration. |
| OSM capability false negative | `siteviewer` as `.p` file was misdetected | Capability probe must understand MATLAB function/class/method realities. |
| OSM material / `isvalid` internal errors | RayTracing internals collapsed into fallback | Internal errors hard fail; only explicit no-path policy may fallback. |
| OSM size filtering | Large maps temporarily excluded by size | Removed. All OSM files should be eligible under balanced file coverage. |
| Logger visibility split | `simulation.m` info visible, runner info hidden | Single `LoggingPlan`, progress channel for operator-visible messages. |
| Frame-level plan reuse | `ScenarioFactory.planScenario -> step(obj,1)` | Removed; scenario plan is built without frame execution. |
| Map type fallback | Unknown map type defaulted to Statistical | Missing/unsupported map type fails fast. |

## 7. Remaining Review Risks

The project is much cleaner than before, but these areas still deserve strict
review.

### 7.1 OSM/RayTracing performance long tail

Large OSM building maps can take minutes because MATLAB `siteviewer` and
`raytrace` process geometry. This is not a correctness failure by itself.

Reviewer should check:

- Are slow stages measured and logged?
- Are resources cached only when physically valid?
- Does moving geometry invalidate cached site/ray/channel state?
- Are large maps still included in coverage, not filtered out?

### 7.2 ScenarioPlan freeze boundary

Reviewer should check:

- Does frame execution ever resample map type, OSM file, Tx/Rx count, frame
  shape, or communication schedule?
- Are all scenario-level decisions made before frame 1 executes?
- Are tests strong enough to detect frame-loop resampling?

### 7.3 Segment midpoint consistency

Reviewer should check:

- Does Doppler use midpoint velocity/relative motion?
- Does distance/path-loss use midpoint position?
- Does RayTracing metadata use midpoint site construction?
- Does annotation design geometry use the same state as the channel path?

### 7.4 Measurement truth

Reviewer should check:

- Are OBW, centroid, SNR, and envelope measurements computed from actual
  receiver signals?
- Are failed live measurements hard failures?
- Are NaNs allowed only for explicit no-signal cases?

### 7.5 Factory fail-fast boundary

Reviewer should inspect factories for lingering defaults:

- `MessageFactory`
- `ModulationFactory`
- `TransmitFactory`
- `ChannelFactory`
- `ReceiveFactory`

Danger signs:

- default message length
- default symbol rate
- default antenna count
- planned sample rate used as execution sample rate without validation
- channel seed fallback such as `frame_<id>`

### 7.6 Tests that only test helpers

Some tests may pin helper behavior without proving the main pipeline uses it.
When a contract affects generated data, prefer at least one pipeline regression
or targeted audit case.

### 7.7 Documentation drift

Current active docs are English except `README.zh-CN.md`. Historical audit docs
may contain old paths and old rules. Reviewers must not treat old phase docs as
current operating instructions unless the current README/config docs agree.

## 8. Recommended Review Order

Start with context:

1. `AGENTS.md`
2. `README.md`
3. `README.zh-CN.md`
4. `docs/configuration.md`
5. `docs/architecture/source-layout.md`
6. `docs/annotation-v2-schema.md`
7. This handoff
8. `docs/audits/manual-full-code-review-guide.md`

Then review the pipeline:

1. `tools/simulation.m`
2. `+csrd/SimulationRunner.m`
3. `+csrd/+runtime/config_loader.m`
4. `+csrd/+pipeline/+runtime/buildRuntimePlan.m`
5. `+csrd/+factories/ScenarioFactory.m`
6. `+csrd/+pipeline/+runtime/buildScenarioPlan.m`
7. `+csrd/+core/@ChangShuo`
8. `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator`
9. `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator`
10. `+csrd/+factories/MessageFactory.m`
11. `+csrd/+factories/ModulationFactory.m`
12. `+csrd/+factories/TransmitFactory.m`
13. `+csrd/+factories/ChannelFactory.m`
14. `+csrd/+factories/ReceiveFactory.m`
15. `+csrd/+pipeline/+annotation`
16. `+csrd/+pipeline/+measurement`

For each module, record:

- what it receives
- what it produces
- units and signal shape
- random seed use
- fallback/error behavior
- annotation impact
- tests that prove the path

Finding classes:

- `Blocker`: generated data can be wrong without failure.
- `Correctness`: signal/scene/annotation can diverge.
- `Performance`: expensive but physically valid path can be improved.
- `Cleanup`: stale names, comments, or docs.
- `Test Gap`: important behavior lacks main-path coverage.

## 9. Targeted Test Matrix

Reviewers should prefer targeted tests over massive random stress.

### 9.1 Static gates

```matlab
test_no_dead_code_phase17_config_contracts
test_no_dead_code_phase21_performance_contracts
test_no_chinese_comments_in_matlab_sources
test_current_docs_language_policy
```

Also run:

```powershell
git diff --check
rg "normalizeRuntimeContracts|Runner.FixedFrameLength|Map\.OSM\.MaxFileSizeMB" +csrd config tools tests
```

Expected:

- No production call to `normalizeRuntimeContracts`.
- Old fields appear only in rejection tests or "do not restore" docs.

### 9.2 RuntimePlan and ScenarioPlan

```matlab
runtests({
    'tests/unit/RunPlanPolicyOnlyTest.m'
    'tests/unit/RuntimePlanBuildTest.m'
    'tests/unit/RuntimePlanRequiredByRunnerTest.m'
    'tests/unit/RuntimePlanPropagationTest.m'
    'tests/unit/ScenarioPlanBuildTest.m'
    'tests/unit/ScenarioPlanDiversityTest.m'
    'tests/unit/ScenarioPlanFrozenBeforeFrameExecutionTest.m'
    'tests/unit/ScenarioPlanPureBuildTest.m'
    'tests/unit/FramePlanBuildTest.m'
    'tests/unit/SegmentPlanMidpointGeometryTest.m'
})
```

### 9.3 Signal and annotation

```matlab
runtests({
    'tests/unit/ContinuousFrameWindowContractTest.m'
    'tests/unit/MultiBurstPerFrameTest.m'
    'tests/unit/SignalGatingTest.m'
    'tests/unit/BuildSourceAnnotationV2Test.m'
    'tests/unit/MeasurementCompletenessHookTest.m'
    'tests/unit/ScenarioPlanAnnotationContractTest.m'
    'tests/unit/AnnotationExecutionSampleGridContractTest.m'
})
```

### 9.4 OSM and RayTracing

```matlab
runtests({
    'tests/unit/FlatTerrainNoOnlineTerrainRegressionTest.m'
    'tests/unit/OsmCoordinateUnitContractTest.m'
    'tests/unit/OsmMapResourceCacheContractTest.m'
    'tests/unit/RayTracingBatchEquivalenceTest.m'
    'tests/unit/RayTracingGeometryCacheToleranceTest.m'
})
run('tests/regression/test_empty_osm_raytracing.m')
run('tests/regression/test_osm_building_raytracing.m')
```

### 9.5 RF and factories

```matlab
runtests({
    'tests/unit/TRFSimulatorTest.m'
    'tests/unit/TRFMatrixResampleContractTest.m'
    'tests/unit/TRFExactResampleContractTest.m'
    'tests/unit/RRFSimulatorTest.m'
    'tests/unit/ChannelSeedRequiresBurstIdTest.m'
    'tests/unit/ModulationFactoryNoExecutionFallbackTest.m'
    'tests/unit/TransmitFactoryRequiresReceiverSampleRateTest.m'
})
```

### 9.6 Pipeline smoke

```matlab
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
run_phase34_boundary_quality_audit('StopOnFailure', true, 'StressCount', 6)
simulation(1, 1, 'csrd2025/csrd2025.m')
```

Do not start a massive long run unless a targeted fix has already passed and
the goal is only throughput evidence.

## 10. Do Not Restore

The following are historical or rejected designs. If a future patch adds them
back, require a strong justification and tests.

- `+csrd/+pipeline/+runtime/normalizeRuntimeContracts.m`
- `+csrd/+pipeline/+runtime/resolveFrameRuntimeContract.m`
- `RuntimePlan.Frame` as a store of resolved scenario frame facts
- `Factories.Scenario.Global.FrameLength`
- `Factories.Scenario.Global.FrameNumSamples`
- `Factories.Scenario.Global.NumFramesPerScenario`
- `Factories.Scenario.Global.FrameDuration`
- `Factories.Scenario.Global.ObservationDuration`
- `Runner.FixedFrameLength`
- `config.Log`
- `Runner.Log.Policy`
- `Channel.LinkBudget.CarrierFrequency` as raw authority
- `Map.OSM.MaxFileSizeMB`
- production `csrd.utils.*`
- MATLAB production comments in Chinese
- Phase 14 bilingual source comment gate
- `ScenarioFactory.planScenario` calling `step(obj,1)`
- silent Statistical fallback for unknown map type
- warning-only missing frame timing
- treating `CSRD:Measurement:*` or annotation failures as successful skips
- hidden fallback message length, symbol rate, sample rate, antenna count, or
  channel seed

## 11. Artifacts And Data Policy

Tracked repository content should include:

- source code
- config
- tests
- current docs
- historical audit docs
- raw map assets under `data/map/`

Do not commit:

- generated datasets under `data/CSRD2025*`
- `artifacts/`
- `.mat` generated samples
- logs
- spectrogram images
- generated audit JSON manifests

Do not run:

```powershell
git clean -fdX
```

It can delete ignored assets that may be expensive or important. Clean explicit
generated paths only.

## 12. GitHub State At Handoff

At the time this document was prepared:

- PR #7 was merged into `main`.
- PR #8 was merged into `main`.
- PR #5 had been closed as superseded.
- Superseded remote branches for #5/#7/#8 had been cleaned up.
- Open PRs: 0.
- Open issues: 0.
- Latest main CI: success.

If this has changed, refresh with:

```powershell
gh pr list --repo Singingkettle/ChangShuoRadioData --state open
gh issue list --repo Singingkettle/ChangShuoRadioData --state open
gh run list --repo Singingkettle/ChangShuoRadioData --branch main --limit 5
git status -sb
git log --oneline --decorate -12
```

## 13. Appendix: Phase Crosswalk

| Phase | Main topic | Current review meaning |
| --- | --- | --- |
| 8 | Regional spectrum catalog and regulatory planning | Check frequency/bandwidth/modulation come from catalog constraints. |
| 10 | Full-flow coverage validation | Use as historical evidence; prefer current targeted audit commands. |
| 11 | Config and dead-code cleanup | Do not reintroduce deleted compatibility paths. |
| 12 | Channel config consumption | Map/channel model provenance must reach execution and annotation. |
| 13 | Full coverage config and comment/reference audit | Historical; current generated manifests stay ignored. |
| 14 | Bilingual comments | Superseded by English-only MATLAB source comments. |
| 15 | OSM RayTracing and package reorg | `runtime/catalog/pipeline/support` package split is current. |
| 16 | OSM RayTracing stress and spectrogram validation | Multi-burst, fixed receiver frame, and overlay consistency remain high risk. |
| 17 | Runtime config authority audit | Raw config should not duplicate runtime facts. |
| 18 | Runtime truth hardening | Fail-fast and measured-field visibility are current policy. |
| 20 | Default simulation hard failure repair | Regress frame window, short measurement, RayTracing frequency, failure accounting. |
| 21 | Generation performance | Optimize only by removing waste, not by simplifying physics. |
| 22/23 | Massive generation and OSM/RayTracing profiling | Use targeted evidence; do not hide slow OSM maps. |
| 24 | OSM large-map policy | Size filtering idea was rejected. |
| 25 | Deep audit | Static and targeted audit tools are useful review aids. |
| 26 | Uniform OSM coverage | Current policy: file-level balanced coverage, no size cap. |
| 27/28 | Massive watchdog | Tool exists, but not default review method. |
| 29 | Targeted quality audit | Preferred high-risk validation style. |
| 30 | Runtime plan de-patching | Current: RuntimePlan is policy-only. |
| 31/32 | Review curation and validation | Evidence phase before manual review. |
| 33 | Scenario-level diversity | Concrete frame facts belong to each ScenarioPlan. |
| 34 | Boundary quality testing | Use current boundary audit before broad stress. |
| 35 | Logger and English-only source docs | Current policy. |
| 36 | Pure ScenarioPlan and segment midpoint geometry | Current execution model. |
| 37 | This handoff | Starting point for next AI/reviewer. |

## 14. Final Guidance For The Next Reviewer

Do not begin by changing code. First write down what each stage claims to
produce and who consumes it. This project fails dangerously when two modules
both look locally reasonable but disagree on time, frequency, coordinates,
sample shape, or truth-plane ownership.

The highest-value review question is always:

```text
Does the generated signal, the simulated scene state, and the exported
annotation describe the same radio event?
```

If the answer is not obviously yes, record a finding.
