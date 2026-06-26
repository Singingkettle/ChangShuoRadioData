classdef OfdmBandwidthTracksPlannedTest < matlab.unittest.TestCase
    % OfdmBandwidthTracksPlannedTest
    %
    % Pins the OFDM realized-bandwidth contract: the OFDM grid (FFT size + used
    % subcarriers) scales with the planned channel bandwidth at a FIXED 15 kHz
    % subcarrier spacing, so the realized occupied bandwidth tracks the planned
    % channel. Pre-fix, a max(15 kHz, .) floor on a fixed 1760-bin grid clamped
    % every channel <= 26.4 MHz to a realized ~26.4 MHz, decoupling the OFDM
    % occupied bandwidth from the planned channel by 1.3x-17x.

    methods (Test)

        function realizedBandwidthTracksPlanned(testCase)
            narrowBw = 5e6;
            wideBw = 20e6;
            narrowObw = localRealizedObw(narrowBw);
            wideObw = localRealizedObw(wideBw);

            % each realized OBW tracks its planned channel (~12% tolerance for
            % the guard bands + measurement)
            testCase.verifyEqual(narrowObw, narrowBw, 'RelTol', 0.12, ...
                sprintf('5 MHz OFDM realized %.2f MHz', narrowObw / 1e6));
            testCase.verifyEqual(wideObw, wideBw, 'RelTol', 0.12, ...
                sprintf('20 MHz OFDM realized %.2f MHz', wideObw / 1e6));
            % and the two are clearly distinct -- pre-fix both pinned to ~26.4 MHz
            testCase.verifyGreaterThan(wideObw / narrowObw, 3, ...
                'OFDM bandwidth did not track the planned channel (pinned?)');
        end

    end
end

function obwHz = localRealizedObw(bandwidth)
% Grid kept IN SYNC with localOfdmGridForBandwidth in
% generateScenarioTransmitterConfigurations.m (the production OFDM grid).
scs = 15e3;
numUsed = max(12, round(bandwidth / scs));
fftSet = [256, 512, 1024, 2048, 4096];
idx = find(fftSet >= numUsed / 0.85, 1);
if isempty(idx)
    fftLength = fftSet(end);
    numUsed = min(numUsed, round(0.85 * fftLength));
else
    fftLength = fftSet(idx);
end
guard = max(1, round((fftLength - numUsed) / 2));

cfg = struct();
cfg.base.mode = "qam";
cfg.ofdm.FFTLength = fftLength;
cfg.ofdm.NumGuardBandCarriers = [guard; guard];
cfg.ofdm.InsertDCNull = true;
cfg.ofdm.CyclicPrefixLength = round(fftLength / 14);
cfg.ofdm.Subcarrierspacing = scs;
cfg.ofdm.Windowing = false;
cfg.mimo.Mode = 'SpatialMultiplexing';
modulator = csrd.blocks.physical.modulate.digital.OFDM.OFDM( ...
    'ModulatorOrder', 16, 'NumTransmitAntennas', 1, 'ModulatorConfig', cfg);
out = step(modulator, struct('data', randi([0 1], 400000, 1)));
obwHz = csrd.pipeline.measurement.obwActual(out.Signal, out.SampleRate);
release(modulator);
end
