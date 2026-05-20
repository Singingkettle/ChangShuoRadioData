function cfg = buildRuntimePlanForTest(cfg)
%BUILDRUNTIMEPLANFORTEST Build RuntimePlan for test fixtures.
% 中文说明：测试 fixture 也必须走生产 buildRuntimePlan 入口。

if isstruct(cfg) && isfield(cfg, 'Global') && ...
        isfield(cfg, 'PhysicalEnvironment') && ...
        isfield(cfg, 'CommunicationBehavior')
    master = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    master.Factories.Scenario = cfg;
    cfg = csrd.pipeline.runtime.buildRuntimePlan(master);
    return;
end
cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);
end
