# Overnight stress / measured-GT bug-hunt findings

Point-in-time reports from autonomous stress-generation and adversarial
measured-GT bug hunts (2026-06-20 … 2026-06-29). Each round ran the real
pipeline, analysed aggregate statistics + physical plausibility, and (for the
later rounds) used multi-agent find→verify workflows. **These are historical
evidence, newest-first; the fixes they describe are already in the code.** For
the current state, start at [`../HANDOVER_2026-06-18_REVIEW_HANDOFF.md`](../HANDOVER_2026-06-18_REVIEW_HANDOFF.md)
and the live docs.

| Report | Focus / outcome |
| --- | --- |
| `OVERNIGHT_2026-06-29_ROUND13_FINDINGS.md` | 12 fresh dimensions; fixed the RX noise figure to read the SDR profile (was a random [10,20] dB draw). |
| `OVERNIGHT_2026-06-28_ROUND12_FINDINGS.md` | 4 measured-GT bugs: MIMO SNR scale, ±Fs/2 OBW/centroid wrap, OBW collapse-guard, PA regrowth aliasing. |
| `OVERNIGHT_2026-06-28_STRESSGEN_FINDINGS.md` | Large-scale generation: ruled out the OQPSK −40 dB SNR as the ADC dynamic-range bound (not a bug). |
| `OVERNIGHT_2026-06-26_ROUND11_FINDINGS.md` | FramePlane TimeOccupancy window, OFDM/OTFS/SCFDMA fallback spacing, FSK realized OBW, link-budget antenna gains. |
| `OVERNIGHT_2026-06-26_ROUND10_FINDINGS.md` | MIMO fading seeded, frame-varying noise, RX DCOffset, centroid smoothing, regulatory overlap, SignalSources array. |
| `OVERNIGHT_2026-06-25_ROUND8_FINDINGS.md` | Wideband OBW collapse + multicarrier bandwidth pinning (round-9 resolutions). |
| `OVERNIGHT_2026-06-25_ROUND7_FINDINGS.md` | Round-7 findings (rate/bandwidth). |
| `OVERNIGHT_2026-06-25_ROUND6_FINDINGS.md` | Round-6 findings. |
| `OVERNIGHT_2026-06-25_ROUND5_GEOMETRY_FINDINGS.md` | Geometry: metres-as-degrees boundary bug (37000× distance error). |
| `OVERNIGHT_2026-06-25_SNR_DISTRIBUTION_FINDINGS.md` | Controlled SNR distribution + ADC bound rationale. |
| `OVERNIGHT_2026-06-21_ROUND4_GT_FINDINGS.md` | Measured-SNR ground-truth, measured center bias. |
| `OVERNIGHT_2026-06-21_ROUND3_FINDINGS.md` | Round-3 static-audit findings. |
| `OVERNIGHT_2026-06-21_ROUND2_FINDINGS.md` | Round-2 static-audit findings. |
| `OVERNIGHT_2026-06-20_STRESS_FINDINGS.md` | First overnight stress baseline. |

> Round 13's later items (FM/FSK/GFSK channel-fit scaling, the geometry
> CreationTime guard) landed as follow-up commits and PRs; see the repository
> history for the exact changes.
