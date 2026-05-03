classdef RegulatoryValidator
    %REGULATORYVALIDATOR Validate regional spectrum catalogs and selections.
    % 中文说明：提供 CSRD 生产链路中的 RegulatoryValidator 实现。

    methods (Static)
        function validateCatalog(catalog, varargin)
            % validateCatalog - Production declaration in CSRD.
            % 中文说明：validateCatalog 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            opts = parseOptions(varargin{:});
            requireScalarStruct(catalog, 'catalog');
            requiredCatalog = {'RegionId', 'RegionName', 'Authority', 'SourceRefs', 'Bands'};
            requireFields(catalog, requiredCatalog, 'catalog');
            requireText(catalog.RegionId, 'catalog.RegionId');
            requireText(catalog.RegionName, 'catalog.RegionName');
            requireText(catalog.Authority, 'catalog.Authority');
            requireNonemptyCellstr(catalog.SourceRefs, 'catalog.SourceRefs');

            if ~isstruct(catalog.Bands) || isempty(catalog.Bands)
                error('CSRD:Spectrum:InvalidCatalog', ...
                    'catalog.Bands must be a non-empty struct array.');
            end
            for k = 1:numel(catalog.Bands)
                csrd.catalog.spectrum.RegulatoryValidator.validateBand( ...
                    catalog.Bands(k), ...
                    'ExcludedServiceClasses', opts.ExcludedServiceClasses);
            end
        end

        function validateBand(band, varargin)
            % validateBand - Production declaration in CSRD.
            % 中文说明：validateBand 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            opts = parseOptions(varargin{:});
            requireScalarStruct(band, 'band');
            required = {'RegionId', 'BandId', 'ServiceTier', 'FrequencyRangeHz', ...
                'ServiceClass', 'Application', 'AllocationStatus', 'DuplexMode', ...
                'ChannelRasterHz', 'ExplicitChannelCentersHz', ...
                'RecommendedBandwidthsHz', 'AllowedModulationFamilies', ...
                'TemporalPattern', 'PriorityWeight', 'SourceRefs', 'EvidenceLevel'};
            requireFields(band, required, 'band');
            requireText(band.RegionId, 'band.RegionId');
            requireText(band.BandId, 'band.BandId');
            requireText(band.ServiceTier, 'band.ServiceTier');
            requireText(band.ServiceClass, 'band.ServiceClass');
            requireText(band.Application, 'band.Application');
            requireText(band.EvidenceLevel, 'band.EvidenceLevel');
            requireNonemptyCellstr(band.SourceRefs, sprintf('%s.SourceRefs', band.BandId));
            requireNonemptyCellstr(band.AllowedModulationFamilies, ...
                sprintf('%s.AllowedModulationFamilies', band.BandId));
            if ~isnumeric(band.FrequencyRangeHz) || numel(band.FrequencyRangeHz) ~= 2 ...
                    || ~all(isfinite(band.FrequencyRangeHz)) ...
                    || band.FrequencyRangeHz(1) >= band.FrequencyRangeHz(2)
                error('CSRD:Spectrum:InvalidBand', ...
                    '%s.FrequencyRangeHz must be [fLow fHigh] with fLow < fHigh.', band.BandId);
            end
            if ~isnumeric(band.ChannelRasterHz) || ~isscalar(band.ChannelRasterHz) ...
                    || ~isfinite(band.ChannelRasterHz) || band.ChannelRasterHz < 0
                error('CSRD:Spectrum:InvalidBand', ...
                    '%s.ChannelRasterHz must be a finite non-negative scalar.', band.BandId);
            end
            if ~iscell(band.RecommendedBandwidthsHz) || isempty(band.RecommendedBandwidthsHz)
                error('CSRD:Spectrum:InvalidBand', ...
                    '%s.RecommendedBandwidthsHz must be a non-empty cell.', band.BandId);
            end
            for k = 1:numel(band.RecommendedBandwidthsHz)
                bw = band.RecommendedBandwidthsHz{k};
                if ~isnumeric(bw) || ~isscalar(bw) || ~isfinite(bw) || bw <= 0
                    error('CSRD:Spectrum:InvalidBand', ...
                        '%s.RecommendedBandwidthsHz{%d} must be a positive scalar.', band.BandId, k);
                end
                if bw > diff(band.FrequencyRangeHz)
                    error('CSRD:Spectrum:InvalidBand', ...
                        '%s bandwidth %.0f Hz exceeds band width %.0f Hz.', ...
                        band.BandId, bw, diff(band.FrequencyRangeHz));
                end
            end
            if ~isempty(band.ExplicitChannelCentersHz)
                centers = band.ExplicitChannelCentersHz(:);
                if ~isnumeric(centers) || any(~isfinite(centers))
                    error('CSRD:Spectrum:InvalidBand', ...
                        '%s.ExplicitChannelCentersHz must be numeric finite.', band.BandId);
                end
                if any(diff(centers) <= 0)
                    error('CSRD:Spectrum:InvalidBand', ...
                        '%s.ExplicitChannelCentersHz must be strictly increasing.', band.BandId);
                end
            end
            if ~ismember(lower(char(string(band.EvidenceLevel))), ...
                    lower({'OfficialAllocation','StandardMapping','EngineeringApproximation'}))
                error('CSRD:Spectrum:InvalidBand', ...
                    '%s.EvidenceLevel "%s" is not supported.', ...
                    band.BandId, char(string(band.EvidenceLevel)));
            end
            if any(strcmpi(char(string(band.ServiceClass)), opts.ExcludedServiceClasses))
                error('CSRD:Spectrum:ExcludedServiceClass', ...
                    '%s uses excluded ServiceClass "%s".', ...
                    band.BandId, char(string(band.ServiceClass)));
            end
            radarTokens = {'radar', 'radiolocation', 'radionavigation'};
            haystack = lower([char(string(band.ServiceClass)) ' ' char(string(band.Application))]);
            for r = 1:numel(radarTokens)
                if contains(haystack, radarTokens{r})
                    error('CSRD:Spectrum:ExcludedServiceClass', ...
                        '%s appears to describe radar/radiolocation service.', band.BandId);
                end
            end
        end

        function validateEmitterPlan(plan, catalog, receiverPlan)
            % validateEmitterPlan - Production declaration in CSRD.
            % 中文说明：validateEmitterPlan 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            requireScalarStruct(plan, 'plan');
            requireFields(plan, {'RegionId', 'BandId', 'SelectedCenterFrequencyHz', ...
                'BandwidthHz', 'ModulationFamily', 'Regulatory'}, 'plan');
            band = findBand(catalog.Bands, plan.BandId);
            if isempty(band)
                error('CSRD:Spectrum:UnknownBand', ...
                    'Selected BandId "%s" is not present in catalog %s.', ...
                    char(string(plan.BandId)), char(string(catalog.RegionId)));
            end
            center = plan.SelectedCenterFrequencyHz;
            bw = plan.BandwidthHz;
            if ~isnumeric(center) || ~isscalar(center) || ~isfinite(center)
                error('CSRD:Spectrum:InvalidSelection', ...
                    '%s selected center must be finite scalar Hz.', plan.BandId);
            end
            if ~isnumeric(bw) || ~isscalar(bw) || ~isfinite(bw) || bw <= 0
                error('CSRD:Spectrum:InvalidSelection', ...
                    '%s selected bandwidth must be positive scalar Hz.', plan.BandId);
            end
            edges = [center - bw / 2, center + bw / 2];
            if edges(1) < band.FrequencyRangeHz(1) - 1 || edges(2) > band.FrequencyRangeHz(2) + 1
                error('CSRD:Spectrum:SelectionOutOfBand', ...
                    '%s selected occupied range [%.0f %.0f] Hz outside band [%.0f %.0f] Hz.', ...
                    plan.BandId, edges(1), edges(2), band.FrequencyRangeHz(1), band.FrequencyRangeHz(2));
            end
            if ~ismember(char(string(plan.ModulationFamily)), band.AllowedModulationFamilies)
                error('CSRD:Spectrum:IllegalModulationForService', ...
                    '%s modulation "%s" is not allowed for band %s.', ...
                    char(string(plan.ModulationFamily)), char(string(plan.ModulationFamily)), plan.BandId);
            end
            if nargin >= 3 && ~isempty(receiverPlan)
                requireFields(receiverPlan, {'CenterFrequencyHz', 'SampleRateHz'}, 'receiverPlan');
                halfWindow = receiverPlan.SampleRateHz / 2;
                offset = center - receiverPlan.CenterFrequencyHz;
                if abs(offset) + bw / 2 > halfWindow + 1
                    error('CSRD:Spectrum:SelectionOutsideReceiverWindow', ...
                        '%s selected offset %.0f Hz with bandwidth %.0f Hz exceeds receiver half-window %.0f Hz.', ...
                        plan.BandId, offset, bw, halfWindow);
                end
            end
        end

        function truth = emptyRegulatoryTruth()
            % emptyRegulatoryTruth - Production declaration in CSRD.
            % 中文说明：emptyRegulatoryTruth 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            truth = struct( ...
                'RegionId', 'UNSPECIFIED', ...
                'Authority', '', ...
                'BandId', '', ...
                'ServiceClass', '', ...
                'Application', '', ...
                'AllocationStatus', '', ...
                'SourceRefs', {{}}, ...
                'EvidenceLevel', 'EngineeringApproximation', ...
                'ChannelRasterHz', NaN, ...
                'SelectedCenterFrequencyHz', NaN, ...
                'AllowedBandwidthHz', NaN, ...
                'AllowedModulationFamilies', {{}});
        end
    end
