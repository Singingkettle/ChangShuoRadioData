classdef RegionSpectrumSelector
    %REGIONSPECTRUMSELECTOR Deterministic-region, stochastic-service selector.

    methods (Static)
        function tf = isEnabled(config)
            % isEnabled - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            tf = isstruct(config) && isfield(config, 'Regulatory') ...
                && isstruct(config.Regulatory) ...
                && isfield(config.Regulatory, 'Enable') ...
                && isequal(config.Regulatory.Enable, true);
        end

        function plan = selectScenarioPlan(config, receiverConfig, numTransmitters)
            % selectScenarioPlan - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            regulatory = normalizeRegulatoryConfig(config);
            regulatory = applyReceiverTuningRange(regulatory, receiverConfig);
            catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(regulatory.RegionId);
            bands = filterBands(catalog.Bands, regulatory);
            if isempty(bands)
                error('CSRD:Spectrum:NoCandidateBands', ...
                    'No regulatory bands remain for region %s tier %s.', ...
                    regulatory.RegionId, regulatory.ServiceTier);
            end

            sampleRateHz = resolveSampleRate(receiverConfig);
            bands = filterBandsByRequiredCarrierRange(bands, sampleRateHz, regulatory);
            if isempty(bands)
                range = regulatory.RequiredCarrierFrequencyRangeHz;
                error('CSRD:Spectrum:NoCarrierCompatibleBands', ...
                    ['No regulatory bands in region %s tier %s can place ', ...
                    'the receiver carrier in [%.0f, %.0f] Hz for the current channel model.'], ...
                    regulatory.RegionId, regulatory.ServiceTier, range(1), range(2));
            end

            anchor = selectMonitoringAnchor(bands, regulatory);
            monitoringCenterHz = selectMonitoringCenter(anchor, sampleRateHz, regulatory);
            receiverPlan = struct( ...
                'RegionId', regulatory.RegionId, ...
                'CenterFrequencyHz', monitoringCenterHz, ...
                'SampleRateHz', sampleRateHz, ...
                'ObservableRangeHz', [-sampleRateHz / 2, sampleRateHz / 2], ...
                'MonitoringBandId', anchor.BandId, ...
                'MonitoringRangeHz', [monitoringCenterHz - sampleRateHz / 2, ...
                    monitoringCenterHz + sampleRateHz / 2], ...
                'Authority', catalog.Authority);

            emitterPlans = repmat(emptyEmitterPlan(), 0, 1);
            for k = 1:numTransmitters
                candidates = filterBandsForReceiverWindow(bands, receiverPlan, regulatory);
                if isempty(candidates)
                    error('CSRD:Spectrum:NoVisibleServiceBands', ...
                        'No service bands in %s intersect receiver window centered at %.0f Hz.', ...
                        regulatory.RegionId, monitoringCenterHz);
                end
                selectedBand = weightedBandChoice(candidates);
                emitterPlans(end + 1) = selectEmitterPlan(selectedBand, receiverPlan, catalog, regulatory); %#ok<AGROW>
            end

            plan = struct( ...
                'RegionId', regulatory.RegionId, ...
                'RegionName', catalog.RegionName, ...
                'Authority', catalog.Authority, ...
                'ServiceTier', regulatory.ServiceTier, ...
                'Catalog', catalog, ...
                'Receiver', receiverPlan, ...
                'EmitterPlans', emitterPlans);
        end
    end
end


function regulatory = normalizeRegulatoryConfig(config)
    % normalizeRegulatoryConfig - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if ~isfield(config, 'Regulatory') || ~isstruct(config.Regulatory)
    error('CSRD:Spectrum:MissingRegulatoryConfig', ...
        'CommunicationBehavior.Regulatory must be configured when regulatory planning is enabled.');
end
raw = config.Regulatory;

