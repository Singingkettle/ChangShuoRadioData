classdef ScenarioModulationAntennaCompatibilityTest < matlab.unittest.TestCase
    %SCENARIOMODULATIONANTENNACOMPATIBILITYTEST Planner honors modulator limits.

    methods (Test)
        function ookWithFlexibleAntennaRangePlansSingleTxAntenna(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            scenarioCfg = localScenarioConfig('OOK', [1 4]);
            cfg = csrd.test_support.buildRuntimePlanForTest(scenarioCfg);
            factory = csrd.factories.ScenarioFactory('Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupFactory = onCleanup(@() release(factory)); %#ok<NASGU>
            [txConfigs, ~, ~] = factory(1);

            testCase.verifyEqual(txConfigs{1}.Modulation.Type, 'OOK');
            testCase.verifyEqual(txConfigs{1}.Hardware.NumAntennas, 1);
        end

        function ookWithMultiAntennaMinimumFailsFast(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            scenarioCfg = localScenarioConfig('OOK', [2 4]);
            cfg = csrd.test_support.buildRuntimePlanForTest(scenarioCfg);
            factory = csrd.factories.ScenarioFactory('Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupFactory = onCleanup(@() release(factory)); %#ok<NASGU>

            testCase.verifyError(@() factory(1), ...
                'CSRD:Scenario:IncompatibleAntennaModulation');
        end

        function pamWithFlexibleAntennaRangePlansSingleTxAntenna(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);

            scenarioCfg = localScenarioConfig('PAM', [1 4]);
            cfg = csrd.test_support.buildRuntimePlanForTest(scenarioCfg);
            factory = csrd.factories.ScenarioFactory('Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupFactory = onCleanup(@() release(factory)); %#ok<NASGU>
            [txConfigs, ~, ~] = factory(1);

            testCase.verifyEqual(txConfigs{1}.Modulation.Type, 'PAM');
            testCase.verifyEqual(txConfigs{1}.Hardware.NumAntennas, 1);
        end
    end
end

function scenarioCfg = localScenarioConfig(modulationType, antennaRange)
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
scenarioCfg = cfg.Factories.Scenario;
scenarioCfg.Runtime.ScenarioId = 1;
scenarioCfg.Runtime.TotalScenarios = 1;
scenarioCfg.Runtime.RandomSeed = 20260508;
scenarioCfg.Runtime.WorkerId = 1;
scenarioCfg.Validator.Enabled = false;
scenarioCfg.Global.NumFramesPerScenario = 1;
scenarioCfg.Global.FrameNumSamples = 1024;
scenarioCfg.PhysicalEnvironment.Map.Types = {'Statistical'};
scenarioCfg.PhysicalEnvironment.Map.Ratio = 1;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.Model = 'Stationary';
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Min = 0;
scenarioCfg.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Max = 0;
scenarioCfg.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
scenarioCfg.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
scenarioCfg.CommunicationBehavior.Regulatory.Enable = false;
scenarioCfg.CommunicationBehavior.Modulation.Types = {char(string(modulationType))};
scenarioCfg.CommunicationBehavior.Transmitter.NumAntennas.Min = antennaRange(1);
scenarioCfg.CommunicationBehavior.Transmitter.NumAntennas.Max = antennaRange(2);
scenarioCfg.CommunicationBehavior.Receiver.NumAntennas = 1;
scenarioCfg.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
scenarioCfg.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
end
