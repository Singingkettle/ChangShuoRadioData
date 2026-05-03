function summary = runFullCoverageValidation(configStruct, configName, projectRoot, workerId, numWorkers, varargin)
%RUNFULLCOVERAGEVALIDATION Execute validation-grade coverage generation.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：从正式 simulation.m 入口派生覆盖矩阵配置，并验证每个生成结果的标注一致性。

p = inputParser;
addParameter(p, 'DryRun', false, @islogical);
parse(p, varargin{:});
dryRun = p.Results.DryRun;

opts = localResolveOptions(configStruct);
cases = localBuildCases(projectRoot, configStruct, opts);
selectedMask = localWorkerSelection(numel(cases), workerId, numWorkers, opts);

outputRoot = fullfile(projectRoot, 'data', opts.OutputDirectory);
generatedConfigRoot = fullfile(projectRoot, 'data', opts.GeneratedConfigDirectory);
summaryRoot = fullfile(projectRoot, 'data', opts.SummaryDirectory);

if ~dryRun
    if ~exist(outputRoot, 'dir'); mkdir(outputRoot); end
    if ~exist(generatedConfigRoot, 'dir'); mkdir(generatedConfigRoot); end
    if ~exist(summaryRoot, 'dir'); mkdir(summaryRoot); end
end

coverage = localEmptyCoverage();
records = repmat(localEmptyRecord(), 0, 1);
passed = 0;
skipped = 0;
failed = 0;

addpath(fullfile(projectRoot, 'tools'));
addpath(fullfile(projectRoot, 'tools', 'visualization'));

for idx = 1:numel(cases)
    c = cases(idx);
    if ~selectedMask(idx)
        continue;
    end

    record = localEmptyRecord();
    record.Index = idx;
    record.Name = string(c.Name);
    record.Status = "Pending";
    record.SkipReason = string(c.SkipReason);

    if ~isempty(c.SkipReason)
        record.Status = "Skipped";
        skipped = skipped + 1;
        records(end + 1) = record; %#ok<AGROW>
        fprintf('  [SKIP] %s: %s\n', c.Name, c.SkipReason);
        continue;
    end

    configPath = fullfile(generatedConfigRoot, ...
        sprintf('csrd_phase13_%03d_%s.m', idx, localSafeName(c.Name)));
    caseOutputDirectory = fullfile(opts.OutputDirectory, 'runs', ...
        localSafeName(c.Name));
    record.ConfigPath = string(configPath);
    record.OutputDirectory = string(fullfile(projectRoot, 'data', caseOutputDirectory));

    if dryRun
        record.Status = "DryRun";
        records(end + 1) = record; %#ok<AGROW>
        continue;
    end

    localWriteCaseConfig(configPath, c, caseOutputDirectory, opts, idx);
    try
        simulation(1, 1, configPath);
        annotationPath = localFindAnnotation(projectRoot, caseOutputDirectory);
        result = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
            'RequireSources', true, 'RequireRuntimeHeader', true);
        caseCoverage = localAssertCaseResult(result, c);
        coverage = localMergeCoverage(coverage, caseCoverage);
        record.Status = "Passed";
        record.AnnotationPath = string(annotationPath);
        record.NumSources = result.Summary.NumSources;
        record.NumReceivers = result.Summary.NumReceivers;
        passed = passed + 1;
        fprintf('  [OK] %s -> sources=%d receivers=%d\n', ...
            c.Name, result.Summary.NumSources, result.Summary.NumReceivers);
    catch ME
        if c.AllowEnvironmentSkip && localIsEnvironmentLimitation(ME)
            record.Status = "Skipped";
            record.SkipReason = "environment limitation: " + string(ME.message);
            skipped = skipped + 1;
            fprintf('  [SKIP] %s: %s\n', c.Name, record.SkipReason);
        else
            record.Status = "Failed";
            record.ErrorIdentifier = string(ME.identifier);
            record.ErrorMessage = string(ME.message);
            failed = failed + 1;
            records(end + 1) = record; %#ok<AGROW>
            localWriteSummary(summaryRoot, configName, opts, cases, records, ...
                coverage, passed, skipped, failed, dryRun);
            rethrow(ME);
        end
    end
    records(end + 1) = record; %#ok<AGROW>
    csrd.runtime.logger.GlobalLogManager.reset();
end

if ~dryRun && opts.EnforceCoverage && numWorkers == 1
    localAssertCoverage(coverage, passed, opts);
end

summary = localMakeSummary(configName, opts, cases, records, coverage, ...
    passed, skipped, failed, dryRun);

if ~dryRun
    localWriteSummary(summaryRoot, configName, opts, cases, records, ...
        coverage, passed, skipped, failed, dryRun);
    if strcmp(opts.Mode, 'osm_raytracing_stress')
        csrd.support.validation.validateOsmRayTracingRun(outputRoot, ...
            'RequireBuilding', true, 'RequireFlat', true);
    end
    if localVisualizationEnabled(opts)
        visualOutputRoot = localVisualizationOutputRoot(projectRoot, opts);
        maxImages = localGetField(opts.Visualization, 'MaxImages', 12);
        selectionMode = localGetField(opts.Visualization, 'SelectionMode', 'first');
        minRectangles = localGetField(opts.Visualization, 'MinRectangles', 1);
        render_csrd_spectrogram_overlays('DataRoot', outputRoot, ...
            'OutputRoot', visualOutputRoot, 'MaxImages', maxImages, ...
            'RequireRectangles', true, 'SelectionMode', selectionMode, ...
            'MinRectangles', minRectangles);
    end
end
end


function opts = localResolveOptions(configStruct)
    % localResolveOptions - Production declaration in CSRD.
    % 中文说明：localResolveOptions 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
cfg = configStruct.CoverageValidation;
opts = struct();
opts.Mode = lower(char(string(localGetField(cfg, 'Mode', 'full_coverage'))));
opts.OutputDirectory = localGetField(cfg, 'OutputDirectory', ...
    'CSRD2025_full_coverage_validation');
opts.GeneratedConfigDirectory = localGetField(cfg, ...
    'GeneratedConfigDirectory', fullfile(opts.OutputDirectory, 'generated_configs'));
opts.SummaryDirectory = localGetField(cfg, 'SummaryDirectory', ...
    fullfile(opts.OutputDirectory, 'summaries'));
opts.IncludeBuildingOSM = localGetField(cfg, 'IncludeBuildingOSM', true);
opts.EnforceCoverage = localGetField(cfg, 'EnforceCoverage', true);
opts.NumFramesPerCase = localGetField(cfg, 'NumFramesPerCase', 1);
opts.ObservationDuration = localGetField(cfg, 'ObservationDuration', 0.0015);
opts.TargetFrameSamples = localGetField(cfg, 'TargetFrameSamples', []);
opts.DefaultSampleRateHz = localGetField(cfg, 'DefaultSampleRateHz', 20e6);
opts.WideSampleRateHz = localGetField(cfg, 'WideSampleRateHz', 50e6);
opts.MinimumModulatorSampleRateHz = localGetField(cfg, ...
    'MinimumModulatorSampleRateHz', 250e3);
