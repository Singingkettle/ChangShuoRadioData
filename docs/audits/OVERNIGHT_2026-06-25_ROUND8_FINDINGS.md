# Round 8 (2026-06-25): deep bug hunt — bandwidth/Nyquist, MIMO, fading, save/load, allocation

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A 6-lens multi-agent static hunt (bandwidth/Nyquist fit, MIMO/antenna, channel fading, pulse shaping,
save/load schema, regulatory allocation) with adversarial verification, plus a targeted MATLAB
investigation of the wideband OBW symptom raised in round 7. **7 confirmed (5 high, 2 medium) + 1
measurement bug from the targeted dig.** 2 fixed here (clear, unambiguous); the rest are design
decisions or need a root-cause dig and are flagged for the owner.

## Fixed (2)

| Commit | Finding | Impact | Fix |
|---|---|---|---|
| `77f13f3` | **Visibility classifier midpoint-blind** (round-7 carry, low/latent) | `abs(projOffset) ± halfBw` vs half-width assumed a 0-centred window; wrong for asymmetric/heterogeneous receivers | classify by direct band overlap with the window; extracted + unit-tested (symmetric + asymmetric) |
| `0c4b7e0` | **MIMO fading at the stale 200 kHz default rate** (HIGH) | the inner `comm.MIMOChannel` rate was only re-aligned when locked, but the per-frame block release leaves it fresh/unlocked, so it ran at the BaseChannel default 200 kHz vs the real 50 MHz — a ~250× time-base error that over-spread the Jakes/Doppler fading and shrank multipath delays to sub-sample, corrupting every fading link's realized signal + measured GT | set the inner rate to the input rate whenever it differs (release only if locked) |

## Flagged — need an owner decision or a deeper dig (6)

1. **Wideband OBW collapses to ~1 FFT bin** (HIGH, measurement). For a fraction of wide (10–40 MHz)
   sources the measured `OccupiedBandwidthHz` collapses to ~24 kHz although the signal is genuinely
   broadband (99% energy spread over ~65k bins). Root cause: the `peak-relative -3 dB` OBW estimator
   (`obwActual` / `measureSignalSummary`) latches onto a strong spectral line (one bin held ~31% of the
   energy in a real wide QAM-64) and clips everything 3 dB below it, leaving the line's neighbourhood.
   A clean synthetic broadband QAM does NOT collapse, so the trigger is a real-signal spectral line whose
   source (a ~−5 dBc carrier/DC on a suppressed-carrier QAM) is itself suspicious and worth finding. Fix
   direction: make the OBW robust to a single line (threshold off a robust statistic e.g. median, or use
   a 99%-energy method with noise-floor removal), and/or find + fix the spurious carrier line. Needs a
   focused root-cause dig before changing a core measurement.

2. **Double Doppler on MIMO fading** (HIGH, design decision). `comm.MIMOChannel` applies its internal
   zero-mean Jakes Doppler SPREAD, and `processChannelPropagation` ALSO applies an explicit deterministic
   `f_d = v·f_c/c` SHIFT (HasInternalDoppler is never set on the MIMO output). The design doc
   (phase-4-measurement.md R1) prescribes setting `HasInternalDoppler=true` to suppress the explicit
   shift. BUT physically the two model different effects — a zero-mean spread vs a deterministic mean
   shift — so suppressing the explicit shift would drop the moving-Tx mean Doppler. Owner should decide:
   follow the doc (suppress) or keep both (and document why). Location:
   `MIMO.m` infoImpl/stepImpl (set ChannelInfo.HasInternalDoppler), `processChannelPropagation.m:655-661`.

3. **Geometry NaN vectors corrupt the JSON round-trip** (HIGH, serialization). When a GeometrySnapshot
   vector is `[NaN NaN NaN]` (reachable when midpoint geometry is off and Position is unset),
   `sanitizeForJson` num2cell's it and JSON `null` → `jsondecode` reads it back as a CELL, not a double,
   so downstream `double()/norm()` throws and the COCO export carries the corrupted type. Fix on the
   write side (don't NaN-cellify a numeric vector / always populate geometry) or the read side (coerce
   null-cells back to numeric). `sanitizeForJson.m:296-316`, `processReceiverProcessing.m:341-352`.

4. **Regulatory allocation lacks inter-emitter de-confliction** (HIGH, design gap). The regulatory path
   places each emitter independently with no min-separation, so two can land co-channel, yet each is
   recorded as a clean isolated SourcePlane with `OverlapOccurred=false`. The default ReceiverCentric
   path enforces non-overlap (errors `FrequencyPlacementFailed`); the regulatory path has no equivalent.
   Owner decides: enforce non-overlap, or allow overlap but record honest provenance + co-channel labels.
   `RegionSpectrumSelector.m:60-69`, `allocateFrequenciesFromRegulatoryPlan.m`, `performScenarioFrequencyAllocation.m:25-28`.

5. **Regulatory OFDM 15 kHz subcarrier-spacing floor fixes realized OBW at ~26 MHz** regardless of the
   planned channel (HIGH, design gap, bandwidth-nyquist lens). The OFDM realized bandwidth doesn't track
   the planned channel bandwidth.

6. **Symbol-rate snap rounds up** (MEDIUM) and **ReceiverView visibility/edges + feasibility use
   PlannedBandwidth** rather than the realized bandwidth (MEDIUM) — both bandwidth-nyquist lens.

## Verification (fixed items)
`checkcode` clean on the changed code; ReceiverVisibilityClassifierTest (symmetric + asymmetric) +
ScenarioPlan/ReceiverView suites and a 24-test channel/SNR/MIMO regression all pass.
