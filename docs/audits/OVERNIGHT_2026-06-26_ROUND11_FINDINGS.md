# Round 11 (2026-06-26): deeper 12-dimension EMPIRICAL bug hunt

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A 12-dimension multi-agent hunt with an empirical-probing mandate (run the pipeline + capture real
signals + check physical plausibility, not just static reads — the approach that found the round-9 OBW
bug), batched 4 dimensions at a time to stay under API rate limits, with 3-angle adversarial verification
(correctness / physics / contract) + a completeness critic. **5 verified-real bugs; 4 fixed, 1 flagged.**

## Fixed (4)

| Commit | Finding | Sev | Fix |
|---|---|---|---|
| `c31b225` | **FramePlane.TimeOccupancy degenerate constant 1.0** | high | the envelope window defaults to min(1e-4 s, frameDur); every frame is < 1e-4 s → one whole-frame window → TimeOccupancy always 1.0. Empirically all 1862 measured sources had FramePlane.TimeOccupancy = 1.0 (SourcePlane spanned 0.037–0.73). Pass an explicit ~1/32-frame `EnvelopeOptions.WindowSec` to the FramePlane call → real fraction (now {0.188, 0.625, 1.0}). Test `FramePlaneTimeOccupancyTest` |
| `c31b225` | **OFDM/OTFS/SCFDMA fallback Subcarrierspacing = 200/400 Hz** | high (partial) | the modulator fallbacks (fired when ModulatorConfig has no `base`) set 200/400 Hz SCS → realized OBW ~100× too narrow. Fixed all three to the standards 15 kHz SCS. Tiny (<1 MHz) multicarrier fell 48% → 26%; fallback now yields ~3.56 MHz. **Residual flagged below.** |
| `62fea97` | **FSK reports analytical BW = fsep·M** | med | under-reports realized OBW by ~33–47% for M ≥ 4 (Truth.Execution.AnalyticalBandwidthHz). Measure the realized OBW directly like every other family |
| `62fea97` | **Link-budget SNR omits Tx+Rx antenna gains** | med | `snr = txPower − pathLoss − noisePower` dropped Gtx + Grx. Add both (default 0). Affects Execution.AnalyticalSNRdB + distance-based realized SNR; controlled-SNR csrd2025 path unaffected |

## Flagged — need a focused dig (1 + 1 residual)

- **Residual multicarrier narrow-band** (HIGH): after the 200/400 Hz fallback fix, ~26% of OFDM still
  realize ~586 kHz for a planned 40 MHz. Instrumented capture: these are SHORT segments (N=103–1638
  samples ≈ 2–33 µs at 50 MHz — a fraction of one 15 kHz OFDM symbol, 67 µs), so the modulator emits a
  sub-symbol fragment whose spectrum is genuinely narrow; the scenario builder's bandwidth-aware grid is
  not reaching the modulator on this path (the fallback default fix only covers the no-`base` path). Needs
  a config-flow + OFDM-burst-length dig.
- **OBW & center wrap the ±Fs/2 Nyquist edge** (MEDIUM, measurement): the contiguous-band search +
  centroid are not circular-aware, so an emitter whose band straddles ±Fs/2 is mis-measured. Fix:
  circular-arc span search + circular centroid. Edge case; deferred.

## Completeness critic (next-round lead)
PA spectral regrowth aliasing under insufficient oversampling: the memoryless nonlinearity (3rd-order
regrowth ~3× signal BW) runs on the baseband grid before resampling; if the oversampling margin is too
small the regrowth aliases. Concrete, testable, un-probed.

## Verification
`checkcode` clean on changed code; measurement + modulation + channel suites pass; end-to-end sim clean;
new tests `FramePlaneTimeOccupancyTest`. FramePlane.TimeOccupancy distinct values verified to span a real
range post-fix; fallback OFDM verified at 3.56 MHz (was 200/400 Hz × FFT).