regulatory = struct();
regulatory.Enable = true;
regulatory.RegionId = 'CN';
if isfield(raw, 'Region') && isstruct(raw.Region)
    region = raw.Region;
    if isfield(region, 'Fixed') && ~isempty(region.Fixed)
        regulatory.RegionId = upper(char(string(region.Fixed)));
    elseif isfield(region, 'RegionId') && ~isempty(region.RegionId)
        regulatory.RegionId = upper(char(string(region.RegionId)));
    end
elseif isfield(raw, 'RegionId') && ~isempty(raw.RegionId)
    regulatory.RegionId = upper(char(string(raw.RegionId)));
end

regulatory.ServiceTier = 'Tier1';
if isfield(raw, 'ServiceTier') && ~isempty(raw.ServiceTier)
    regulatory.ServiceTier = char(string(raw.ServiceTier));
end

regulatory.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
if isfield(raw, 'ExcludedServiceClasses') && ~isempty(raw.ExcludedServiceClasses)
    regulatory.ExcludedServiceClasses = raw.ExcludedServiceClasses;
end

regulatory.MonitoringBand = struct();
if isfield(raw, 'MonitoringBand') && isstruct(raw.MonitoringBand)
    regulatory.MonitoringBand = raw.MonitoringBand;
end

regulatory.RequiredCarrierFrequencyRangeHz = [];
if isfield(config, 'Runtime') && isstruct(config.Runtime) && ...
        isfield(config.Runtime, 'RequiredCarrierFrequencyRangeHz') && ...
        ~isempty(config.Runtime.RequiredCarrierFrequencyRangeHz)
    range = double(config.Runtime.RequiredCarrierFrequencyRangeHz);
    if ~isnumeric(range) || numel(range) ~= 2 || ...
            any(~isfinite(range)) || any(range <= 0) || range(1) >= range(2)
        error('CSRD:Spectrum:InvalidRequiredCarrierRange', ...
            'Runtime.RequiredCarrierFrequencyRangeHz must be [min max] positive finite Hz.');
    end
    regulatory.RequiredCarrierFrequencyRangeHz = reshape(range, 1, 2);
end

regulatory.RestrictEmittersToMonitoringBand = isfield(regulatory.MonitoringBand, 'FixedBandId') ...
    && ~isempty(regulatory.MonitoringBand.FixedBandId);
if isfield(regulatory.MonitoringBand, 'RestrictEmittersToFixedBand') && ...
        isLogicalScalar(regulatory.MonitoringBand.RestrictEmittersToFixedBand)
    regulatory.RestrictEmittersToMonitoringBand = ...
        logical(regulatory.MonitoringBand.RestrictEmittersToFixedBand);
elseif isfield(regulatory.MonitoringBand, 'AllowIntersectingServices') && ...
        isLogicalScalar(regulatory.MonitoringBand.AllowIntersectingServices)
    regulatory.RestrictEmittersToMonitoringBand = ...
        ~logical(regulatory.MonitoringBand.AllowIntersectingServices);
end

regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
if isfield(raw, 'MaxBandwidthFractionOfSampleRate') && ...
        isnumeric(raw.MaxBandwidthFractionOfSampleRate) && ...
        isscalar(raw.MaxBandwidthFractionOfSampleRate) && ...
        raw.MaxBandwidthFractionOfSampleRate > 0 && ...
        raw.MaxBandwidthFractionOfSampleRate <= 1
    regulatory.MaxBandwidthFractionOfSampleRate = raw.MaxBandwidthFractionOfSampleRate;
end

% Optional per-service transmit power overrides (dBm). When absent the
% selector uses realistic per-ServiceClass defaults (broadcast towers high,
% short-range devices low) instead of one flat range for every emitter.
regulatory.ServicePowerDbm = struct();
if isfield(raw, 'ServicePowerDbm') && isstruct(raw.ServicePowerDbm)
    regulatory.ServicePowerDbm = raw.ServicePowerDbm;
end
end


