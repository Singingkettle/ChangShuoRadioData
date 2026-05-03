classdef EntitySyncFailFastTest < matlab.unittest.TestCase
    % EntitySyncFailFastTest
    %
    % Phase 1 / A4: CommunicationBehaviorSimulator.stepImpl must
    % refuse to fabricate a frame when entity synchronisation fails.
    %
    %   * Empty `entities` argument           => CSRD:Scenario:EmptyEntities
    %   * Sync collapse (drift) on later frame => CSRD:Scenario:EntityDriftDetected
    %
    % Both identifiers must be recognised by isScenarioSkipException so
    % SimulationRunner can translate them into a "scenario skipped"
    % record instead of crashing the run.

    methods (Test)

        function emptyEntitiesIsScenarioSkip(testCase)
            sim = csrd.blocks.scenario.CommunicationBehaviorSimulator();
            try
                sim(1, []);
                testCase.fatalAssertFail( ...
                    'Expected CSRD:Scenario:EmptyEntities for empty entities.');
            catch ME
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Scenario:EmptyEntities', ...
                    'Identifier must be CSRD:Scenario:EmptyEntities.');
                testCase.verifyTrue( ...
                    csrd.pipeline.scenario.isScenarioSkipException(ME), ...
                    'EmptyEntities must be on the scenario-skip whitelist.');
            end
        end

        function emptyEntitiesIdentifierIsWhitelisted(testCase)
            ME = MException('CSRD:Scenario:EmptyEntities', 'sample');
            testCase.verifyTrue( ...
                csrd.pipeline.scenario.isScenarioSkipException(ME));
        end

        function entityDriftIdentifierIsWhitelisted(testCase)
            ME = MException('CSRD:Scenario:EntityDriftDetected', 'sample');
            testCase.verifyTrue( ...
                csrd.pipeline.scenario.isScenarioSkipException(ME));
        end

        function nonRecognisedIdentifierStaysOff(testCase)
            ME = MException('Some:Other:Error', 'sample');
            testCase.verifyFalse( ...
                csrd.pipeline.scenario.isScenarioSkipException(ME), ...
                'Unrelated identifiers must not become scenario-skip.');
        end

    end

end
