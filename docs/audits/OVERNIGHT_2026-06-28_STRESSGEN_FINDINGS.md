# Stress-generation round (2026-06-28): large-scale empirical anomaly hunt

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A large-scale sequential generation (15× `simulation(1,1,csrd2025)`, **648+ measured sources, 0
failures**) followed by an aggregate-statistics analyzer (per-modulation × bandwidth distributions +
physical-plausibility bands + cross-plane consistency + NaN/Inf/Nyquist checks). The pipeline is robust
under volume (no crashes). Three flagged clusters — **all explained, none a new production bug.**

## Flagged clusters + verdicts

1. **Narrow OQPSK measured SNR ≈ −40 dB** (7 sources, flagged as out-of-[−10,30] band) — **NOT A BUG
   (deep-dived).** Ruled out an OQPSK-specific power deficit empirically: the OQPSK modulator output power
   is 1.0 (narrow SPS=30 and wide SPS=2 alike), and the TRF output power is identical (1:1, 0 dB) for
   narrow vs wide OQPSK — so neither the modulator nor the TRF drops narrow-OQPSK power. All 7 collapsed
   cases sit in frames WITH a strong co-emitter (a 21 dB OFDM); a co-frame OFDM at 195 kHz (even narrower)
   reads 21 dB fine. The −40 dB is the documented **ADC dynamic-range bound**: a weak emitter (low Tx
   power / far link) co-channel with a strong broadcast is buried below the ADC quantization floor that
   the strong emitter sets. Physically correct ([[csrd-snr-controlled-and-adc-bounded]]). The
   "OQPSK-specific" pattern was a small-sample artifact (the weak emitters happened to be narrow OQPSK
   devices). **The analyzer's plausibility band ([−15,70]) was too tight** — it should allow the ADC bound
   to push weak emitters below −10 dB.

2. **OOK/FSK/GFSK realized OBW ≫ planned** (OOK ~23×, FSK ~16×, GFSK ~3.5×) — **realistic, not a bug.**
   These are spectrally-inefficient modulations (sharp on-off transitions / wide tone separation), whose
   99%-energy occupied bandwidth genuinely exceeds the symbol-rate channel by the sinc/deviation tails.
   The Measured plane (GT) correctly captures the real footprint; the Design `PlannedBandwidth` is the
   symbol-rate channel. Cross-plane `OBW/ModulatedBW` median = 1.00 (Execution and Measured agree).

3. **OFDM low-SNR Measured OBW ≈ full band** while Execution ModulatedBW is narrow — the **known short-
   burst residual** (round-11): a sub-symbol OFDM fragment's RX-side OBW latches onto broadband noise.
   Bounded by the option-A spacing fix (median realized/planned 0.99); the tail is the OFDM-in-a-tiny-
   window feasibility limit.

## Conclusion
The large-scale stress generation found **no new production bug**: 0 generation failures, cross-plane
medians ≈ 1.0, and the three flagged clusters are (1) correct ADC-bound behavior, (2) realistic wide-
spectrum modulations, (3) the bounded known OFDM residual. This validates the rounds 5–11 fixes under
volume. Recommended next step: **merge PR #10** (~57 fixes across rounds 5–11). The only follow-on is the
OFDM-in-tiny-window feasibility limit (option B territory) if ever needed.
