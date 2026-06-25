classdef StatisticalMapDistanceContractTest < matlab.unittest.TestCase
    % StatisticalMapDistanceContractTest
    %
    % Guards the Statistical/Grid map coordinate-unit contract: its boundaries
    % are LOCAL METRES [xmin xmax ymin ymax], so generated entity positions and
    % inter-entity distances must stay within those metre extents.
    %
    % Regression: initializeStatisticalMap once stored the raw metre extents
    % into a geographic {MinLatitude,...} struct, so createEntity/geoToLocalMeters
    % treated +/-2000 m as +/-2000 DEGREES and scaled them by deg2rad*earthRadius
    % (~37000x). Emitters were placed tens to hundreds of thousands of km apart
    % (path loss ~200 dB, SNR ~-90 dB) which silently corrupted every
    % Statistical-map link's measured ground truth. These assertions fail loudly
    % if that scaling ever returns.

    methods (Test)

        function statisticalEntitiesStayWithinMetreBoundaries(testCase)
            halfExtent = 2000;
            cfg = localStatisticalConfig([-halfExtent, halfExtent, -halfExtent, halfExtent]);
            sim = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg);
            entities = step(sim, 1);

            testCase.verifyNotEmpty(entities);
            diagonal = hypot(2 * halfExtent, 2 * halfExtent);
            positions = zeros(numel(entities), 2);
            for idx = 1:numel(entities)
                entity = entities(idx);
                testCase.verifyEqual(entity.PositionUnit, 'meters');
                testCase.verifyTrue(isnumeric(entity.Position) && numel(entity.Position) == 3);
                % Symmetric metre bounds are centred on 0, so the horizontal
                % extent must not exceed the half-extent (small tolerance for
                % the geographic round-trip used internally).
                testCase.verifyLessThanOrEqual(abs(entity.Position(1)), halfExtent * 1.001);
                testCase.verifyLessThanOrEqual(abs(entity.Position(2)), halfExtent * 1.001);
                positions(idx, :) = entity.Position(1:2);
            end

            % Anti-regression: the largest pairwise distance must be on the order
            % of the map diagonal (kilometres), never the ~1e7-1e8 m produced by
            % the metres-as-degrees bug.
            maxDistance = 0;
            for a = 1:size(positions, 1)
                for b = a + 1:size(positions, 1)
                    maxDistance = max(maxDistance, norm(positions(a, :) - positions(b, :)));
                end
            end
            testCase.verifyLessThanOrEqual(maxDistance, diagonal * 1.01);
        end

    end
end

function cfg = localStatisticalConfig(boundaries)
cfg = struct();
cfg.TimeResolution = 1024 / 50e6;
cfg.Map.Type = 'Grid';
cfg.Map.Boundaries = boundaries;
cfg.Map.Resolution = 100;
cfg.Entities.Transmitters.Count = struct('Min', 4, 'Max', 4);
cfg.Entities.Transmitters.Mobility.Model = 'Stationary';
cfg.Entities.Transmitters.Mobility.MaxSpeedMps = 15;
cfg.Entities.Receivers.Count = struct('Min', 1, 'Max', 1);
cfg.Entities.Receivers.Mobility.Model = 'Stationary';
cfg.Entities.Receivers.Mobility.MaxSpeedMps = 0;
cfg.Environment.Weather.Enable = false;
cfg.Environment.Obstacles.Enable = false;
cfg.Mobility.EnableCollisionAvoidance = false;
cfg.Global.NumFramesPerScenario = 2;
end
