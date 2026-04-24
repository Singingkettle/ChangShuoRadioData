classdef RandomBitSeedTest < matlab.unittest.TestCase
    % RandomBitSeedTest - Verify reproducibility and bias of RandomBit.
    %
    %   The Seed property is the cornerstone of reproducible dataset
    %   generation. These tests guarantee:
    %     * Identical Seed yields bit-for-bit identical sequences.
    %     * Different Seeds yield different sequences.
    %     * BitProbability bias matches the configured value within a
    %       statistical tolerance.
    %     * Empty Seed (auto-seed mode) still produces a valid sequence.

    methods (Test)

        function sameSeedSameSequence(testCase)
            len = 5000;
            symbolRate = 1e6;
            gen1 = csrd.blocks.physical.message.RandomBit('Seed', 12345);
            gen2 = csrd.blocks.physical.message.RandomBit('Seed', 12345);
            out1 = gen1(len, symbolRate);
            out2 = gen2(len, symbolRate);
            release(gen1); release(gen2);
            testCase.verifyEqual(out1.data, out2.data, ...
                'Identical seeds must produce identical bit sequences.');
            testCase.verifyEqual(numel(out1.data), len);
        end

        function differentSeedsDiffer(testCase)
            len = 5000;
            symbolRate = 1e6;
            gen1 = csrd.blocks.physical.message.RandomBit('Seed', 1);
            gen2 = csrd.blocks.physical.message.RandomBit('Seed', 2);
            out1 = gen1(len, symbolRate);
            out2 = gen2(len, symbolRate);
            release(gen1); release(gen2);
            testCase.verifyNotEqual(out1.data, out2.data, ...
                'Different seeds should produce different sequences.');
        end

        function bitProbabilityBiasIsRespected(testCase)
            targets = [0.1, 0.5, 0.8];
            len = 100000;
            symbolRate = 1e6;
            for p = targets
                gen = csrd.blocks.physical.message.RandomBit( ...
                    'Seed', 7, 'BitProbability', p);
                out = gen(len, symbolRate);
                release(gen);
                actual = mean(out.data);
                testCase.verifyLessThan(abs(actual - p), 0.01, ...
                    sprintf('BitProbability target %.2f but actual %.4f', p, actual));
            end
        end

        function emptySeedStillProducesData(testCase)
            len = 1024;
            gen = csrd.blocks.physical.message.RandomBit('Seed', []);
            out = gen(len, 1e6);
            release(gen);
            testCase.verifyEqual(numel(out.data), len);
            testCase.verifyTrue(all(ismember(out.data, [0 1])));
        end

        function outputOrientationRespected(testCase)
            len = 100;
            genCol = csrd.blocks.physical.message.RandomBit( ...
                'Seed', 3, 'OutputOrientation', 'column');
            genRow = csrd.blocks.physical.message.RandomBit( ...
                'Seed', 3, 'OutputOrientation', 'row');
            outCol = genCol(len, 1e6);
            outRow = genRow(len, 1e6);
            release(genCol); release(genRow);
            testCase.verifyEqual(size(outCol.data), [len, 1]);
            testCase.verifyEqual(size(outRow.data), [1, len]);
        end

        function resetReturnsToInitialSequence(testCase)
            len = 200;
            gen = csrd.blocks.physical.message.RandomBit('Seed', 99);
            firstOut = gen(len, 1e6);
            secondOut = gen(len, 1e6);
            reset(gen);
            thirdOut = gen(len, 1e6);
            release(gen);
            testCase.verifyNotEqual(firstOut.data, secondOut.data, ...
                'Sequential calls must advance the RNG state.');
            testCase.verifyEqual(thirdOut.data, firstOut.data, ...
                'reset() must restore the original sequence.');
        end

    end

end
