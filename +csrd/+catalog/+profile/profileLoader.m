function profile = profileLoader(category, name)
%PROFILELOADER Load a Phase 2 reference profile by (category, name).
% 中文说明：提供 CSRD 生产链路中的 profileLoader 实现。
%
% Phase 2 profile library entry point. Returns a fully-validated profile
% struct from one of four registered categories.
%
% Inputs:
%   category : char vector, one of {'bands','receivers','phaseNoise','antennaCompat'}
%   name     : char vector, must match a function name living in
%              +csrd/+catalog/+profile/+<category>/<name>.m
%
% Outputs:
%   profile  : struct, schema is category-dependent (see
%              docs/audits/phases/phase-2-blueprint.md §3.1.3)
%
% Throws:
%   CSRD:Profile:NotFound       - category invalid OR name not found in category
%   CSRD:Profile:SchemaInvalid  - loaded struct missing required fields
%
% Example:
%   p = csrd.catalog.profile.profileLoader('bands', 'ISM24_WiFi24');
%
% See also: docs/audits/phases/phase-2-blueprint.md §3.1

    arguments
        category (1,:) char
        name     (1,:) char
    end

    validCategories = {'bands','receivers','phaseNoise','antennaCompat'};
    if ~any(strcmp(category, validCategories))
        error('CSRD:Profile:NotFound', ...
            ['Unknown profile category "%s". Valid categories: %s.'], ...
            category, strjoin(validCategories, ', '));
    end

    fqName = sprintf('csrd.catalog.profile.%s.%s', category, name);
    if isempty(which(fqName))
        error('CSRD:Profile:NotFound', ...
            ['Profile "%s" not found in category "%s". ', ...
             'Expected file: +csrd/+catalog/+profile/+%s/%s.m'], ...
            name, category, category, name);
    end

    profile = feval(fqName);

    validateProfileSchema(category, name, profile);
end

