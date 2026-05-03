function test_phase8_regulatory_region_matrix_smoke()
    %TEST_PHASE8_REGULATORY_REGION_MATRIX_SMOKE Multi-region SimulationRunner smoke.
    %
    % Uses the public SimulationRunner generation interface for every Phase
    % 8 Tier-1 region. Each case pins one representative broadcast band so
    % failures are attributable to regional catalog plumbing rather than
    % stochastic service selection.

    fprintf('=== Phase 8 regulatory region matrix smoke ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    cases = [
        localCase('CN', 'CN_FM_BROADCAST', 'FM')
        localCase('US', 'US_FM_BROADCAST', 'FM')
        localCase('EU', 'EU_FM_BROADCAST', 'FM')
        localCase('JP', 'JP_FM_BROADCAST', 'FM')
        localCase('KR', 'KR_FM_BROADCAST', 'FM')];

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase8_region_matrix');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    for k = 1:numel(cases)
        csrd.runtime.logger.GlobalLogManager.reset();
        caseRoot = fullfile(runRoot, sprintf('%02d_%s', k, cases(k).RegionId));
        if ~exist(caseRoot, 'dir'); mkdir(caseRoot); end
        csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
            'Name', sprintf('CSRD-Phase8-%s', cases(k).RegionId), ...
            'Level', 'WARNING', ...
            'SaveToFile', true, ...
            'DisplayInConsole', false), caseRoot);
        policy = csrd.runtime.logger.policy.LogPolicy('Standard');
        policy.apply();

        rng(20260428 + k, 'twister');
        cfg = localConfig(projectRoot, caseRoot, cases(k), k);
        annotationPath = localRunOneScenario(cfg);
        result = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
            'RequireSources', true, 'RequireRuntimeHeader', true);
        localAssertCase(result.Sources, cases(k));
    end

    fprintf('=== Phase 8 regulatory region matrix smoke PASSED ===\n');
end


function c = localCase(regionId, bandId, modulationFamily)
c = struct('RegionId', regionId, 'BandId', bandId, ...
    'ModulationFamily', modulationFamily);
end


function cfg = localConfig(~, outputRoot, c, idx)
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg.Runner.NumScenarios = 1;
cfg.Runner.RandomSeed = 20260428 + idx;
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

cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 20e6;
cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.003, 1);
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = 'Fixed';
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = c.RegionId;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = 'Tier1';
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = c.BandId;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = ...
    {'Radar','Radiolocation','Radionavigation'};
end


function annotationPath = localRunOneScenario(cfg)
runner = csrd.SimulationRunner( ...
    'RunnerConfig', cfg.Runner, 'FactoryConfigs', cfg.Factories);
setup(runner);
cleanup = onCleanup(@() localRelease(runner)); %#ok<NASGU>
step(runner, 1, 1);

warnState = warning('off', 'MATLAB:structOnObject');
warnGuard = onCleanup(@() warning(warnState)); %#ok<NASGU>
s = struct(runner);
annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Phase 8 region matrix: annotation file was not written: %s', annotationPath);
end


function localAssertCase(sources, c)
assert(~isempty(sources), ...
    'Phase 8 region matrix %s: expected at least one SignalSource.', c.RegionId);
for k = 1:numel(sources)
    design = sources{k}.Truth.Design;
    assert(isfield(design, 'Regulatory'), ...
        'Phase 8 region matrix %s: missing Truth.Design.Regulatory.', c.RegionId);
    reg = design.Regulatory;
    assert(strcmp(char(reg.RegionId), c.RegionId), ...
        'Phase 8 region matrix: expected %s, got %s.', ...
        c.RegionId, char(reg.RegionId));
    assert(strcmp(char(reg.BandId), c.BandId), ...
        'Phase 8 region matrix %s: expected %s, got %s.', ...
        c.RegionId, c.BandId, char(reg.BandId));
    assert(strcmp(char(design.ModulationFamily), c.ModulationFamily), ...
        'Phase 8 region matrix %s: expected %s modulation, got %s.', ...
        c.RegionId, c.ModulationFamily, char(design.ModulationFamily));
    assert(~isempty(reg.SourceRefs), ...
        'Phase 8 region matrix %s: SourceRefs must be non-empty.', c.RegionId);
end
end


function localRelease(runner)
if isLocked(runner)
    release(runner);
end
end