opts.StartAt = localGetField(cfg, 'StartAt', 1);
opts.StopAfter = localGetField(cfg, 'StopAfter', Inf);
opts.RegulatoryCases = localGetField(cfg, 'RegulatoryCases', { ...
    'CN', 'CN_FM_BROADCAST'; 'CN', 'CN_NR_N78'; 'US', 'US_ISM_915'; ...
    'EU', 'EU_DAB_VHF'; 'JP', 'JP_ISDB_UHF'; 'KR', 'KR_SRD_920'});
opts.StatisticalChannelModels = localGetField(cfg, ...
    'StatisticalChannelModels', {'AWGN', 'Rayleigh', 'Rician', 'MultiPath'});
opts.AntennaCombos = localGetField(cfg, 'AntennaCombos', [ ...
    1, 1, 1, 1; 2, 2, 2, 2; 3, 2, 4, 4; 2, 3, 2, 3]);
opts.OsmRayTracing = localGetField(cfg, 'OsmRayTracing', struct());
opts.Visualization = localGetField(cfg, 'Visualization', struct());
end


function value = localGetField(s, name, fallback)
    % localGetField - Production declaration in CSRD.
    % 中文说明：localGetField 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = fallback;
end
end


function n = localTargetFrameSamples(opts)
    % localTargetFrameSamples - Resolve optional per-frame sample target.
    % 中文说明：解析可选目标帧采样点数；为空时沿用 ObservationDuration。
    % Inputs / 输入: resolved validation options.
    % 输出 / Outputs: positive integer sample count or [].
n = [];
if isfield(opts, 'TargetFrameSamples') && ~isempty(opts.TargetFrameSamples)
    n = round(double(opts.TargetFrameSamples));
    assert(isfinite(n) && n > 0, ...
        'CoverageValidation.TargetFrameSamples must be a positive scalar.');
end
end


function duration = localCaseObservationDuration(c, opts)
    % localCaseObservationDuration - Derive duration from target samples.
    % 中文说明：优先按目标采样点数和 case 采样率计算帧时长，保证高分辨率验证。
    % Inputs / 输入: case descriptor and resolved options.
    % 输出 / Outputs: observation duration in seconds.
targetFrameSamples = localTargetFrameSamples(opts);
if isempty(targetFrameSamples)
    duration = opts.ObservationDuration;
else
    duration = targetFrameSamples * double(opts.NumFramesPerCase) / ...
        double(c.SampleRateHz);
end
end


function txt = localMatlabCellstr(values)
    % localMatlabCellstr - Serialize a cellstr/string vector for generated config.
    % 中文说明：把字符串列表序列化为 MATLAB cell 字符串字面量。
    % Inputs / 输入: cell/string/char values.
    % 输出 / Outputs: MATLAB source snippet.
if ischar(values) || isstring(values)
    values = cellstr(string(values));
end
parts = cell(1, numel(values));
for k = 1:numel(values)
    parts{k} = sprintf('''%s''', localEscapeMatlabChar(values{k}));
end
txt = ['{', strjoin(parts, ', '), '}'];
end


function txt = localMatlabNumericVector(values)
    % localMatlabNumericVector - Serialize a numeric vector for generated config.
    % 中文说明：把数值向量序列化为 MATLAB 字面量。
    % Inputs / 输入: numeric scalar/vector.
    % 输出 / Outputs: MATLAB source snippet.
values = double(values);
txt = ['[', strjoin(arrayfun(@(x) sprintf('%.17g', x), values(:).', ...
    'UniformOutput', false), ', '), ']'];
end


function intervals = localScaleIntervalFractions(intervalFractions, durationSec)
    % localScaleIntervalFractions - Convert [0,1] fractions to seconds.
if ~iscell(intervalFractions)
    error('CSRD:Validation:InvalidExplicitIntervals', ...
        'ExplicitIntervalFractions must be a cell array of Nx2 matrices.');
end
intervals = cell(size(intervalFractions));
for k = 1:numel(intervalFractions)
    m = double(intervalFractions{k});
    if size(m, 2) ~= 2 || isempty(m) || any(~isfinite(m(:))) || ...
            any(m(:) < 0) || any(m(:) > 1) || any(m(:, 2) <= m(:, 1))
        error('CSRD:Validation:InvalidExplicitIntervals', ...
            'ExplicitIntervalFractions{%d} must be finite [0,1] Nx2 intervals.', k);
    end
    intervals{k} = m .* double(durationSec);
end
end


function txt = localMatlabCellOfMatrices(values)
    % localMatlabCellOfMatrices - Serialize a cell array of numeric matrices.
parts = cell(1, numel(values));
for k = 1:numel(values)
    parts{k} = localMatlabMatrix(values{k});
end
txt = ['{', strjoin(parts, ', '), '}'];
end


function txt = localMatlabMatrix(values)
values = double(values);
rows = cell(1, size(values, 1));
for r = 1:size(values, 1)
    rows{r} = strjoin(arrayfun(@(x) sprintf('%.17g', x), ...
        values(r, :), 'UniformOutput', false), ', ');
end
txt = ['[', strjoin(rows, '; '), ']'];
end


function tf = localVisualizationEnabled(opts)
    % localVisualizationEnabled - Detect requested Phase 16 visual QA output.
    % 中文说明：判断覆盖验证配置是否要求生成频谱图 overlay 目视检查产物。
    % Inputs / 输入: resolved coverage validation options.
    % 输出 / Outputs: true when spectrogram overlays should be rendered.
tf = isstruct(opts.Visualization) && isfield(opts.Visualization, 'Enable') && ...
    isequal(opts.Visualization.Enable, true);
end


function outputRoot = localVisualizationOutputRoot(projectRoot, opts)
    % localVisualizationOutputRoot - Resolve visualization artifact directory.
    % 中文说明：把相对 artifacts 目录解析到项目根，确保目视检查图不写进源码目录树之外。
    % Inputs / 输入: project root and resolved coverage validation options.
    % 输出 / Outputs: absolute output directory for PNG/contact-sheet artifacts.
relativeRoot = localGetField(opts.Visualization, 'OutputDirectory', ...
    fullfile('artifacts', 'visual_checks', 'coverage_validation'));
if isfolder(relativeRoot) || startsWith(char(string(relativeRoot)), projectRoot)
    outputRoot = char(string(relativeRoot));
else
    outputRoot = fullfile(projectRoot, char(string(relativeRoot)));
end
end


function mask = localWorkerSelection(numCases, workerId, numWorkers, opts)
    % localWorkerSelection - Production declaration in CSRD.
    % 中文说明：localWorkerSelection 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
mask = false(1, numCases);
for idx = 1:numCases
    if idx < opts.StartAt || idx > opts.StopAfter
        continue;
    end
    mask(idx) = mod(idx - 1, numWorkers) + 1 == workerId;
end
end


function cases = localBuildCases(projectRoot, configStruct, opts)
    % localBuildCases - Production declaration in CSRD.
    % 中文说明：localBuildCases 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
cases = repmat(localDefaultCase('placeholder', opts), 0, 1);

