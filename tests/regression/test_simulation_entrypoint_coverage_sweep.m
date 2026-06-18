function summary = test_simulation_entrypoint_coverage_sweep(varargin)
    %TEST_SIMULATION_ENTRYPOINT_COVERAGE_SWEEP Public simulation.m coverage.
    %
    %   test_simulation_entrypoint_coverage_sweep()
    %   test_simulation_entrypoint_coverage_sweep('Mode', 'extended')

    p = inputParser;
    addParameter(p, 'Mode', 'quick', @(x) any(strcmpi(char(string(x)), ...
        {'quick', 'extended'})));
    addParameter(p, 'IncludeBuildingOSM', true, @islogical);
    addParameter(p, 'StartAt', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'StopAfter', Inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'EnforceCoverage', true, @islogical);
    parse(p, varargin{:});
    mode = lower(char(string(p.Results.Mode)));

    fprintf('=== simulation.m entrypoint coverage sweep (%s) ===\n', mode);

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'tools'));

    cases = localBuildCases(projectRoot, mode, p.Results.IncludeBuildingOSM);
    assert(~isempty(cases), 'No simulation entrypoint coverage cases were built.');

    generatedConfigRoot = fullfile(projectRoot, 'artifacts', 'tests', ...
        'generated_configs', 'simulation_entrypoint_coverage', mode);
    if ~exist(generatedConfigRoot, 'dir'); mkdir(generatedConfigRoot); end

    coverage = localEmptyCoverage();
    skipped = strings(0, 1);
    passed = 0;

    for idx = 1:numel(cases)
        if idx < p.Results.StartAt || idx > p.Results.StopAfter
            continue;
        end
        c = cases(idx);
        if ~isempty(c.SkipReason)
            fprintf('  [SKIP] %s: %s\n', c.Name, c.SkipReason);
            skipped(end + 1, 1) = string(c.Name); %#ok<AGROW>
            continue;
        end

        configPath = localWriteConfig(generatedConfigRoot, projectRoot, mode, c, idx);
        csrd.runtime.logger.GlobalLogManager.reset();
        try
            simulation(1, 1, configPath);
        catch ME
            csrd.runtime.logger.GlobalLogManager.reset();
            if c.AllowEnvironmentSkip && localIsEnvironmentLimitation(ME)
                fprintf('  [SKIP] %s: environment limitation: %s\n', ...
                    c.Name, ME.message);
                skipped(end + 1, 1) = string(c.Name); %#ok<AGROW>
                continue;
            end
            rethrow(ME);
        end
        csrd.runtime.logger.GlobalLogManager.reset();

        annotationPath = localFindAnnotation(projectRoot, mode, c);
        result = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
            'RequireSources', true, 'RequireRuntimeHeader', true);
        caseCoverage = localAssertCaseResult(result, c);
        coverage = localMergeCoverage(coverage, caseCoverage);
        passed = passed + 1;

        fprintf('  [OK] %s -> sources=%d receivers=%d\n', ...
            c.Name, result.Summary.NumSources, result.Summary.NumReceivers);
    end

    if p.Results.EnforceCoverage
        localAssertCoverage(coverage, mode, passed);
    else
        assert(passed > 0, 'No selected simulation entrypoint cases passed.');
    end

    summary = struct( ...
        'Mode', mode, ...
        'CasesBuilt', numel(cases), ...
        'CasesPassed', passed, ...
        'CasesSkipped', numel(skipped), ...
        'SkippedCases', skipped, ...
        'Coverage', coverage);

    fprintf(['  Summary: passed=%d skipped=%d regions=%d bands=%d ', ...
        'modulations=%d rfMethods=%d antennaCombos=%d\n'], ...
        summary.CasesPassed, summary.CasesSkipped, ...
        numel(unique(coverage.RegionIds)), numel(unique(coverage.Bands)), ...
        numel(unique(coverage.Modulations)), numel(unique(coverage.RFMethods)), ...
        numel(unique(coverage.AntennaCombos)));
    fprintf('=== simulation.m entrypoint coverage sweep PASSED (%s) ===\n', mode);
end

function cases = localBuildCases(projectRoot, mode, includeBuildingOSM)
cases = repmat(localDefaultCase('placeholder'), 0, 1);

