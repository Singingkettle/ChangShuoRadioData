classdef SegmentPlanMidpointGeometryTest < matlab.unittest.TestCase
    %SEGMENTPLANMIDPOINTGEOMETRYTEST Segment midpoint geometry is deterministic.

    methods (Test)
        function constantVelocityUsesMidpointTime(testCase)
            scenarioPlan = localScenarioPlanWithEntity( ...
                'Tx1', 'ConstantVelocity', [10, 20, 5], [2, -4, 0]);

            state = csrd.pipeline.scenario.evaluateEntityState( ...
                scenarioPlan, 'Tx1', 0.25);

            testCase.verifyEqual(state.EvaluationPolicy, 'SegmentMidpoint');
            testCase.verifyEqual(state.PositionM, [10.5, 19, 5], ...
                AbsTol=1e-12);
            testCase.verifyEqual(state.VelocityMps, [2, -4, 0]);
        end

        function stationaryEntityIgnoresStoredVelocity(testCase)
            scenarioPlan = localScenarioPlanWithEntity( ...
                'Rx1', 'Stationary', [1, 2, 3], [9, 9, 0]);

            state = csrd.pipeline.scenario.evaluateEntityState( ...
                scenarioPlan, 'Rx1', 10);

            testCase.verifyEqual(state.PositionM, [1, 2, 5], AbsTol=1e-12);
            testCase.verifyEqual(state.VelocityMps, [0, 0, 0]);
        end
    end
end

function scenarioPlan = localScenarioPlanWithEntity(id, mobility, position, velocity)
entity = struct();
entity.ID = id;
entity.Type = 'Transmitter';
entity.CreationTime = 0;
entity.LastUpdateTime = 0;
entity.Position = position;
entity.PositionUnit = 'meters';
entity.Velocity = velocity;
entity.MobilityModel = mobility;

scenarioPlan = struct();
scenarioPlan.Entities = struct('Initial', entity);
scenarioPlan.Map = struct('Boundaries', [-100, 100, -100, 100]);
end
