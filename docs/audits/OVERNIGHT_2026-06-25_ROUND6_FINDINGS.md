# Static-audit — round 6 (2026-06-25): annotation labels, modulation, frequency, timing, power

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

A 6-dimension multi-agent static hunt (29 agents: per-dimension finders + adversarial verifiers, all
design-intent-aware — a behaviour pinned by a test is a contract, not a bug). Dimensions: digital
modulators, multicarrier+analog modulators, annotation/label GT, frequency/spectrum, timing/framing,
binding+power. The verifiers defaulted to refuting; only high-confidence, file:line-cited defects that
make the realized signal or its recorded GT/label wrong survived.

**4 confirmed bugs → 3 fixed, 1 flagged.** Modulation, frequency-placement, and timing dimensions
produced candidates but all were refuted or shown to be deliberate (the measured-GT machinery there is
sound). The survivors are all in the **annotation-label / impairment** class — exactly where a wrong
value silently mislabels training data.

## Fixed (3)

| Commit | Finding | GT impact | Fix |
|---|---|---|---|
| `1d26fbf` | **SourcePlane.TimeOccupancy measured on the burst-only buffer** (HIGH) | `buildMeasuredTruth` ran the envelope on the per-emitter buffer, which is clipped to the emitter's active extent, so a continuously-modulated burst read `TimeOccupancy ≈ 1.0` regardless of its sub-frame footprint — a 10%-duty short burst and a full-frame continuous emitter both labelled ~1.0. The FramePlane (zero-padded to frame length) correctly reported the sub-frame fraction; the two planes disagreed on the same physical fact. | scale the buffer occupancy by the burst's fraction of the frame (`FrameSampleCount/FrameLengthSamples`) so SourcePlane matches the FramePlane semantics. Regression guard added (`TimeOccupancy ≤ frame fraction`) |
| `19eb4eb` | **TX DCOffset dB→linear used the power factor `/10`** (MEDIUM) | `TRFSimulator` added the DC/LO-leakage term as `10^(DCOffset/10)`; DCOffset is a dB level and the term is an amplitude, so it must be `10^(dB/20)`. The realized DC spur was ~2× too many dB below the signal (−50 dB → −100 dBc), disagreeing with the dB recorded in `RFImpairments.DCOffset`. | use the amplitude factor `10^(DCOffset/20)` |
| `8612673` | **COCO bbox center used the planned offset, not the measured center** (MEDIUM) | `makeFrequencyBbox` built the box center from `ReceiverView.ProjectedCenterOffsetHz` (the planner's pre-Doppler offset) while taking the width from the measured OBW — so with non-trivial Doppler the detection box was mis-centered on the realized lobe, inconsistent with the project's own measured-over-planned rule. | center on measured `SourcePlane.CenterFrequencyHz`; regression test with a Doppler-divergent center |

## Flagged (1, low — spawned as a separate task)

- **`Design.PlannedCenterFrequencyHz` stores the receiver-baseband offset, not an absolute RF center**
  (`processSingleSegment.m:138-139` assigns `Placement.FrequencyOffset`). The schema documents it as the
  absolute "Blueprint center frequency". This is the **Design** (planning) plane — not GT — so impact is
  low, and the value appears to be a deliberate "offset now, add the absolute carrier later" placeholder.
  Left for the owner; a downstream consumer reading `metadata.design.PlannedCenterFrequencyHz` as an
  absolute RF center would be off by ~the receiver tuned frequency.

## Verification
`checkcode` clean on the changed code; TRFSimulatorTest, ConvertCsrdToCocoTest (incl. the new
measured-center test), BuildSourceAnnotationTest (incl. the new TimeOccupancy invariant),
MeasurementPackageTest, TRFExactResampleContractTest, and the phase-6 COCO fixture all pass (52/52 +
the two new cases). No existing test encoded the buggy behaviour.
