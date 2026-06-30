function test_measured_truth_plausibility(varargin)
    %TEST_MEASURED_TRUTH_PLAUSIBILITY Physical plausibility gate for measured GT.
    %
    %   test_measured_truth_plausibility()    % default 6-scenario sweep
    %   test_measured_truth_plausibility(N)   % N >= 1 scenarios
    %
    %   The existing measured-truth coverage gate only checks that the
    %   Truth.Measured fields are FINITE and scalar. Finiteness/shape gates
    %   structurally cannot catch a value that is finite, correctly shaped, and
    %   yet PHYSICALLY IMPOSSIBLE (the class behind the historical
    %   metres-as-degrees geometry bug, which passed 19,200 scenarios). This
    %   gate decomposes each measured SourcePlane field to its physical bound
    %   relative to the receiver and asserts it cannot be violated:
    %
    %     0 <  OccupiedBandwidthHz <= SampleRate            (cannot occupy more
    %                                                        than the captured band)
    %     |CenterFrequencyHz|     <= SampleRate / 2          (must sit in the
    %                                                        captured passband)
    %     0 <= TimeOccupancy      <= 1                       (a fraction)
    %     0 <= FrequencyOccupancy <= 1                       (a fraction)
    %     -100 <= SNRdB           <= 200                     (no infinite/absurd SNR)
    %
    %   A violation is a definitive bug, not measurement variance. Any source
    %   that breaches a bound fails the gate.

    p = inputParser;
    addOptional(p, 'numScenarios', 6, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, varargin{:});
    numScenarios = double(p.Results.numScenarios);

    fprintf('=== Measured-truth physical plausibility (N=%d) ===\n', numScenarios);

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'measured_truth_plausibility');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    bootstrapLog = struct('Name', 'CSRD-Plausibility', 'Level', 'ERROR', ...
        'SaveToFile', false, 'DisplayInConsole', false);
    csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, runRoot);

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    % Cycle the registered statistical channel models so the gate sees AWGN and
    % the fading models; Statistical-only keeps the sweep fast and OSM-free.
    channelModels = {'AWGN', 'Rayleigh', 'Rician'};

    sourcesChecked = 0;
    scenariosRun = 0;
    violations = {};

    for k = 1:numScenarios
        try
            cfg = masterCfg;
            cfg.Runner.NumScenarios = 1;
            cfg.Runner.RandomSeed = 20260630 + 17 * k;
            cfg.Runner.Toolbox.Level = 'minimal';
            cfg.Logging.Policy = 'Standard';
            cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
                sprintf('scenario_%06d', k));
            cfg.Runner.Data.CompressData = false;
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ...
                channelModels{mod(k - 1, numel(channelModels)) + 1};

            cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
            runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner, ...
                'FactoryConfigs', cfg.Factories, 'RuntimePlan', cfg.RuntimePlan);
            setup(runner);
            step(runner, 1, 1);

            warnState = warning('off', 'MATLAB:structOnObject');
            s = struct(runner);
            warning(warnState);
            annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
                'scenario_000001_annotation.json');
            if exist(annotationPath, 'file') ~= 2
                continue;
            end

            annotation = jsondecode(fileread(annotationPath));
            frames = annotation.Frames;
            for fi = 1:numel(frames)
                fr = frames(fi);
                if iscell(frames); fr = frames{fi}; end
                if ~isfield(fr, 'SampleRate') || ~isfield(fr, 'SignalSources')
                    continue;
                end
                Fs = double(fr.SampleRate);
                sources = fr.SignalSources;
                for si = 1:numel(sources)
                    src = sources(si);
                    if iscell(sources); src = sources{si}; end
                    sp = localSourcePlane(src);
                    if isempty(sp); continue; end
                    sourcesChecked = sourcesChecked + 1;
                    violations = [violations, ...
                        localCheckPlausibility(sp, Fs, k, fi, si)]; %#ok<AGROW>
                end
            end
            scenariosRun = scenariosRun + 1;
        catch ME_run
            fprintf(2, '  Scenario %d skipped: %s\n', k, ME_run.message);
        end
    end

    assert(scenariosRun >= 1, ...
        'Plausibility gate: no scenario produced an annotation.');
    assert(sourcesChecked >= 1, ...
        'Plausibility gate: 0 SignalSources observed across %d scenarios.', ...
        scenariosRun);

    fprintf('  Scenarios run     : %d\n', scenariosRun);
    fprintf('  Sources checked   : %d\n', sourcesChecked);
    fprintf('  Bound violations  : %d\n', numel(violations));

    if ~isempty(violations)
        for v = 1:numel(violations)
            fprintf(2, '    !! %s\n', violations{v});
        end
        error('CSRD:Measurement:PhysicalPlausibilityViolated', ...
            ['Measured GT breached a hard physical bound in %d of %d sources. ', ...
             'See the per-source report above.'], numel(violations), sourcesChecked);
    end

    fprintf('=== Measured-truth physical plausibility PASSED ===\n');
end


function sp = localSourcePlane(src)
    sp = [];
    if ~isstruct(src) || ~isfield(src, 'Truth') || ~isstruct(src.Truth)
        return;
    end
    if ~isfield(src.Truth, 'Measured') || ~isstruct(src.Truth.Measured)
        return;
    end
    if ~isfield(src.Truth.Measured, 'SourcePlane') ...
            || ~isstruct(src.Truth.Measured.SourcePlane)
        return;
    end
    sp = src.Truth.Measured.SourcePlane;
end


function v = localCheckPlausibility(sp, Fs, sid, fi, si)
    v = {};
    tag = sprintf('s%d/f%d/src%d', sid, fi, si);
    tol = 1.02; % 2% slack for bin granularity / floating point

    if localFiniteScalar(sp, 'OccupiedBandwidthHz')
        ob = sp.OccupiedBandwidthHz;
        if ob <= 0 || ob > Fs * tol
            v{end + 1} = sprintf('%s OccupiedBandwidthHz=%.4g out of (0, Fs=%.4g]', tag, ob, Fs);
        end
    end
    if localFiniteScalar(sp, 'CenterFrequencyHz')
        ce = sp.CenterFrequencyHz;
        if abs(ce) > (Fs / 2) * tol
            v{end + 1} = sprintf('%s |CenterFrequencyHz|=%.4g > Fs/2=%.4g', tag, abs(ce), Fs / 2);
        end
    end
    if localFiniteScalar(sp, 'TimeOccupancy')
        to = sp.TimeOccupancy;
        if to < -1e-3 || to > 1 + 1e-3
            v{end + 1} = sprintf('%s TimeOccupancy=%.4g out of [0,1]', tag, to);
        end
    end
    if localFiniteScalar(sp, 'FrequencyOccupancy')
        fo = sp.FrequencyOccupancy;
        if fo < -1e-3 || fo > 1 + 1e-3
            v{end + 1} = sprintf('%s FrequencyOccupancy=%.4g out of [0,1]', tag, fo);
        end
    end
    if localFiniteScalar(sp, 'SNRdB')
        sn = sp.SNRdB;
        if sn < -100 || sn > 200
            v{end + 1} = sprintf('%s SNRdB=%.4g out of [-100,200]', tag, sn);
        end
    end
end


function tf = localFiniteScalar(s, f)
    tf = isfield(s, f) && isnumeric(s.(f)) && isscalar(s.(f)) && isfinite(s.(f));
end
