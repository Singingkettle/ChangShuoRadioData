# Overnight static-audit — round 2 (2026-06-21)

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

A second 10-dimension multi-agent static bug-hunt over previously-unaudited subsystems
(scenario planner, annotation round-trip, config merge, MIMO antenna dims, receiver chain,
message source, Doppler, toolbox fallback, data IO, spectrum occupancy). 21 candidates,
13 adversarially-verified. Each fix below was independently reproduced before applying and
validated with the relevant regression suites. Findings that conflict with a deliberate
existing contract, or that change the dataset's statistical/spectral character, were NOT
auto-fixed — they are flagged for your decision (the #3 case below is exactly why).

## Bugs fixed (7 findings) — committed & pushed

| Commit | Finding | Root cause | Fix |
|---|---|---|---|
| `7ca036d` | #1 Scheduled collapse (HIGH) | For the us-scale observation windows the framework uses, the Scheduled SlotDuration is clamped to 0.3*obs, so AssignedSlot>=5 (~52% of Scheduled emitters) produced no in-window slot; the sentinel fallback rewrote intervals to continuous but left Type='Scheduled' — annotation said slotted, signal was continuous | clamp AssignedSlot to the startable slots; relabel any residual sentinel-fallback as Continuous |
| `9d11a51` | #10/#11 swallowed save failures (HIGH/MED) | a failed signal `.mat` save and a failed/​unopenable annotation write were caught-and-logged, so the scenario still counted Success with a missing signal or annotation file | rethrow on save/write failure (and on fopen==-1) so the scenario is counted Failed; signal/annotation stay co-present-or-both-absent |
| `f2410d6` | #4/#5 OSTBC truncation (MED/LOW) | `genOSTBCWithX` used `floor(SymbolRate*8)` as the block size — 6 for the 2-antenna Alamouti (default SymbolRate 0.75) and the rate-3/4 codes, dropping up to 5 trailing payload symbols | derive the true symbols/block (2 Alamouti, 4 rate-1/2, 3 rate-3/4) |
| `4cbd034` | #2 COCO single-element shape (HIGH) | jsonencode of a 1-element struct emits a JSON object, so a single-frame export wrote `"images": {...}` not `[{...}]`, breaking pycocotools | encode from a cell-wrapped copy so collections are always JSON arrays |
| `4cbd034` | #8 stereo audio crash (MED) | a stereo WAV in the audio pool returned `[1024 x 2]` and crashed the `[1024 x 1]` per-block assignment | mix multichannel reads down to mono |

Validation: Monte Carlo (Scheduled collapse 52.1%→0.0%), comm.OSTBCEncoder symbol-retention
checks, ConvertCsrdToCocoTest 5/5, 32 runner/annotation tests, 36 modulator tests, end-to-end
scenarios — all green.

## Flagged for your decision (6 findings) — NOT changed

These are real or plausible, but the correct behaviour is a design/contract/dataset decision.
One of them (#3) was initially "fixed" and then reverted when it broke a deliberate test — a
reminder that an agent finding can mistake intended design for a bug.

- **#3 COCO rejects a NoSignal SourcePlane (MED).** A frequency-visible source whose isolated
  SourcePlane is NoSignal (NaN OccupiedBandwidthHz, finite FramePlane) makes the converter
  error — and `ConvertCsrdToCocoTest.rejectsMissingMeasuredBandwidth` **deliberately asserts that
  rejection**. So the converter requiring a finite SourcePlane OBW is an intended contract, not a
  bug. Open question: should it instead (a) fall back to the FramePlane OBW, (b) skip just that
  source, or (c) keep rejecting? Separately, the reject currently aborts the *whole* export for one
  bad source (no per-source try/catch) — worth softening regardless of (a)/(b)/(c).
- **#6 RX DCOffset is annotated but never applied (HIGH).** `ReceiveFactory` samples and writes
  `RxImpairments.DCOffset`, but `RRFSimulator`'s documented 4-stage chain (LNA → thermal noise →
  IQ imbalance → sample-rate offset) does not apply it, so the annotation reports a phantom
  impairment. The TX side *does* apply its DCOffset. Decision: either apply the RX DCOffset
  (symmetric with TX, makes the annotation true — but changes the signal and needs the dB-vs-linear
  unit convention reconciled), or remove the phantom from the annotation (honest — but drops a field
  that `ReceiveFactoryRxImpairmentsTest` asserts).
- **#9 RayTracing free-space fallback keeps Tx-antenna columns (HIGH).** `applyNoPathFallback` returns
  a signal with `numTxAntennas` columns while the success path and the rest of the channel zoo
  output `numRxAntennas` columns. Only fires on the no-path fallback. The fix needs a MIMO mapping
  choice (sum-and-replicate vs per-antenna array response), so it's a modeling decision.
- **#12 / #13 OFDM occupied bandwidth decoupled from the plan (HIGH/MED).** The regulatory OFDM
  config pins FFTLength and lets the subcarrier-spacing floor fix the occupied bandwidth (~26.4 MHz
  regulatory / ~6.72 MHz legacy) regardless of the planned channel bandwidth, so realized spectrum
  diverges from placement/annotation. The fix (size FFTLength from the planned bandwidth) changes
  the spectral footprint of every OFDM emitter across the dataset — a sizable dataset-statistics
  change that should be your call.
- **#7 genIqImbalance has no config guard (LOW).** Dereferences `IqImbalanceConfig.A/.P` with no
  guard, so a receiver config that omits IQImbalance crashes cryptically. Only reachable via a
  malformed custom config; a one-line clear-error guard would help, but the project prefers minimal
  defensive code, so left for your call.

## Round-1 flags still open
`#7 MIMO fading not burst-isolated` and `#9 AWGN per-frame noise identical` from
`OVERNIGHT_2026-06-20_STRESS_FINDINGS.md` remain open pending your channel-physics decision.
