# Round 12 (2026-06-28): exhaustive measured-GT bug hunt (12 un-probed dimensions)

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A design-intent-aware multi-agent workflow (12 dimensions × static deep-read finder → adversarial
verifier) surfaced 13 suspects → **2 confirmed real + 2 needs-empirical (all 4 then empirically confirmed
and fixed) + 9 dismissed** (intended/false-positive). The finders ran static-only (no MATLAB) to avoid
contending with a running generation; every confirmed finding was then reproduced with a targeted MATLAB
probe before fixing.

## Fixed (4)

| Finding | Sev | Empirical proof | Fix |
|---|---|---|---|
| **MIMO measured-SNR scale mismatch** | med | summed monitor-stream power ≈ NR× the per-column power (NR=4/8/16 → 4.2/9.1/7.2×) → measured SNR biased low ~6–10 dB | The receiver saves `sum(antennas)` (localCollapseAntennaSignal), but `ChannelSignalPowerW` was the per-column mean while the receiver thermal/ADC noise is an absolute floor on that summed stream → low bias up to ~10·log10(NR) dB. Record the **collapsed-scale** signal+channel-noise power in `MIMO.m` and `ChannelFactory.applyControlledSnrNoise`. Waveform unchanged; SISO unchanged (`sum(.,2)` is a no-op). |
| **Nyquist-edge wrap mis-measurement** | med | edge-placed (off=0.49·Fs) narrow emitter: OBW 1.42→**50 MHz**, centre 24.5→13.6 MHz | A complex-baseband offset is a CIRCULAR shift; a band whose realized width overruns ±Fs/2 wraps, and the LINEAR OBW span search + centroid mis-read it. New `circularRecenterSpectrum` recentres the (periodic) spectrum on its energy-weighted circular mean before the linear estimators in `obwActual`/`measureSignalSummary`/`spectrumCentroid`. Post-fix: OBW 1.42 MHz ✓, centre 24.56 MHz ✓; non-wrapped tones unaffected. |
| **OBW collapse-guard defeated at high occupancy** | med | 78%-occupancy band + spike: OBW collapsed to **0.05 MHz** (realized ~39 MHz) | The collapse-guard floor `prctile(spec,25)+6 dB` lands INSIDE a wideband occupied band (emitters may occupy up to 0.8·Fs → only ≥20% noise bins), so the floor estimate collapses to the spike too and the guard never fires. Lowered the floor percentile to the **10th** (stays in noise for ≤90% occupancy) in all three estimators. Post-fix: OBW 48.8 MHz ✓ (recovered). |
| **PA spectral-regrowth aliasing at low SPS** | high | in-band EVM at SPS=2 (margin 1.0) = **−5.8 dB** vs −11.8 dB at SPS≥8 | `TRFSimulator` applied the memoryless-nonlinearity PA on the modulator native grid before resampling; 3rd-order regrowth (~3× BW) exceeded the input Nyquist at low SPS and aliased in-band, corrupting the realized waveform. Now **oversample → PA → decimate** (the decimation anti-alias filter removes the out-of-band regrowth as the receiver band-limiting would, keeping genuine in-band distortion); only triggers when the oversampling margin is low. Post-fix: SPS=2 EVM −11.9 dB ✓ (matches well-sampled), SPS≥4 unchanged. |

## Dismissed (9, design-intent-aware)
ADC never hard-clips (GT is measured pre-RF-chain, and the quant-floor bound is intentional); a wrapped
emitter aliasing onto a co-channel emitter at the opposite edge (intended placement physics);
`HasInternalDoppler` unset (intentional — Jakes spread vs deterministic shift); silent/DC audio →
degenerate burst (GT faithfully reflects it); channel-seed key omits ScenarioId (entity IDs already unique
per scenario); inter-emitter-gap bridging in the FramePlane combined OBW (intended — combined band spans
the occupied range); pwelch nfft-floor bin width inflating tiny-emitter OBW (sub-bin, within tolerance).

## Verification
80 existing measurement/MIMO/TRF unit tests pass; 5 new regression tests pass
(`NyquistWrapAndOccupancyMeasurementTest`, `MimoMeasuredSnrScaleTest`); checkcode clean on all changed
code; end-to-end `simulation(1,1,csrd2025)` runs clean.