regCases = opts.RegulatoryCases;
for k = 1:size(regCases, 1)
    region = regCases{k, 1};
    band = regCases{k, 2};
    c = localDefaultCase(sprintf('reg_%s_%s', region, band), opts);
    c.Regulatory = true;
    c.RegionId = region;
    c.BandId = band;
    c.SampleRateHz = opts.WideSampleRateHz;
    if strcmp(band, 'CN_NR_N78')
        c.TxCount = 2;
        c.RxCount = 2;
        c.TxAntMin = 2;
        c.TxAntMax = 4;
        c.RxAntennas = 2;
    end
    cases(end + 1) = c; %#ok<AGROW>
end

openOcean = fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Open_Ocean_Area', ...
    'Open_Ocean_Area_Central_Indian_Ocean_-20.0000_80.0000.osm');
c = localDefaultCase('osm_flat_KR_SRD_920', opts);
c.Regulatory = true;
c.RegionId = 'KR';
c.BandId = 'KR_SRD_920';
c.MapType = 'OSM';
c.OSMFile = openOcean;
c.ExpectChannelModel = 'RayTracing';
c.TxCount = 2;
c.RxCount = 2;
if exist(openOcean, 'file') ~= 2
    c.SkipReason = 'selected flat-terrain OSM file is missing';
end
cases(end + 1) = c;

if opts.IncludeBuildingOSM
    c = localDefaultCase('osm_building_CN_ISM_24', opts);
    c.Regulatory = true;
    c.RegionId = 'CN';
    c.BandId = 'CN_ISM_24';
    c.MapType = 'OSM';
    c.OSMFile = localFindBuildingOsm(projectRoot);
    c.ExpectChannelModel = 'RayTracing';
    c.AllowEnvironmentSkip = true;
    if isempty(c.OSMFile)
        c.SkipReason = 'no selected building OSM file found';
    else
        rfCaps = csrd.runtime.capabilities.rfPropagationCapabilities( ...
            'OsmFile', c.OSMFile, 'RunSmoke', false);
        if ~rfCaps.CanUseBuildingOsmRayTracing
            c.SkipReason = rfCaps.SkipReason;
        end
    end
    cases(end + 1) = c;
end

if strcmp(opts.Mode, 'osm_raytracing_stress') || ...
        (isstruct(opts.OsmRayTracing) && isfield(opts.OsmRayTracing, 'Enable') && ...
         isequal(opts.OsmRayTracing.Enable, true))
    cases = localAppendOsmRayTracingStressCases(cases, projectRoot, configStruct, opts);
end

for k = 1:numel(opts.StatisticalChannelModels)
    modelName = opts.StatisticalChannelModels{k};
    c = localDefaultCase(sprintf('channel_%s', modelName), opts);
    c.Regulatory = false;
    c.ModulationType = 'QAM';
    c.ModulationOrder = 16;
    c.MapType = 'Statistical';
    c.StatisticalChannelModel = modelName;
    c.ExpectChannelModel = modelName;
    cases(end + 1) = c; %#ok<AGROW>
end

modulationTypes = localAllModulationTypes(configStruct);
for k = 1:numel(modulationTypes)
    typeId = modulationTypes{k};
    c = localDefaultCase(sprintf('mod_%s', typeId), opts);
    c.Regulatory = false;
    c.ModulationType = typeId;
    c.ModulationOrder = localOrderForType(typeId);
    c.BandwidthRatio = localBandwidthRatioForType(typeId);
    c.TxAntMin = localAntennaCountForType(typeId);
    c.TxAntMax = c.TxAntMin;
    cases(end + 1) = c; %#ok<AGROW>
end

rfMethods = configStruct.Factories.Transmit.Simulation.Nonlinearity.Methods;
for k = 1:numel(rfMethods)
    c = localDefaultCase(sprintf('rf_%s', localSafeName(rfMethods{k})), opts);
    c.Regulatory = false;
    c.ModulationType = 'QAM';
    c.ModulationOrder = 16;
    c.NonlinearityMethod = rfMethods{k};
    cases(end + 1) = c; %#ok<AGROW>
end

for k = 1:size(opts.AntennaCombos, 1)
    combo = opts.AntennaCombos(k, :);
    c = localDefaultCase(sprintf('multi_%dtx_%drx_%dtxant_%drxant', ...
        combo(1), combo(2), combo(3), combo(4)), opts);
    c.Regulatory = false;
    c.ModulationType = 'QAM';
    c.ModulationOrder = 16;
    c.TxCount = combo(1);
    c.RxCount = combo(2);
    c.TxAntMin = combo(3);
    c.TxAntMax = combo(3);
    c.RxAntennas = combo(4);
    cases(end + 1) = c; %#ok<AGROW>
end
end


function c = localDefaultCase(name, opts)
    % localDefaultCase - Production declaration in CSRD.
    % 中文说明：localDefaultCase 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
c = struct( ...
    'Name', char(name), ...
    'Regulatory', true, ...
    'RegionId', 'CN', ...
    'BandId', 'CN_FM_BROADCAST', ...
    'ModulationType', '', ...
    'ModulationOrder', 0, ...
    'MapType', 'Statistical', ...
    'MapFlavor', '', ...
    'OSMFile', '', ...
    'StatisticalChannelModel', 'Statistical', ...
    'TxCount', 1, ...
    'RxCount', 1, ...
    'TxAntMin', 1, ...
    'TxAntMax', 1, ...
    'RxAntennas', 1, ...
    'SampleRateHz', opts.DefaultSampleRateHz, ...
    'BandwidthRatio', 0.05, ...
    'NonlinearityMethod', '', ...
    'ExpectChannelModel', '', ...
    'TemporalPatternTypes', {{'Continuous'}}, ...
    'TemporalPatternDistribution', 1.0, ...
    'RandomNumBursts', [1 1], ...
    'ExplicitIntervalFractions', {{}}, ...
    'ExpectedSourcesMin', 0, ...
    'MessageLengthMin', 64, ...
    'MessageLengthMax', 4096, ...
    'ModulationTypes', {{}}, ...
    'OFDMMimoMode', '', ...
    'AllowEnvironmentSkip', false, ...
    'SkipReason', '', ...
    'Seed', 20260430);
end


function cases = localAppendOsmRayTracingStressCases(cases, projectRoot, configStruct, opts)
    % localAppendOsmRayTracingStressCases - Add Phase 16 OSM RayTracing matrix.
    % 中文说明：追加 Phase 16 building/empty OSM 与多实体、多天线、调制覆盖组合。
    % Inputs / 输入: existing cases, project root, merged config, resolved options.
    % 输出 / Outputs: cases with validation-grade OSM RayTracing stress cases.
osmOpts = opts.OsmRayTracing;
buildingFile = localFindOsmFromCategories(projectRoot, ...
    localGetField(osmOpts, 'BuildingCategories', {'Dense_Urban_Mid_Rise'}), true);
flatFile = localFindOsmFromCategories(projectRoot, ...
    localGetField(osmOpts, 'FlatCategories', {'Open_Ocean_Area'}), false);
regCases = localGetField(osmOpts, 'RegulatoryCases', opts.RegulatoryCases);
combos = localGetField(osmOpts, 'AntennaCombos', opts.AntennaCombos);
coverAllModulations = localGetField(osmOpts, 'CoverAllModulations', true);

