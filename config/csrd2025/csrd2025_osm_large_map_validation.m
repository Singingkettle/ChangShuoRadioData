function config = csrd2025_osm_large_map_validation()
    % csrd2025_osm_large_map_validation - Specific OSM RayTracing smoke.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.

    config.baseConfigs = {
                          '_base_/logging/default.m',
                          '_base_/runners/default.m',
                          '_base_/factories/scenario_factory.m',
                          '_base_/factories/message_factory.m',
                          '_base_/factories/modulation_factory.m',
                          '_base_/factories/transmit_factory.m',
                          '_base_/factories/channel_factory.m',
                          '_base_/factories/receive_factory.m'
                          };

    currentFilePath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(currentFilePath));
    pragueLargeOsm = fullfile(projectRoot, 'data', 'map', 'osm', ...
        'Historical_City_Center', ...
        'Historical_City_Center_Old_Town_Square_Prague_50.0878_14.4205.osm');

    config.Runner.NumScenarios = 1;
    config.Runner.RandomSeed = 20260507;
    config.Runner.SimulationMode = 'Phase26-SpecificOsmMapValidation';
    config.Runner.ValidationLevel = 'Strict';
    config.Runner.Toolbox.Level = 'minimal';

    config.Runner.Data.OutputDirectory = 'CSRD2025_osm_large_map_validation';
    config.Runner.Data.SaveFormat = 'mat';
    config.Runner.Data.CompressData = false;
    config.Runner.Data.MetadataIncluded = true;
    config.Runner.Data.BackupEnabled = false;
    config.Runner.Data.RetentionPolicy = 'Keep';
    config.Runner.Data.VersionControl = false;
    config.Runner.Data.ScenarioGrouping = true;
    config.Runner.Data.PrettyPrintAnnotations = false;

    config.Runner.Performance.EnableStageTiming = true;
    config.Runner.Performance.ArtifactDirectory = ...
        fullfile('artifacts', 'performance', 'phase26_specific_osm');
    config.Logging.Name = 'CSRD-Phase26-OSM-SpecificMap';
    config.Logging.Policy = 'LargeMC';
    config.Logging.Console.Enabled = true;
    config.Logging.File.Enabled = true;
    config.Logging.Progress.Mode = 'Summary';

    config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Fixed';
    config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = 1024;
    config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'Fixed';
    config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Value = 1;

    config.Factories.Scenario.PhysicalEnvironment.Map.Types = {'OSM'};
    config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = pragueLargeOsm;
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.ChannelModel = 'RayTracing';

    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.Model = 'Stationary';
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Min = 0;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Max = 0;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
    config.Factories.Scenario.CommunicationBehavior.Receiver.NumAntennas = 1;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Min = 1;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Max = 1;
    config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.Selection = 'Fixed';
    config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.Fixed = 'CN_ISM_24';
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;

    config.Metadata.Version = '2025.1.0-phase26';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = ...
        'CSRD Phase 26 specific OSM RayTracing validation config';
    config.Metadata.Author = 'ChangShuo';
    config.Metadata.Architecture = 'Scenario-Driven-Specific-OSM-Validation';
    config.Metadata.LastModified = datetime('now');
end
