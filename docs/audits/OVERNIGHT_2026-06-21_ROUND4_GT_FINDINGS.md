# Static-audit — round 4 (2026-06-21): MEASURED ground-truth correctness

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

This round was framed by the project owner's key principle: **the dataset's ground truth (GT) comes
from the MEASURED plane — values measured from the actual received signal — NOT from the planning
stage**, because the plan does not represent the final signal. The audit therefore targeted whether
the Measured GT faithfully reflects the real signal. The verifier was design-intent-aware (a behavior
asserted by an existing test is a contract, not a bug).

**19 candidates → 2 confirmed, 17 rejected as deliberate design.** The high rejection rate is the
point: the measurement code is mostly correct/intentional, and the two survivors are exactly the
"measured GT is wrong" class the principle warns about.

## Bugs fixed (2) — committed & pushed

| Commit | Finding | GT impact | Fix |
|---|---|---|---|
| `9d6f14c` | #1 centroid biased by AWGN (HIGH) | the measured `CenterFrequencyHz` GT integrated the raw periodogram with no noise-floor threshold; broadband AWGN (symmetric about 0 Hz) pulled the measured center toward baseband — an emitter at 15 MHz measured 14.85/13.65/11.98/**7.52** MHz at SNR 20/10/6/0 dB (off by up to 7.5 MHz), worst for edge-of-band emitters | apply the peak-relative −3 dBc threshold the sibling OBW estimator already uses, in `spectrumCentroid` and `measureSignalSummary.localSpectrumCentroid`. Error collapses to ≤0.13 MHz across SNR 0–20 dB; clean-tone/Doppler tests unchanged; new regression added |
| `3a5c854` | #2 (round-3 flag) narrow-SDR frame desync (HIGH) | `buildScenarioPlan` derived the frame from the un-capped 50 MHz rate while the receiver capped to the SDR IBW, so a narrow-SDR production run failed `CSRD:Frame:InconsistentFrameSamples`; per the measured-GT contract the frame must use the rate the signal is actually realized/measured at | cap `localReceiverSampleRate` by the SDR's `MaxInstantaneousBandwidthHz`. Verified: a production RTL-SDR (2.4 MHz) scenario now generates instead of erroring |

## Resolved after this report (1) — measured SNR implemented (`1b93ee6`)

- **Measured SNR GT is now a true measurement, not the analytical label (HIGH).** Originally flagged
  because `Truth.Measured.SourcePlane.SNRdB` was copied from the analytical `AppliedSNRdB` while every
  other Measured field was measured. The owner chose the **received-SNR** semantics (signal vs ALL
  realized noise, the most credible). Implemented: each stage reports its realized power
  (AWGNChannel → signal + noise; fading channels → faded signal + zero channel noise; RRFSimulator →
  thermal noise referred to the receiver-input scale by the measured LNA gain), and
  processReceiverProcessing measures the per-emitter SNR = signal / (channel noise + thermal noise)
  via `actualSnrFromComponents`, falling back to the label only when realized powers are unavailable.
  The saved waveform is unchanged (read-only measurement, determinism preserved). Verified: AWGN
  measured SNR reproduces the label exactly; Rayleigh diverges 1–3 dB as expected; all sources
  finite; 68 regression tests pass. Execution.AppliedSNRdB keeps the analytical value.

## Earlier open flags (unchanged)
Round-1: #7 MIMO fading not burst-isolated, #9 AWGN per-frame noise.
Round-2: #3 COCO NoSignal reject, #6 RX phantom DCOffset, #9 RayTracing fallback antenna columns,
#12/#13 OFDM bandwidth-vs-plan, #7 IqImbalance guard.
Round-3: #4 analog message-length units, #5 multi-frame provenance accuracy.
