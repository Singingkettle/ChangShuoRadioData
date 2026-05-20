function test_phase8_regulatory_unified_coverage_sweep()
    %TEST_PHASE8_REGULATORY_UNIFIED_COVERAGE_SWEEP Service matrix via SimulationRunner.
    %
    % This regression runs the public generation entrypoint across a
    % representative regulatory service matrix. It asserts that the chosen
    % frequency, bandwidth, modulation family, source references, and service
    % metadata in annotation v2 are still traceable to the regional catalog.

    fprintf('=== Phase 8 regulatory unified coverage sweep ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    cases = [
        localCase('CN', 'CN_FM_BROADCAST')
        localCase('CN', 'CN_LAND_MOBILE_VHF')
        localCase('CN', 'CN_ISM_24')
        localCase('CN', 'CN_NR_N78')
        localCase('US', 'US_ISM_915')
        localCase('EU', 'EU_DAB_VHF')
        localCase('JP', 'JP_ISDB_UHF')
        localCase('KR', 'KR_SRD_920')];

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase8_unified_coverage');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    observedBands = strings(0, 1);
    observedServices = strings(0, 1);
    observedFamilies = strings(0, 1);
    sourceCount = 0;

    for k = 1:numel(cases)
        c = cases(k);
        csrd.runtime.logger.GlobalLogManager.reset();
        caseRoot = fullfile(runRoot, sprintf('%02d_%s_%s', ...
            k, c.RegionId, c.BandId));
        if ~exist(caseRoot, 'dir'); mkdir(caseRoot); end
        csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
            'Name', sprintf('CSRD-Phase8-Coverage-%s-%s', c.RegionId, c.BandId), ...
            'Level', 'WARNING', ...
            'SaveToFile', true, ...
            'DisplayInConsole', false), caseRoot);
        policy = csrd.runtime.logger.policy.LogPolicy('Standard');
        policy.apply();

        rng(20260428 + 100 + k, 'twister');
        cfg = localConfig(caseRoot, c, k);
        annotationPath = localRunOneScenario(cfg);
        result = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
            'RequireSources', true, 'RequireRuntimeHeader', true);

        [caseBands, caseServices, caseFamilies, n] = ...
            localAssertAnnotation(result.Sources, c);
        observedBands = [observedBands; caseBands]; %#ok<AGROW>
        observedServices = [observedServices; caseServices]; %#ok<AGROW>
        observedFamilies = [observedFamilies; caseFamilies]; %#ok<AGROW>
        sourceCount = sourceCount + n;
    end

    assert(sourceCount >= numel(cases), ...
        'Phase 8 unified sweep: expected at least one source per case.');
    assert(numel(unique(observedBands)) >= 6, ...
        'Phase 8 unified sweep: insufficient band diversity.');
    assert(numel(unique(observedServices)) >= 4, ...
        'Phase 8 unified sweep: insufficient service-class diversity.');
    assert(numel(unique(observedFamilies)) >= 4, ...
        'Phase 8 unified sweep: insufficient modulation-family diversity.');

    fprintf(['  Sources=%d, Bands=%d, ServiceClasses=%d, ', ...
        'ModulationFamilies=%d\n'], sourceCount, numel(unique(observedBands)), ...
        numel(unique(observedServices)), numel(unique(observedFamilies)));
    fprintf('=== Phase 8 regulatory unified coverage sweep PASSED ===\n');
end


function c = localCase(regionId, bandId)
c = struct('RegionId', regionId, 'BandId', bandId);
end


function cfg = localConfig(outputRoot, c, idx)
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg.Runner.NumScenarios = 1;
cfg.Runner.RandomSeed = 20260500 + idx;
cfg.Runner.Toolbox.Level = 'minimal';
cfg.Runner.Data.OutputDirectory = outputRoot;
cfg.Runner.Data.CompressData = false;

cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1.0;
cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = 'AWGN';
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;

cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;
cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.002, 1);
cfg.Factories.Scenario.CommunicationBehavior.Message.Length.Min = 64;
cfg.Factories.Scenario.CommunicationBehavior.Message.Length.Max = 4096;
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = 'Fixed';
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = c.RegionId;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = 'Tier1';
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = c.BandId;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = true;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MaxBandwidthFractionOfSampleRate = 0.5;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = ...
    {'Radar','Radiolocation','Radionavigation'};
end


function annotationPath = localRunOneScenario(cfg)
cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
runner = csrd.SimulationRunner( ...
    'RunnerConfig', cfg.Runner, ...
    'FactoryConfigs', cfg.Factories, ...
    'RuntimePlan', cfg.RuntimePlan);
