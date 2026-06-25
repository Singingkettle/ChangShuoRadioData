# SNR-distribution audit (2026-06-25): ADC dynamic range + controlled target-SNR

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).
Follow-on to the [round-5 geometry finding](OVERNIGHT_2026-06-25_ROUND5_GEOMETRY_FINDINGS.md): after
the metres-as-degrees distance fix made distances realistic, the question was *"is the realized
measured-SNR distribution reasonable?"*. It was not — for two compounding reasons, both now fixed.

The measured SNR is the dataset's ground truth (it comes from the realized RX signal), so an
unphysical or unusable SNR distribution corrupts the GT's credibility and the dataset's usefulness.

## Finding 1 — ADC dynamic range was not modeled (HIGH, fixed `fa0eb33`)

The RX chain (RRFSimulator) had four amplitude stages — LNA, thermal noise, IQ imbalance,
sample-rate offset — **none of which quantizes amplitude**, and the SDR catalog's `AdcBits` was a dead
flow (set on the profile but dropped at `validateRxPlanIntoRxInfo`, never reaching the receiver block).
So nothing imposed the ADC quantization-noise floor, and the measured SNR ran far past any physical
converter:

| | median | p90 | p99 | max | > 12-bit ceiling (74 dB) |
|---|---|---|---|---|---|
| before | 58.0 dB | 95.2 | 110.7 | 115.1 | 33 % of sources |

An N-bit ADC's ideal SNR ceiling is `6.02·N + 1.76 dB` (8-bit → 50, 12-bit → 74, 16-bit → 98). The
default receiver is a 12-bit USRP B210, so 58–115 dB is physically impossible.

**Fix (option B — additive quantization noise):** thread `AdcBits` through `RxInfo` onto a new
`RRFSimulator.AdcBits` property; after IQ imbalance, add noise sized to the ideal converter SNR relative
to the digitized signal power (AGC assumed to fill the converter), so the realized SNR saturates at the
ADC ceiling. The noise uses a local `RandStream` seeded from the signal (reproducible, global RNG
untouched). Its input-referred power is summed with the channel + thermal noise in the measured-SNR
estimator. `NaN AdcBits` disables the stage.

| | median | p90 | max | > 12-bit ceiling |
|---|---|---|---|---|
| after | 48.8 dB | 68.6 | 75.5 | 0.2 % |

## Finding 2 — the link budget over-produces SNR; distance can't fix it (HIGH, fixed `d067744`)

Even ADC-bounded, the median (~49 dB) is far too clean for spectrum-sensing detection/classification
(useful band ≈ −10..+30 dB). The cause is not distance — widening the Statistical map barely moves it:

| map half-extent | distance range | SNR median | in [−10, 30] |
|---|---|---|---|
| ±2 km | 46 m – 4.5 km | 60.0 dB | 7 % |
| ±10 km | 0.2 – 22 km | 52.2 dB | 11 % |
| ±30 km | 0.6 – 67 km | 45.7 dB | 16 % |
| ±60 km | 1.2 – 135 km | 39.8 dB | 25 % |

Even at 135 km the median is 40 dB, because high service-class transmit powers (broadcast 43–60 dBm,
mobile 37–49 dBm) and the narrowband noise bandwidth (a 200 kHz emitter gains +24 dB, a 12.5 kHz one
+36 dB, vs the 50 MHz receiver bandwidth) dominate. There was no configured target-SNR distribution and
no upper clamp — the high SNR was an unbounded emergent artifact of the link budget.

**Fix (controlled target-SNR mode):** when `LinkBudget.EnableDistanceBasedSNR` is false, each burst
draws a deterministic uniform target SNR from `LinkBudget.TargetSnrRangeDb` (default `[-10, 30]` dB).
The target is realized for **every channel model**: AWGN scales its noise from `SNRdB`; channels that
carry no noise of their own (RayTracing propagation, fading) get a post-channel AWGN injection sized to
the target relative to the realized signal power. Both set `ChannelSignalPowerW`/`ChannelNoisePowerW`,
so the measured GT reflects the target. The draw and injection use a burst-seeded local `RandStream`
(reproducible, global RNG untouched). The physical distance still drives path loss and Doppler, and
`ComputedSNR`/`AnalyticalSNRdB` still record the link-budget value for provenance. `csrd2025` enables
the mode; the base `channel_factory` default stays distance-based so existing tests are unaffected.

| path | realized SNR | in [−10, 30] | deterministic |
|---|---|---|---|
| AWGN / Statistical | uniform −9.5 .. 29.8, median 9.5 | 100 % | yes |
| RayTracing / FlatTerrain | uniform −9.5 .. 29.4, median 9.5 | 100 % | yes |

## Net result

The measured SNR GT is now both **credible** (bounded by the receiver's physical ADC dynamic range) and
**useful** (uniform across the spectrum-sensing band). The link-budget SNR, path loss, and distance are
preserved as `ComputedSNR`/`AnalyticalSNRdB`/geometry provenance, and the distance-based mode remains
available (`EnableDistanceBasedSNR = true`) for physically-emergent scenarios.

Verification: `RRFSimulatorTest` (ADC saturation + disabled-by-default), `ControlledTargetSnrTest`
(AWGN, fading-injection, distance-based backward-compat), and a 68-test channel/RayTracing/RX/measured
regression all pass; end-to-end determinism confirmed (same seed → identical measured SNR).

## Notes / open

- The controlled mode draws **uniform in dB**. If a different shape is wanted (e.g. more low-SNR
  examples, or a per-service band), it is a one-line change to the sampling in
  `ChannelFactory.resolveAppliedSnr` plus the `TargetSnrRangeDb` config.
- Tracker task #39 "E8: Dynamic range / ADC quantization" was marked complete but no ADC code/test
  existed before this work — that completion was stale.
