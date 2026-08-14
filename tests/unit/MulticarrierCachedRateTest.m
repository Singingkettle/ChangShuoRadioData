classdef MulticarrierCachedRateTest < matlab.unittest.TestCase
    % MulticarrierCachedRateTest - the cached multicarrier rate-label contract.
    %
    %   ModulationFactory caches one modulator instance per type and reuses
    %   it across frames. The multicarrier families (OFDM/SCFDMA/OTFS) derive
    %   their sample rate from THEIR GRID during first-call setup; the cached,
    %   locked instance never reruns setup, so the factory's generic
    %   SymbolRate*SPS write RELABELED the rate on every later call (a
    %   30.72 MHz OFDM waveform stamped 64 MHz). The waveform was unchanged,
    %   but every downstream consumer stretched its spectrum by the ratio --
    %   measured as the entire exec > 0.85*Fs capture-band-fill class of the
    %   widening-probe anchor, and misattributed to PA regrowth until a TRF
    %   isolation run came back clean. This pins: the SECOND call must report
    %   the SAME rate and the SAME occupied bandwidth as the first.

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

        function cachedCallsKeepTheGridRateAndBandwidth(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            types = {'OFDM', 'SCFDMA', 'OTFS'};
            for t = 1:numel(types)
                typeId = types{t};
                factory = csrd.factories.ModulationFactory( ...
                    'Config', cfg.Factories.Modulation);
                cleanup = onCleanup(@() release(factory));
                [segment, placement] = ...
                    MulticarrierCachedRateTest.segmentFor(typeId);
                rates = zeros(1, 3); bws = zeros(1, 3);
                for callIdx = 1:3
                    payload = struct('data', randi([0 1], 16384, 1), ...
                        'SymbolRate', segment.SymbolRate);
                    out = step(factory, payload, callIdx, 'TxCache', 1, ...
                        segment, placement);
                    rates(callIdx) = out.SampleRate;
                    bws(callIdx) = csrd.pipeline.measurement.obwAntennaMax( ...
                        out.Signal, out.SampleRate);
                end
                testCase.verifyEqual(rates(2:3), rates([1 1]), sprintf( ...
                    ['%s: cached calls must keep the first call''s grid ', ...
                     'rate (got %s Hz) -- a diverging label stretches the ', ...
                     'spectrum downstream.'], typeId, mat2str(rates, 6)));
                testCase.verifyEqual(bws(2:3), bws([1 1]), 'RelTol', 0.05, ...
                    sprintf(['%s: cached-call occupied bandwidth drifted ', ...
                    '(%s Hz).'], typeId, mat2str(round(bws), 6)));
                clear cleanup;
            end
        end

    end

    methods (Static)

        function [segment, placement] = segmentFor(typeId)
            % segmentFor - a pipeline-shaped multicarrier segment config.
            % Inputs: typeId - 'OFDM' | 'SCFDMA' | 'OTFS'.
            % Outputs: segment/placement structs as the scenario layer builds.
            bw = 20e6;
            mc = struct();
            switch typeId
                case 'OFDM'
                    mc.base.mode = "qam";
                    mc.ofdm.FFTLength = 2048;
                    mc.ofdm.NumGuardBandCarriers = [128; 128];
                    mc.ofdm.InsertDCNull = true;
                    mc.ofdm.CyclicPrefixLength = 64;
                    mc.ofdm.Subcarrierspacing = 15e3;
                    mc.ofdm.Windowing = false;
                    mc.mimo.Mode = 'OSTBC';
                case 'SCFDMA'
                    mc.base.mode = "qam";
                    mc.scfdma.FFTLength = 2048;
                    mc.scfdma.CyclicPrefixLength = 64;
                    mc.scfdma.Subcarrierspacing = 15e3;
                    mc.scfdma.SubcarrierMappingInterval = 1;
                    mc.scfdma.NumDataSubcarriers = 1200;
                case 'OTFS'
                    mc.base.mode = "qam";
                    mc.otfs.DelayLength = 1024;
                    mc.otfs.Subcarrierspacing = 15e3;
                    mc.otfs.padType = "CP";
                    mc.otfs.padLen = 16;
            end
            segment = struct( ...
                'TypeID', typeId, 'Type', typeId, 'Family', typeId, ...
                'Order', 16, 'BitsPerSymbol', 4, 'RolloffFactor', 0.25, ...
                'SymbolRate', bw / 1.25, 'SamplesPerSymbol', 4, ...
                'NumTransmitAntennas', 1 + strcmp(typeId, 'OFDM'), ...
                'ModulatorConfig', mc);
            placement = struct('TargetBandwidth', bw, 'CenterFrequency', 0);
        end

    end

end
