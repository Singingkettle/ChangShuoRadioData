function test_phase8_regulatory_pipeline_smoke()
    %TEST_PHASE8_REGULATORY_PIPELINE_SMOKE End-to-end regulatory spectrum smoke.
    %
    % Runs the normal SimulationRunner entrypoint with a China FM broadcast
    % monitoring band. The assertion is intentionally business-level:
    % the regulatory catalog must determine receiver RF center, Tx
    % bandwidth/modulation, and Truth.Design.Regulatory in annotation v2.

    fprintf('=== Phase 8 regulatory pipeline smoke ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    csrd.utils.logger.GlobalLogManager.reset();
    csrd.utils.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase8_regulatory_smoke');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    csrd.utils.logger.GlobalLogManager.initialize(struct( ...
        'Name', 'CSRD-Phase8-Regulatory-Smoke', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false), runRoot);
    policy = csrd.utils.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260428, 'twister');
    cfg = csrd.utils.config_loader('csrd2025/csrd2025.m');
    cfg.Runner.NumScenarios = 1;
    cfg.Runner.RandomSeed = 20260428;
    cfg.Runner.Toolbox.Level = 'minimal';
    cfg.Runner.Data.OutputDirectory = runRoot;
    cfg.Runner.Data.CompressData = false;
    cfg.Factories.Channel.PreferredType = 'AWGN';

    cfg.Factories.Scenario.Global.NumFramesPerScenario = 1;
    cfg.Factories.Scenario.Global.ObservationDuration = 0.005;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1.0;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
    cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 20e6;
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = 'Fixed';
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = 'CN';
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = 'Tier1';
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = 'CN_FM_BROADCAST';
    cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = ...
        {'Radar','Radiolocation','Radionavigation'};

    annotationPath = localRunOneScenario(cfg);
    result = csrd.utils.annotation.readAnnotationV2(annotationPath, ...
        'RequireSources', true, 'RequireRuntimeHeader', true);

    sources = result.Sources;
    assert(~isempty(sources), ...
        'Phase 8 smoke: expected at least one SignalSource.');

    sawRegulatory = false;
    for k = 1:numel(sources)
        design = sources{k}.Truth.Design;
        assert(isfield(design, 'Regulatory'), ...
            'Phase 8 smoke: Truth.Design.Regulatory missing.');
        reg = design.Regulatory;
        assert(strcmp(char(reg.RegionId), 'CN'), ...
            'Phase 8 smoke: expected CN RegionId, got %s.', char(reg.RegionId));
        assert(strcmp(char(reg.BandId), 'CN_FM_BROADCAST'), ...
            'Phase 8 smoke: expected CN_FM_BROADCAST BandId, got %s.', char(reg.BandId));
        assert(strcmp(char(design.ModulationFamily), 'FM'), ...
            'Phase 8 smoke: FM broadcast band must not select %s.', ...
            char(design.ModulationFamily));
        assert(design.PlannedBandwidthHz <= 200e3 + 1, ...
            'Phase 8 smoke: FM planned bandwidth %.0f Hz is not catalog-constrained.', ...
            design.PlannedBandwidthHz);
        assert(isfinite(reg.SelectedCenterFrequencyHz) && ...
            reg.SelectedCenterFrequencyHz >= 87e6 && ...
            reg.SelectedCenterFrequencyHz <= 108e6, ...
            'Phase 8 smoke: selected FM center %.0f Hz is outside CN FM band.', ...
            reg.SelectedCenterFrequencyHz);
        sawRegulatory = true;
    end
    assert(sawRegulatory, ...
        'Phase 8 smoke: no source carried regulatory design truth.');

    fprintf('=== Phase 8 regulatory pipeline smoke PASSED ===\n');
end


function annotationPath = localRunOneScenario(cfg)
runner = csrd.SimulationRunner( ...
    'RunnerConfig', cfg.Runner, 'FactoryConfigs', cfg.Factories);
setup(runner);
cleanup = onCleanup(@() localRelease(runner));
step(runner, 1, 1);

warnState = warning('off', 'MATLAB:structOnObject');
warnGuard = onCleanup(@() warning(warnState)); %#ok<NASGU>
s = struct(runner);
outDir = s.actualOutputDirectory;
annotationPath = fullfile(outDir, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Phase 8 smoke: annotation file was not written: %s', annotationPath);
end


function localRelease(runner)
if isLocked(runner)
    release(runner);
end
end