function regulatory = applyReceiverTuningRange(regulatory, receiverConfig)
    % applyReceiverTuningRange - Constrain monitoring center to the SDR tuning range.
    % Inputs: normalized regulatory config, unified receiver config.
    % Outputs: regulatory config whose RequiredCarrierFrequencyRangeHz is
    %   intersected with the receiver SDR tuning range, so a band whose
    %   carrier the radio cannot physically tune to is never selected
    %   (e.g. an RTL-SDR never monitors a 3.5 GHz NR band).
    if ~isstruct(receiverConfig) || ~isfield(receiverConfig, 'Sdr') || ...
            ~isstruct(receiverConfig.Sdr) || ...
            ~isfield(receiverConfig.Sdr, 'TuningRangeHz')
        return;
    end
    tuning = double(receiverConfig.Sdr.TuningRangeHz);
    if numel(tuning) ~= 2 || any(~isfinite(tuning)) || tuning(1) >= tuning(2)
        return;
    end
    tuning = reshape(tuning, 1, 2);
    existing = regulatory.RequiredCarrierFrequencyRangeHz;
    if isempty(existing)
        regulatory.RequiredCarrierFrequencyRangeHz = tuning;
    else
        regulatory.RequiredCarrierFrequencyRangeHz = ...
            [max(existing(1), tuning(1)), min(existing(2), tuning(2))];
    end
end


function tf = isLogicalScalar(value)
    % isLogicalScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
tf = (islogical(value) || isnumeric(value)) && isscalar(value) && ...
    isfinite(double(value));
end


function sampleRateHz = resolveSampleRate(receiverConfig)
    % resolveSampleRate - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
sampleRateHz = 50e6;
if isstruct(receiverConfig) && isfield(receiverConfig, 'SampleRate') ...
        && ~isempty(receiverConfig.SampleRate)
    sampleRateHz = double(receiverConfig.SampleRate);
end
if ~isnumeric(sampleRateHz) || ~isscalar(sampleRateHz) || ...
        ~isfinite(sampleRateHz) || sampleRateHz <= 0
    error('CSRD:Spectrum:InvalidReceiverSampleRate', ...
        'Receiver sample rate must be a positive scalar Hz.');
end
end


function bands = filterBands(allBands, regulatory)
    % filterBands - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
keep = false(size(allBands));
for k = 1:numel(allBands)
    b = allBands(k);
    if tierRank(b.ServiceTier) > tierRank(regulatory.ServiceTier)
        continue;
    end
    if any(strcmpi(b.ServiceClass, regulatory.ExcludedServiceClasses))
        continue;
    end
    keep(k) = true;
end
bands = allBands(keep);
end


function bands = filterBandsByRequiredCarrierRange(bands, sampleRateHz, regulatory)
    % filterBandsByRequiredCarrierRange - Apply channel-model carrier support.
    % Inputs: regulatory bands, receiver sample rate, runtime range.
    % Outputs: bands that can place the receiver center in range.
if isempty(regulatory.RequiredCarrierFrequencyRangeHz)
    return;
end

keep = false(size(bands));
for k = 1:numel(bands)
    [centerMin, centerMax] = monitoringCenterBounds(bands(k), sampleRateHz, regulatory);
    supportedRange = regulatory.RequiredCarrierFrequencyRangeHz;
    keep(k) = max(centerMin, supportedRange(1)) <= min(centerMax, supportedRange(2));
end

if isfield(regulatory.MonitoringBand, 'FixedBandId') && ...
        ~isempty(regulatory.MonitoringBand.FixedBandId)
    fixedId = char(string(regulatory.MonitoringBand.FixedBandId));
    fixedIdx = find(strcmpi({bands.BandId}, fixedId), 1, 'first');
    if ~isempty(fixedIdx) && ~keep(fixedIdx)
        supportedRange = regulatory.RequiredCarrierFrequencyRangeHz;
        error('CSRD:Spectrum:MonitoringBandCarrierUnsupported', ...
            ['Fixed monitoring BandId "%s" cannot place receiver carrier ', ...
            'in [%.0f, %.0f] Hz required by the current channel model.'], ...
            fixedId, supportedRange(1), supportedRange(2));
    end