regulatoryCases = { ...
    'CN', 'CN_FM_BROADCAST'; ...
    'CN', 'CN_NR_N78'; ...
    'US', 'US_ISM_915'; ...
    'EU', 'EU_DAB_VHF'; ...
    'JP', 'JP_ISDB_UHF'; ...
    'KR', 'KR_SRD_920'; ...
    'CN', 'CN_LAND_MOBILE_VHF'; ...
    'CN', 'CN_ISM_24'};
if strcmp(mode, 'quick')
    regulatoryCases = regulatoryCases(1:4, :);
end
for k = 1:size(regulatoryCases, 1)
    region = regulatoryCases{k, 1};
    band = regulatoryCases{k, 2};
    c = localDefaultCase(sprintf('reg_%s_%s', region, band));
    c.Regulatory = true;
    c.RegionId = region;
    c.BandId = band;
    c.SampleRateHz = 50e6;
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
c = localDefaultCase('osm_flat_KR_SRD_920');
c.Regulatory = true;
c.RegionId = 'KR';
c.BandId = 'KR_SRD_920';
c.MapType = 'OSM';
c.OSMFile = openOcean;
c.ExpectChannelModel = 'RayTracing';
c.SampleRateHz = 20e6;
c.TxCount = 2;
c.RxCount = 2;
if exist(openOcean, 'file') ~= 2
    c.SkipReason = 'selected flat-terrain OSM file is missing';
end
cases(end + 1) = c;

if includeBuildingOSM && strcmp(mode, 'extended')
    c = localDefaultCase('osm_building_CN_ISM_24');
    c.Regulatory = true;
    c.RegionId = 'CN';
    c.BandId = 'CN_ISM_24';
    c.MapType = 'OSM';
    c.OSMFile = localFindBuildingOsm(projectRoot);
    c.ExpectChannelModel = 'RayTracing';
    c.AllowEnvironmentSkip = true;
    c.SampleRateHz = 20e6;
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

if strcmp(mode, 'extended')
    modulationTypes = localAllModulationTypes(projectRoot);
else
    modulationTypes = {'APSK', 'GMSK', 'MSK', 'OFDM', 'QAM', 'FM'};
end
for k = 1:numel(modulationTypes)
    typeId = modulationTypes{k};
    c = localDefaultCase(sprintf('legacy_mod_%s', typeId));
    c.Regulatory = false;
    c.ModulationType = typeId;
    c.ModulationOrder = localOrderForType(typeId);
    c.SampleRateHz = 20e6;
    c.BandwidthRatio = localBandwidthRatioForType(typeId);
    c.TxAntMin = localAntennaCountForType(typeId);
    c.TxAntMax = c.TxAntMin;
    cases(end + 1) = c; %#ok<AGROW>
end

rfMethods = { ...
    'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
    'Ghorbani model', 'Modified Rapp model', 'Lookup table'};
if strcmp(mode, 'quick')
    rfMethods = rfMethods([1, 3]);
end
for k = 1:numel(rfMethods)
    c = localDefaultCase(sprintf('rf_%s', localSafeName(rfMethods{k})));
    c.Regulatory = false;
    c.ModulationType = 'QAM';
    c.ModulationOrder = 16;
    c.SampleRateHz = 20e6;
    c.BandwidthRatio = 0.05;
    c.NonlinearityMethod = rfMethods{k};
    cases(end + 1) = c; %#ok<AGROW>
end

antennaCombos = [ ...
    1, 1, 1, 1; ...
    2, 2, 2, 2; ...
    3, 2, 4, 4; ...
    2, 3, 2, 3];
if strcmp(mode, 'quick')
    antennaCombos = antennaCombos(1:2, :);
end
for k = 1:size(antennaCombos, 1)
    c = localDefaultCase(sprintf('multi_%dtx_%drx_%dtxant_%drxant', ...
        antennaCombos(k, 1), antennaCombos(k, 2), ...
        antennaCombos(k, 3), antennaCombos(k, 4)));
    c.Regulatory = false;
    c.ModulationType = 'QAM';
    c.ModulationOrder = 16;
    c.TxCount = antennaCombos(k, 1);
    c.RxCount = antennaCombos(k, 2);
    c.TxAntMin = antennaCombos(k, 3);
    c.TxAntMax = antennaCombos(k, 3);
    c.RxAntennas = antennaCombos(k, 4);
    c.SampleRateHz = 20e6;
    c.BandwidthRatio = 0.04;
    cases(end + 1) = c; %#ok<AGROW>
end
end

