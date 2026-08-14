classdef TrfPaOperatingPointTest < matlab.unittest.TestCase
    % TrfPaOperatingPointTest - the PA operating-point contract.
    %
    %   The input-back-off mechanism ATTENUATES the TRF drive down to
    %   InputBackoffDb below the PA's measured 1 dB compression point when --
    %   and only when -- the drive sits closer than that; a drive already
    %   further from compression passes through untouched. These cases pin the
    %   three things that mechanism rests on:
    %
    %     1. paInputReferenceDbm finds the right compression point (checked
    %        against the closed form available for the cubic model, and against
    %        the lookup table's own rows -- two independent anchors).
    %     2. The parasitic AM/PM phase is bounded by the drawn window
    %        (AMPMConversion * (Upper - Lower)), which is the physics the batch-1
    %        config ranges promise.
    %     3. Two-tone IM3 reproduces the drawn IIP3 -- evidence that the PA model
    %        the pipeline builds is the PA the config describes.
    %
    %   And the outcome the mechanism exists for: a QAM waveform through the
    %   LOOKUP-table PA -- whose table puts 1 dB compression ~17 dB below a
    %   unit-power drive, the one Method the batch-1 range changes could not fix
    %   -- keeps its occupied bandwidth once the back-off engages.

    methods (TestMethodSetup)
        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
                'Level', 'ERROR', 'SaveToFile', false, 'DisplayInConsole', false));
        end
    end

    methods (TestMethodTeardown)
        function teardown(~)
            csrd.runtime.logger.GlobalLogManager.reset();
        end
    end

    methods (Test)

        function referencePointMatchesTheCubicClosedForm(testCase)
            % For the cubic polynomial with TOISpecification = 'IP1dB' the input
            % 1 dB compression point IS the drawn parameter, so the numeric probe
            % has a closed-form answer to hit.
            ip1dB = 24;
            trf = TrfPaOperatingPointTest.makeTrf(struct( ...
                'Method', 'Cubic polynomial', 'LinearGain', 5, ...
                'TOISpecification', 'IP1dB', 'IP1dB', ip1dB, ...
                'AMPMConversion', 0, 'PowerLowerLimit', 2, ...
                'PowerUpperLimit', 22, 'ReferenceImpedance', 50));
            cleanup = onCleanup(@() release(trf));
            refDbm = trf.paInputReferenceDbm();
            testCase.verifyEqual(refDbm, ip1dB, 'AbsTol', 1.0, sprintf( ...
                ['Numeric 1 dB compression search found %.2f dBm; the drawn ', ...
                 'IP1dB is %g dBm. A miss here mis-positions every operating ', ...
                 'point the back-off mechanism sets.'], refDbm, ip1dB));
        end

        function referencePointMatchesTheLookupTable(testCase)
            % Independent anchor: the production lookup table's own rows put the
            % 1 dB gain compression near -4 dBm input (gain falls from 30.16 dB
            % at -25 dBm to 29.16 dB between -5 and 0 dBm).
            trf = TrfPaOperatingPointTest.makeTrf(struct( ...
                'Method', 'Lookup table', ...
                'Table', TrfPaOperatingPointTest.productionLookupTable(), ...
                'ReferenceImpedance', 50));
            cleanup = onCleanup(@() release(trf));
            refDbm = trf.paInputReferenceDbm();
            testCase.verifyEqual(refDbm, -4, 'AbsTol', 2.0, sprintf( ...
                'Lookup-table compression found at %.2f dBm, expected ~-4 dBm.', ...
                refDbm));
        end

        function parasiticPhaseIsBoundedByTheDrawnWindow(testCase)
            % The batch-1 physics promise: with AMPMConversion a deg/dB and the
            % power window [lower, upper], the parasitic phase can never exceed
            % a*(upper-lower). Sweep an amplitude ramp and measure the realized
            % phase twist directly.
            ampm = 4.0; lowerDbm = 2; upperDbm = 22;
            pa = comm.MemorylessNonlinearity('Method', 'Cubic polynomial', ...
                'LinearGain', 0, 'TOISpecification', 'IIP3', 'IIP3', 40, ...
                'AMPMConversion', ampm, 'PowerLowerLimit', lowerDbm, ...
                'PowerUpperLimit', upperDbm, 'ReferenceImpedance', 50);
            cleanup = onCleanup(@() release(pa));
            amps = logspace(-3, 1.5, 400).';
            y = pa(complex(amps, zeros(size(amps))));
            phaseDeg = rad2deg(angle(y ./ complex(amps)));
            twistDeg = max(phaseDeg) - min(phaseDeg);
            capDeg = ampm * (upperDbm - lowerDbm);
            testCase.verifyLessThanOrEqual(twistDeg, capDeg + 1, sprintf( ...
                ['Realized AM/PM twist %.1f deg exceeds the drawn cap ', ...
                 '%.1f deg = AMPMConversion*(Upper-Lower). The finite ', ...
                 'PowerUpperLimit exists precisely to make this cap real.'], ...
                twistDeg, capDeg));
            % And it must not be trivially zero -- the diversity is a feature.
            testCase.verifyGreaterThan(twistDeg, 1, ...
                'AM/PM must remain present, not sterilized away.');
        end

        function twoToneImdTracksTheDrawnIip3(testCase)
            % Classic two-tone estimate: IIP3 ~ Pin + (P_fund - P_im3)/2.
            % The tone frequencies MUST land on exact FFT bins (the estimate
            % is read straight off two bins, and off-grid tones leak enough
            % fundamental energy into the IM3 bin to fake a ~6 dB error and
            % decouple the estimate from the drawn value entirely).
            %
            % Two assertions: the absolute value (the object's IIP3 is the
            % complex-envelope per-tone dBm convention this test uses -- no
            % offset, verified empirically to <0.05 dB) and the 10 dB step
            % (the drawn parameter reaches the cubic term with unit slope).
            drawn = [25, 35];
            estimates = zeros(1, 2);
            for k = 1:2
                estimates(k) = TrfPaOperatingPointTest.twoToneIip3Estimate(drawn(k));
            end
            testCase.verifyEqual(estimates, drawn, 'AbsTol', 0.5, sprintf( ...
                'Two-tone IM3 gives IIP3 = [%.2f, %.2f] dBm, drawn [25, 35].', ...
                estimates(1), estimates(2)));
            testCase.verifyEqual(estimates(2) - estimates(1), 10, 'AbsTol', 0.2, ...
                sprintf(['A 10 dB step in drawn IIP3 produced a %.2f dB step ', ...
                'in the two-tone estimate.'], estimates(2) - estimates(1)));
        end

        function backoffKeepsQamCleanThroughTheLookupPa(testCase)
            % The outcome case. The production lookup table compresses ~17 dB
            % below a unit-power drive, so without back-off a QAM waveform
            % widens ~3x (measured in the batch-1 isolation probe). With the
            % drawn back-off the occupied bandwidth must stay near clean.
            Fs = 8e6;
            rng(7);
            sym = qammod(randi([0 15], 8192, 1), 16, 'UnitAveragePower', true);
            x = upfirdn(sym, rcosdesign(0.25, 12, 8, 'sqrt'), 8);
            x = x(:) / sqrt(mean(abs(x(:)).^2));
            cleanObw = csrd.pipeline.measurement.obwActual(x, Fs);

            nlCfg = struct('Method', 'Lookup table', ...
                'Table', TrfPaOperatingPointTest.productionLookupTable(), ...
                'ReferenceImpedance', 50, 'InputBackoffDb', 8);
            trf = TrfPaOperatingPointTest.makeTrf(nlCfg, ...
                'SampleRate', Fs, 'TargetSampleRate', Fs, 'BandWidth', 1.25e6);
            cleanup = onCleanup(@() release(trf));
            y = step(trf, x);
            obw = csrd.pipeline.measurement.obwActual(y, Fs);
            testCase.verifyLessThan(obw / cleanObw, 1.2, sprintf( ...
                ['QAM through the lookup PA at 8 dB back-off reads %.3fx its ', ...
                 'clean bandwidth; without the back-off this PA widened it ', ...
                 '~3.2x. The mechanism exists for exactly this case.'], ...
                obw / cleanObw));

            % Control: the same TRF with the back-off field REMOVED must show
            % the widening -- proving the improvement is the mechanism, not an
            % accident of the fixture.
            nlCfgOff = rmfield(nlCfg, 'InputBackoffDb');
            trfOff = TrfPaOperatingPointTest.makeTrf(nlCfgOff, ...
                'SampleRate', Fs, 'TargetSampleRate', Fs, 'BandWidth', 1.25e6);
            cleanupOff = onCleanup(@() release(trfOff));
            yOff = step(trfOff, x);
            obwOff = csrd.pipeline.measurement.obwActual(yOff, Fs);
            testCase.verifyGreaterThan(obwOff / cleanObw, 2, sprintf( ...
                ['Without back-off the lookup PA should still widen QAM ', ...
                 '(measured %.2fx). If this stops failing, the table itself ', ...
                 'changed and the back-off case above proves nothing.'], ...
                obwOff / cleanObw));
        end

        function referencePointSurvivesGainExpansiveCurves(testCase)
            % The Ghorbani AM/AM (x4 < 0) is gain-EXPANSIVE at small drive:
            % its gain RISES with amplitude before compressing. A reference
            % search anchored to the smallest-amplitude gain misreads that
            % expansion as compression and reports ~-47 dBm -- and the
            % back-off step then crushes a healthy drive 40-60 dB down into
            % the expansion region (measured on the widening-probe anchor as
            % RRC wideband OBW/theory p90 1.09 -> 2.03). The peak-referenced
            % search must place the production Ghorbani corners at their
            % physical compression points instead.
            ghorbani = @(inputScaling) struct('Method', 'Ghorbani model', ...
                'InputScaling', inputScaling, ...
                'AMAMParameters', [8.108, 1.5413, 6.5202, -0.0718], ...
                'AMPMParameters', [4.6645, 2.0965, 10.88, -0.003], ...
                'OutputScaling', 0, 'ReferenceImpedance', 50);
            expected = [16.4, 8.5];   % measured physical corners, dBm
            scalings = [-12, -4];
            for k = 1:2
                trf = TrfPaOperatingPointTest.makeTrf(ghorbani(scalings(k)));
                cleanup = onCleanup(@() release(trf));
                refDbm = trf.paInputReferenceDbm();
                testCase.verifyEqual(refDbm, expected(k), 'AbsTol', 2.0, sprintf( ...
                    ['Ghorbani (InputScaling %g dB) compression found at ', ...
                     '%.2f dBm, expected ~%.1f. A large negative value here ', ...
                     'means the search fell back to the expansion region.'], ...
                    scalings(k), refDbm, expected(k)));
            end
        end

        function backoffNeverBoostsACleanDrive(testCase)
            % Attenuate-only semantics. A cubic PA drawn at IP1dB = 30 dBm puts
            % the unit-power 50-ohm drive (~+13 dBm) already 17 dB below
            % compression -- further than the 12 dB back-off asks for -- so the
            % back-off must not touch it: the output must be bit-identical to
            % the same TRF without the field. The boost variant of Step 3.5
            % (scale every drive to sit exactly at P1dB - IBO) failed exactly
            % here, pulling clean draws INTO compression: the widening-probe
            % anchor read RRC wideband OBW/theory p90 1.09 -> 2.03 and QAM
            % through Ghorbani filled the capture band.
            Fs = 8e6;
            rng(11);
            sym = qammod(randi([0 15], 4096, 1), 16, 'UnitAveragePower', true);
            x = upfirdn(sym, rcosdesign(0.25, 12, 8, 'sqrt'), 8);
            x = x(:) / sqrt(mean(abs(x(:)).^2));

            nlCfg = struct('Method', 'Cubic polynomial', 'LinearGain', 3, ...
                'TOISpecification', 'IP1dB', 'IP1dB', 30, ...
                'AMPMConversion', 2, 'PowerLowerLimit', 2, ...
                'PowerUpperLimit', 22, 'ReferenceImpedance', 50, ...
                'InputBackoffDb', 12);
            trf = TrfPaOperatingPointTest.makeTrf(nlCfg, ...
                'SampleRate', Fs, 'TargetSampleRate', Fs, 'BandWidth', 1.25e6);
            cleanup = onCleanup(@() release(trf));
            rng(99); y = step(trf, x);   % pin the phase-noise realization

            nlCfgOff = rmfield(nlCfg, 'InputBackoffDb');
            trfOff = TrfPaOperatingPointTest.makeTrf(nlCfgOff, ...
                'SampleRate', Fs, 'TargetSampleRate', Fs, 'BandWidth', 1.25e6);
            cleanupOff = onCleanup(@() release(trfOff));
            rng(99); yOff = step(trfOff, x);

            testCase.verifyEqual(y, yOff, ['A drive already further from ', ...
                'compression than the drawn back-off must pass through ', ...
                'bit-identically -- the back-off is a guard, not a boost.']);
        end

    end

    methods (Static)

        function estimate = twoToneIip3Estimate(drawnIip3)
            % twoToneIip3Estimate - complex-envelope two-tone IIP3 estimate.
            % Inputs: drawnIip3 - the IIP3 (dBm) configured on the PA.
            % Outputs: estimate - Pin + (P_fund - P_im3)/2 in this measurement's
            %          convention (per-tone dBm at 50 ohm, complex tones).
            pa = comm.MemorylessNonlinearity('Method', 'Cubic polynomial', ...
                'LinearGain', 0, 'TOISpecification', 'IIP3', 'IIP3', drawnIip3, ...
                'AMPMConversion', 0, 'PowerLowerLimit', -100, ...
                'PowerUpperLimit', 100, 'ReferenceImpedance', 50);
            cleanup = onCleanup(@() release(pa));
            % N = 10000 at Fs = 1 MHz puts the bin spacing at exactly 100 Hz,
            % so f1/f2/2f1-f2 all land on exact bins (1000/1100/900) and the
            % bin readout below carries no leakage.
            Fs = 1e6; N = 10000; n = (0:N - 1).' / Fs;
            f1 = 100e3; f2 = 110e3;
            perToneDbm = 0;   % well below IIP3 so the cubic term dominates
            toneAmp = sqrt(50 * 10 ^ ((perToneDbm - 30) / 10));
            x = toneAmp * (exp(2i * pi * f1 * n) + exp(2i * pi * f2 * n));
            y = pa(x);
            spec = fft(y);
            powAt = @(f) 20 * log10(abs(spec(round(f / Fs * N) + 1)) / N);
            estimate = perToneDbm + (powAt(f1) - powAt(2 * f1 - f2)) / 2;
        end

        function table = productionLookupTable()
            % productionLookupTable - the 9-row table from transmit_factory.m.
            % Inputs: none.
            % Outputs: table - [Pin dBm, Pout dBm, phase deg] rows.
            table = [ ...
                -25,  5.16, -0.25;
                -20, 10.11, -0.47;
                -15, 15.11, -0.68;
                -10, 20.05, -0.89;
                 -5, 24.79, -1.22;
                  0, 27.64,  5.59;
                  5, 28.49, 12.03;
                 10, 28.90, 14.00;
                 15, 29.00, 15.00 ];
        end

        function trf = makeTrf(nlCfg, varargin)
            % makeTrf - a TRF with neutral impairments except the given PA.
            % Inputs: nlCfg - MemoryLessNonlinearityConfig struct; name-value
            %         overrides for TRF properties.
            % Outputs: trf - configured TRFSimulator.
            defaults = struct( ...
                'TargetSampleRate', 1e6, ...
                'SampleRate', 1e6, ...
                'BandWidth', 1e6, ...
                'TxPowerDb', 0, ...
                'DCOffset', -100);
            for k = 1:2:numel(varargin)
                defaults.(varargin{k}) = varargin{k + 1};
            end
            trf = csrd.blocks.physical.txRadioFront.TRFSimulator( ...
                'TargetSampleRate', defaults.TargetSampleRate, ...
                'SampleRate', defaults.SampleRate, ...
                'BandWidth', defaults.BandWidth, ...
                'TxPowerDb', defaults.TxPowerDb, ...
                'DCOffset', defaults.DCOffset, ...
                'CarrierFrequency', 0, ...
                'IqImbalanceConfig', struct('A', 0, 'P', 0), ...
                'PhaseNoiseConfig', struct('Level', -150, 'FrequencyOffset', 10e3), ...
                'PhaseNoiseBackend', 'FastSpectral', ...
                'MemoryLessNonlinearityConfig', nlCfg);
        end

    end

end