end

bands = bands(keep);
end


function rank = tierRank(tier)
    % tierRank - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
tier = lower(char(string(tier)));
switch tier
    case 'tier1'
        rank = 1;
    case 'tier2'
        rank = 2;
    otherwise
        rank = 99;
end
end


function anchor = selectMonitoringAnchor(bands, regulatory)
    % selectMonitoringAnchor - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if isfield(regulatory.MonitoringBand, 'FixedBandId') && ...
        ~isempty(regulatory.MonitoringBand.FixedBandId)
    fixedId = char(string(regulatory.MonitoringBand.FixedBandId));
    idx = find(strcmp({bands.BandId}, fixedId), 1, 'first');
    if isempty(idx)
        error('CSRD:Spectrum:MonitoringBandNotFound', ...
            'Fixed monitoring BandId "%s" is not available after filtering.', fixedId);
    end
    anchor = bands(idx);
    return;
end
anchor = weightedBandChoice(bands);
end


function centerHz = selectMonitoringCenter(anchor, sampleRateHz, regulatory)
    % selectMonitoringCenter - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if isfield(regulatory.MonitoringBand, 'CenterFrequencyHz') && ...
        isnumeric(regulatory.MonitoringBand.CenterFrequencyHz) && ...
        isscalar(regulatory.MonitoringBand.CenterFrequencyHz) && ...
        isfinite(regulatory.MonitoringBand.CenterFrequencyHz)
    centerHz = regulatory.MonitoringBand.CenterFrequencyHz;
    if ~isempty(regulatory.RequiredCarrierFrequencyRangeHz)
        supportedRange = regulatory.RequiredCarrierFrequencyRangeHz;
        if centerHz < supportedRange(1) || centerHz > supportedRange(2)
            error('CSRD:Spectrum:MonitoringCarrierUnsupported', ...
                ['MonitoringBand.CenterFrequencyHz %.0f is outside ', ...
                '[%.0f, %.0f] Hz required by the current channel model.'], ...
                centerHz, supportedRange(1), supportedRange(2));
        end
    end
    return;
end

[centerMin, centerMax] = monitoringCenterBounds(anchor, sampleRateHz, regulatory);
if ~isempty(regulatory.RequiredCarrierFrequencyRangeHz)
    supportedRange = regulatory.RequiredCarrierFrequencyRangeHz;
    centerMin = max(centerMin, supportedRange(1));
    centerMax = min(centerMax, supportedRange(2));
end

if centerMin > centerMax
    supportedText = 'unrestricted';
    if ~isempty(regulatory.RequiredCarrierFrequencyRangeHz)
        supportedText = sprintf('[%.0f, %.0f] Hz', ...
            regulatory.RequiredCarrierFrequencyRangeHz(1), ...
            regulatory.RequiredCarrierFrequencyRangeHz(2));
    end
    error('CSRD:Spectrum:NoMonitoringCarrier', ...
        'Band %s cannot place a monitoring carrier for sample rate %.0f Hz and support %s.', ...
        anchor.BandId, sampleRateHz, supportedText);
end

preferredCenterHz = mean(anchor.FrequencyRangeHz);
if centerMin == centerMax
    centerHz = centerMin;
elseif diff(anchor.FrequencyRangeHz) <= sampleRateHz
    centerHz = min(max(preferredCenterHz, centerMin), centerMax);
else
    centerHz = centerMin + rand() * (centerMax - centerMin);
end

centerHz = ensurePlaceableMonitoringCenter(centerHz, centerMin, centerMax, ...
    anchor, sampleRateHz, regulatory);
end


