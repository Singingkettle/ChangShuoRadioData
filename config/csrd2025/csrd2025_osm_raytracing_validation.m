function config = csrd2025_osm_raytracing_validation()
    % csrd2025_osm_raytracing_validation - Phase 16 OSM RayTracing validation config.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：通过正式 simulation.m 入口压测 building/empty OSM RayTracing、多实体、多天线和法规频谱链路。

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

    config.Runner.NumScenarios = 1;
    config.Runner.RandomSeed = 20260502;
    config.Runner.SimulationMode = 'Phase16-OsmRayTracingValidation';
    config.Runner.ValidationLevel = 'Strict';
    config.Runner.Toolbox.Level = 'minimal';

    config.Runner.Data.OutputDirectory = 'CSRD2025_osm_raytracing_validation';
    config.Runner.Data.SaveFormat = 'mat';
    config.Runner.Data.CompressData = false;
    config.Runner.Data.MetadataIncluded = true;
    config.Runner.Data.BackupEnabled = false;
    config.Runner.Data.RetentionPolicy = 'Keep';
    config.Runner.Data.VersionControl = false;
    config.Runner.Data.ScenarioGrouping = true;

    config.Log.Name = 'CSRD-Phase16-OSM-RayTracing';
    config.Log.Level = 'INFO';
    config.Log.SaveToFile = true;
    config.Log.DisplayInConsole = true;
    config.Log.SessionLogging = true;

    config.CoverageValidation.Enable = true;
    config.CoverageValidation.Mode = 'osm_raytracing_stress';
    config.CoverageValidation.OutputDirectory = ...
        'CSRD2025_osm_raytracing_validation';
    config.CoverageValidation.GeneratedConfigDirectory = ...
        fullfile('CSRD2025_osm_raytracing_validation', 'generated_configs');
    config.CoverageValidation.SummaryDirectory = ...
        fullfile('CSRD2025_osm_raytracing_validation', 'summaries');
    config.CoverageValidation.IncludeBuildingOSM = true;
    config.CoverageValidation.EnforceCoverage = true;
    config.CoverageValidation.NumFramesPerCase = 1;
    config.CoverageValidation.ObservationDuration = 0.0012;
    config.CoverageValidation.TargetFrameSamples = 262144;
    config.CoverageValidation.DefaultSampleRateHz = 20e6;
    config.CoverageValidation.WideSampleRateHz = 50e6;
    config.CoverageValidation.MinimumModulatorSampleRateHz = 250e3;
    config.CoverageValidation.StartAt = 1;
    config.CoverageValidation.StopAfter = Inf;

    config.CoverageValidation.RegulatoryCases = { ...
        'CN', 'CN_FM_BROADCAST'; ...
        'CN', 'CN_NR_N78'; ...
        'US', 'US_ISM_915'; ...
        'EU', 'EU_DAB_VHF'; ...
        'JP', 'JP_ISDB_UHF'; ...
        'KR', 'KR_SRD_920'; ...
        'CN', 'CN_LAND_MOBILE_VHF'; ...
        'CN', 'CN_ISM_24'};
    config.CoverageValidation.StatisticalChannelModels = ...
        {'AWGN', 'Rayleigh', 'Rician', 'MultiPath'};
    config.CoverageValidation.AntennaCombos = [ ...
        1, 1, 1, 1; ...
        1, 2, 1, 2; ...
        2, 1, 2, 1; ...
        2, 2, 2, 2; ...
        3, 2, 4, 4; ...
        2, 3, 2, 4; ...
        4, 4, 4, 4];

    config.CoverageValidation.OsmRayTracing.Enable = true;
    config.CoverageValidation.OsmRayTracing.CoverAllModulations = false;
    config.CoverageValidation.OsmRayTracing.RepresentativeModulations = ...
        {'QAM', 'OFDM', 'GMSK', 'FM', 'DSBAM', 'PSK'};
    config.CoverageValidation.OsmRayTracing.BuildingCategories = { ...
        'Dense_Urban_Mid_Rise', 'Urban_Canyon', 'University_Campus'};
    config.CoverageValidation.OsmRayTracing.FlatCategories = { ...
        'Open_Ocean_Area', 'Open_Farmland_Flat'};
    config.CoverageValidation.OsmRayTracing.RegulatoryCases = { ...
        'CN', 'CN_ISM_24'; ...
        'CN', 'CN_NR_N78'; ...
        'US', 'US_ISM_915'; ...
        'EU', 'EU_DAB_VHF'; ...
        'JP', 'JP_ISDB_UHF'; ...
        'KR', 'KR_SRD_920'};
    config.CoverageValidation.OsmRayTracing.AntennaCombos = ...
        config.CoverageValidation.AntennaCombos;
    config.CoverageValidation.Visualization.Enable = true;
    config.CoverageValidation.Visualization.MaxImages = 24;
    config.CoverageValidation.Visualization.SelectionMode = 'diverse';
    config.CoverageValidation.Visualization.MinRectangles = 9;
    config.CoverageValidation.Visualization.OutputDirectory = ...
        fullfile('artifacts', 'visual_checks', 'osm_raytracing', 'phase16');

    config.Metadata.Version = '2025.1.0-phase16';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = ...
        'CSRD Phase 16 validation-grade OSM RayTracing stress generation config';
    config.Metadata.Author = 'ChangShuo';
    config.Metadata.Architecture = 'Scenario-Driven-OSM-RayTracing-Validation';
    config.Metadata.LastModified = datetime('now');
end
