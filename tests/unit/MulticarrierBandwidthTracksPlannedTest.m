classdef MulticarrierBandwidthTracksPlannedTest < matlab.unittest.TestCase
    % MulticarrierBandwidthTracksPlannedTest
    %
    % Pins the multicarrier realized-bandwidth contract for OFDM, OTFS and
    % SCFDMA: the grid (FFT/delay size + used subcarriers) scales with the
    % planned channel bandwidth at a FIXED 15 kHz subcarrier spacing, so the
    % realized occupied bandwidth tracks the planned channel. Pre-fix, a
    % max(15 kHz, .) floor on a FIXED grid pinned the realized OBW to a constant
    % (OFDM 26.4 MHz, OTFS 7.56 MHz, SCFDMA 4.5 MHz) for every channel at or
    % below that constant, decoupling occupied bandwidth from the planned
    % channel by up to ~17x.

    methods (Test)

        function ofdmTracksPlanned(testCase)
            localAssertTracks(testCase, 'OFDM');
        end

        function otfsTracksPlanned(testCase)
            localAssertTracks(testCase, 'OTFS');
        end

        function scfdmaTracksPlanned(testCase)
            localAssertTracks(testCase, 'SCFDMA');
        end

    end
end

function localAssertTracks(testCase, modType)
narrowBw = 5e6;
wideBw = 20e6;
narrowObw = localRealizedObw(modType, narrowBw);
wideObw = localRealizedObw(modType, wideBw);

testCase.verifyEqual(narrowObw, narrowBw, 'RelTol', 0.12, ...
    sprintf('%s 5 MHz realized %.2f MHz', modType, narrowObw / 1e6));
testCase.verifyEqual(wideObw, wideBw, 'RelTol', 0.12, ...
    sprintf('%s 20 MHz realized %.2f MHz', modType, wideObw / 1e6));
% the two are clearly distinct -- pre-fix both pinned to a fixed constant
testCase.verifyGreaterThan(wideObw / narrowObw, 3, ...
    sprintf('%s bandwidth did not track the planned channel (pinned?)', modType));
end

function obwHz = localRealizedObw(modType, bandwidth)
% Grids kept IN SYNC with localOfdmGridForBandwidth + the OTFS branch in
% generateScenarioTransmitterConfigurations.m (the production multicarrier grids).
scs = 15e3;
cfg = struct();
cfg.base.mode = "qam";
switch modType
    case 'OTFS'
        cfg.otfs.DelayLength = max(16, round(bandwidth / scs) + 8);
        cfg.otfs.Subcarrierspacing = scs;
        cfg.otfs.padType = "CP";
        cfg.otfs.padLen = 16;
        modulator = csrd.blocks.physical.modulate.digital.OTFS.OTFS( ...
            'ModulatorOrder', 16, 'NumTransmitAntennas', 1, 'ModulatorConfig', cfg);
    case 'OFDM'
        [fftLength, guard] = localGrid(bandwidth, scs);
        cfg.ofdm.FFTLength = fftLength;
        cfg.ofdm.NumGuardBandCarriers = [guard; guard];
        cfg.ofdm.InsertDCNull = true;
        cfg.ofdm.CyclicPrefixLength = round(fftLength / 14);
        cfg.ofdm.Subcarrierspacing = scs;
        cfg.ofdm.Windowing = false;
        cfg.mimo.Mode = 'SpatialMultiplexing';
        modulator = csrd.blocks.physical.modulate.digital.OFDM.OFDM( ...
            'ModulatorOrder', 16, 'NumTransmitAntennas', 1, 'ModulatorConfig', cfg);
    otherwise % SCFDMA
        [fftLength, guard] = localGrid(bandwidth, scs);
        cfg.scfdma.FFTLength = fftLength;
        cfg.scfdma.CyclicPrefixLength = round(fftLength / 14);
        cfg.scfdma.Subcarrierspacing = scs;
        cfg.scfdma.SubcarrierMappingInterval = 1;
        cfg.scfdma.NumDataSubcarriers = fftLength - 2 * guard;
        modulator = csrd.blocks.physical.modulate.digital.SCFDMA.SCFDMA( ...
            'ModulatorOrder', 16, 'NumTransmitAntennas', 1, 'ModulatorConfig', cfg);
end
out = step(modulator, struct('data', randi([0 1], 600000, 1)));
obwHz = csrd.pipeline.measurement.obwActual(out.Signal, out.SampleRate);
release(modulator);
end

function [fftLength, guard] = localGrid(bandwidth, scs)
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
end
