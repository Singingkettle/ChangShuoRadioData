classdef RegionSpectrumSelector
    %REGIONSPECTRUMSELECTOR Deterministic-region, stochastic-service selector.

    methods (Static)
        function tf = isEnabled(config)
            tf = isstruct(config) && isfield(config, 'Regulatory') ...
                && isstruct(config.Regulatory) ...
                && isfield(config.Regulatory, 'Enable') ...
                && isequal(config.Regulatory.Enable, true);
        end

        function plan = selectScenarioPlan(config, receiverConfig, numTransmitters)
            regulatory = normalizeRegulatoryConfig(config);
            catalog = csrd.utils.spectrum.RegionSpectrumCatalog.load(regulatory.RegionId);
            bands = filterBands(catalog.Bands, regulatory);
            if isempty(bands)
                error('CSRD:Spectrum:NoCandidateBands', ...
                    'No regulatory bands remain for region %s tier %s.', ...
                    regulatory.RegionId, regulatory.ServiceTier);
            end

            sampleRateHz = resolveSampleRate(receiverConfig);
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
end


function tf = isLogicalScalar(value)
tf = (islogical(value) || isnumeric(value)) && isscalar(value) && ...
    isfinite(double(value));
end


function sampleRateHz = resolveSampleRate(receiverConfig)
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


function rank = tierRank(tier)
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
if isfield(regulatory.MonitoringBand, 'CenterFrequencyHz') && ...
        isnumeric(regulatory.MonitoringBand.CenterFrequencyHz) && ...
        isscalar(regulatory.MonitoringBand.CenterFrequencyHz) && ...
        isfinite(regulatory.MonitoringBand.CenterFrequencyHz)
    centerHz = regulatory.MonitoringBand.CenterFrequencyHz;
    return;
end

window = anchor.FrequencyRangeHz;
if diff(window) <= sampleRateHz
    centerHz = mean(window);
    return;
end

margin = sampleRateHz / 2;
centerMin = window(1) + margin;
centerMax = window(2) - margin;
if centerMin >= centerMax
    centerHz = mean(window);
else
    centerHz = centerMin + rand() * (centerMax - centerMin);
end
end


function bands = filterBandsForReceiverWindow(allBands, receiverPlan, regulatory)
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
    bwChoices = usableBandwidths(b, receiverPlan.SampleRateHz, regulatory);
    if isempty(bwChoices)
        continue;
    end
    minBw = min(bwChoices);
    low = max(b.FrequencyRangeHz(1) + minBw / 2, rxWindow(1) + minBw / 2);
    high = min(b.FrequencyRangeHz(2) - minBw / 2, rxWindow(2) - minBw / 2);
    keep(k) = low <= high;
end
bands = allBands(keep);
end


function plan = selectEmitterPlan(band, receiverPlan, catalog, regulatory)
bwChoices = usableBandwidths(band, receiverPlan.SampleRateHz, regulatory);
if isempty(bwChoices)
    error('CSRD:Spectrum:NoUsableBandwidth', ...
        'Band %s has no bandwidth that fits receiver sample rate %.0f Hz.', ...
        band.BandId, receiverPlan.SampleRateHz);
end
bw = bwChoices(randi(numel(bwChoices)));
centerHz = selectCenterInBand(band, bw, receiverPlan);
family = chooseCellValue(band.AllowedModulationFamilies);
order = defaultModulationOrder(family);

regTruth = csrd.utils.spectrum.RegulatoryValidator.emptyRegulatoryTruth();
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
plan.TemporalPattern = band.TemporalPattern;
plan.Regulatory = regTruth;

csrd.utils.spectrum.RegulatoryValidator.validateEmitterPlan(plan, catalog, receiverPlan);
end


function bwChoices = usableBandwidths(band, sampleRateHz, regulatory)
raw = zeros(1, numel(band.RecommendedBandwidthsHz));
for k = 1:numel(band.RecommendedBandwidthsHz)
    raw(k) = double(band.RecommendedBandwidthsHz{k});
end
maxBw = min(diff(band.FrequencyRangeHz), sampleRateHz * regulatory.MaxBandwidthFractionOfSampleRate);
bwChoices = raw(raw > 0 & raw <= maxBw);
end


function centerHz = selectCenterInBand(band, bandwidthHz, receiverPlan)
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
value = values{randi(numel(values))};
end


function order = defaultModulationOrder(family)
family = char(string(family));
switch family
    case {'FM','PM','AM','SSBAM','DSBAM','DSBSCAM','VSBAM'}
        order = 1;
    case {'OOK','GMSK','MSK','OQPSK'}
        order = 2 + 2 * strcmp(family, 'OQPSK');
    case {'FSK','CPFSK','GFSK'}
        choices = [2, 4];
        order = choices(randi(numel(choices)));
    case {'PSK'}
        choices = [2, 4, 8];
        order = choices(randi(numel(choices)));
    case {'QAM','OFDM'}
        choices = [16, 64, 256];
        order = choices(randi(numel(choices)));
    otherwise
        order = 2;
end
end


function p = emptyEmitterPlan()
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
    'TemporalPattern', '', ...
    'Regulatory', csrd.utils.spectrum.RegulatoryValidator.emptyRegulatoryTruth());
end
