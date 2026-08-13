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

        function backoffHoldsTheHotFrameAtTheLnaOperatingPoint(testCase)
            % The receive-side outcome case. Combined channel-output frames
            % reach the LNA at +33..+35 dBm (50-ohm convention), which sits
            % PAST the lookup-table LNA's ~-4 dBm compression point, so
            % without the back-off guard the saved frame is hard-clipped and
            % its bandwidth widens. With the drawn back-off the occupied
            % bandwidth must stay near the clean input's.
            Fs = 20e6;
            rng(21);
            sym = qammod(randi([0 15], 8192, 1), 16, 'UnitAveragePower', true);
            x = upfirdn(sym, rcosdesign(0.25, 12, 8, 'sqrt'), 8);
            x = x(:) / sqrt(mean(abs(x(:)).^2));
            hot = x * sqrt(50 * 10 ^ ((33 - 30) / 10));  % +33 dBm at 50 ohm
            cleanObw = csrd.pipeline.measurement.obwActual(x, Fs);

            nlCfg = RRFSimulatorTest.lookupLnaConfig();
            nlCfg.InputBackoffDb = 12;
            sim = RRFSimulatorTest.makeSimulator(0, nlCfg);
            rng(31); y = step(sim, hot);
            release(sim);
            obw = csrd.pipeline.measurement.obwActual(y, Fs);
            testCase.verifyLessThan(obw / cleanObw, 1.2, sprintf( ...
                ['A +33 dBm frame through the lookup LNA at 12 dB back-off ', ...
                 'reads %.3fx its clean bandwidth.'], obw / cleanObw));

            % Control: the same chain with the back-off field REMOVED must
            % show the clipping -- proving the improvement is the guard.
            simOff = RRFSimulatorTest.makeSimulator(0, ...
                RRFSimulatorTest.lookupLnaConfig());
            rng(31); yOff = step(simOff, hot);
            release(simOff);
            obwOff = csrd.pipeline.measurement.obwActual(yOff, Fs);
            testCase.verifyGreaterThan(obwOff / cleanObw, 1.5, sprintf( ...
                ['Without back-off the +33 dBm drive should clip in the ', ...
                 'lookup LNA and widen (measured %.2fx). If this stops ', ...
                 'failing, the fixture no longer overdrives and the case ', ...
                 'above proves nothing.'], obwOff / cleanObw));
        end

        function backoffNeverBoostsAWeakFrame(testCase)
            % Attenuate-only semantics, receive side: a frame already further
            % from LNA compression than the drawn back-off passes through
            % bit-identically to the same chain without the field. Same
            % contract as TRFSimulator Step 3.5 (whose boost variant measurably
            % pulled clean draws into compression on the transmit side).
            rng(22);
            weak = complex(randn(4096, 1), randn(4096, 1)) * 1e-4;

            nlCfg = RRFSimulatorTest.lookupLnaConfig();
            nlCfg.InputBackoffDb = 16;
            sim = RRFSimulatorTest.makeSimulator(0, nlCfg);
            rng(41); y = step(sim, weak);
            release(sim);

            simOff = RRFSimulatorTest.makeSimulator(0, ...
                RRFSimulatorTest.lookupLnaConfig());
            rng(41); yOff = step(simOff, weak);
            release(simOff);

            testCase.verifyEqual(y, yOff, ['A weak frame must pass through ', ...
                'bit-identically -- the back-off is a guard, not a boost.']);
        end

    end

    methods (Static, Access = private)

        function sim = makeSimulator(ppmOffset, nlCfg)
            iqCfg = struct('A', 0, 'P', 0);

            if nargin < 2
                nlCfg = struct( ...
                    'Method', 'Cubic polynomial', ...
                    'LinearGain', 0, ...
                    'TOISpecification', 'IIP3', ...
                    'IIP3', 30, ...
                    'AMPMConversion', 0, ...
                    'PowerLowerLimit', -30, ...
                    'PowerUpperLimit', 10, ...
                    'ReferenceImpedance', 1);
            end

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

        function nlCfg = lookupLnaConfig()
            % The production lookup table (receive_factory.m), 50-ohm
            % convention, compression ~-4 dBm input.
            nlCfg = struct( ...
                'Method', 'Lookup table', ...
                'Table', [ ...
                    -25,  5.16, -0.25;
                    -20, 10.11, -0.47;
                    -15, 15.11, -0.68;
                    -10, 20.05, -0.89;
                     -5, 24.79, -1.22;
                      0, 27.64,  5.59;
                      5, 28.49, 12.03;
                     10, 28.90, 14.00;
                     15, 29.00, 15.00 ], ...
                'ReferenceImpedance', 50);
        end

    end

end