for flavorIdx = 1:2
    if flavorIdx == 1
        mapFlavor = 'Building';
        osmFile = buildingFile;
    else
        mapFlavor = 'FlatTerrain';
        osmFile = flatFile;
    end

    for k = 1:size(regCases, 1)
        combo = combos(mod(k - 1, size(combos, 1)) + 1, :);
        region = regCases{k, 1};
        band = regCases{k, 2};
        txAntennas = localTxAntennasForRegulatoryBand( ...
            region, band, combo(3));
        c = localDefaultCase(sprintf('osm_rt_%s_reg_%s_%s_%dtx_%drx_%dtxant_%drxant', ...
            lower(mapFlavor), region, band, combo(1), combo(2), txAntennas, combo(4)), opts);
        c.Regulatory = true;
        c.RegionId = region;
        c.BandId = band;
        c.MapType = 'OSM';
        c.MapFlavor = mapFlavor;
        c.OSMFile = osmFile;
        c.ExpectChannelModel = 'RayTracing';
        c.TxCount = combo(1);
        c.RxCount = combo(2);
        c.TxAntMin = txAntennas;
        c.TxAntMax = txAntennas;
        c.RxAntennas = combo(4);
        c.SampleRateHz = localSampleRateForBand(band, opts);
        c.AllowEnvironmentSkip = strcmp(mapFlavor, 'Building');
        c.SkipReason = localOsmSkipReason(osmFile, mapFlavor);
        cases(end + 1) = c; %#ok<AGROW>
    end
end

if coverAllModulations
    modulationTypes = localAllModulationTypes(configStruct);
else
    modulationTypes = localGetField(osmOpts, 'RepresentativeModulations', ...
        {'QAM', 'OFDM', 'GMSK', 'FM'});
end

for k = 1:numel(modulationTypes)
    typeId = modulationTypes{k};
    combo = combos(mod(k - 1, size(combos, 1)) + 1, :);
    txAntennas = localTxAntennasForModulationType(typeId, combo(3));
    c = localDefaultCase(sprintf('osm_rt_building_mod_%s_%dtx_%drx_%dtxant_%drxant', ...
        typeId, combo(1), combo(2), txAntennas, combo(4)), opts);
    c.Regulatory = false;
    c.ModulationType = typeId;
    c.ModulationOrder = localOrderForType(typeId);
    c.BandwidthRatio = localBandwidthRatioForType(typeId);
    c.MapType = 'OSM';
    c.MapFlavor = 'Building';
    c.OSMFile = buildingFile;
    c.ExpectChannelModel = 'RayTracing';
    c.TxCount = combo(1);
    c.RxCount = combo(2);
    c.TxAntMin = txAntennas;
    c.TxAntMax = txAntennas;
    c.RxAntennas = combo(4);
    c.SampleRateHz = opts.DefaultSampleRateHz;
    c.AllowEnvironmentSkip = true;
    c.SkipReason = localOsmSkipReason(buildingFile, 'Building');
    cases(end + 1) = c; %#ok<AGROW>
end

% A receiver-level visual QA case with several emitters and several bursts.
% 中文说明：专门生成“单接收机看到多个发射机、多段 burst”的频谱图样本。
c = localDefaultCase('osm_rt_building_multi_tx_multi_burst_visual', opts);
c.Regulatory = false;
c.ModulationType = 'OFDM';
c.ModulationTypes = {'OFDM', 'QAM'};
c.ModulationOrder = 16;
c.BandwidthRatio = 0.06;
c.MapType = 'OSM';
c.MapFlavor = 'Building';
c.OSMFile = buildingFile;
c.ExpectChannelModel = 'RayTracing';
c.TxCount = 3;
c.RxCount = 1;
c.TxAntMin = 2;
c.TxAntMax = 4;
c.RxAntennas = 4;
c.SampleRateHz = opts.DefaultSampleRateHz;
c.TemporalPatternTypes = {'Explicit'};
c.TemporalPatternDistribution = 1.0;
c.RandomNumBursts = [3 3];
c.ExplicitIntervalFractions = { ...
    [0.08 0.18; 0.36 0.46; 0.64 0.74], ...
    [0.18 0.28; 0.46 0.56; 0.74 0.84], ...
    [0.28 0.38; 0.56 0.66; 0.84 0.94]};
c.ExpectedSourcesMin = 9;
c.MessageLengthMin = 8192;
c.MessageLengthMax = 65536;
c.OFDMMimoMode = 'SpatialMultiplexing';
c.AllowEnvironmentSkip = true;
c.SkipReason = localOsmSkipReason(buildingFile, 'Building');
cases(end + 1) = c; %#ok<AGROW>
end


function reason = localOsmSkipReason(osmFile, mapFlavor)
    % localOsmSkipReason - Resolve missing/capability skip reason for OSM cases.
    % 中文说明：在生成子配置前明确 OSM 文件缺失或 building RayTracing 能力限制。
    % Inputs / 输入: selected OSM file and Phase 16 map flavor.
    % 输出 / Outputs: reason is empty when the case should execute.
reason = '';
if isempty(osmFile) || exist(osmFile, 'file') ~= 2
    reason = sprintf('selected %s OSM file is missing', mapFlavor);
    return;
end
if strcmp(mapFlavor, 'Building')
    rfCaps = csrd.runtime.capabilities.rfPropagationCapabilities( ...
        'OsmFile', osmFile, 'RunSmoke', false);
    if ~rfCaps.CanUseBuildingOsmRayTracing
        reason = rfCaps.SkipReason;
    end
end
end


function path = localFindOsmFromCategories(projectRoot, categories, requireBuildings)
    % localFindOsmFromCategories - Pick the first matching OSM fixture.
    % 中文说明：按目录类别选择 building 或 empty/no-building OSM 文件，不扫描无关数据。
    % Inputs / 输入: project root, preferred categories, and building requirement.
    % 输出 / Outputs: absolute OSM path or empty char when none match.
path = '';
for c = 1:numel(categories)
    cat = char(string(categories{c}));
    files = dir(fullfile(projectRoot, 'data', 'map', 'osm', cat, '*.osm'));
    for f = 1:numel(files)
        candidate = fullfile(files(f).folder, files(f).name);
        hasBuildings = csrd.runtime.map.osmHasBuildings(candidate);
        if (requireBuildings && hasBuildings) || (~requireBuildings && ~hasBuildings)
            path = candidate;
            return;
        end
    end
end
end


function sampleRate = localSampleRateForBand(bandId, opts)
    % localSampleRateForBand - Use wider receiver bandwidth for broadband bands.
    % 中文说明：对 NR/WLAN/ISM 等宽带业务使用更宽采样率，其余使用默认采样率。
    % Inputs / 输入: catalog band identifier and resolved validation options.
    % 输出 / Outputs: receiver sample rate in Hz.
wideTokens = {'NR', 'ISM', 'WLAN', 'LTE', 'UHF'};
if any(contains(upper(char(string(bandId))), wideTokens))
    sampleRate = opts.WideSampleRateHz;
else
    sampleRate = opts.DefaultSampleRateHz;
end
end


function localWriteCaseConfig(configPath, c, outputDirectory, opts, idx)
    % localWriteCaseConfig - Production declaration in CSRD.
    % 中文说明：localWriteCaseConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
