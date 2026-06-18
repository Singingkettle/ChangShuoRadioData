function test_phase12_channel_model_pipeline()
    %TEST_PHASE12_CHANNEL_MODEL_PIPELINE Verify map ChannelModel reaches annotation.

    fprintf('=== Phase 12 channel model pipeline regression ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    models = {'Rayleigh', 'Rician'};
    for k = 1:numel(models)
        modelName = models{k};
        annotationPath = localRunPipeline(projectRoot, modelName, k);
        result = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
            'RequireSources', true, 'RequireRuntimeHeader', true);
        sources = result.Sources;
        assert(~isempty(sources), ...
            'Phase 12 pipeline: expected at least one source for %s.', ...
            modelName);
        for s = 1:numel(sources)
            execution = sources{s}.Truth.Execution;
            assert(strcmp(char(execution.ChannelModel), modelName), ...
                ['Phase 12 pipeline: expected Truth.Execution.ChannelModel ', ...
                 '%s, got %s.'], modelName, char(execution.ChannelModel));
        end
        fprintf('  [OK] %s reached Truth.Execution.ChannelModel.\n', modelName);
    end

    fprintf('=== Phase 12 channel model pipeline regression PASSED ===\n');
end

function annotationPath = localRunPipeline(projectRoot, modelName, idx)
csrd.runtime.logger.GlobalLogManager.reset();
csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
    'phase12_channel_model_pipeline', lower(modelName));
if ~exist(runRoot, 'dir')
    mkdir(runRoot);
end

csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
    'Name', ['CSRD-Phase12-ChannelModel-' modelName], ...
    'Level', 'WARNING', ...
    'SaveToFile', true, ...
    'DisplayInConsole', false), runRoot);
policy = csrd.runtime.logger.policy.LogPolicy('Standard');
policy.apply();

rng(20260430 + idx, 'twister');
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg.Runner.NumScenarios = 1;
cfg.Runner.RandomSeed = 20260430 + idx;
cfg.Runner.Toolbox.Level = 'minimal';
cfg.Runner.Data.OutputDirectory = runRoot;
cfg.Runner.Data.CompressData = false;

cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1.0;
cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = modelName;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = false;
cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 1e6;
cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.002, 1);
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
cfg.Factories.Scenario.CommunicationBehavior.Modulation.Types = {'PSK'};
cfg = csrd.test_support.buildRuntimePlanForTest(cfg);

runner = csrd.SimulationRunner( ...
    'RunnerConfig', cfg.Runner, ...
    'FactoryConfigs', cfg.Factories, ...
    'RuntimePlan', cfg.RuntimePlan);
setup(runner);
cleanupObj = onCleanup(@() localRelease(runner)); %#ok<NASGU>
step(runner, 1, 1);

warnState = warning('off', 'MATLAB:structOnObject');
warnGuard = onCleanup(@() warning(warnState)); %#ok<NASGU>
s = struct(runner);
outDir = s.actualOutputDirectory;
annotationPath = fullfile(outDir, 'annotations', ...
    'scenario_000001_annotation.json');
assert(exist(annotationPath, 'file') == 2, ...
    'Phase 12 pipeline: annotation file was not written: %s', ...
    annotationPath);
end

function localRelease(runner)
if isLocked(runner)
    release(runner);
end
end