function validateProfileSchema(category, name, profile)
%VALIDATEPROFILESCHEMA Enforce per-category required-field contract.
% 中文说明：validateProfileSchema 在 CSRD 生产链路中执行对应处理。
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.

    if ~isstruct(profile) || ~isscalar(profile)
        error('CSRD:Profile:SchemaInvalid', ...
            'Profile %s/%s must return a scalar struct.', category, name);
    end

    switch category
        case 'bands'
            required = {'FrequencyRangeHz', 'RecommendedBandwidthsHz', ...
                'RecommendedModulationFamilies', 'TemporalPattern', ...
                'RecommendedTxAntennas', 'TypicalNoiseFigureDb', ...
                'RecommendedRxProfiles'};
        case 'receivers'
            required = {'SampleRateChoicesHz', 'ObservableBandwidthHz', ...
                'NumAntennasRange', 'NoiseFigureRangeDb', ...
                'SensitivityDbm', 'CarrierFrequencyRangeHz'};
        case 'phaseNoise'
            required = {'LevelDbcPerHz', 'FrequencyOffsetsHz'};
        case 'antennaCompat'
            required = {'Matrix', 'AntennaBins', 'Conditions'};
        otherwise
            error('CSRD:Profile:SchemaInvalid', ...
                'No schema registered for category "%s".', category);
    end

    missing = required(~isfield(profile, required));
    if ~isempty(missing)
        error('CSRD:Profile:SchemaInvalid', ...
            'Profile %s/%s missing required fields: %s.', ...
            category, name, strjoin(missing, ', '));
    end

    switch category
        case 'bands'
            if ~isnumeric(profile.FrequencyRangeHz) || numel(profile.FrequencyRangeHz) ~= 2
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.FrequencyRangeHz must be 1x2 numeric [fLow fHigh].', name);
            end
            if profile.FrequencyRangeHz(1) >= profile.FrequencyRangeHz(2)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.FrequencyRangeHz must satisfy fLow < fHigh.', name);
            end
            if ~iscell(profile.RecommendedBandwidthsHz) || isempty(profile.RecommendedBandwidthsHz)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.RecommendedBandwidthsHz must be a non-empty cell.', name);
            end
            if ~iscell(profile.RecommendedModulationFamilies) || isempty(profile.RecommendedModulationFamilies)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.RecommendedModulationFamilies must be a non-empty cell.', name);
            end
            if ~ismember(profile.TemporalPattern, {'Continuous','Burst','Scheduled'})
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.TemporalPattern must be one of {Continuous,Burst,Scheduled}.', name);
            end
            if ~isnumeric(profile.RecommendedTxAntennas) || numel(profile.RecommendedTxAntennas) ~= 2 ...
                    || profile.RecommendedTxAntennas(1) > profile.RecommendedTxAntennas(2)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.RecommendedTxAntennas must be 1x2 [min max] with min<=max.', name);
            end
            if ~isnumeric(profile.TypicalNoiseFigureDb) || ~isscalar(profile.TypicalNoiseFigureDb)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.TypicalNoiseFigureDb must be scalar numeric.', name);
            end
            if ~iscell(profile.RecommendedRxProfiles) || isempty(profile.RecommendedRxProfiles)
                error('CSRD:Profile:SchemaInvalid', ...
                    'bands/%s.RecommendedRxProfiles must be a non-empty cell.', name);
            end

        case 'receivers'
            if ~iscell(profile.SampleRateChoicesHz) || isempty(profile.SampleRateChoicesHz)
                error('CSRD:Profile:SchemaInvalid', ...
                    'receivers/%s.SampleRateChoicesHz must be a non-empty cell.', name);
            end
            if ~isnumeric(profile.NumAntennasRange) || numel(profile.NumAntennasRange) ~= 2 ...
                    || profile.NumAntennasRange(1) > profile.NumAntennasRange(2) ...
                    || profile.NumAntennasRange(1) < 1
                error('CSRD:Profile:SchemaInvalid', ...
                    'receivers/%s.NumAntennasRange must be 1x2 [min max] with 1<=min<=max.', name);
            end
            if ~isnumeric(profile.NoiseFigureRangeDb) || numel(profile.NoiseFigureRangeDb) ~= 2 ...
                    || profile.NoiseFigureRangeDb(1) > profile.NoiseFigureRangeDb(2)
                error('CSRD:Profile:SchemaInvalid', ...
                    'receivers/%s.NoiseFigureRangeDb must be 1x2 [min max] with min<=max.', name);
            end
            if ~isnumeric(profile.SensitivityDbm) || ~isscalar(profile.SensitivityDbm)
                error('CSRD:Profile:SchemaInvalid', ...
                    'receivers/%s.SensitivityDbm must be scalar numeric (dBm).', name);
            end
            if ~isnumeric(profile.CarrierFrequencyRangeHz) || numel(profile.CarrierFrequencyRangeHz) ~= 2 ...
                    || profile.CarrierFrequencyRangeHz(1) >= profile.CarrierFrequencyRangeHz(2)
                error('CSRD:Profile:SchemaInvalid', ...
                    'receivers/%s.CarrierFrequencyRangeHz must be 1x2 [fLow fHigh] with fLow<fHigh.', name);
            end

        case 'phaseNoise'
            if ~isnumeric(profile.LevelDbcPerHz) || ~isvector(profile.LevelDbcPerHz)
                error('CSRD:Profile:SchemaInvalid', ...
                    'phaseNoise/%s.LevelDbcPerHz must be a numeric vector (dBc/Hz).', name);
            end
            if ~isnumeric(profile.FrequencyOffsetsHz) || ~isvector(profile.FrequencyOffsetsHz)
                error('CSRD:Profile:SchemaInvalid', ...
                    'phaseNoise/%s.FrequencyOffsetsHz must be a numeric vector (Hz).', name);
            end
            if numel(profile.LevelDbcPerHz) ~= numel(profile.FrequencyOffsetsHz)
                error('CSRD:Profile:SchemaInvalid', ...
                    'phaseNoise/%s.LevelDbcPerHz and FrequencyOffsetsHz must have equal length.', name);
            end

        case 'antennaCompat'
            if ~isa(profile.Matrix, 'containers.Map')
                error('CSRD:Profile:SchemaInvalid', ...
                    'antennaCompat/%s.Matrix must be a containers.Map.', name);
            end
            if ~isnumeric(profile.AntennaBins) || ~isvector(profile.AntennaBins)
                error('CSRD:Profile:SchemaInvalid', ...
                    'antennaCompat/%s.AntennaBins must be a numeric vector.', name);
            end
            if ~isstruct(profile.Conditions)
                error('CSRD:Profile:SchemaInvalid', ...
                    'antennaCompat/%s.Conditions must be a struct.', name);
            end
    end
end
