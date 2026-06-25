# Static+measured audit — round 5 (2026-06-25): Statistical-map geometry / distance GT

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

Triggered by the round-4 follow-up question *"is the realized SNR distribution reasonable?"*. Decomposing
the measured SNR per emitter exposed a **fundamental geometry bug**: every Statistical-map link placed its
emitters tens-to-hundreds of thousands of km apart, so the measured ground-truth SNR was ~−90 dB — the
signal was buried, i.e. effectively absent — for the entire Statistical fraction of generated data.

This is exactly the "measured GT is wrong" class the project's GT principle warns about: the corruption
reached the **Measured** plane (the dataset's ground truth), not just a planning label.

## The bug (HIGH — fixed)

`+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/initializeStatisticalMap.m` stored the
Statistical map's **local-metre** boundaries `[xmin xmax ymin ymax]` (default `[-2000 2000 -2000 2000]`)
verbatim into a **geographic** struct: `MinLatitude = boundaries(3)`, `MaxLatitude = boundaries(4)`, etc.
`createEntity.m:98-104` then drew lat/lon uniformly in those "degree" bounds and called
`geoToLocalMeters` (`metres = deg2rad(deg) · earthRadius`, earthRadius = 6371008.8 m), which inflated the
±2000 **metre** extent — treated as ±2000 **degrees** — by `deg2rad·earthRadius ≈ 111,195 m/deg` (~37,000×).

**Measured before the fix** (forced Statistical map, AWGN):

| emitter | distance | path loss | measured SNR |
|---|---|---|---|
| 1 | 74,532 km | 197.6 dB | −92.4 dB |
| 5 | 109,054 km | 200.9 dB | −93.0 dB |
| 7 | 197,641 km | 206.1 dB | −80.1 dB |

`TxPos ≈ [2.22e8, 1.18e8, 85] m` — `2.22e8 = deg2rad(2000)·6371008.8` confirms the metres-as-degrees scaling.

The ~200 dB path loss propagates through `computeLinkBudgetSNR` (`snr = txPower − pathLoss − noisePower`,
`ChannelFactory.m:770`) into the AWGN channel's target SNR, which `AWGNChannel` accepts (−90 dB is finite)
and realises by burying the signal; `processReceiverProcessing` then **measures** that buried signal into
`Truth.Measured.SourcePlane.SNRdB`. No clamp or separately-configured SNR range masked it.

### The fix

Convert metres→degrees with the **exact inverse of `geoToLocalMeters`** when building the geographic struct,
so the round-trip reproduces the intended metre extents while keeping the geographic-struct format (all
downstream consumers untouched):

```matlab
metresPerDegree = 6371008.8 * pi / 180; % inverse of geoToLocalMeters (~111194.93)
obj.mapData.Boundaries = struct( ...
    'MinLatitude',  boundaries(3) / metresPerDegree, ...
    'MaxLatitude',  boundaries(4) / metresPerDegree, ...
    'MinLongitude', boundaries(1) / metresPerDegree, ...
    'MaxLongitude', boundaries(2) / metresPerDegree, ...
    'CenterLatitude',  ((boundaries(3) + boundaries(4)) / 2) / metresPerDegree, ...
    'CenterLongitude', ((boundaries(1) + boundaries(2)) / 2) / metresPerDegree);
```

**Measured after the fix** (distances now bounded by the map diagonal, SNR in the useful range):

| config | map diagonal | distance range | SNR range | finite |
|---|---|---|---|---|
| symmetric `[-2000,2000,-2000,2000]` | 5657 m | 185–3955 m | 15.1–50.7 dB | 78/78 |
| asymmetric `[0,4000,-1000,3000]` | 5657 m | 232–4059 m | 46.2–123.3 dB | 44/44 |

## Verification (fix-correct, six independent checks)

- **Adversarial correctness** (round-trip algebra): for the only production config (symmetric, centre 0)
  `cos(centreLat)=1` → round-trip is **bit-for-bit exact** (0.000000 % span error). Asymmetric plausible
  bounds < 0.00001 %. The `cos` shrink only exceeds 1 % for a Y-midpoint > ~1000 km of metres, which no
  config/test/scenario uses. Z/height, MinDistance clamp, boundary clamp, multi-frame mobility untouched;
  no new non-finite or error path.
- **OSM non-regression**: the OSM/FlatTerrain path (real lat/lon) never divides by `metresPerDegree`; the
  fix is isolated to `initializeStatisticalMap`. `OsmCoordinateUnitContractTest` passes.
- **Consumer completeness**: every in-simulator reader of the boundaries (`createEntity`,
  `applyBoundaryConstraints`/`createGridMap`, `generateStaticObstacles`, `updateEntityStates`,
  `getGeoOriginFromBounds`) shares earthRadius = 6371008.8 and round-trips the degree struct back to ±2000 m.
- **MATLAB**: `checkcode` clean; multi-seed × {symmetric, asymmetric} distance/SNR validation PASS
  (deterministic); broad 48-test regression suite **48/48 pass**; new guard test added (below).

### New regression guard

`tests/unit/StatisticalMapDistanceContractTest.m` — asserts Statistical/Grid entity positions stay within
the metre boundaries and the max pairwise distance stays on the order of the map diagonal (km), failing
loudly if the metres-as-degrees scaling ever returns. No existing test encoded the old (buggy) behaviour.

## Blast radius & data-regeneration guidance

- The default production config (`config/csrd2025/csrd2025.m`) inherits
  `Map.Types = {'Statistical','OSM'}`, `Map.Ratio = [0.1, 0.9]` (`scenario_factory.m:74-75`) — the
  Statistical map is selected on **~10 %** of default-path links. **That ~10 % of all default-path data
  generated before this fix has corrupted measured SNR ground truth (signals buried ~90 dB) and should be
  regenerated or quarantined.** The OSM/RayTracing 90 % used real geo coordinates and was correct all along.
- **Forced-Statistical runs** (`Map.Ratio = [1.0]`, used in several of this campaign's stress sweeps and the
  earlier SNR verification) were **100 %** affected.
- **Why ~19,200 prior "clean" scenarios missed it**: the sweep harness and baseline gates only check
  NaN / finiteness / shape / exception strings. A finite −90 dB SNR or a 74,000 km distance trips no check,
  and the one SNR-aware metric *excludes* sub-6 dB sources — so buried-signal scenarios were invisible by
  design. Lesson: anomaly gates need a **physical-plausibility band** (e.g. distance ≤ map diagonal, SNR in
  a sane range), not just finiteness.

## Minor flag (spawned as a separate cleanup task)

`calculateBoundingBox.m:19` uses `6371.0 km` while `geoToLocalMeters`/`localMetersToGeo`/the fix use
`6371008.8 m` — a ~1.4 ppm (~3 mm at 2 km) latent constant drift. Negligible physically; flagged for
unification on a single Earth-radius source of truth (out of scope for this fix).