parentDir = fileparts(configPath);
if ~exist(parentDir, 'dir'); mkdir(parentDir); end
[~, fn] = fileparts(configPath);
fid = fopen(configPath, 'w');
assert(fid > 0, 'Could not write generated config: %s', configPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'function config = %s()\n', fn);
fprintf(fid, '%% %s - Generated coverage validation case config.\n', fn);
fprintf(fid, '%% 中文说明：自动生成的覆盖验证子配置。\n');
fprintf(fid, 'config.baseConfigs = { ...\n');
fprintf(fid, '    ''_base_/logging/default.m'', ...\n');
fprintf(fid, '    ''_base_/runners/default.m'', ...\n');
fprintf(fid, '    ''_base_/factories/scenario_factory.m'', ...\n');
fprintf(fid, '    ''_base_/factories/message_factory.m'', ...\n');
fprintf(fid, '    ''_base_/factories/modulation_factory.m'', ...\n');
fprintf(fid, '    ''_base_/factories/transmit_factory.m'', ...\n');
fprintf(fid, '    ''_base_/factories/channel_factory.m'', ...\n');
fprintf(fid, '    ''_base_/factories/receive_factory.m''};\n\n');

fprintf(fid, 'config.Runner.NumScenarios = 1;\n');
fprintf(fid, 'config.Runner.RandomSeed = %d;\n', c.Seed + idx);
targetFrameSamples = localTargetFrameSamples(opts);
fprintf(fid, 'config.Runner.Toolbox.Level = ''minimal'';\n');
fprintf(fid, 'config.Runner.Data.OutputDirectory = ''%s'';\n', ...
    localEscapeMatlabChar(outputDirectory));
fprintf(fid, 'config.Runner.Data.CompressData = false;\n');
fprintf(fid, 'config.Log.Name = ''CSRD-Phase13-Case'';\n');
fprintf(fid, 'config.Log.Level = ''ERROR'';\n');
fprintf(fid, 'config.Log.SaveToFile = true;\n');
fprintf(fid, 'config.Log.DisplayInConsole = false;\n');
fprintf(fid, 'config.CoverageValidation.Enable = false;\n\n');

caseObservationDuration = localCaseObservationDuration(c, opts);
caseFrameSamples = targetFrameSamples;
if isempty(caseFrameSamples)
    caseFrameSamples = round(caseObservationDuration / opts.NumFramesPerCase * ...
        c.SampleRateHz);
end
caseFrameDuration = double(caseFrameSamples) / double(c.SampleRateHz);
caseObservationDuration = caseFrameDuration * double(opts.NumFramesPerCase);
fprintf(fid, 'config.Factories.Scenario.Global.NumFramesPerScenario = %d;\n', ...
    opts.NumFramesPerCase);
fprintf(fid, 'config.Factories.Scenario.Global.ObservationDuration = %.17g;\n', ...
    caseObservationDuration);
fprintf(fid, 'config.Factories.Scenario.Global.FrameNumSamples = %d;\n', ...
    caseFrameSamples);
fprintf(fid, 'config.Factories.Scenario.Global.FrameDuration = %.17g;\n', ...
    caseFrameDuration);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''%s''};\n', ...
    c.MapType);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1.0;\n');
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = %d;\n', c.TxCount);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = %d;\n', c.TxCount);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = %d;\n', c.RxCount);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = %d;\n', c.RxCount);
if strcmp(c.MapType, 'OSM')
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = ''%s'';\n', ...
        localEscapeMatlabChar(c.OSMFile));
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.ChannelModel = ''RayTracing'';\n');
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.EmptyGeometryPolicy = ''FlatTerrain'';\n');
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Terrain = ''none'';\n');
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Material = ''seawater'';\n');
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.MaxNumReflections = 1;\n');
else
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ''%s'';\n', ...
        c.StatisticalChannelModel);
end

fprintf(fid, '\nconfig.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = %.17g;\n', c.SampleRateHz);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Receiver.NumAntennas = %d;\n', c.RxAntennas);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Min = %d;\n', c.TxAntMin);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Max = %d;\n', c.TxAntMax);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Min = %.17g;\n', c.BandwidthRatio);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Max = %.17g;\n', c.BandwidthRatio);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = %s;\n', ...
    localMatlabCellstr(c.TemporalPatternTypes));
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = %s;\n', ...
    localMatlabNumericVector(c.TemporalPatternDistribution));
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.NumBursts.Min = %d;\n', ...
    round(double(c.RandomNumBursts(1))));
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.NumBursts.Max = %d;\n', ...
    round(double(c.RandomNumBursts(end))));
if isfield(c, 'ExplicitIntervalFractions') && ~isempty(c.ExplicitIntervalFractions)
    explicitIntervals = localScaleIntervalFractions( ...
        c.ExplicitIntervalFractions, caseObservationDuration);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Explicit.Intervals = %s;\n', ...
        localMatlabCellOfMatrices(explicitIntervals));
end
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Message.Length.Min = %d;\n', ...
    round(double(c.MessageLengthMin)));
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Message.Length.Max = %d;\n', ...
    round(double(c.MessageLengthMax)));

if c.Regulatory
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = ''Fixed'';\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = ''%s'';\n', c.RegionId);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = ''Tier1'';\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = ''%s'';\n', c.BandId);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = true;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MaxBandwidthFractionOfSampleRate = 0.5;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MinimumModulatorSampleRateHz = %.17g;\n', ...
        opts.MinimumModulatorSampleRateHz);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = {''Radar'', ''Radiolocation'', ''Radionavigation''};\n');
else
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = false;\n');
    modTypes = c.ModulationTypes;
    if isempty(modTypes)
        modTypes = {c.ModulationType};
    end
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.Types = %s;\n', ...
        localMatlabCellstr(modTypes));
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.DefaultOrders.%s = %d;\n', ...
        c.ModulationType, c.ModulationOrder);
    for mt = 1:numel(modTypes)
        if ~strcmp(char(string(modTypes{mt})), c.ModulationType)
            fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.DefaultOrders.%s = %d;\n', ...
                char(string(modTypes{mt})), localOrderForType(modTypes{mt}));
        end
    end
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.RolloffFactor = 0.25;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.SamplesPerSymbol = 4;\n');
    if ~isempty(c.OFDMMimoMode)
        fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.OFDMMimoMode = ''%s'';\n', ...
            localEscapeMatlabChar(c.OFDMMimoMode));
    end
end

if ~isempty(c.NonlinearityMethod)
    method = localEscapeMatlabChar(c.NonlinearityMethod);
    fprintf(fid, 'config.Factories.Transmit.Simulation.Nonlinearity.Methods = {''%s''};\n', method);
    fprintf(fid, 'config.Factories.Receive.Simulation.Nonlinearity.Methods = {''%s''};\n', method);
end
fprintf(fid, 'end\n');
end


function annotationPath = localFindAnnotation(projectRoot, outputDirectory)
    % localFindAnnotation - Production declaration in CSRD.
    % 中文说明：localFindAnnotation 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
