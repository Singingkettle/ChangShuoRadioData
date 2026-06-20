# Overnight stress-test & static-audit findings — 2026-06-20

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

Autonomous overnight run: large-scale combinatorial stress sweeps + a 10-dimension
multi-agent static bug-hunt, each candidate adversarially verified and then
independently reproduced before any fix. All fixes below are committed and pushed;
each was validated with the relevant regression suites (no regressions).

## Bugs fixed (6) — committed & pushed

| Commit | Finding | Root cause | Fix |
|---|---|---|---|
| `961d2b7` | OBW tail-discard (Bug 9) | `pwelch` drops the trailing partial window; a burst entirely in the frame tail measured OBW=0 and tripped `requirePositiveMeasurement`, dropping the frame | whole-signal periodogram fallback when pwelch sees no energy but the signal has energy (in `measureSignalSummary` + `obwActual`) |
| `2583d9f` | Envelope tail + energy-liveness (#1/#4/#5/#6) | (a) the per-window envelope also dropped the tail → `TimeOccupancy=0` for a live burst; (b) liveness was keyed on sample count, so a zero-energy buffer (empty channel output zero-padded by `gateToDuration`) was classified "Measured" and its valid OBW=0 dropped the frame | (a) tail fallback in `localDetectEnvelope`/`detectBurstEnvelope`; (b) energy-based liveness (`any(\|x\|>0)`) so silent buffers become `NoSignal` |
| `77ce3c7` | OFDM pilots / frame-tail placement / non-power-of-2 (#8/#3/#10) | (#8) pilot cap `floor(L/nTx)` let pilots fill every data subcarrier → `comm:OFDM:NoDataCarriers` (~0.5% of nTx=4 OFDM); (#3) `round(startTime*Fs)` pushed a tail-overlapping burst onto frame end → silently dropped; (#10) non-power-of-2 digital order → cryptic `bit2int` error | (#8) reserve one data carrier `floor((L-1)/nTx)`; (#3) clamp a rounding overshoot to the last valid sample; (#10) clear `CSRD:Modulation:NonPowerOfTwoOrder` |
| `a9ab0f8` | MIMO stale path loss (#2) | `PathLoss` derived once at construction from default `Distance=1 m`; per-frame `Distance` updates never recompute it, so every Rayleigh/Rician/MultiPath link was attenuated by ~40 dB regardless of distance while the annotation recorded the correct distance-based path loss/SNR (signal ~80 dB too strong vs label at 10 km) | recompute `PathLoss` from the current `Distance` in `MIMO.stepImpl` |

Reproduced impact for #2: a 1 m→10 km `Distance` change now drops output power **82 dB**
(was ~0 dB) and `PathLoss` reports `fspl(10 km)=120.1 dB`. Verified: 43 channel/annotation
tests + 61 measurement tests pass; new regression guards added
(`ObwActualShortSignalContractTest`, `BaseChannelDistanceTest.mimoStepTracksUpdatedDistance`).

## Flagged for your decision (2) — NOT changed (alters dataset statistics / intended physics)

These are confirmed real, but the "right" behaviour is a channel-physics design choice that
changes the statistical character of generated data, so I did not change it unilaterally.

- **#7 — MIMO fading is not burst-isolated.** `comm.MIMOChannel` is built with no
  `RandomStream`/`Seed`, and neither `MIMO` nor `BaseChannel` declares a `Seed` property, so
  `ChannelFactory`'s burst-aware `deriveChannelSeed` (and `Config.Seed=73`) are silently dropped
  (the `isprop(block,'Seed')` guard is false). Fading is drawn from the scenario global stream.
  Determinism is preserved (the global stream is seeded per scenario via `rng(scenarioSeed)`), but
  the documented H13 contract "same (Tx,Rx,Burst) ⇒ same fading across frames" does NOT hold for
  MIMO. `ChannelSeedBurstAwareTest` only tests `deriveChannelSeed` in isolation, so it never caught
  this. **Recommendation:** add a `Seed` property to MIMO and pass `'RandomStream','mt19937ar with
  seed','Seed',obj.Seed` to the comm objects; decide whether same-burst fading *should* be
  frame-stable (H13) or evolve with time (physical mobility).
- **#9 — AWGN thermal noise is identical across frames for a recurring burst.** `AWGNChannel`
  *does* have a `Seed`, so it receives the frame-invariant burst seed; combined with the per-frame
  release+re-seed lifecycle and identical burst length, the additive noise is byte-identical every
  frame carrying that BurstId. The burst-stable seed policy is correct for *fading* but additive
  *thermal noise* should be independent per observation frame. **Recommendation:** give AWGN a
  frame-dependent noise seed (fold `frameId` into the key for additive-noise blocks only), keep
  fading blocks burst-stable.

## Robustness / stress results

- **Validation sweeps:** ~14,400 clean random combinatorial scenarios across all
  regions/channels/SDRs/antenna counts/frame counts/velocities:
  - chunks 0–11 (seeds 30M–41M, 9,600) → **0 real anomalies** (the 5 originally found were the
    Bug-9 class, now fixed).
  - chunks 30–35 (seeds 60M–65M, 4,800) — the **final sweep with all six fixes present, nothing run
    concurrently** → **0 anomalies**.
  - chunks 20–25 (seeds 50M–55M, 4,800) showed 18 "no annotation" failures clustered at consecutive
    seeds in one wall-clock window — reproduced as **transient resource contention** (several
    verify/MCP MATLAB processes were running alongside the 6 sweep chunks); all sampled seeds
    regenerate valid annotations in isolation, and the ~4,600 scenarios after that window were clean.
    Not a code defect. Lesson applied: validation runs are serialized, never piled onto a running sweep.
- **Final regression:** all 18 suites touched by the fixes run together with every fix present →
  **112 tests, 0 failed**.
- **F-memory:** 300 single-process scenarios, **0 failures**, MemUsedMATLAB 3856→4029 MB; growth is
  warm-up-dominated then ~6–8 MB/50 scenarios (sub-linear plateau) → no leak.
- **F-parpool:** real 4-worker parpool, **0 crashes / 0 failures**; output byte-identical within a
  thread mode. One cross-mode fingerprint diff was MATLAB multithreaded-FP last-bit noise
  (rel diff 2e-16), not a CSRD defect.

## Housekeeping

- Temp scripts at repo root (to delete at wrap-up): `massive_sweep_tmp.m`, `fmem_tmp.m`,
  `fpar_tmp.m`, `repro_anom_tmp.m`, `repro_new_tmp.m`, `reprofp_tmp.m`, `verify_fixes_tmp.m`,
  `verify_fixes2_tmp.m`, `verify_pathloss_tmp.m`, and `artifacts/coverage/*` logs.
- PR #10 left for your review/merge per your standing instruction.