setup(runner);
cleanup = onCleanup(@() localRelease(runner)); %#ok<NASGU>
step(runner, 1, 1);

warnState = warning('off', 'MATLAB:structOnObject');
warnGuard = onCleanup(@() warning(warnState)); %#ok<NASGU>
s = struct(runner);
annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Phase 8 unified sweep: annotation file was not written: %s', annotationPath);
end


function [bands, services, families, sourceCount] = localAssertAnnotation(sources, c)
assert(~isempty(sources), ...
    'Phase 8 unified sweep %s/%s: expected SignalSource entries.', ...
    c.RegionId, c.BandId);

catalog = csrd.catalog.spectrum.RegionSpectrumCatalog.load(c.RegionId);
bandIdx = find(strcmp({catalog.Bands.BandId}, c.BandId), 1, 'first');
assert(~isempty(bandIdx), ...
    'Phase 8 unified sweep: missing catalog band %s/%s.', c.RegionId, c.BandId);
catalogBand = catalog.Bands(bandIdx);

bands = strings(0, 1);
services = strings(0, 1);
families = strings(0, 1);
sourceCount = numel(sources);

for k = 1:numel(sources)
    design = sources{k}.Truth.Design;
    assert(isfield(design, 'Regulatory'), ...
        'Phase 8 unified sweep %s/%s: missing Truth.Design.Regulatory.', ...
        c.RegionId, c.BandId);
    reg = design.Regulatory;

    assert(strcmp(char(reg.RegionId), c.RegionId), ...
        'Expected RegionId %s, got %s.', c.RegionId, char(reg.RegionId));
    assert(strcmp(char(reg.BandId), c.BandId), ...
        'Expected BandId %s, got %s.', c.BandId, char(reg.BandId));
    assert(strcmp(char(reg.Authority), catalog.Authority), ...
        'Authority drift for %s/%s.', c.RegionId, c.BandId);
    assert(strcmp(char(reg.ServiceClass), catalogBand.ServiceClass), ...
        'ServiceClass drift for %s/%s.', c.RegionId, c.BandId);
    assert(strcmp(char(reg.Application), catalogBand.Application), ...
        'Application drift for %s/%s.', c.RegionId, c.BandId);
    assert(~isempty(reg.SourceRefs), ...
        'SourceRefs must be non-empty for %s/%s.', c.RegionId, c.BandId);
    assert(~isempty(char(reg.EvidenceLevel)), ...
        'EvidenceLevel must be non-empty for %s/%s.', c.RegionId, c.BandId);
    assert(~contains(lower(char(reg.ServiceClass)), 'radar') && ...
        ~contains(lower(char(reg.Application)), 'radar'), ...
        'Radar-like service leaked into Phase 8 generation.');

    selectedCenter = double(reg.SelectedCenterFrequencyHz);
    allowedBw = double(reg.AllowedBandwidthHz);
    assert(isfinite(selectedCenter) && isfinite(allowedBw) && allowedBw > 0, ...
        'Invalid selected center/bandwidth for %s/%s.', c.RegionId, c.BandId);
    assert(selectedCenter - allowedBw / 2 >= catalogBand.FrequencyRangeHz(1) - 1, ...
        'Selected channel lower edge is outside catalog band.');
    assert(selectedCenter + allowedBw / 2 <= catalogBand.FrequencyRangeHz(2) + 1, ...
        'Selected channel upper edge is outside catalog band.');

    recommended = cellfun(@double, catalogBand.RecommendedBandwidthsHz);
    assert(any(abs(recommended - allowedBw) <= max(1, allowedBw * 1e-9)), ...
        'AllowedBandwidthHz %.0f is not a catalog recommendation.', allowedBw);
    assert(abs(double(design.PlannedBandwidthHz) - allowedBw) <= ...
        max(1, allowedBw * 1e-9), ...
        'Design bandwidth does not match regulatory selected bandwidth.');
    assert(ismember(char(design.ModulationFamily), catalogBand.AllowedModulationFamilies), ...
        'Design modulation %s is not allowed for %s/%s.', ...
        char(design.ModulationFamily), c.RegionId, c.BandId);

    bands(end + 1, 1) = string(c.BandId); %#ok<AGROW>
    services(end + 1, 1) = string(reg.ServiceClass); %#ok<AGROW>
    families(end + 1, 1) = string(design.ModulationFamily); %#ok<AGROW>
end
end


function localRelease(runner)
if isLocked(runner)
    release(runner);
end
end
