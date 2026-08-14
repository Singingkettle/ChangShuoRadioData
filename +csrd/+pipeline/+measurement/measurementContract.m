function contract = measurementContract()
%MEASUREMENTCONTRACT What the measured labels in this annotation mean.
%
%   contract = csrd.pipeline.measurement.measurementContract()
%
%   Stamped once per annotation under `Header.Runtime.MeasurementContract`, so a
%   consumer can establish which QUANTITY the measured fields hold, produced by
%   WHICH estimator, at WHICH point in the pipeline, by reading one place -- rather
%   than inferring it from a per-source field, or worse, from the field's name.
%
%   WHY A VERSIONED CONTRACT
%   `OccupiedBandwidthHz` previously held a peak-relative (-3 dBc) main-lobe width
%   measured on a NOISY, antenna-summed buffer. That is a different quantity from
%   the ITU-R SM.328 occupied bandwidth the name promises -- ITU-R SM.443 needs
%   x ~ 26 dB before an x-dB-down width approximates one, and at x = 3 dB the result
%   is roughly the baud rate, independent of pulse roll-off. Data from before and
%   after that fix are therefore NOT comparable, and nothing in the annotation said
%   so: the field name was identical in both eras. `ContractVersion` is the marker
%   that makes the two eras distinguishable without having to know the provenance of
%   a file. Version 1 is retroactively the pre-fix era; no file carries it, because
%   the marker did not exist then -- an ABSENT MeasurementContract is exactly what
%   identifies version 1 data.
%
%   Bump `ContractVersion` whenever the published quantity, the measurement point,
%   or the estimator changes in a way that makes new data incomparable with old.
%   Do NOT bump it for a bug fix that brings the measurement CLOSER to the same
%   stated definition -- that is what the definition string is for.
%
%   Outputs:
%     contract - struct with:
%       .ContractVersion        - integer, bumped on an incomparable change
%       .BandwidthDefinition    - the quantity, from bandwidthDefinitionString
%       .BandwidthEstimator     - fully qualified function that computes it
%       .BandwidthMeasurePoint  - where in the pipeline the buffer was taken
%       .NoiseFreeMeasurement   - logical, whether the buffers carry no noise
%       .PerEmitterPerAntenna   - logical, whether emitters/antennas are separated
%
%   See also: csrd.pipeline.measurement.bandwidthDefinitionString
%             csrd.pipeline.measurement.occupiedBandwidthCore

contract = struct();
contract.ContractVersion = 2;
contract.BandwidthDefinition = ...
    csrd.pipeline.measurement.bandwidthDefinitionString(99);
contract.BandwidthEstimator = ...
    'csrd.pipeline.measurement.occupiedBandwidthCore';

% The three properties that make the labels usable, stated rather than implied.
% Each was false in version 1, and each on its own is enough to invalidate a
% power-integral bandwidth: noise contributes power across the whole band, and
% summing independently faded antenna copies reports the interference pattern
% between the copies rather than a bandwidth any transmitter emitted.
contract.BandwidthMeasurePoint = 'post_channel_pre_noise_per_emitter_per_antenna';
contract.NoiseFreeMeasurement = true;
contract.PerEmitterPerAntenna = true;
end
