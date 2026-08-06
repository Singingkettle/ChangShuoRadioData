function config = default()
    % default - Default runner configuration
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Provides standard simulation execution settings.

    config.Runner.NumScenarios = 4;
    config.Runner.RandomSeed = 'shuffle';

    % Data Storage Configuration
    config.Runner.Data.OutputDirectory = 'CSRD2025';
    config.Runner.Data.CompressData = true;

    % Engine Configuration
    config.Runner.Engine.Handle = 'csrd.core.ChangShuo';

    % Phase 21 performance tracing is opt-in. It writes only runtime timing
    % artifacts under ignored artifacts/performance/phase21/, never signal data.
    config.Runner.Performance.EnableStageTiming = false;
    config.Runner.Performance.ArtifactDirectory = fullfile('artifacts', 'performance', 'phase21');
end