function c = localDefaultCase(name)
c = struct( ...
    'Name', char(name), ...
    'Regulatory', true, ...
    'RegionId', 'CN', ...
    'BandId', 'CN_FM_BROADCAST', ...
    'ModulationType', '', ...
    'ModulationOrder', 0, ...
    'MapType', 'Statistical', ...
    'OSMFile', '', ...
    'TxCount', 1, ...
    'RxCount', 1, ...
    'TxAntMin', 1, ...
    'TxAntMax', 1, ...
    'RxAntennas', 1, ...
    'SampleRateHz', 50e6, ...
    'BandwidthRatio', 0.05, ...
    'NonlinearityMethod', '', ...
    'ExpectChannelModel', '', ...
    'AllowEnvironmentSkip', false, ...
    'SkipReason', '', ...
    'Seed', 20260428);
end

function configPath = localWriteConfig(rootDir, projectRoot, mode, c, idx)
fn = sprintf('csrd_sim_entry_%03d_%s', idx, localSafeName(c.Name));
configPath = fullfile(rootDir, [fn '.m']);
fid = fopen(configPath, 'w');
assert(fid > 0, 'Could not write generated config: %s', configPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'function config = %s()\n', fn);
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
fprintf(fid, 'config.Runner.Toolbox.Level = ''minimal'';\n');
fprintf(fid, 'config.Runner.Data.OutputDirectory = fullfile(''..'', ''artifacts'', ''tests'', ''runs'', ''simulation_entrypoint_coverage'', ''%s'', ''%s'');\n', ...
    mode, localSafeName(c.Name));
fprintf(fid, 'config.Runner.Data.CompressData = false;\n');
fprintf(fid, 'config.Logging.Name = ''CSRD-SimEntryCoverage'';\n');
fprintf(fid, 'config.Logging.Policy = ''LargeMC'';\n');
fprintf(fid, 'config.Logging.File.Enabled = true;\n');
fprintf(fid, 'config.Logging.Console.Enabled = false;\n');
fprintf(fid, 'config.Logging.Progress.Mode = ''Summary'';\n\n');

frameSamples = round(0.0015 * c.SampleRateHz);
fprintf(fid, 'config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = ''Fixed'';\n');
fprintf(fid, 'config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Value = 1;\n');
fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = ''Fixed'';\n');
fprintf(fid, 'config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = %d;\n', ...
    frameSamples);
fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Types = {''%s''};\n', c.MapType);
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
    fprintf(fid, 'config.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ''Statistical'';\n');
end

fprintf(fid, '\nconfig.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = %.17g;\n', c.SampleRateHz);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Receiver.NumAntennas = %d;\n', c.RxAntennas);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Min = %d;\n', c.TxAntMin);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Max = %d;\n', c.TxAntMax);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Min = %.17g;\n', c.BandwidthRatio);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Max = %.17g;\n', c.BandwidthRatio);
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {''Continuous''};\n');
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1.0;\n');
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Message.Length.Min = 64;\n');
fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Message.Length.Max = 4096;\n');

if c.Regulatory
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = ''Fixed'';\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = ''%s'';\n', c.RegionId);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = ''Tier1'';\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = ''%s'';\n', c.BandId);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = true;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MaxBandwidthFractionOfSampleRate = 0.5;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.MinimumModulatorSampleRateHz = 250e3;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = {''Radar'', ''Radiolocation'', ''Radionavigation''};\n');
else
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = false;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.Types = {''%s''};\n', c.ModulationType);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.DefaultOrders.%s = %d;\n', ...
        c.ModulationType, c.ModulationOrder);
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.RolloffFactor = 0.25;\n');
    fprintf(fid, 'config.Factories.Scenario.CommunicationBehavior.Modulation.SamplesPerSymbol = 4;\n');
end

if ~isempty(c.NonlinearityMethod)
    escapedMethod = localEscapeMatlabChar(c.NonlinearityMethod);
    fprintf(fid, 'config.Factories.Transmit.Simulation.Nonlinearity.Methods = {''%s''};\n', escapedMethod);
    fprintf(fid, 'config.Factories.Receive.Simulation.Nonlinearity.Methods = {''%s''};\n', escapedMethod);
end
fprintf(fid, 'end\n');

% Keep projectRoot referenced so static analyzers know this helper receives it.
assert(exist(projectRoot, 'dir') == 7, 'Invalid project root.');
end

