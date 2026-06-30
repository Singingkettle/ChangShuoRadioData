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

        function adcQuantizationDisabledByDefault(testCase)
            % With no AdcBits set the converter stage is identity and reports no
            % realized quantization noise (falls back to thermal-only SNR GT).
            sim = RRFSimulatorTest.makeSimulator(0);
            rng(3);
            sig = complex(0.1 * randn(4096, 1), 0.1 * randn(4096, 1));
            step(sim, sig);
            testCase.verifyTrue(isnan(sim.RealizedAdcQuantizationNoiseInputReferredW), ...
                'AdcBits unset (NaN) must leave ADC quantization disabled.');
            release(sim);
        end

        function adcQuantizationCapsSnrAtConverterCeiling(testCase)
            % A modeled N-bit ADC must bound the realized SNR at ~6.02*N + 1.76 dB.
            % Feed a clean, strong signal (thermal noise negligible) so the
            % realized quantization-noise floor sets the SNR, and check the
            % input-referred quantization power implies the ideal ADC ceiling.
            adcBits = 12;
            sim = RRFSimulatorTest.makeSimulator(0);
            sim.AdcBits = adcBits;
            rng(4);
            sig = complex(0.1 * randn(8192, 1), 0.1 * randn(8192, 1));
            step(sim, sig);

            qnW = sim.RealizedAdcQuantizationNoiseInputReferredW;
            testCase.verifyTrue(isfinite(qnW) && qnW > 0, ...
                'A modeled ADC must report a finite positive quantization-noise power.');
            inPowerW = mean(abs(sig) .^ 2);
            impliedCeilingDb = 10 * log10(inPowerW / qnW);
            expectedCeilingDb = 6.02 * adcBits + 1.76;
            testCase.verifyEqual(impliedCeilingDb, expectedCeilingDb, 'AbsTol', 3, ...
                'Realized ADC quantization floor must imply the ~6.02N+1.76 dB SNR ceiling.');

            % Fewer bits -> coarser converter -> strictly more quantization noise.
            simCoarse = RRFSimulatorTest.makeSimulator(0);
            simCoarse.AdcBits = 8;
            step(simCoarse, sig);
            testCase.verifyGreaterThan(simCoarse.RealizedAdcQuantizationNoiseInputReferredW, qnW, ...
                'An 8-bit converter must add more quantization noise than a 12-bit one.');
            release(sim);
            release(simCoarse);
        end

        function dcOffsetIsRelativeToReceivedLevel(testCase)
            % Regression: DCOffset is a dBc level, so the realized DC spur must
            % scale with the received RMS. The previous code added a fixed
            % absolute amplitude 10^(DCOffset/20), so the realized DC-to-signal
            % ratio drifted with the received power (which varies across the
            % SNR sweep) and no longer matched the annotated dBc value. Drive
            % the chain at two received levels and check the realized DC stays
            % at the same dBc relative to the received level.
            dcDb = -10;
            rng(10);
            base = complex(randn(8192, 1), randn(8192, 1));
            base = base / sqrt(mean(abs(base) .^ 2)); % unit power
            for scale = [1, 4]
                sim = RRFSimulatorTest.makeSimulator(0);
                sim.DCOffset = dcDb;
                out = step(sim, scale * base);
                dcAmplitude = abs(mean(out));
                receivedRms = sqrt(mean(abs(out - mean(out)) .^ 2));
                realizedDbc = 20 * log10(dcAmplitude / receivedRms);
                testCase.verifyEqual(realizedDbc, dcDb, 'AbsTol', 1, ...
                    sprintf(['Realized DC must stay at %g dBc relative to the ', ...
                        'received level (received scale = %g).'], dcDb, scale));
                release(sim);
            end
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
