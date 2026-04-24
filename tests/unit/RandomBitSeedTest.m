classdef RandomBitSeedTest < matlab.unittest.TestCase
    % RandomBitSeedTest - Unit tests for RandomBit reproducibility.
    %
    %   Pins the contract that two RandomBit instances seeded with the
    %   same integer produce identical bit sequences.

    methods (Test)

        function sameSeedSameSequence(testCase)
            a = csrd.blocks.physical.message.RandomBit('Seed', 12345);
            b = csrd.blocks.physical.message.RandomBit('Seed', 12345);
            outA = step(a, 4096, 1e6);
            outB = step(b, 4096, 1e6);
            testCase.verifyEqual(outA.data, outB.data, ...
                'Same seed must yield identical bits.');
        end

        function differentSeedDifferentSequence(testCase)
            a = csrd.blocks.physical.message.RandomBit('Seed', 1);
            b = csrd.blocks.physical.message.RandomBit('Seed', 2);
            outA = step(a, 4096, 1e6);
            outB = step(b, 4096, 1e6);
            testCase.verifyFalse(isequal(outA.data, outB.data), ...
                'Different seeds must yield different bits.');
        end

        function emptySeedUsesDefaultStream(testCase)
            block = csrd.blocks.physical.message.RandomBit('Seed', []);
            out = step(block, 64, 1e6);
            testCase.verifyEqual(numel(out.data), 64);
            testCase.verifyTrue(all(out.data == 0 | out.data == 1));
        end

    end

end
