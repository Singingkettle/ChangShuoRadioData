classdef RRFSimulatorTest < matlab.unittest.TestCase
    % RRFSimulatorTest - Pin the receiver RF chain contract.
    %
    %   Validates that csrd.blocks.physical.rxRadioFront.RRFSimulator
    %   actually wires the four documented impairment stages
    %   (LNA -> ThermalNoise -> IQImbalance -> SampleShifter) and that
    %   the previously declared-but-unwired stages (PhaseNoise, AGC,
    %   BandpassFilter, FrequencyShifter) are gone. Specifically, the
    %   ADC sample-rate-offset (ppm) used to be silently dropped; this
    %   test guards against the regression by exercising both the 0 ppm
    %   identity branch and a non-zero offset that perturbs the output
    %   length via the Farrow resampler.

    methods (TestMethodSetup)

        function configureLogging(~)
            csrd.utils.logger.GlobalLogManager.reset();
            logCfg = struct( ...
                'Level', 'ERROR', ...
                'SaveToFile', false, ...
                'DisplayInConsole', false);
            csrd.utils.logger.GlobalLogManager.initialize(logCfg);
        end

    end

    methods (TestMethodTeardown)

        function teardown(~)
            csrd.utils.logger.GlobalLogManager.reset();
        end

    end

    methods (Test)

        function honestlyAdvertisedStagesOnly(testCase)
            % Make sure removed-but-formerly-declared stages stay removed.
            mc = ?csrd.blocks.physical.rxRadioFront.RRFSimulator;
            propNames = arrayfun(@(p) p.Name, mc.PropertyList, 'UniformOutput', false);

            forbiddenStageNames = {'PhaseNoise', 'AGC', 'BandpassFilter', 'FrequencyShifter'};
            for k = 1:numel(forbiddenStageNames)
                testCase.verifyFalse(any(strcmp(propNames, forbiddenStageNames{k})), ...
                    sprintf('RRFSimulator must not expose %s; the impairment is not wired.', ...
                        forbiddenStageNames{k}));
            end

            requiredStageNames = {'LowerPowerAmplifier', 'ThermalNoise', 'IQImbalance', 'SampleShifter'};
            for k = 1:numel(requiredStageNames)
                testCase.verifyTrue(any(strcmp(propNames, requiredStageNames{k})), ...
                    sprintf('RRFSimulator must expose %s for inspection.', requiredStageNames{k}));
            end
        end

        function zeroPpmIsIdentityLength(testCase)
            sim = RRFSimulatorTest.makeSimulator(0);

            rng(1);
            sig = complex(0.05 * randn(2048, 1), 0.05 * randn(2048, 1));
            out = step(sim, sig);

            testCase.verifyClass(out, 'double');
            testCase.verifySize(out, size(sig), ...
                'At 0 ppm the SampleShifter must preserve length.');
            testCase.verifyTrue(any(out ~= 0), ...
                'Output should not be identically zero (some impairment still active).');
            release(sim);
        end

        function nonZeroPpmIsActuallyApplied(testCase)
            sim = RRFSimulatorTest.makeSimulator(50000);

            rng(2);
            sig = complex(0.05 * randn(4096, 1), 0.05 * randn(4096, 1));

            simRef = RRFSimulatorTest.makeSimulator(0);

            out = step(sim, sig);
            outRef = step(simRef, sig);

            sameLen = numel(out) == numel(outRef);
            if sameLen
                isIdentical = isequal(out, outRef);
                testCase.verifyFalse(isIdentical, ...
                    'Non-zero ppm offset must perturb the output samples.');
            else
                testCase.verifyTrue(true);
            end

            release(sim);
            release(simRef);
        end

        function sampleShifterIsConstructedDuringSetup(testCase)
            sim = RRFSimulatorTest.makeSimulator(123);
            setup(sim, complex(zeros(8, 1)));

            testCase.verifyNotEmpty(sim.SampleShifter, ...
                'SampleShifter must be instantiated by setupImpl.');
            testCase.verifyClass(sim.SampleShifter, 'comm.SampleRateOffset');
            testCase.verifyEqual(sim.SampleShifter.Offset, 123, ...
                'SampleShifter.Offset must mirror the configured ppm value.');
            release(sim);
        end

    end

    methods (Static, Access = private)

        function sim = makeSimulator(ppmOffset)
            iqCfg = struct('A', 0, 'P', 0);

            nlCfg = struct( ...
                'Method', 'Cubic polynomial', ...
                'LinearGain', 0, ...
                'TOISpecification', 'IIP3', ...
                'IIP3', 30, ...
                'AMPMConversion', 0, ...
                'PowerLowerLimit', -30, ...
                'PowerUpperLimit', 10, ...
                'ReferenceImpedance', 1);

            thCfg = struct('NoiseTemperature', 290);

            sim = csrd.blocks.physical.rxRadioFront.RRFSimulator( ...
                'SampleRateOffset', ppmOffset, ...
                'MasterClockRate', 20e6, ...
                'BandWidth', 20e6, ...
                'CenterFrequency', 0, ...
                'NumReceiveAntennas', 1, ...
                'IqImbalanceConfig', iqCfg, ...
                'MemoryLessNonlinearityConfig', nlCfg, ...
                'ThermalNoiseConfig', thCfg);
        end

    end

end