function centerHz = ensurePlaceableMonitoringCenter(centerHz, centerMin, ...
        centerMax, anchor, sampleRateHz, regulatory)
    % ensurePlaceableMonitoringCenter - Snap the center so an emitter fits.
    % A narrow receiver window over a coarse channel raster can leave the
    % random monitoring center with no raster-aligned channel inside it, which
    % later fails emitter placement (CSRD:Spectrum:NoVisibleServiceBands). When
    % that happens, snap the center to the nearest channel grid point (within
    % the allowed center range) whose channel does fit the window.
bws = usableBandwidths(anchor, sampleRateHz, regulatory);
if isempty(bws)
    return;  % nothing usable; selectEmitterPlan raises a precise error
end
if localCenterIsPlaceable(centerHz, anchor, sampleRateHz, bws)
    return;  % common case: the chosen center already admits a channel
end
candidates = localChannelGrid(anchor, centerMin, centerMax);
best = [];
bestDist = inf;
for c = candidates
    if localCenterIsPlaceable(c, anchor, sampleRateHz, bws) && ...
            abs(c - centerHz) < bestDist
        best = c;
        bestDist = abs(c - centerHz);
    end
end
if ~isempty(best)
    centerHz = best;
end
end


function tf = localCenterIsPlaceable(centerHz, anchor, sampleRateHz, bws)
    % localCenterIsPlaceable - True when some usable channel fits the window.
rp = struct('MonitoringRangeHz', ...
    [centerHz - sampleRateHz / 2, centerHz + sampleRateHz / 2], ...
    'SampleRateHz', sampleRateHz);
tf = false;
for k = 1:numel(bws)
    if canPlaceBandwidthInReceiverWindow(anchor, bws(k), rp)
        tf = true;
        return;
    end
end
end


function centers = localChannelGrid(anchor, lo, hi)
    % localChannelGrid - Channel-center candidates within [lo, hi].
if ~isempty(anchor.ExplicitChannelCentersHz)
    centers = anchor.ExplicitChannelCentersHz(:)';
    centers = centers(centers >= lo & centers <= hi);
    return;
end
if anchor.ChannelRasterHz > 0
    ref = anchor.FrequencyRangeHz(1);
    kMin = ceil((lo - ref) / anchor.ChannelRasterHz);
    kMax = floor((hi - ref) / anchor.ChannelRasterHz);
    centers = ref + (kMin:kMax) * anchor.ChannelRasterHz;
    return;
end
centers = [];  % continuous placement; no snapping needed
end


function [centerMin, centerMax] = monitoringCenterBounds(anchor, sampleRateHz, regulatory)
    % monitoringCenterBounds - Receiver center bounds that cover the band.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    %#ok<INUSD> regulatory is kept for signature symmetry with callers.
window = double(anchor.FrequencyRangeHz);
if diff(window) <= sampleRateHz
    halfSpan = sampleRateHz / 2;
    centerMin = window(2) - halfSpan;
    centerMax = window(1) + halfSpan;
    if centerMin > centerMax
        centerMin = mean(window);
        centerMax = centerMin;
    end
    return;
end

margin = sampleRateHz / 2;
centerMin = window(1) + margin;
centerMax = window(2) - margin;
end


function bands = filterBandsForReceiverWindow(allBands, receiverPlan, regulatory)
    % filterBandsForReceiverWindow - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
rxWindow = receiverPlan.MonitoringRangeHz;
keep = false(size(allBands));
restrictToBand = regulatory.RestrictEmittersToMonitoringBand && ...
    isfield(regulatory.MonitoringBand, 'FixedBandId') && ...
    ~isempty(regulatory.MonitoringBand.FixedBandId);
if restrictToBand
    fixedId = char(string(regulatory.MonitoringBand.FixedBandId));
end
for k = 1:numel(allBands)
    b = allBands(k);
    if restrictToBand && ~strcmpi(b.BandId, fixedId)
        continue;
    end
    bwChoices = usableBandwidthsForReceiverWindow(b, receiverPlan, regulatory);
    keep(k) = ~isempty(bwChoices);
