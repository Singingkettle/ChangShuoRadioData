classdef FrequencyAllocationStrategyTest < matlab.unittest.TestCase
    %FREQUENCYALLOCATIONSTRATEGYTEST Phase 2 (D7) unit tests covering the
    %fail-fast strategy gate inside performScenarioFrequencyAllocation.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.5.4.
    %
    %   Phase 2 collapses FrequencyAllocation.Strategy down to the single
    %   value 'ReceiverCentric'. The historical 'Optimized' and 'Random'
    %   strategies were thin wrappers that silently delegated to
    %   ReceiverCentric (audit H6 / D7), and the otherwise branch silently
    %   fell back to ReceiverCentric with only a warning. All three silent
    %   fallbacks have been removed, so any non-ReceiverCentric value must
    %   now raise CSRD:Scenario:UnsupportedFrequencyStrategy.
    %
    %   The gate is implemented as a Hidden static method on the simulator
    %   class so it can be exercised in isolation without spinning up the
    %   full PhysicalEnvironment + CommunicationBehavior pipeline.

    methods (TestMethodSetup)
        function silenceLogger(~)
            try
                csrd.runtime.logger.GlobalLogManager.setLevel('error');
            catch
            end
        end
    end

    methods (Test)

        function receiverCentricStrategyPasses(testCase)
            % Golden path: the only supported value must not throw.
            testCase.verifyWarningFree(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy('ReceiverCentric'));
        end

        function optimizedStrategyThrowsUnsupportedError(testCase)
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy('Optimized'), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
        end

        function randomStrategyThrowsUnsupportedError(testCase)
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy('Random'), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
        end

        function unknownStrategyThrowsUnsupportedError(testCase)
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy('typo-strategy'), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
        end

        function emptyStrategyThrowsUnsupportedError(testCase)
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy(''), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
        end

        function nonStringStrategyThrowsUnsupportedError(testCase)
            % Numeric or struct values must also fail fast, not silently
            % coerce or fall through.
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy(42), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
            testCase.verifyError(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy(struct('Strategy', 'ReceiverCentric')), ...
                'CSRD:Scenario:UnsupportedFrequencyStrategy');
        end

        function stringClassReceiverCentricAlsoPasses(testCase)
            % Accept both char arrays and string scalars for ergonomics.
            testCase.verifyWarningFree(@() ...
                csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .validateFrequencyAllocationStrategy(string('ReceiverCentric')));
        end

    end
end