function annotationPath = localFindAnnotation(projectRoot, mode, c)
caseRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
    'simulation_entrypoint_coverage', mode, localSafeName(c.Name));
sessions = dir(fullfile(caseRoot, 'session_*'));
assert(~isempty(sessions), 'No session directory found for case %s in %s.', ...
    c.Name, caseRoot);
[~, order] = sort([sessions.datenum], 'descend');
sessionDir = fullfile(sessions(order(1)).folder, sessions(order(1)).name);
annotationPath = fullfile(sessionDir, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Annotation file was not written for case %s: %s', c.Name, annotationPath);
end

function coverage = localAssertCaseResult(result, c)
coverage = localEmptyCoverage();
assert(result.Summary.NumReceivers == c.RxCount, ...
    'Case %s expected %d receivers, got %d.', ...
    c.Name, c.RxCount, result.Summary.NumReceivers);
assert(result.Summary.NumSources >= c.TxCount * c.RxCount, ...
    'Case %s expected at least %d sources, got %d.', ...
    c.Name, c.TxCount * c.RxCount, result.Summary.NumSources);

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
    design = source.Truth.Design;
    execution = source.Truth.Execution;
    modulationFamily = char(design.ModulationFamily);
    coverage.Modulations(end + 1, 1) = string(modulationFamily); %#ok<AGROW>
    coverage.TxCounts(end + 1, 1) = c.TxCount; %#ok<AGROW>
    coverage.RxCounts(end + 1, 1) = c.RxCount; %#ok<AGROW>
    coverage.AntennaCombos(end + 1, 1) = string(sprintf('%dtx-%drx-%dtxant-%drxant', ...
        c.TxCount, c.RxCount, round(double(design.NumTransmitAntennas)), c.RxAntennas)); %#ok<AGROW>
    coverage.MapTypes(end + 1, 1) = string(c.MapType); %#ok<AGROW>

    assert(double(design.NumTransmitAntennas) >= c.TxAntMin && ...
        double(design.NumTransmitAntennas) <= c.TxAntMax, ...
        'Case %s Tx antenna count %.0f is outside [%d, %d].', ...
        c.Name, double(design.NumTransmitAntennas), c.TxAntMin, c.TxAntMax);

    if c.Regulatory
        localAssertRegulatoryDesign(design, c);
        coverage.RegionIds(end + 1, 1) = string(c.RegionId); %#ok<AGROW>
        coverage.Bands(end + 1, 1) = string(c.BandId); %#ok<AGROW>
    else
        assert(strcmp(modulationFamily, c.ModulationType), ...
            'Case %s expected modulation %s, got %s.', ...
            c.Name, c.ModulationType, modulationFamily);
    end

    if ~isempty(c.NonlinearityMethod)
        txMethod = localTxNonlinearityMethod(source);
        assert(strcmp(txMethod, c.NonlinearityMethod), ...
            'Case %s expected TX nonlinearity %s, got %s.', ...
            c.Name, c.NonlinearityMethod, txMethod);
        coverage.RFMethods(end + 1, 1) = string(txMethod); %#ok<AGROW>
    end

    if ~isempty(c.ExpectChannelModel)
        channelModel = '';
        if isfield(execution, 'ChannelModel')
            channelModel = char(execution.ChannelModel);
        end
        assert(strcmp(channelModel, c.ExpectChannelModel), ...
            'Case %s expected channel model %s, got %s.', ...
            c.Name, c.ExpectChannelModel, channelModel);
    end
end
end

function localAssertRegulatoryDesign(design, c)
assert(isfield(design, 'Regulatory'), ...
    'Case %s missing Truth.Design.Regulatory.', c.Name);
reg = design.Regulatory;
assert(strcmp(char(reg.RegionId), c.RegionId), ...
    'Case %s expected RegionId %s, got %s.', ...
    c.Name, c.RegionId, char(reg.RegionId));
assert(strcmp(char(reg.BandId), c.BandId), ...
    'Case %s expected BandId %s, got %s.', ...
    c.Name, c.BandId, char(reg.BandId));

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

function method = localTxNonlinearityMethod(source)
method = '';
if isfield(source, 'RFImpairments') && isstruct(source.RFImpairments) && ...
        isfield(source.RFImpairments, 'NonlinearityConfig') && ...
        isstruct(source.RFImpairments.NonlinearityConfig) && ...
        isfield(source.RFImpairments.NonlinearityConfig, 'Method')
    method = char(source.RFImpairments.NonlinearityConfig.Method);
end
end

function method = localRxNonlinearityMethod(frame)
method = '';
if isfield(frame, 'RxImpairments') && isstruct(frame.RxImpairments) && ...
        isfield(frame.RxImpairments, 'MemoryLessNonlinearityConfig') && ...
        isstruct(frame.RxImpairments.MemoryLessNonlinearityConfig) && ...
        isfield(frame.RxImpairments.MemoryLessNonlinearityConfig, 'Method')
    method = char(frame.RxImpairments.MemoryLessNonlinearityConfig.Method);
end
end

function localAssertCoverage(coverage, mode, passed)
assert(passed > 0, 'No simulation entrypoint coverage cases passed.');
assert(any(coverage.MapTypes == "Statistical"), ...
    'Coverage did not include statistical map cases.');
assert(any(coverage.MapTypes == "OSM"), ...
    'Coverage did not include OSM map cases.');
assert(numel(unique(coverage.Modulations)) >= 4, ...
    'Coverage did not include enough modulation families.');
assert(max(coverage.TxCounts) >= 2 && max(coverage.RxCounts) >= 2, ...
    'Coverage did not include multi-transmitter and multi-receiver cases.');

if strcmp(mode, 'extended')
    assert(numel(unique(coverage.RegionIds)) >= 5, ...
        'Extended coverage did not include CN/US/EU/JP/KR regions.');
    assert(numel(unique(coverage.Modulations)) >= 20, ...
        'Extended coverage did not include all configured modulation families.');
    assert(numel(unique(coverage.RFMethods)) >= 6, ...
        'Extended coverage did not include all RF nonlinearity methods.');
    assert(max(coverage.TxCounts) >= 3 && max(coverage.RxCounts) >= 3, ...
        'Extended coverage did not include larger multi-Tx/Rx cases.');
    assert(any(contains(coverage.AntennaCombos, '4txant')) && ...
        any(contains(coverage.AntennaCombos, '3rxant')), ...
        'Extended coverage did not include the requested antenna-count variation.');
end
end

function coverage = localEmptyCoverage()
coverage = struct( ...
    'RegionIds', strings(0, 1), ...
    'Bands', strings(0, 1), ...
    'Modulations', strings(0, 1), ...
    'RFMethods', strings(0, 1), ...
    'MapTypes', strings(0, 1), ...
    'AntennaCombos', strings(0, 1), ...
    'TxCounts', zeros(0, 1), ...
    'RxCounts', zeros(0, 1));
end

function merged = localMergeCoverage(a, b)
merged = a;
names = fieldnames(a);
for k = 1:numel(names)
    name = names{k};
    merged.(name) = [a.(name); b.(name)];
end
end

function types = localAllModulationTypes(projectRoot)
addpath(projectRoot);
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
types = {};
categories = {'digital', 'analog'};
for c = 1:numel(categories)
    category = categories{c};
    names = fieldnames(cfg.Factories.Modulation.(category));
    for n = 1:numel(names)
        entry = cfg.Factories.Modulation.(category).(names{n});
        if isstruct(entry) && isfield(entry, 'handle') && ~isempty(entry.handle)
            types{end + 1} = names{n}; %#ok<AGROW>
        end
    end
end
end

function order = localOrderForType(typeId)
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
if strcmp(char(string(typeId)), 'OFDM')
    n = 2;
else
    n = 1;
end
end

function path = localFindBuildingOsm(projectRoot)
path = '';
files = dir(fullfile(projectRoot, 'data', 'map', 'osm', ...
    'Dense_Urban_Mid_Rise', '*.osm'));
if ~isempty(files)
    path = fullfile(files(1).folder, files(1).name);
end
end

function safe = localSafeName(value)
safe = regexprep(char(string(value)), '[^A-Za-z0-9_]', '_');
safe = regexprep(safe, '_+', '_');
safe = lower(safe);
safe = matlab.lang.makeValidName(safe);
end

function escaped = localEscapeMatlabChar(value)
escaped = strrep(char(string(value)), '''', '''''');
end

function tf = localIsEnvironmentLimitation(ME)
message = lower(ME.message);
identifier = lower(ME.identifier);
patterns = {'license', 'toolbox', 'siteviewer', 'txsite', ...
    'propagationmodel', 'raytrace', 'rf propagation'};
tf = any(contains(message, patterns)) || any(contains(identifier, patterns));
end
