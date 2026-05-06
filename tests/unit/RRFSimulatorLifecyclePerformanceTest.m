classdef RRFSimulatorLifecyclePerformanceTest < matlab.unittest.TestCase
    %RRFSIMULATORLIFECYCLEPERFORMANCETEST Phase 21 RRF hot-path contracts.

    methods (TestMethodSetup)

        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            logCfg = struct( ...
                'Level', 'ERROR', ...
                'SaveToFile', false, ...
                'DisplayInConsole', false);
            csrd.runtime.logger.GlobalLogManager.initialize(logCfg);
        end

    end

    methods (TestMethodTeardown)

        function teardown(~)
            csrd.runtime.logger.GlobalLogManager.reset();
        end

    end

    methods (Test)

        function zeroPpmUsesIdentityFastPath(testCase)
            sim = RRFSimulatorLifecyclePerformanceTest.makeSimulator(0);
            cleanupObj = onCleanup(@() release(sim)); %#ok<NASGU>

            sig = complex(0.05 * randn(256, 1), 0.05 * randn(256, 1));
            out = step(sim, sig);

            testCase.verifySize(out, size(sig));
            testCase.verifyEmpty(sim.SampleShifter, ...
                '0 ppm must not construct comm.SampleRateOffset on the hot path.');
            testCase.verifyFalse(sim.SampleRateOffsetInfo.Applied);
            testCase.verifyEqual(sim.SampleRateOffsetInfo.Action, 'identity');
            testCase.verifyEqual(sim.SampleRateOffsetInfo.InputSamples, size(sig, 1));
            testCase.verifyEqual(sim.SampleRateOffsetInfo.OutputSamples, size(out, 1));
        end

        function thermalNoiseObjectIsReusedWhenConfigStable(testCase)
            sim = RRFSimulatorLifecyclePerformanceTest.makeSimulator(0);
            cleanupObj = onCleanup(@() release(sim)); %#ok<NASGU>

            sig = complex(0.05 * randn(256, 1), 0.05 * randn(256, 1));
            step(sim, sig);
            firstNoise = sim.ThermalNoise;
            step(sim, sig);

            testCase.verifySameHandle(sim.ThermalNoise, firstNoise, ...
                'ThermalNoise must be reused until sample rate/noise config changes.');
        end

        function nonZeroPpmReusesSampleRateOffsetObject(testCase)
            sim = RRFSimulatorLifecyclePerformanceTest.makeSimulator(250);
            cleanupObj = onCleanup(@() release(sim)); %#ok<NASGU>

            sig = complex(0.05 * randn(512, 1), 0.05 * randn(512, 1));
            step(sim, sig);
            firstShifter = sim.SampleShifter;
            step(sim, sig);

            testCase.verifyNotEmpty(sim.SampleShifter);
            testCase.verifySameHandle(sim.SampleShifter, firstShifter, ...
                'SampleRateOffset object must be reused while ppm offset is stable.');
            testCase.verifyTrue(sim.SampleRateOffsetInfo.Applied);
            testCase.verifyEqual(sim.SampleRateOffsetInfo.Action, 'sample-rate-offset');
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
                'NumAntennas', 1, ...
                'IqImbalanceConfig', iqCfg, ...
                'MemoryLessNonlinearityConfig', nlCfg, ...
                'ThermalNoiseConfig', thCfg);
        end

    end
end