caseRoot = fullfile(projectRoot, 'data', outputDirectory);
sessions = dir(fullfile(caseRoot, 'session_*'));
assert(~isempty(sessions), 'No session directory found in %s.', caseRoot);
[~, order] = sort([sessions.datenum], 'descend');
sessionDir = fullfile(sessions(order(1)).folder, sessions(order(1)).name);
annotationPath = fullfile(sessionDir, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Annotation file was not written: %s', annotationPath);
end


function coverage = localAssertCaseResult(result, c)
    % localAssertCaseResult - Production declaration in CSRD.
    % 中文说明：localAssertCaseResult 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
coverage = localEmptyCoverage();
assert(result.Summary.NumReceivers == c.RxCount, ...
    'Case %s expected %d receivers, got %d.', ...
    c.Name, c.RxCount, result.Summary.NumReceivers);
expectedSourcesMin = c.TxCount * c.RxCount;
if isfield(c, 'ExpectedSourcesMin') && c.ExpectedSourcesMin > 0
    expectedSourcesMin = c.ExpectedSourcesMin;
end
assert(result.Summary.NumSources >= expectedSourcesMin, ...
    'Case %s expected at least %d sources, got %d.', ...
    c.Name, expectedSourcesMin, result.Summary.NumSources);

for f = 1:numel(result.Frames)
    frame = result.Frames{f};
    if ~isempty(c.NonlinearityMethod)
        rxMethod = localRxNonlinearityMethod(frame);
        assert(strcmp(rxMethod, c.NonlinearityMethod), ...
            'Case %s expected RX nonlinearity %s, got %s.', ...
            c.Name, c.NonlinearityMethod, rxMethod);
        coverage.RFMethods(end + 1, 1) = string(rxMethod); %#ok<AGROW>
    end
end

for s = 1:numel(result.Sources)
    source = result.Sources{s};
    assert(isfield(source, 'BurstId') && ~isempty(source.BurstId), ...
        'Case %s source %d must publish a non-empty BurstId.', c.Name, s);
    design = source.Truth.Design;
    execution = source.Truth.Execution;
    modulationFamily = char(design.ModulationFamily);
    coverage.Modulations(end + 1, 1) = string(modulationFamily); %#ok<AGROW>
    coverage.TxCounts(end + 1, 1) = c.TxCount; %#ok<AGROW>
    coverage.RxCounts(end + 1, 1) = c.RxCount; %#ok<AGROW>
    coverage.TxAntennaCounts(end + 1, 1) = round(double(design.NumTransmitAntennas)); %#ok<AGROW>
    coverage.RxAntennaCounts(end + 1, 1) = c.RxAntennas; %#ok<AGROW>
    coverage.AntennaCombos(end + 1, 1) = string(sprintf('%dtx-%drx-%dtxant-%drxant', ...
        c.TxCount, c.RxCount, round(double(design.NumTransmitAntennas)), c.RxAntennas)); %#ok<AGROW>
    coverage.MapTypes(end + 1, 1) = string(c.MapType); %#ok<AGROW>
    if ~isempty(c.MapFlavor)
        coverage.MapFlavors(end + 1, 1) = string(c.MapFlavor); %#ok<AGROW>
    end

    assert(double(design.NumTransmitAntennas) >= c.TxAntMin && ...
        double(design.NumTransmitAntennas) <= c.TxAntMax, ...
        'Case %s Tx antenna count %.0f is outside [%d, %d].', ...
        c.Name, double(design.NumTransmitAntennas), c.TxAntMin, c.TxAntMax);

    if c.Regulatory
        localAssertRegulatoryDesign(design, c);
        coverage.RegionIds(end + 1, 1) = string(c.RegionId); %#ok<AGROW>
        coverage.Bands(end + 1, 1) = string(c.BandId); %#ok<AGROW>
    else
        expectedModulations = c.ModulationTypes;
        if isempty(expectedModulations)
            expectedModulations = {c.ModulationType};
        end
        assert(any(strcmp(modulationFamily, expectedModulations)), ...
            'Case %s expected modulation in {%s}, got %s.', ...
            c.Name, strjoin(string(expectedModulations), ', '), modulationFamily);
    end

    channelModel = '';
    if isfield(execution, 'ChannelModel')
        channelModel = char(execution.ChannelModel);
        coverage.ChannelModels(end + 1, 1) = string(channelModel); %#ok<AGROW>
    end
    if ~isempty(c.ExpectChannelModel)
        assert(strcmp(channelModel, c.ExpectChannelModel), ...
            'Case %s expected channel model %s, got %s.', ...
            c.Name, c.ExpectChannelModel, channelModel);
    end
    if strcmp(c.MapType, 'OSM')
        localAssertOsmExecution(execution, c);
    end

    if ~isempty(c.NonlinearityMethod)
        txMethod = localTxNonlinearityMethod(source);
        assert(strcmp(txMethod, c.NonlinearityMethod), ...
            'Case %s expected TX nonlinearity %s, got %s.', ...
            c.Name, c.NonlinearityMethod, txMethod);
        coverage.RFMethods(end + 1, 1) = string(txMethod); %#ok<AGROW>
    end
end
end


function localAssertRegulatoryDesign(design, c)
    % localAssertRegulatoryDesign - Production declaration in CSRD.
    % 中文说明：localAssertRegulatoryDesign 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
assert(isfield(design, 'Regulatory'), ...
    'Case %s missing Truth.Design.Regulatory.', c.Name);
reg = design.Regulatory;
assert(strcmp(char(reg.RegionId), c.RegionId), ...
    'Case %s expected RegionId %s, got %s.', ...
    c.Name, c.RegionId, char(reg.RegionId));
assert(strcmp(char(reg.BandId), c.BandId), ...
    'Case %s expected BandId %s, got %s.', ...
    c.Name, c.BandId, char(reg.BandId));
assert(~isempty(reg.SourceRefs), ...
    'Case %s regulatory SourceRefs must be non-empty.', c.Name);

catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(c.RegionId);
bandIdx = find(strcmp({catalog.Bands.BandId}, c.BandId), 1, 'first');
assert(~isempty(bandIdx), 'Catalog band not found: %s/%s.', c.RegionId, c.BandId);
band = catalog.Bands(bandIdx);

selectedCenter = double(reg.SelectedCenterFrequencyHz);
allowedBw = double(reg.AllowedBandwidthHz);
assert(selectedCenter - allowedBw / 2 >= band.FrequencyRangeHz(1) - 1, ...
    'Case %s regulatory channel lower edge outside catalog band.', c.Name);
assert(selectedCenter + allowedBw / 2 <= band.FrequencyRangeHz(2) + 1, ...
    'Case %s regulatory channel upper edge outside catalog band.', c.Name);
assert(ismember(char(design.ModulationFamily), band.AllowedModulationFamilies), ...
    'Case %s modulation %s is not allowed by catalog band %s.', ...
    c.Name, char(design.ModulationFamily), c.BandId);
assert(~contains(lower(char(reg.ServiceClass)), 'radar') && ...
    ~contains(lower(char(reg.Application)), 'radar'), ...
    'Case %s leaked a radar-like regulatory service.', c.Name);
end


function localAssertOsmExecution(execution, c)
    % localAssertOsmExecution - Validate OSM RayTracing execution truth.
    % 中文说明：检查 OSM case 的 RayTracing、MapProfile 和 fallback 信息是否写入执行真值。
    % Inputs / 输入: Truth.Execution struct and expected case descriptor.
    % 输出 / Outputs: throws when execution metadata is inconsistent.
assert(isfield(execution, 'ChannelModel') && strcmp(char(execution.ChannelModel), 'RayTracing'), ...
    'Case %s OSM execution must report ChannelModel=RayTracing.', c.Name);
assert(isfield(execution, 'MapProfile') && isstruct(execution.MapProfile), ...
    'Case %s OSM execution must publish Truth.Execution.MapProfile.', c.Name);
profile = execution.MapProfile;
assert(isfield(profile, 'ChannelModel') && strcmp(char(profile.ChannelModel), 'RayTracing'), ...
    'Case %s MapProfile.ChannelModel must remain RayTracing.', c.Name);
if strcmp(c.MapFlavor, 'Building')
    assert(isfield(profile, 'HasBuildings') && logical(profile.HasBuildings), ...
        'Case %s expected building OSM MapProfile.HasBuildings=true.', c.Name);
    assert(isfield(profile, 'Mode') && strcmp(char(profile.Mode), 'OSMBuildings'), ...
        'Case %s expected MapProfile.Mode=OSMBuildings.', c.Name);
elseif strcmp(c.MapFlavor, 'FlatTerrain')
    assert(isfield(profile, 'HasBuildings') && ~logical(profile.HasBuildings), ...
        'Case %s expected flat OSM MapProfile.HasBuildings=false.', c.Name);
    assert(isfield(profile, 'Mode') && strcmp(char(profile.Mode), 'FlatTerrain'), ...
        'Case %s expected MapProfile.Mode=FlatTerrain.', c.Name);
    assert(isfield(execution, 'ChannelFallback'), ...
        'Case %s flat OSM execution must publish ChannelFallback.', c.Name);
end
if isfield(execution, 'RayCount') && ~isempty(execution.RayCount)
    assert(isnumeric(execution.RayCount) && isscalar(execution.RayCount) && ...
        isfinite(execution.RayCount) && execution.RayCount >= 0, ...
        'Case %s RayCount must be a finite non-negative scalar.', c.Name);
end
end


function method = localTxNonlinearityMethod(source)
    % localTxNonlinearityMethod - Production declaration in CSRD.
    % 中文说明：localTxNonlinearityMethod 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
method = '';
if isfield(source, 'RFImpairments') && isstruct(source.RFImpairments) && ...
        isfield(source.RFImpairments, 'NonlinearityConfig') && ...
        isstruct(source.RFImpairments.NonlinearityConfig) && ...
        isfield(source.RFImpairments.NonlinearityConfig, 'Method')
    method = char(source.RFImpairments.NonlinearityConfig.Method);
end
end


function method = localRxNonlinearityMethod(frame)
    % localRxNonlinearityMethod - Production declaration in CSRD.
    % 中文说明：localRxNonlinearityMethod 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
method = '';
if isfield(frame, 'RxImpairments') && isstruct(frame.RxImpairments) && ...
        isfield(frame.RxImpairments, 'MemoryLessNonlinearityConfig') && ...
        isstruct(frame.RxImpairments.MemoryLessNonlinearityConfig) && ...
        isfield(frame.RxImpairments.MemoryLessNonlinearityConfig, 'Method')
    method = char(frame.RxImpairments.MemoryLessNonlinearityConfig.Method);
end
end


function localAssertCoverage(coverage, passed, opts)
    % localAssertCoverage - Production declaration in CSRD.
    % 中文说明：localAssertCoverage 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
assert(passed > 0, 'No selected Phase 13 cases passed.');
assert(any(coverage.MapTypes == "Statistical"), ...
    'Coverage did not include statistical map cases.');
assert(any(coverage.MapTypes == "OSM"), ...
    'Coverage did not include OSM map cases.');
if strcmp(opts.Mode, 'osm_raytracing_stress')
    assert(any(coverage.MapFlavors == "Building"), ...
        'Phase 16 OSM stress did not execute a building OSM case.');
    assert(any(coverage.MapFlavors == "FlatTerrain"), ...
        'Phase 16 OSM stress did not execute an empty/no-building OSM case.');
    assert(any(coverage.ChannelModels == "RayTracing"), ...
        'Phase 16 OSM stress did not execute RayTracing channel output.');
end
assert(numel(unique(coverage.RegionIds)) >= 5, ...
    'Coverage did not include CN/US/EU/JP/KR regulatory regions.');
assert(numel(unique(coverage.Modulations)) >= 20, ...
    'Coverage did not include all configured modulation families.');
assert(numel(unique(coverage.RFMethods)) >= 6, ...
    'Coverage did not include all RF nonlinearity methods.');
assert(all(ismember(["AWGN"; "Rayleigh"; "Rician"; "MultiPath"], ...
    unique(coverage.ChannelModels))), ...
    'Coverage did not include all configured statistical channel models.');
assert(max(coverage.TxCounts) >= 3 && max(coverage.RxCounts) >= 3, ...
    'Coverage did not include larger multi-Tx/Rx cases.');
assert(max(coverage.TxAntennaCounts) >= 4 && max(coverage.RxAntennaCounts) >= 3, ...
    'Coverage did not include antenna-count variation.');
end


function coverage = localEmptyCoverage()
    % localEmptyCoverage - Production declaration in CSRD.
    % 中文说明：localEmptyCoverage 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
coverage = struct( ...
    'RegionIds', strings(0, 1), ...
    'Bands', strings(0, 1), ...
    'Modulations', strings(0, 1), ...
    'RFMethods', strings(0, 1), ...
    'MapTypes', strings(0, 1), ...
    'MapFlavors', strings(0, 1), ...
    'ChannelModels', strings(0, 1), ...
    'AntennaCombos', strings(0, 1), ...
    'TxCounts', zeros(0, 1), ...
    'RxCounts', zeros(0, 1), ...
    'TxAntennaCounts', zeros(0, 1), ...
    'RxAntennaCounts', zeros(0, 1));
end


function merged = localMergeCoverage(a, b)
    % localMergeCoverage - Production declaration in CSRD.
    % 中文说明：localMergeCoverage 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
merged = a;
names = fieldnames(a);
for k = 1:numel(names)
    name = names{k};
    merged.(name) = [a.(name); b.(name)];
end
end


function types = localAllModulationTypes(configStruct)
    % localAllModulationTypes - Production declaration in CSRD.
    % 中文说明：localAllModulationTypes 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
types = {};
categories = {'digital', 'analog'};
for c = 1:numel(categories)
    category = categories{c};
    names = fieldnames(configStruct.Factories.Modulation.(category));
    for n = 1:numel(names)
        entry = configStruct.Factories.Modulation.(category).(names{n});
        if isstruct(entry) && isfield(entry, 'handle') && ~isempty(entry.handle)
            types{end + 1} = names{n}; %#ok<AGROW>
        end
    end
end
end


function order = localOrderForType(typeId)
    % localOrderForType - Production declaration in CSRD.
    % 中文说明：localOrderForType 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
switch char(string(typeId))
    case {'APSK', 'DVBSAPSK', 'QAM', 'Mill88QAM', 'OFDM', 'OTFS', 'SCFDMA'}
        order = 16;
    case {'ASK', 'PSK', 'OQPSK'}
        order = 4;
    case {'CPFSK', 'GFSK', 'GMSK', 'MSK', 'FSK', 'OOK'}
        order = 2;
    otherwise
        order = 1;
end
end


function ratio = localBandwidthRatioForType(typeId)
    % localBandwidthRatioForType - Production declaration in CSRD.
    % 中文说明：localBandwidthRatioForType 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
switch char(string(typeId))
    case {'OFDM', 'OTFS', 'SCFDMA'}
        ratio = 0.075;
    case {'FM', 'PM', 'AM', 'SSBAM', 'DSBAM', 'DSBSCAM', 'VSBAM'}
        ratio = 0.01;
    otherwise
        ratio = 0.05;
end
end


function n = localAntennaCountForType(typeId)
    % localAntennaCountForType - Production declaration in CSRD.
    % 中文说明：localAntennaCountForType 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
n = localTxAntennasForModulationType(typeId, 1);
end


function n = localTxAntennasForRegulatoryBand(regionId, bandId, requestedCount)
    % localTxAntennasForRegulatoryBand - Choose a stable antenna count for a regulatory band.
    % 中文说明：根据法规频段可能抽到的调制族，选择不会被调制器静默降级的发射天线数。
    % Inputs / 输入: region id, band id, requested Tx antenna count.
    % 输出 / Outputs: compatible Tx antenna count for the generated case.
catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(regionId);
bands = catalog.Bands;
idx = find(strcmpi({bands.BandId}, char(string(bandId))), 1, 'first');
if isempty(idx)
    n = localClampTxAntennas(requestedCount);
    return;
end
families = bands(idx).AllowedModulationFamilies;
if localAllModulationFamiliesSupportMultiTx(families)
    n = localClampTxAntennas(requestedCount);
else
    n = 1;
end
end


function n = localTxAntennasForModulationType(typeId, requestedCount)
    % localTxAntennasForModulationType - Respect requested antennas only for multi-Tx capable modulators.
    % 中文说明：只有调制器支持多发射天线时才使用请求值，否则固定为 1，避免标注与信号不一致。
    % Inputs / 输入: modulation type id and requested Tx antenna count.
    % 输出 / Outputs: compatible Tx antenna count.
if localAllModulationFamiliesSupportMultiTx({char(string(typeId))})
    n = localClampTxAntennas(requestedCount);
else
    n = 1;
end
end


function tf = localAllModulationFamiliesSupportMultiTx(families)
    % localAllModulationFamiliesSupportMultiTx - Detect families that can keep requested Tx antennas.
    % 中文说明：判断允许集合中的每个调制族是否都能保持请求的多发射天线数量。
    % Inputs / 输入: cell array or string array of modulation family names.
    % 输出 / Outputs: true when random selection cannot pick a single-antenna-only family.
if isstring(families)
    families = cellstr(families);
elseif ischar(families)
    families = {families};
end
multiTxFamilies = {'ASK', 'APSK', 'DVBSAPSK', 'OFDM', 'OTFS', ...
    'OQPSK', 'PSK', 'QAM', 'SCFDMA'};
tf = ~isempty(families) && all(ismember(upper(string(families)), upper(string(multiTxFamilies))));
end


function n = localClampTxAntennas(requestedCount)
    % localClampTxAntennas - Clamp requested Tx antennas to supported hardware range.
    % 中文说明：将请求的发射天线数限制在当前调制/信道链路支持的 1 到 4 范围。
    % Inputs / 输入: requested Tx antenna count.
    % 输出 / Outputs: integer Tx antenna count.
n = max(1, min(4, round(double(requestedCount))));
end


function path = localFindBuildingOsm(projectRoot)
    % localFindBuildingOsm - Production declaration in CSRD.
    % 中文说明：localFindBuildingOsm 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
path = '';
files = dir(fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Dense_Urban_Mid_Rise', '*.osm'));
if ~isempty(files)
    path = fullfile(files(1).folder, files(1).name);
end
end


function tf = localIsEnvironmentLimitation(ME)
    % localIsEnvironmentLimitation - Production declaration in CSRD.
    % 中文说明：localIsEnvironmentLimitation 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
message = lower(ME.message);
identifier = lower(ME.identifier);
patterns = {'license', 'toolbox', 'siteviewer', 'txsite', ...
    'propagationmodel', 'raytrace', 'rf propagation'};
tf = any(contains(message, patterns)) || any(contains(identifier, patterns));
end


function record = localEmptyRecord()
    % localEmptyRecord - Production declaration in CSRD.
    % 中文说明：localEmptyRecord 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
record = struct( ...
    'Index', 0, ...
    'Name', "", ...
    'Status', "", ...
    'SkipReason', "", ...
    'ConfigPath', "", ...
    'OutputDirectory', "", ...
    'AnnotationPath', "", ...
    'NumSources', 0, ...
    'NumReceivers', 0, ...
    'ErrorIdentifier', "", ...
    'ErrorMessage', "");
end


function summary = localMakeSummary(configName, opts, cases, records, ...
    coverage, passed, skipped, failed, dryRun)
        % localMakeSummary - Production declaration in CSRD.
        % 中文说明：localMakeSummary 在 CSRD 生产链路中执行对应处理。
        % Inputs / 输入: see signature arguments and local validation.
        % 输出 / Outputs: see signature return values and contract fields.
summary = struct( ...
    'ConfigName', string(configName), ...
    'OutputDirectory', string(opts.OutputDirectory), ...
    'CasesBuilt', numel(cases), ...
    'CasesSelected', numel(records), ...
    'CasesPassed', passed, ...
    'CasesSkipped', skipped, ...
    'CasesFailed', failed, ...
    'DryRun', dryRun, ...
    'Records', records, ...
    'Coverage', coverage);
end


function localWriteSummary(summaryRoot, configName, opts, cases, records, ...
    coverage, passed, skipped, failed, dryRun)
        % localWriteSummary - Production declaration in CSRD.
        % 中文说明：localWriteSummary 在 CSRD 生产链路中执行对应处理。
        % Inputs / 输入: see signature arguments and local validation.
        % 输出 / Outputs: see signature return values and contract fields.
if ~exist(summaryRoot, 'dir'); mkdir(summaryRoot); end
summary = localMakeSummary(configName, opts, cases, records, coverage, ...
    passed, skipped, failed, dryRun);
[clean, ~] = csrd.pipeline.annotation.sanitizeForJson(summary);
txt = jsonencode(clean, 'PrettyPrint', true);
summaryPath = fullfile(summaryRoot, ...
    sprintf('%s_summary.json', localSafeName(opts.Mode)));
fid = fopen(summaryPath, 'w');
assert(fid > 0, 'Could not write Phase 13 summary: %s', summaryPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end


function safe = localSafeName(value)
    % localSafeName - Production declaration in CSRD.
    % 中文说明：localSafeName 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
safe = regexprep(char(string(value)), '[^A-Za-z0-9_]', '_');
safe = regexprep(safe, '_+', '_');
safe = lower(safe);
safe = matlab.lang.makeValidName(safe);
end


function escaped = localEscapeMatlabChar(value)
    % localEscapeMatlabChar - Production declaration in CSRD.
    % 中文说明：localEscapeMatlabChar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
escaped = strrep(char(string(value)), '''', '''''');
end