end
bands = allBands(keep);
end


function plan = selectEmitterPlan(band, receiverPlan, catalog, regulatory)
    % selectEmitterPlan - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
bwChoices = usableBandwidthsForReceiverWindow(band, receiverPlan, regulatory);
if isempty(bwChoices)
    error('CSRD:Spectrum:NoUsableBandwidth', ...
        ['Band %s has no bandwidth/channel center that fits receiver ', ...
        'sample rate %.0f Hz and monitoring window.'], ...
        band.BandId, receiverPlan.SampleRateHz);
end
bw = bwChoices(randi(numel(bwChoices)));
centerHz = selectCenterInBand(band, bw, receiverPlan);
family = chooseCellValue(band.AllowedModulationFamilies);
order = selectModulationOrder(family, bw);
powerRange = servicePowerRangeDbm(band.ServiceClass, regulatory);

regTruth = csrd.catalog.spectrum.RegulatoryValidator.emptyRegulatoryTruth();
regTruth.RegionId = catalog.RegionId;
regTruth.Authority = catalog.Authority;
regTruth.BandId = band.BandId;
regTruth.ServiceClass = band.ServiceClass;
regTruth.Application = band.Application;
regTruth.AllocationStatus = band.AllocationStatus;
regTruth.SourceRefs = band.SourceRefs;
regTruth.EvidenceLevel = band.EvidenceLevel;
regTruth.ChannelRasterHz = band.ChannelRasterHz;
regTruth.SelectedCenterFrequencyHz = centerHz;
regTruth.AllowedBandwidthHz = bw;
regTruth.AllowedModulationFamilies = band.AllowedModulationFamilies;

plan = emptyEmitterPlan();
plan.RegionId = catalog.RegionId;
plan.BandId = band.BandId;
plan.ServiceClass = band.ServiceClass;
plan.Application = band.Application;
plan.SelectedCenterFrequencyHz = centerHz;
plan.CenterOffsetHz = centerHz - receiverPlan.CenterFrequencyHz;
plan.BandwidthHz = bw;
plan.ModulationFamily = family;
plan.ModulationOrder = order;
plan.PowerDbmRange = powerRange;
plan.TemporalPattern = band.TemporalPattern;
plan.Regulatory = regTruth;

csrd.catalog.spectrum.RegulatoryValidator.validateEmitterPlan(plan, catalog, receiverPlan);
end


function bwChoices = usableBandwidths(band, sampleRateHz, regulatory)
    % usableBandwidths - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
raw = zeros(1, numel(band.RecommendedBandwidthsHz));
for k = 1:numel(band.RecommendedBandwidthsHz)
    raw(k) = double(band.RecommendedBandwidthsHz{k});
end
maxBw = min(diff(band.FrequencyRangeHz), sampleRateHz * regulatory.MaxBandwidthFractionOfSampleRate);
bwChoices = raw(raw > 0 & raw <= maxBw);
end


function bwChoices = usableBandwidthsForReceiverWindow(band, receiverPlan, regulatory)
    % usableBandwidthsForReceiverWindow - Candidate bandwidths that can be placed.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
raw = usableBandwidths(band, receiverPlan.SampleRateHz, regulatory);
keep = false(size(raw));
for k = 1:numel(raw)
    keep(k) = canPlaceBandwidthInReceiverWindow(band, raw(k), receiverPlan);
end
bwChoices = raw(keep);
end


function tf = canPlaceBandwidthInReceiverWindow(band, bandwidthHz, receiverPlan)
    % canPlaceBandwidthInReceiverWindow - Validate center feasibility.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rxWindow = receiverPlan.MonitoringRangeHz;
centerMin = max(band.FrequencyRangeHz(1) + bandwidthHz / 2, ...
    rxWindow(1) + bandwidthHz / 2);
