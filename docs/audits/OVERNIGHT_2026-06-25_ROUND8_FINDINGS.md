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
| _(round-9)_ | **Geometry NaN vectors corrupt the JSON round-trip** (HIGH, was flag #3) | a `[NaN NaN NaN]` GeometrySnapshot vector serialises to JSON `[[],[],[]]` and `jsondecode` reads it back as a CELL, not a double, so downstream `double()/norm()` throws and the COCO export carries the corrupted type | read-side coercion in `readAnnotation` (`localCoerceSourceGeometry`): the known-numeric GeometrySnapshot fields are coerced back to a double column (cell `[]` → NaN); the COCO path reads via `readAnnotation` so it benefits too. Regression test `ReadAnnotationGeometryRoundTripTest` asserts class `double` + `norm()` does not throw |
| _(round-9)_ | **Wideband OBW collapses to ~1 FFT bin** (HIGH, was flag #1) | instrumented capture of a real collapsed source: a realized ~17 MHz QAM-16 (energy spread over the full band, RMS bandwidth ~14.7 MHz) measured at **1.56 MHz**. Root cause is NOT a spurious line — the occupied band is flat at ~−6 dB but a single localized spike (short burst / channel-selective peak) sits ~5 dB higher, so the peak-relative −3 dB threshold lands ABOVE the flat band and clips it away. Affected **33/212 (~15%)** of wide sources in a default-config probe | **collapse guard** in both `measureSignalSummary` + `obwActual` (kept equivalent): keep the peak-relative −3 dB estimate normally, but fall back to a noise-floor-relative estimate (25th-percentile floor + 6 dB, which keeps the whole occupied band) only when the peak-relative width is < 0.3× the floor-relative width. Post-fix probe: **0/… under-measured**, wide sources now read 79–98% of the realized BW; common cases unchanged. Regression test `ObwCollapseGuardTest` + measurement-equivalence suite |

## Flagged — need an owner decision or a deeper dig (6)

1. ~~**Wideband OBW collapses to ~1 FFT bin**~~ **FIXED (round-9)** — see the Fixed table. The
   instrumented dig showed it is NOT a spurious line but a flat occupied band clipped away by the
   peak-relative −3 dB threshold when a localized spike sits a few dB above it (short bursts / channel-
   selective peaks). Fixed with a collapse guard that falls back to a noise-floor-relative estimate only
   when the peak-relative width is implausibly narrow, in both estimators, validated end-to-end.

2. **Double Doppler on MIMO fading** (HIGH, design decision). `comm.MIMOChannel` applies its internal
   zero-mean Jakes Doppler SPREAD, and `processChannelPropagation` ALSO applies an explicit deterministic
   `f_d = v·f_c/c` SHIFT (HasInternalDoppler is never set on the MIMO output). The design doc
   (phase-4-measurement.md R1) prescribes setting `HasInternalDoppler=true` to suppress the explicit
   shift. BUT physically the two model different effects — a zero-mean spread vs a deterministic mean
   shift — so suppressing the explicit shift would drop the moving-Tx mean Doppler. Owner should decide:
   follow the doc (suppress) or keep both (and document why). Location:
   `MIMO.m` infoImpl/stepImpl (set ChannelInfo.HasInternalDoppler), `processChannelPropagation.m:655-661`.

3. ~~**Geometry NaN vectors corrupt the JSON round-trip**~~ **FIXED (round-9)** — read-side coercion
   in `readAnnotation` (`localCoerceSourceGeometry`) restores the known-numeric GeometrySnapshot fields
   to a double column (cell `[]` → NaN); the COCO path reads via `readAnnotation` so it benefits.
   Regression test `ReadAnnotationGeometryRoundTripTest`. (Chose read-side over write-side because the
   honest value of unknown geometry IS NaN, which JSON cannot carry as a number — the round-trip can
   only be repaired on read.)

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
