function test_phase21_stage_timing_runner_hook()
%TEST_PHASE21_STAGE_TIMING_RUNNER_HOOK Verify opt-in runner timing artifacts.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tests', 'regression'));

csrd.runtime.logger.GlobalLogManager.reset();
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() localCleanup(tempRoot));

runnerCfg = struct();
runnerCfg.NumScenarios = 1;
runnerCfg.RandomSeed = 42;
runnerCfg.Data.OutputDirectory = fullfile(tempRoot, 'phase21_stage_timing_out');
runnerCfg.Data.CompressData = false;
runnerCfg.Data.PrettyPrintAnnotations = false;
runnerCfg.Engine.Handle = 'Phase0FakeEngine';
runnerCfg.Toolbox.Level = 'minimal';
runnerCfg.Performance.EnableStageTiming = true;
runnerCfg.Performance.ArtifactDirectory = fullfile(tempRoot, 'perf');

masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
masterCfg.Runner = runnerCfg;
masterCfg.Logging.Name = 'CSRD-Phase21-StageTiming';
masterCfg.Logging.Policy = 'LargeMC';
masterCfg.Logging.File.Enabled = true;
masterCfg.Logging.Console.Enabled = false;
masterCfg.Logging.Progress.Mode = 'Summary';
masterCfg = csrd.pipeline.runtime.buildRuntimePlan(masterCfg);

csrd.runtime.logger.GlobalLogManager.initialize( ...
    masterCfg.RuntimePlan.Logging, fullfile(tempRoot, 'logs'));

runner = csrd.SimulationRunner( ...
    'RunnerConfig', runnerCfg, ...
    'FactoryConfigs', masterCfg.Factories, ...
    'RuntimePlan', masterCfg.RuntimePlan);
setup(runner);
step(runner, 1, 1);
release(runner);

matFiles = dir(fullfile(runnerCfg.Performance.ArtifactDirectory, ...
    'phase21-stage-timing-worker*.mat'));
jsonFiles = dir(fullfile(runnerCfg.Performance.ArtifactDirectory, ...
    'phase21-stage-timing-worker*.json'));
heartbeatFiles = dir(fullfile(runnerCfg.Performance.ArtifactDirectory, ...
    'phase28-heartbeat-worker*.json'));
assert(~isempty(matFiles), ...
    'CSRD:Phase21:MissingStageTimingMat', ...
    'Expected stage timing MAT artifact.');
assert(~isempty(jsonFiles), ...
    'CSRD:Phase21:MissingStageTimingJson', ...
    'Expected stage timing JSON artifact.');
assert(~isempty(heartbeatFiles), ...
    'CSRD:Phase28:MissingScenarioHeartbeat', ...
    'Expected live scenario heartbeat JSON artifact.');

loaded = load(fullfile(matFiles(1).folder, matFiles(1).name), ...
    'performanceTrace');
trace = loaded.performanceTrace;
stages = string({trace.Events.Stage});
requiredStages = [
    "Runner.SetupTotal"
    "Scenario.ChangShuoStep"
    "Save.EncodeAnnotationJson"
    "Runner.WorkerTotal"
];
for k = 1:numel(requiredStages)
    assert(any(stages == requiredStages(k)), ...
        'CSRD:Phase21:MissingStageTimingEvent', ...
        'Stage timing artifact missing event "%s".', requiredStages(k));
end
assert(isfield(trace, 'RuntimePerformance'), ...
    'CSRD:Phase22:MissingRuntimePerformanceSnapshot', ...
    'Stage timing artifact must include the Phase 22 runtime counters snapshot.');
assert(isfield(trace.RuntimePerformance, 'Counters'), ...
    'CSRD:Phase22:MissingRuntimePerformanceCounters', ...
    'Runtime performance snapshot must include construction counters.');

heartbeat = jsondecode(fileread(fullfile(heartbeatFiles(1).folder, ...
    heartbeatFiles(1).name)));
assert(isfield(heartbeat, 'StageName') && isfield(heartbeat, 'ScenarioId'), ...
    'CSRD:Phase28:InvalidScenarioHeartbeat', ...
    'Heartbeat must expose the active stage and scenario id.');
end

function localCleanup(pathName)
try
    csrd.runtime.logger.GlobalLogManager.reset();
catch
end
if isfolder(pathName)
    try
        rmdir(pathName, 's');
    catch
    end
end
end
