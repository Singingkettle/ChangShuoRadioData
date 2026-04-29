classdef ScenarioFactoryRegulatoryChinaTest < matlab.unittest.TestCase
    %SCENARIOFACTORYREGULATORYCHINATEST Phase 8 CommunicationBehavior slice.

    methods (Test)
        function communicationSimulatorPublishesRegulatoryBlueprint(testCase)
            cfg = localCommunicationConfig();
            sim = csrd.blocks.scenario.CommunicationBehaviorSimulator('Config', cfg);
            cleanup = onCleanup(@() releaseIfLocked(sim));
            setup(sim);

            rng(101, 'twister');
            entities = localEntities();
            [txConfigs, rxConfigs, layout] = step(sim, 1, entities);

            testCase.assertNotEmpty(txConfigs);
            testCase.assertNotEmpty(rxConfigs);
            testCase.verifyTrue(isfield(layout, 'Regulatory'));
            testCase.verifyTrue(layout.Regulatory.Enable);
            testCase.verifyEqual(layout.Regulatory.RegionId, 'CN');

            rx = rxConfigs{1};
            testCase.verifyEqual(rx.Observation.RealCarrierFrequency, ...
                layout.Regulatory.Receiver.CenterFrequencyHz);

            for k = 1:numel(txConfigs)
                tx = txConfigs{k};
                testCase.verifyTrue(isfield(tx, 'Regulatory'));
                testCase.verifyEqual(tx.Regulatory.RegionId, 'CN');
                testCase.verifyNotEmpty(tx.Regulatory.BandId);
                testCase.verifyEqual(tx.Spectrum.AbsoluteCenterFrequencyHz, ...
                    tx.Regulatory.SelectedCenterFrequencyHz);
                testCase.verifyLessThanOrEqual( ...
                    abs(tx.Spectrum.PlannedFreqOffset) + tx.Spectrum.PlannedBandwidth / 2, ...
                    rx.Observation.SampleRate / 2 + 1);
                testCase.verifyTrue(ismember(tx.Modulation.Type, ...
                    tx.Regulatory.AllowedModulationFamilies));
            end
        end

        function oqpskRegulatoryConfigModulatesWithFactoryDefaults(testCase)
            modFactory = csrd.factories.ModulationFactory( ...
                'Config', localModulationFactoryConfig());
            cleanup = onCleanup(@() releaseIfLocked(modFactory));
            setup(modFactory);

            inputData = randi([0 1], 4096, 1);
            modulation = struct( ...
                'TypeID', 'OQPSK', ...
                'Type', 'OQPSK', ...
                'Family', 'OQPSK', ...
                'Order', 4, ...
                'SymbolRate', 1.6e6, ...
                'SamplesPerSymbol', 4, ...
                'RolloffFactor', 0.25);
            placement = struct('TargetBandwidth', 2e6);

            out = step(modFactory, inputData, 1, 'Tx1', 1, modulation, placement);
            testCase.verifyTrue(isfield(out, 'SampleRate'));
            testCase.verifyGreaterThan(out.SampleRate, 0);
            testCase.verifyTrue(isfield(out.ModulatorConfig, 'span'));
            testCase.verifyTrue(isfield(out.ModulatorConfig, 'SymbolMapping'));
            testCase.verifyTrue(isfield(out.ModulatorConfig, 'PhaseOffset'));
        end

        function qamNestedModulatorConfigIsAdaptedNotRawOverwritten(testCase)
            modFactory = csrd.factories.ModulationFactory( ...
                'Config', localModulationFactoryConfig());
            cleanup = onCleanup(@() releaseIfLocked(modFactory));
            setup(modFactory);

            inputData = randi([0 1], 4096, 1);
            modulation = struct( ...
                'TypeID', 'QAM', ...
                'Type', 'QAM', ...
                'Family', 'QAM', ...
                'Order', 64, ...
                'SymbolRate', 32e6, ...
                'SamplesPerSymbol', 4, ...
                'RolloffFactor', 0.25, ...
                'ModulatorConfig', struct('beta', 0.25, 'ostbcSymbolRate', 1));
            placement = struct('TargetBandwidth', 40e6);

            out = step(modFactory, inputData, 1, 'Tx1', 1, modulation, placement);
            testCase.verifyTrue(isfield(out, 'SampleRate'));
            testCase.verifyGreaterThan(out.SampleRate, 0);
            testCase.verifyTrue(isfield(out.ModulatorConfig, 'span'));
            testCase.verifyEqual(out.ModulatorConfig.span, 10);
            testCase.verifyTrue(isfield(out.ModulatorConfig, 'SymbolOrder'));
            testCase.verifyEqual(out.ModulatorConfig.ostbcSymbolRate, 1);
        end
    end
end


function cfg = localCommunicationConfig()
cfg = struct();
cfg.Receiver.Type = 'Simulation';
cfg.Receiver.SampleRate = 50e6;
cfg.Receiver.CenterFrequency = 0;
cfg.Receiver.RealCarrierFrequency = 2.4e9;
cfg.Receiver.NumAntennas = 1;
cfg.Transmitter.Types = {'Simulation'};
cfg.Transmitter.Power.Min = 10;
cfg.Transmitter.Power.Max = 20;
cfg.Transmitter.NumAntennas.Min = 1;
cfg.Transmitter.NumAntennas.Max = 4;
cfg.Transmitter.BandwidthRatio.Min = 0.02;
cfg.Transmitter.BandwidthRatio.Max = 0.25;
cfg.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.TemporalBehavior.PatternDistribution = 1;
cfg.Message.Types = {'RandomBit'};
cfg.Modulation.Types = {'PSK','QAM'};
cfg.Modulation.RolloffFactor = 0.25;
cfg.Modulation.SamplesPerSymbol = 4;
cfg.FrequencyAllocation.Strategy = 'ReceiverCentric';
cfg.FrequencyAllocation.MinSeparation = 50e3;
cfg.FrequencyAllocation.AllowOverlap = true;
cfg.FrequencyAllocation.MaxOverlap = 0.3;
cfg.Regulatory.Enable = true;
cfg.Regulatory.Region.Policy = 'Fixed';
cfg.Regulatory.Region.Fixed = 'CN';
cfg.Regulatory.ServiceTier = 'Tier1';
cfg.Regulatory.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
cfg.Regulatory.MonitoringBand.FixedBandId = 'CN_NR_N78';
cfg.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
cfg.Global.ObservationDuration = 0.01;
cfg.Global.NumFramesPerScenario = 1;
end


function entities = localEntities()
entities = repmat(struct( ...
    'ID', '', 'Type', '', 'Position', [0 0 0], 'Velocity', [0 0 0], ...
    'Orientation', [0 0 0], 'AngularVelocity', [0 0 0], ...
    'Snapshots', {{struct('Physical', struct(), 'Communication', struct(), 'Temporal', struct())}}), 1, 3);
entities(1).ID = 'Tx1'; entities(1).Type = 'Transmitter'; entities(1).Position = [0 0 10];
entities(2).ID = 'Tx2'; entities(2).Type = 'Transmitter'; entities(2).Position = [100 0 10];
entities(3).ID = 'Rx1'; entities(3).Type = 'Receiver'; entities(3).Position = [0 100 10];
end


function releaseIfLocked(sim)
if isLocked(sim)
    release(sim);
end
end


function modConfig = localModulationFactoryConfig()
configDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
    'config', '_base_', 'factories');
oldPath = path;
cleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(configDir);
cfg = modulation_factory();
modConfig = cfg.Factories.Modulation;
end
