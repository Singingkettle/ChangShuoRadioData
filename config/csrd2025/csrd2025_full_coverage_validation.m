function config = csrd2025_full_coverage_validation()
    % csrd2025_full_coverage_validation - Phase 13 validation-grade generation config.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：通过正式 simulation.m 入口调度覆盖矩阵，用于验证重构后的全链路生成能力。

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
    config.Runner.RandomSeed = 20260430;
    config.Runner.SimulationMode = 'Phase13-FullCoverageValidation';
    config.Runner.ValidationLevel = 'Strict';
    config.Runner.Toolbox.Level = 'minimal';

    config.Runner.Data.OutputDirectory = 'CSRD2025_full_coverage_validation';
    config.Runner.Data.SaveFormat = 'mat';
    config.Runner.Data.CompressData = false;
    config.Runner.Data.MetadataIncluded = true;
    config.Runner.Data.BackupEnabled = false;
    config.Runner.Data.RetentionPolicy = 'Keep';
    config.Runner.Data.VersionControl = true;
    config.Runner.Data.ScenarioGrouping = true;

    config.Log.Name = 'CSRD-Phase13-FullCoverage';
    config.Log.Level = 'INFO';
    config.Log.SaveToFile = true;
    config.Log.DisplayInConsole = true;
    config.Log.SessionLogging = true;

    config.CoverageValidation.Enable = true;
    config.CoverageValidation.Mode = 'validation';
    config.CoverageValidation.OutputDirectory = ...
        'CSRD2025_full_coverage_validation';
    config.CoverageValidation.GeneratedConfigDirectory = ...
        fullfile('CSRD2025_full_coverage_validation', 'generated_configs');
    config.CoverageValidation.SummaryDirectory = ...
        fullfile('CSRD2025_full_coverage_validation', 'summaries');
    config.CoverageValidation.IncludeBuildingOSM = true;
    config.CoverageValidation.EnforceCoverage = true;
    config.CoverageValidation.NumFramesPerCase = 1;
    config.CoverageValidation.ObservationDuration = 0.0015;
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
        2, 2, 2, 2; ...
        3, 2, 4, 4; ...
        2, 3, 2, 3];

    config.Metadata.Version = '2025.1.0-phase13';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = ...
        'CSRD Phase 13 validation-grade full coverage generation config';
    config.Metadata.Author = 'ChangShuo';
    config.Metadata.Architecture = 'Scenario-Driven-FullCoverageValidation';
    config.Metadata.LastModified = datetime('now');
end