end


function opts = parseOptions(varargin)
    % parseOptions - Production declaration in CSRD.
    % 中文说明：parseOptions 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
opts.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
if mod(numel(varargin), 2) ~= 0
    error('CSRD:Spectrum:InvalidOptions', 'Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    key = char(string(varargin{k}));
    opts.(key) = varargin{k + 1};
end
end


function requireScalarStruct(value, context)
    % requireScalarStruct - Production declaration in CSRD.
    % 中文说明：requireScalarStruct 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~isstruct(value) || ~isscalar(value)
    error('CSRD:Spectrum:InvalidStruct', '%s must be a scalar struct.', context);
end
end


function requireFields(value, fields, context)
    % requireFields - Production declaration in CSRD.
    % 中文说明：requireFields 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
for k = 1:numel(fields)
    if ~isfield(value, fields{k})
        error('CSRD:Spectrum:MissingField', ...
            '%s missing required field "%s".', context, fields{k});
    end
end
end


function requireText(value, context)
    % requireText - Production declaration in CSRD.
    % 中文说明：requireText 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~((ischar(value) && (isempty(value) || isrow(value))) || ...
        (isstring(value) && isscalar(value))) || isempty(char(string(value)))
    error('CSRD:Spectrum:InvalidText', '%s must be non-empty text.', context);
end
end


function requireNonemptyCellstr(value, context)
    % requireNonemptyCellstr - Production declaration in CSRD.
    % 中文说明：requireNonemptyCellstr 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~iscell(value) || isempty(value)
    error('CSRD:Spectrum:InvalidCellText', '%s must be a non-empty cell array.', context);
end
for k = 1:numel(value)
    requireText(value{k}, sprintf('%s{%d}', context, k));
end
end


function band = findBand(bands, bandId)
    % findBand - Production declaration in CSRD.
    % 中文说明：findBand 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
band = [];
for k = 1:numel(bands)
    if strcmp(char(string(bands(k).BandId)), char(string(bandId)))
        band = bands(k);
        return;
    end
end
end
