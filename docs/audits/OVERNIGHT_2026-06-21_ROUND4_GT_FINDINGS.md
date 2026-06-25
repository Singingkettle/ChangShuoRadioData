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

## Flagged for your decision (1) — needs the measurement-vs-label call

- **Measured SNR GT is the analytical link-budget label, not a measurement (HIGH).**
  `Truth.Measured.SourcePlane.SNRdB` is set directly from `AppliedSNRdB` (the analytical
  `txPower − pathLoss − noise` link-budget number), while every other Measured field is computed by
  `measureSignalSummary`. The already-written, tested helper `actualSnrFromComponents` is never used
  in production. **Nuance (verifier-corrected):** for the AWGN channel the noise IS scaled to the
  actual signal power to hit the target SNR, so there `AppliedSNRdB` ≈ the realized SNR and the label
  is fine. For the FADING channels (Rayleigh/Rician/MultiPath/RayTracing) the channel adds no noise,
  so the realized per-emitter SNR is set only by the receiver thermal-noise stage and may diverge
  from the analytical label. A faithful measured-GT SNR would measure it from the clean-vs-noisy
  signal (`actualSnrFromComponents` with `signalPow = mean(|clean|²)`, `noisePow = mean(|noisy −
  clean|²)`), which needs the pre-noise reference plumbed through `processChannelPropagation`. This is
  a real measured-vs-label gap aligned with the GT principle, but the right measurement semantics
  (per-source isolation, whether the receiver thermal noise counts, clean-reference plumbing) is a
  design decision for you. Recommended: measure it; flagged rather than auto-changed because it
  reshapes how the SNR GT is produced for every emitter.

## Earlier open flags (unchanged)
Round-1: #7 MIMO fading not burst-isolated, #9 AWGN per-frame noise.
Round-2: #3 COCO NoSignal reject, #6 RX phantom DCOffset, #9 RayTracing fallback antenna columns,
#12/#13 OFDM bandwidth-vs-plan, #7 IqImbalance guard.
Round-3: #4 analog message-length units, #5 multi-frame provenance accuracy.
