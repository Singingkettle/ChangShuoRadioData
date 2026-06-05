function cfg = buildRuntimePlanForTest(cfg)
%BUILDRUNTIMEPLANFORTEST Build RuntimePlan for test fixtures.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

if isstruct(cfg) && isfield(cfg, 'PhysicalEnvironment') && ...
        isfield(cfg, 'CommunicationBehavior')
    master = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    master.Factories.Scenario = cfg;
    cfg = csrd.pipeline.runtime.buildRuntimePlan(master);
    return;
end
cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);
end