centerMax = min(band.FrequencyRangeHz(2) - bandwidthHz / 2, ...
    rxWindow(2) - bandwidthHz / 2);
if centerMin > centerMax
    tf = false;
    return;
end

if ~isempty(band.ExplicitChannelCentersHz)
    centers = band.ExplicitChannelCentersHz(:)';
    tf = any(centers >= centerMin & centers <= centerMax);
    return;
end

if band.ChannelRasterHz > 0
    ref = band.FrequencyRangeHz(1);
    kMin = ceil((centerMin - ref) / band.ChannelRasterHz);
    kMax = floor((centerMax - ref) / band.ChannelRasterHz);
    tf = kMin <= kMax;
    return;
end

tf = true;
end


function centerHz = selectCenterInBand(band, bandwidthHz, receiverPlan)
    % selectCenterInBand - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
rxWindow = receiverPlan.MonitoringRangeHz;
centerMin = max(band.FrequencyRangeHz(1) + bandwidthHz / 2, rxWindow(1) + bandwidthHz / 2);
centerMax = min(band.FrequencyRangeHz(2) - bandwidthHz / 2, rxWindow(2) - bandwidthHz / 2);
if centerMin > centerMax
    error('CSRD:Spectrum:NoUsableChannel', ...
        'Band %s cannot fit bandwidth %.0f Hz in receiver window.', ...
        band.BandId, bandwidthHz);
end

if ~isempty(band.ExplicitChannelCentersHz)
    centers = band.ExplicitChannelCentersHz(:)';
    centers = centers(centers >= centerMin & centers <= centerMax);
    if isempty(centers)
        error('CSRD:Spectrum:NoUsableChannel', ...
            'Band %s has no explicit channel center in receiver window.', band.BandId);
    end
    centerHz = centers(randi(numel(centers)));
    return;
end

if band.ChannelRasterHz > 0
    ref = band.FrequencyRangeHz(1);
    kMin = ceil((centerMin - ref) / band.ChannelRasterHz);
    kMax = floor((centerMax - ref) / band.ChannelRasterHz);
    if kMin > kMax
        error('CSRD:Spectrum:NoUsableChannel', ...
            'Band %s has no raster-aligned center in receiver window.', band.BandId);
    end
    centerHz = ref + randi([kMin, kMax]) * band.ChannelRasterHz;
else
    centerHz = centerMin + rand() * (centerMax - centerMin);
end
end


function band = weightedBandChoice(bands)
    % weightedBandChoice - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
weights = [bands.PriorityWeight];
weights(~isfinite(weights) | weights < 0) = 0;
if all(weights == 0)
    weights = ones(size(weights));
end
weights = weights / sum(weights);
cum = cumsum(weights);
idx = find(rand() <= cum, 1, 'first');
if isempty(idx)
    idx = numel(bands);
end
band = bands(idx);
end


function value = chooseCellValue(values)
    % chooseCellValue - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
value = values{randi(numel(values))};
end


function order = selectModulationOrder(family, bandwidthHz)
    % selectModulationOrder - Pick a modulation order feasible for the channel.
    % Inputs: modulation family, allocated channel bandwidth (Hz).
    % Outputs: a modulation order from the family-specific choices, capped so
    %   that narrow channels do not carry implausibly high constellations.
    %
    % High-order QAM/PSK need both spectral room and high SNR. A narrowband
    % land-mobile or SRD channel (a few tens of kHz) physically would not run
    % 256-QAM, so the upper order is gated by the allocated bandwidth using a
    % coarse, documented bandwidth->max-order ladder. The order is still drawn
    % from the family choices via the scenario RNG so runs stay reproducible.
family = char(string(family));
switch family
    case {'FM','PM','AM','SSBAM','DSBAM','DSBSCAM','VSBAM'}
        order = 1;
        return;
    case {'OOK','GMSK','MSK','OQPSK'}
        order = 2 + 2 * strcmp(family, 'OQPSK');
        return;
    case {'FSK','CPFSK','GFSK'}
        choices = [2, 4];
    case {'PSK'}
        choices = [2, 4, 8];
    case {'QAM','OFDM'}
        choices = [16, 64, 256];
    otherwise
        order = 2;
        return;
