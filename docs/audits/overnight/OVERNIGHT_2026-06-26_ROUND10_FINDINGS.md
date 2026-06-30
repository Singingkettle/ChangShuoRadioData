# Round 10 (2026-06-26): exhaustive multi-dimension bug hunt — channel seeds, RF chain, measurement, allocation, serialization

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged**).

A 7-dimension multi-agent hunt (channel+seeds, modulators, TX RF chain, RX RF chain, measurement,
scenario allocation, annotation/downstream) with per-finding adversarial verification (default-to-refute,
design-intent-aware). **7 verified-real bugs, all fixed**, including the two long-standing memory-flagged
channel-seed defects (#7 MIMO fading, #9 AWGN noise) confirmed still-live and now resolved.

## Fixed (7)

| Commit | Finding | Sev | Fix |
|---|---|---|---|
| `25bc3b7` | **MIMO fading drawn from the global RNG, not seeded** (memory defect #7) | med | `comm.MIMOChannel` built with no `RandomStream`/`Seed`; MIMO had no `Seed` property, so the burst-aware `deriveChannelSeed` was silently dropped (`isprop` false) — fading non-reproducible, `reset()` drew fresh fading each frame, breaking H13 + worker reproducibility. Added a `Seed` property + `'RandomStream','mt19937ar with seed','Seed',obj.Seed`; the factory now routes the burst-aware seed in. Test `MimoFadingDeterminismTest` |
| `2a285ed` | **Additive noise byte-identical across all frames of a scenario** (memory defect #9) | med | `deriveChannelSeed` omits FrameId (so fading is burst-stable, H13) and BurstId carries no frame term, so the AWGN block + controlled-SNR injection produced an identical noise mask every frame — physically wrong (thermal noise is i.i.d.) and memorizable. New `frameSaltedNoiseSeed` salts FrameId into the noise seed ONLY (AWGN block + injection); fading seed + SNR target stay frame-stable, so noise power is unchanged, only the samples vary per frame. Test `AwgnNoiseFrameVariationTest` |
| `7e74535` | **RX DCOffset annotated but never applied** (phantom impairment) | med | `RRFSimulator` recorded RX DCOffset as a realized impairment but `stepImpl` never applied it. Apply after IQ imbalance matching the TX convention (`+ 10^(DCOffset/20)`) |
| `7e74535` | **Center-frequency smoothing discontinuity at N=256** | low | the round-9 centroid `movmean` only ran for N≥256, leaving a boundary discontinuity. Smooth for all N≥8 with an odd window floored at 3 |
| `7e74535` | **Regulatory OverlapOccurred over-reports** | low | the round-9 co-channel detector used `checkFrequencyOverlap`, which adds the MinSeparation placement margin → flagged near-but-separated emitters. Use a strict band-overlap predicate so it records ACTUAL collisions only |
| `7e74535` | **Single-source frame serializes SignalSources as a bare object** | low | a 1-source frame emitted `SignalSources` as a JSON object, not an array (inconsistent vs multi-source frames). Normalize each receiver annotation's SignalSources to a cell before `jsonencode` (`SimulationRunner.normalizeReceiverSources`); `readAnnotation` accepts both. Verified now a JSON array |
| `7e74535` | **Stale doc: COCO bbox center provenance** | low | `annotation-schema.md` said the bbox center comes from `ReceiverView.ProjectedCenterOffsetHz`; it has used the measured `Truth.Measured.SourcePlane.CenterFrequencyHz` since round-7. Doc corrected |

## Verified NOT bugs (adversarial pass refuted / design-intent)
The hunt's verify stage refuted several candidates as intentional/contract-pinned (e.g. the receiver-baseband
OFFSET placement, IQ-imbalance image spurs, the complex-baseband single-sided spectrum, the burst-stable
FADING seed). The double-Doppler question (round-8 #2) remains intentional (distinct spread vs mean shift).

## Verification
`checkcode` clean on the changed production code; 88-test channel suite + measurement/equivalence + COCO +
annotation + RRF suites pass; end-to-end `simulation(1,1,'csrd2025/csrd2025.m')` runs clean; new regression
tests `MimoFadingDeterminismTest`, `AwgnNoiseFrameVariationTest`. Determinism repros: same-seed fading
identical across global-RNG states + reset()-stable; additive noise differs across frames at stable power.
