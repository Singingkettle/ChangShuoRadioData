classdef UnsupportedStatefulMobilityFailsFastTest < matlab.unittest.TestCase
    %UNSUPPORTEDSTATEFULMOBILITYFAILSFASTTEST Stateful mobility cannot be approximated.

    methods (Test)
        function randomWalkCannotBeEvaluatedWithoutAPathModel(testCase)
            scenarioPlan = localScenarioPlanWithMobility('RandomWalk');

            testCase.verifyError(@() ...
                csrd.pipeline.scenario.evaluateEntityState( ...
                    scenarioPlan, 'Tx1', 0.5), ...
                'CSRD:ScenarioPlan:UnsupportedStatefulMobility');
        end

        function nonZeroInitialTimeFailsFast(testCase)
            scenarioPlan = localScenarioPlanWithMobility('ConstantVelocity');
            scenarioPlan.Entities.Initial.CreationTime = 0.1;

            testCase.verifyError(@() ...
                csrd.pipeline.scenario.evaluateEntityState( ...
                    scenarioPlan, 'Tx1', 0.5), ...
                'CSRD:ScenarioPlan:InitialEntityNotAtZero');
        end
    end
end

function scenarioPlan = localScenarioPlanWithMobility(mobility)
entity = struct();
entity.ID = 'Tx1';
entity.Type = 'Transmitter';
entity.CreationTime = 0;
entity.LastUpdateTime = 0;
entity.Position = [0, 0, 10];
entity.PositionUnit = 'meters';
entity.Velocity = [1, 0, 0];
entity.MobilityModel = mobility;

scenarioPlan = struct();
scenarioPlan.Entities = struct('Initial', entity);
scenarioPlan.Map = struct('Boundaries', [-100, 100, -100, 100]);
end
