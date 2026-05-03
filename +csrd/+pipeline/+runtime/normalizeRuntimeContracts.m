function config = normalizeRuntimeContracts(config)
%NORMALIZERUNTIMECONTRACTS Stamp derived runtime contract fields after config load.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：配置加载后写入派生运行合同字段；旧别名不再被接收。

if nargin < 1 || isempty(config) || ~isstruct(config) || ...
        ~isfield(config, 'Factories') || ~isstruct(config.Factories) || ...
        ~isfield(config.Factories, 'Scenario') || ...
        ~isstruct(config.Factories.Scenario)
    return;
end

runnerConfig = struct();
if isfield(config, 'Runner') && isstruct(config.Runner)
    runnerConfig = config.Runner;
end

contract = csrd.pipeline.runtime.resolveFrameRuntimeContract( ...
    config.Factories, runnerConfig);
truthContract = csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
    config.Factories, runnerConfig);

config.Factories.Scenario.Global.FrameNumSamples = contract.FrameNumSamples;
config.Factories.Scenario.Global.FrameDuration = contract.FrameDurationSec;
config.Factories.Scenario.Global.ObservationDuration = ...
    contract.FrameDurationSec * contract.NumFramesPerScenario;

config.Metadata.RuntimeContracts.Frame = contract;
config.Metadata.RuntimeContracts.RuntimeTruth = truthContract;
end
