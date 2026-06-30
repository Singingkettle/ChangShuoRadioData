# Round 7 (2026-06-25): end-to-end design review + bug hunt

Branch: `fix/message-source-modulation-binding` (PR #10, **not merged** — awaiting your review).

A 6-lens multi-agent static review (per-lens finders + adversarial verifiers, design-intent-aware) of
the **Plan → Build → Measure** three-plane principle and the **complex-baseband architecture**, plus a
deep bug hunt on under-audited dimensions (modulation, resampling, message source, multi-Rx projection).

## Design-conformance conclusion — the core architecture is correct

- **Plan → Build → Measure (Design / Execution / Measured)** holds: Design carries planned values,
  Execution the realized-analytical ones, Measured is taken from the realized RX signal, and the dataset
  GT comes from the Measured plane. The one leak found (NoSignal SNRdB) is fixed below.
- **Complex-baseband / equivalent-lowpass** is implemented correctly: the signal is generated at the
  receiver bandwidth and each emitter placed at a receiver-baseband **offset** by complex-exponential
  translation (single-sided, no mirror); the **absolute carrier** (2.4 GHz) is used only for the
  frequency-dependent physics (free-space path loss, Doppler). The absolute carrier is never synthesized
  (Nyquist-infeasible), which is why the offset representation is both necessary and exact.

## Fixed (4)

| Commit | Finding | Impact | Fix |
|---|---|---|---|
| `c4cc803` | **OQPSK SampleRate stale after even-SPS coercion** (HIGH) | OQPSK forces SamplesPerSymbol even, but SampleRate was set from the raw (odd) SPS before setup, so the TRF resampled the realized even-rate waveform at the stale odd rate — scaling its frequency/bandwidth by oddSPS/evenSPS (e.g. 3→2 = 1.5×) and breaking Execution.SampleRate vs the measured OBW | recompute SampleRate from the coerced even SPS |
| `3da4de6` | **Analog message length missing the SamplesPerSymbol factor** (HIGH) | digital symbols are upsampled by SPS (the factor cancels) but analog (FM/PM/AM) is modulated sample-by-sample, so the source was ~1/SPS of the burst and gateToDuration zero-padded the rest — **45–86 % of every analog burst was silence** | branch on IsDigital; multiply by SamplesPerSymbol for analog in both length computations. Measured: realized FM active fraction rose from ~15–55 % to the full burst |
| `99423c2` | **NoSignal SourcePlane.SNRdB leaked a finite value** (MEDIUM, three-plane) | a silent/dropped/out-of-window buffer reported a finite channel-power-derived SNR for a signal absent from the realized buffer | initialise SNRdB=NaN like the other measured scalars; assign the measured value only in the hasSignal branch |
| `166bf80` | **Spectrogram overlay box used planned pre-Doppler edges** (MEDIUM) | the STFT GT overlay drew the box from `ProjectedLowerEdge/UpperEdge` (planned) while the COCO bbox already uses the measured center/OBW — inconsistent under Doppler | use the measured SourcePlane center/OBW (clamped to the view), planned fallback |

## Flagged (2)

- **Receiver visibility classifier is midpoint-blind** (LOW, latent — spawned as a task). The
  InBand/EdgeClipped/OutOfBand decision uses `abs(projOffset) ± halfBw` vs the half-width, which assumes a
  0-centered observable window. Correct for the current unified-rx case (always 0-centered), latently
  wrong for future heterogeneous receivers with asymmetric windows. `CommunicationBehaviorSimulator.m:219-240`.
- **Wideband modulation can exceed the receiver Nyquist limit** (observation). Forcing OQPSK at the
  configured max bandwidth (40 MHz = 0.8 × 50 MHz `MaxBandwidthFractionOfSampleRate`) produced a realized
  OBW that collapsed to ~24 kHz — the signal aliases when the symbol-rate-driven bandwidth (×(1+β),
  OQPSK offset) exceeds the receiver's usable band. Worth revisiting whether the max-bandwidth fraction
  should be tighter for the widest single-carrier families, or the planner should cap symbol rate so the
  realized occupied bandwidth fits the receiver.

## Verification
`checkcode` clean on the changed code (only pre-existing AGROW pre-allocation hints remain);
AllModulationFactorySmokeTest, BuildSourceAnnotationTest, AnalogModulationRobustnessTest,
ScenarioPlanBuildTest, ScenarioFactoryRegulatoryChinaTest, MeasurementPackageTest, RRFSimulatorTest, and
the test_bandwidth_consistency / test_phase16 scripts all pass (53/53 + 2 scripts). Analog non-silence
and OQPSK rate-consistency confirmed by an end-to-end reproduction.
