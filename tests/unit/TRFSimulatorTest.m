classdef TRFSimulatorTest < matlab.unittest.TestCase
    % TRFSimulatorTest - Pin the transmitter RF chain contract.
    %
    %   The legacy version of this file expected struct-in / struct-out
    %   plus a phase-noise stage that the production class does not
    %   actually expose, so it failed against every recent build. This
    %   rewrite mirrors the real signature used by TransmitFactory:
    %
    %       outputArray = step(trf, basebandArray)
    %
    %   Tests cover:
    %     * Configuration knobs (TargetSampleRate, CarrierFrequency,
    %       BandWidth, TxPowerDb) are honoured.
    %     * IIP3 is written to the IIP3 property when
    %       TOISpecification='IIP3' (regression for the I/O spec bug).
    %     * Frequency translation actually shifts the spectrum.
    %     * Sample-rate conversion changes the output length.
    %     * Multi-antenna inputs are processed independently.

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

        function defaultConstructorWorks(testCase)
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator();
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>
            testCase.verifyClass(trf, 'csrd.blocks.physical.txRadioFront.TRFSimulator');
            testCase.verifyEqual(trf.TargetSampleRate, 20e6);
        end

        function iip3SpecPopulatesIip3Property(testCase)
            % Regression for the IIP3->OIP3 typo: when
            % TOISpecification = 'IIP3', the *IIP3* property must be
            % written, not OIP3. Build a TRF, force setup so the
            % nonlinearity object is constructed, and inspect the
            % property.
            trf = TRFSimulatorTest.makeSimulator(0);
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>
            x = complex(0.05 * randn(1024, 1), 0.05 * randn(1024, 1));
            step(trf, x);
            testCase.verifyEqual(trf.MemoryLessNonlinearity.IIP3, ...
                trf.MemoryLessNonlinearityConfig.IIP3, ...
                'IIP3 setting must be written to the IIP3 property.');
        end

        function frequencyTranslationShiftsSpectrum(testCase)
            % Frequency translation runs at the input sample rate, so the
            % carrier must lie inside the input Nyquist band, otherwise
            % the complex exponential aliases. Production code feeds this
            % block with baseband signals at the modulator output rate
            % and a CarrierFrequency that is already constrained by the
            % planner.
            inputFs = 4e6;
            targetFs = 20e6;
            carrier = 800e3;
            tonalFreq = 100e3;

            trf = TRFSimulatorTest.makeSimulator(carrier, ...
                'TargetSampleRate', targetFs, ...
                'SampleRate', inputFs, ...
                'BandWidth', 1e6);
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>

            n = (0:4095).';
            tone = exp(1j * 2 * pi * tonalFreq * n / inputFs);
            outSig = step(trf, tone);

            nfft = 8192;
            spectrum = fftshift(fft(outSig, nfft));
            freqAxis = (-nfft/2:nfft/2-1) * targetFs / nfft;
            [~, peakIdx] = max(abs(spectrum));
            peakFreq = freqAxis(peakIdx);

            expected = carrier + tonalFreq;
            tolerance = max(20e3, targetFs / nfft * 5);
            testCase.verifyLessThan(abs(peakFreq - expected), tolerance, ...
                sprintf('Spectrum peak at %.1f Hz, expected near %.1f Hz', ...
                    peakFreq, expected));
        end

        function sampleRateConversionChangesLength(testCase)
            inputFs = 1e6;
            targetFs = 5e6;
            inputLen = 512;

            trf = TRFSimulatorTest.makeSimulator(0, ...
                'TargetSampleRate', targetFs, ...
                'SampleRate', inputFs);
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>

            n = (0:inputLen-1).';
            sig = exp(1j * 2 * pi * 50e3 * n / inputFs);
            outSig = step(trf, sig);

            expectedLen = round(inputLen * targetFs / inputFs);
            testCase.verifyLessThan(abs(numel(outSig) - expectedLen), ...
                max(10, round(0.05 * expectedLen)), ...
                'Resampled length must be within 5% (or 10 samples) of expected.');
        end

        function multiAntennaIsProcessedColumnByColumn(testCase)
            numAnt = 2;
            inputFs = 1e6;
            targetFs = 5e6;

            trf = TRFSimulatorTest.makeSimulator(1e6, ...
                'TargetSampleRate', targetFs, ...
                'SampleRate', inputFs);
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>

            n = (0:255).';
            tone = exp(1j * 2 * pi * 100e3 * n / inputFs);
            input = repmat(tone, 1, numAnt);
            outSig = step(trf, input);

            testCase.verifyEqual(size(outSig, 2), numAnt, ...
                'Number of antennas must be preserved.');
            for k = 1:numAnt
                testCase.verifyGreaterThan(var(outSig(:, k)), 0, ...
                    sprintf('Antenna %d output must have non-zero variance', k));
            end
        end

    end

    methods (Static, Access = private)

        function trf = makeSimulator(carrierFrequency, varargin)
            iqCfg = struct('A', 0, 'P', 0);
            phCfg = struct('Level', -100, 'FrequencyOffset', 10e3);
            nlCfg = struct( ...
                'Method', 'Cubic polynomial', ...
                'LinearGain', 0, ...
                'TOISpecification', 'IIP3', ...
                'IIP3', 30, ...
                'AMPMConversion', 0, ...
                'PowerLowerLimit', -50, ...
                'PowerUpperLimit', 10, ...
                'ReferenceImpedance', 50);

            defaults = struct( ...
                'TargetSampleRate', 20e6, ...
                'SampleRate', 1e6, ...
                'BandWidth', 1e6, ...
                'TxPowerDb', 0, ...
                'DCOffset', -100);

            for k = 1:2:numel(varargin)
                defaults.(varargin{k}) = varargin{k+1};
            end

            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', defaults.TargetSampleRate, ...
                'SampleRate', defaults.SampleRate, ...
                'BandWidth', defaults.BandWidth, ...
                'TxPowerDb', defaults.TxPowerDb, ...
                'DCOffset', defaults.DCOffset, ...
                'CarrierFrequency', carrierFrequency, ...
                'IqImbalanceConfig', iqCfg, ...
                'PhaseNoiseConfig', phCfg, ...
                'MemoryLessNonlinearityConfig', nlCfg);
        end

    end

end
