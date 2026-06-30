# Static-audit — round 3 (2026-06-21)

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

Third 10-dimension multi-agent static bug-hunt over deeper subsystems (blueprint feasibility,
regulatory compliance, frame-contract math, carrier placement, power/link budget, payload length,
multi-receiver, geometry/mobility, logging/provenance, spatial modes). The verifier was given
design-intent awareness (grep tests/ for an asserting test → reject as deliberate design): **13
candidates → 7 confirmed, 5 rejected as deliberate design** (much better signal-to-noise than the
prior rounds; the design-intent filter prevented another #3-COCO-style false fix).

## Bugs fixed (4) — committed & pushed

| Commit | Finding | Root cause | Fix |
|---|---|---|---|
| `f29831c` | #3 transmit power never realized (HIGH) | the per-service power is `TxInfo.Power` (dBm) but the TRF block property is `TxPowerDb`; the name-match copy in `configureTransmitterBlock` never bridges them, so every emitter is scaled to the hard-coded default `TxPowerDb=50 dBm` regardless of its planned, annotated power | add an explicit `Power -> TxPowerDb` mapping (both dBm) |
| `3acaee2` | #1 regulatory temporal mislabel (MED) | `applyRegulatoryTemporalPattern` rebuilt 'Scheduled' as a single full-window slot `[0,obsDur]` (and 'Burst' as a single front block) while keeping `Type='Scheduled'/'Burst'` — a continuous signal annotated as slotted/bursty | build genuinely intermittent intervals via the existing generators; relabel Continuous if a rebuild still collapses to the sentinel |
| `3acaee2` | #7 OTFS resample churn (MED) | OTFS missing from `singleAntennaFamilies` though `AntennaModulationMatrix` allows it only at 1 antenna, so the planner drew 2/4 antennas, the validator rejected, and the scenario resampled up to 50× | add 'OTFS' to keep the two lists consistent |
| `17568b1` | #6 empty spatial mode (HIGH) | `Planned.ModulationSpatialMode` was read only from `ModulatorConfig.mimo.Mode`, which the non-OFDM families never set, so a multi-antenna OSTBC-encoded QAM/PSK signal was annotated with an empty mode | derive `'OSTBC'` from `Hardware.NumAntennas>1` when no explicit mimo.Mode |

`#3` is the most consequential: the "transmit power by service type" feature (planned + annotated)
was never realized in the signal — all emitters were emitted at 50 dBm.

Validation: round-2 validation stress sweep (chunks 40-45, **4,800 scenarios, 0 anomalies** —
19,200 clean scenarios across the whole campaign); 41 scenario/regulatory/transmit/antenna
regression tests pass; targeted checks (TxPowerDb drives power scaling; OTFS now single-antenna).

## Flagged for your decision (3) — NOT changed

- **#2 frame contract desync for a narrow SDR (HIGH).** In the PRODUCTION path
  (`buildScenarioPlan`), `ScenarioPlan.Frame` is derived from the un-capped receiver SampleRate
  (50e6) while the realized receiver caps to the SDR's IBW (e.g. RTL_SDR 2.4e6), so a frame can fail
  with `CSRD:Frame:InconsistentFrameSamples`. The default config and the whole 19,200-scenario
  test_support stress sweep do NOT trigger it (that path resolves the frame from the capped rate), so
  it is reachable only when a narrow SDR is configured in a production run. Fix (agent): cap
  `buildScenarioPlan.localReceiverSampleRate` by the SDR's `MaxInstantaneousBandwidthHz` (and the
  regulatory monitoring-band rate) before computing Frame.*, mirroring `setupImpl`. Flagged because
  it changes the production frame-contract derivation and I could not exercise it end-to-end cleanly.
- **#4 analog message length in symbol units (LOW).** For analog (Audio) emitters,
  `localPerSegmentMessageLength` computes the message length with the digital symbol-rate formula,
  but Audio.stepImpl consumes it as an audio-sample count — a unit mismatch. Fix: branch the length
  formula on the digital/analog flag. Low severity; needs careful unit reasoning, so left for review.
- **#5 multi-frame blueprint provenance records only the last frame (MED).** `LastGlobalLayout` is
  overwritten every frame, and the scenario provenance (BlueprintHash/Resamples) is read after the
  loop, so the recorded resample count reflects only the final frame (frame-1 resamples are
  under-reported). Since ScenarioPlan is frozen after frame 1 the hash is usually identical, but the
  resample count is inaccurate. Fix: accumulate provenance per frame. Flagged as a provenance-accuracy
  decision.

## Earlier open flags
Round-1 (`OVERNIGHT_2026-06-20...`): #7 MIMO fading not burst-isolated, #9 AWGN per-frame noise.
Round-2 (`OVERNIGHT_2026-06-21_ROUND2...`): #3 COCO NoSignal reject, #6 RX phantom DCOffset,
#9 RayTracing fallback antenna columns, #12/#13 OFDM bandwidth-vs-plan, #7 IqImbalance guard.
