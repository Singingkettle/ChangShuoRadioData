# Phase 8 - Regulatory Spectrum Planning

Version: v0.8.0-draft
Date: 2026-04-28

## Goal

Phase 8 replaces arbitrary scenario-level frequency, bandwidth, and
modulation sampling with region-aware regulatory planning. A generated
transmitter must be explainable as:

1. a physical scene bound to a region,
2. a monitoring receiver observing a real RF window in that region,
3. one or more emitters selected from services allowed in that window,
4. modulation and bandwidth choices that are plausible for that service,
5. annotations that preserve those design facts separately from measured IQ
   facts.

This phase does not try to reproduce full protocol stacks such as NR, LTE,
Wi-Fi, DTMB, ATSC, ISDB, or DMB. It maps those services onto the modulator
families available in this repository, such as OFDM, QAM, FM, DSBAM, FSK,
GFSK, OQPSK, OOK, and VSBAM.

## Contract

The new planning layer lives above the Phase 2 band profile library:

- `RegionSpectrumCatalog` loads source-backed regional service bands.
- `RegionSpectrumSelector` chooses monitoring windows and emitter plans.
- `RegulatoryValidator` rejects invalid catalog entries and selected plans.

Every catalog entry must declare:

- region and authority,
- frequency range in Hz,
- service class and application,
- allowed modulation families and bandwidths,
- channel raster or explicit channel centers,
- source references,
- evidence level.

No catalog entry may use radar, radiolocation, or radionavigation-radar
services as an emitter source in Phase 8.

## Planning Flow

1. Resolve `CommunicationBehavior.Regulatory.Region`.
2. Load the region catalog and filter by `ServiceTier`.
3. Select a receiver monitoring band and set
   `Receiver.RealCarrierFrequency` to the selected RF center.
4. For each transmitter, select an intersecting service band.
   If `MonitoringBand.FixedBandId` is configured, the default is stricter:
   transmitters are selected from that fixed band only. A test or legacy
   experiment must explicitly set
   `MonitoringBand.AllowIntersectingServices = true` to allow neighboring
   services inside the same receiver bandwidth.
5. Select bandwidth, channel center, modulation family, and modulation order
   from the service band.
6. Keep the selected occupied bandwidth as the design truth, but raise
   `SamplesPerSymbol` when required so narrowband services still satisfy the
   repository's Tx RF impairment sample-rate floor.
7. Store the absolute selected center frequency in
   `Truth.Design.Regulatory.SelectedCenterFrequencyHz`.
8. Store the receiver-baseband projection in the existing
   `Spectrum.PlannedFreqOffset` and `ReceiverViews` contract.

This preserves the earlier truth split:

- design values come from the blueprint,
- execution values come from construction/channel blocks,
- measured values come from receiver-side IQ measurement.

## Region Rollout

Phase 8.0 implements the framework, schema validation, and selector tests.

Phase 8.1 implements China Tier 1. The first tier covers AM/FM broadcast,
DTMB-like terrestrial television approximation, public mobile LTE/NR-style
services, 2.4/5 GHz WLAN/ISM/SRD, land mobile, and short-range devices.

Phase 8.2-8.5 add the same Tier 1 service categories for the United States,
Europe/CEPT, Japan, and Korea.

Phase 8.6 expands to Tier 2 services: satellite communications, amateur,
fixed microwave, maritime and aeronautical communications, LPWAN, and
GNSS-like communication/navigation signal visibility. Radar remains excluded.

## Evidence Levels

- `OfficialAllocation`: frequency range and service are taken from a
  regulator or allocation table.
- `StandardMapping`: modulation or bandwidth comes from a public standard
  or common standard family.
- `EngineeringApproximation`: repository-level waveform approximation used
  because the full protocol stack is out of scope.

Entries may carry multiple evidence levels in notes, but the scalar
`EvidenceLevel` field records the weakest link used for simulation.

## Exit Criteria

- Region catalogs for CN, US, EU, JP, and KR load and validate.
- Fixed-seed selector output is deterministic.
- Analog broadcast bands do not select digital modulation families.
- LTE/NR-like bands select OFDM/QAM approximations only.
- Selected center frequency and bandwidth stay inside both the regional
  service band and the receiver monitoring window.
- Annotation v2 carries `Truth.Design.Regulatory` for generated sources.
- `run_all_tests('phase8')` passes.

## 2026-04-28 Validation Note

Phase 4 measured-truth coverage exposed one Phase 8 integration defect before
final closure: the CN 2.4 GHz ISM catalog can select `OQPSK`, and the
regulatory blueprint supplied `RolloffFactor` without the pulse-shaping fields
that the OQPSK modulator expects. The first fix is to make the modulation
factory fill deterministic OQPSK pulse-shaping defaults (`span`,
`SymbolMapping`, and `PhaseOffset`) when a scenario provides only the
service-level modulation family and bandwidth. The same test also exposed an
older OQPSK class defect: its internal modulator handle was not declared and
the OQPSK base method recursively called itself. That class now owns the handle
explicitly and calls it directly. A Phase 8 unit runs this OQPSK path through
`ModulationFactory` so future catalog changes cannot silently reintroduce the
same failure.

The unified service sweep then exposed two broader integration issues. First,
OFDM-like regulatory services were reaching the old random OFDM defaults, whose
200/400 Hz subcarrier spacing produced waveform sample rates too low for RF
frequency translation. Regulatory OFDM now carries an explicit executable OFDM
configuration derived from the selected bandwidth. Second, `TransmitFactory`
could log RF front-end failures but return a sentinel signal, allowing
`SimulationRunner` to count the scenario as successful. The Tx front-end now
rethrows step failures so a broken waveform cannot produce a normal-looking
annotation.

The Phase 4 measured-truth rerun exposed one additional configuration merge
defect: a nested QAM `ModulatorConfig` containing only `beta` could overwrite
the deterministic pulse-shaping defaults after they had already been derived.
`ModulationFactory` now adapts nested `ModulatorConfig` values through the same
defaulting path as top-level modulation fields, then merges them without
raw-overwriting `span` or symbol ordering.

## 2026-04-29 Review Hardening

Code review exposed one release-packaging issue: the default scenario factory
enables `CommunicationBehavior.Regulatory.Enable = true`, but the spectrum
catalog package and regulatory allocation helper were still untracked in the
working tree. That makes a clean checkout fail during
`initializeScenarioConfigurations` before any transmitter or receiver blueprint
is built.

The Phase 8 closure rule is therefore tightened:

- `+csrd/+catalog/+spectrum/{RegionSpectrumCatalog,RegionSpectrumSelector,RegulatoryValidator}.m`
  is part of the mandatory runtime surface, not optional research data.
- `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesFromRegulatoryPlan.m`
  is part of the mandatory scenario allocation surface.
- The Phase 8 unit and regression tests are the packaging guard: a clean diff
  must include the catalog package, the allocation helper, and the curated tests
  that exercise the default regulatory path.

No default configuration may enable regulatory planning unless those files are
present in the patch.
