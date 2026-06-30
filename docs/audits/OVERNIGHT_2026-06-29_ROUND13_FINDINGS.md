# Round 13 (2026-06-29): fresh-dimension measured-GT bug hunt

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A design-intent-aware workflow over 12 fresh, un-probed dimensions (static deep-read finder → adversarial
verifier), with the round-12 + FM/FSK/GFSK fixes folded into the do-not-flag intent. **9 suspects → 1
confirmed real + 8 dismissed** (intended/false-positive). One dimension (multi-burst-alignment) failed its
structured-output retries and produced no result.

## Fixed (1)

| Finding | Sev | Fix |
|---|---|---|
| **Realized RX noise figure ignores the SDR profile** | med | The SDR catalog sets per-model `NoiseFigureDb` (USRP 5–8, RTL-SDR 6, HackRF 10 …) and it flows into the annotation, but `validateRxPlanIntoRxInfo` extracted **only** `Sdr.AdcBits` into RxInfo — never `NoiseFigureDb`. So `ReceiveFactory.configureReceiverBlock` unconditionally drew `NoiseFigure = rand[10,20] dB` (the base config range) for **every** receiver. Result: the realized thermal floor was profile-independent (USRP ≡ RTL-SDR) and disagreed with the annotated `Sdr.NoiseFigureDb` by up to ~14 dB, biasing the measured per-emitter SNR GT. This is the documented H10 intent ("NF drawn once at blueprint from the SDR profile, read — not re-drawn — by the factory"); the AdcBits half of the same plumbing was wired, the NoiseFigureDb half was left unwired. Fix: thread `Sdr.NoiseFigureDb → RxInfo.NoiseFigure` and have the factory prefer it over the random draw (falling back to the range only for non-SDR-profile test receivers). Verified: realized NF now clusters on the profile set {5,6,8,10} dB (never the old (10,20]); 14 + 2 new tests pass; e2e clean. |

## Dismissed (8, design-intent-aware)
phase-noise variance scales with frame duration (intended — realized PSD is correct); phase-noise catalog
masks validate fine (false-positive); SSB/VSB IQ image in the SourcePlane waveform (intended — allowed
image spurs); RX SampleRateOffset is dead in production (ppm never configured → SRO=0, intended);
same-emitter time-overlapping bursts from a random temporal pattern (intended/realistic); RRC `filter()`
tail truncation (intended — consistent across all linear modulators); per-segment 64-bit message floor
(false-positive); regulatory band-edge overshoot not separately recorded (intended — the Measured plane
captures the realized center/OBW).

## Verification
`SdrNoiseFigureWiredTest` (2 cases) + 14 existing receive/RRF tests pass; checkcode clean on changed code;
end-to-end `simulation(1,1,csrd2025)` runs clean with realized NF on the SDR-profile set.