end
maxOrder = maxModulationOrderForBandwidth(bandwidthHz);
feasible = choices(choices <= maxOrder);
if isempty(feasible)
    feasible = min(choices); % never drop below the family minimum
end
order = feasible(randi(numel(feasible)));
end


function maxOrder = maxModulationOrderForBandwidth(bandwidthHz)
    % maxModulationOrderForBandwidth - Coarse bandwidth -> max-order ladder.
    % Inputs: allocated channel bandwidth in Hz.
    % Outputs: the highest modulation order considered realistic for that
    %   bandwidth. Thresholds are engineering approximations: very narrow
    %   voice/data channels stay low order; only wideband channels admit the
    %   densest constellations.
bw = double(bandwidthHz);
if ~isfinite(bw) || bw <= 0
    maxOrder = 4;
elseif bw < 50e3        % narrowband voice/data (<50 kHz)
    maxOrder = 4;
elseif bw < 200e3       % land-mobile / narrowband data
    maxOrder = 16;
elseif bw < 1e6         % wide channels
    maxOrder = 64;
else                    % broadband (>= 1 MHz)
    maxOrder = 256;
end
end


function range = servicePowerRangeDbm(serviceClass, regulatory)
    % servicePowerRangeDbm - Transmit power range (dBm) for a service class.
    % Inputs: catalog ServiceClass string, normalized regulatory config.
    % Outputs: [minDbm maxDbm] range that the planner samples from.
    %
    % Real emitters span a wide power range by role: broadcast towers radiate
    % far more than handheld land-mobile radios or short-range devices. A
    % single flat range for every emitter is unrealistic, so power is keyed to
    % the service class. Defaults can be overridden per class through
    % config.Regulatory.ServicePowerDbm.<ServiceClass> = [min max].
name = char(string(serviceClass));
if isfield(regulatory, 'ServicePowerDbm') && ...
        isstruct(regulatory.ServicePowerDbm) && ...
        isfield(regulatory.ServicePowerDbm, name)
    override = double(regulatory.ServicePowerDbm.(name));
    if isnumeric(override) && numel(override) == 2 && ...
            all(isfinite(override)) && override(1) <= override(2)
        range = reshape(override, 1, 2);
        return;
    end
end
switch name
    case 'Broadcast'
        range = [43, 60];   % FM/AM/TV transmitters (kW-class EIRP)
    case 'Mobile'
        range = [37, 49];   % cellular base-station downlink
    case 'LandMobile'
        range = [27, 40];   % mobile/handheld trunking radios
    case 'Aeronautical'
        range = [30, 44];   % airborne sets to ground stations (VHF AM)
    case 'Maritime'
        range = [27, 44];   % handheld 5 W to ship/coast 25 W (VHF FM)
    case 'ISM'
        range = [13, 30];   % WLAN/Bluetooth/ISM
    case 'ShortRangeDevice'
        range = [0, 14];    % SRD / LPWAN
    otherwise
        range = [10, 30];   % conservative legacy fallback
end
end


function p = emptyEmitterPlan()
    % emptyEmitterPlan - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
p = struct( ...
    'RegionId', '', ...
    'BandId', '', ...
    'ServiceClass', '', ...
    'Application', '', ...
    'SelectedCenterFrequencyHz', NaN, ...
    'CenterOffsetHz', NaN, ...
    'BandwidthHz', NaN, ...
    'ModulationFamily', '', ...
    'ModulationOrder', NaN, ...
    'PowerDbmRange', [NaN NaN], ...
    'TemporalPattern', '', ...
    'Regulatory', csrd.catalog.spectrum.RegulatoryValidator.emptyRegulatoryTruth());
end
