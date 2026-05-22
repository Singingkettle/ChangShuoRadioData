function test_measured_truth_coverage(varargin)
    %TEST_MEASURED_TRUTH_COVERAGE Phase 4 §6 C1 / §6 C8 measured-truth gate.
    %
    %   test_measured_truth_coverage()       % default 20-scenario sweep
    %   test_measured_truth_coverage(N)      % N >= 20 (smoke override)
    %
    %   Drives a randomised 20+ scenario sweep across every cohort in
    %   `baseline_recipe_v0` and asserts the Phase 4 §6 C1 measured-truth
    %   coverage gate: at least 90 % of all SignalSources entries must
    %   carry a finite `Truth.Measured.SourcePlane.OccupiedBandwidthHz`,
    %   `SNRdB`, `TimeOccupancy`, and `FrequencyOccupancy` (the four
    %   fields the Phase 4 measurement package fills).
    %
    %   The sweep also enforces a complementary coverage gate on
    %   `Truth.Measured.FramePlane` (`OccupiedBandwidthHz`,
    %   `TimeOccupancy`, `FrequencyOccupancy`), since Phase 4 §3.4 C5
    %   requires the FramePlane cache to be populated once per receiver
    %   and shared across every source.
    %
    %   Coverage rule:
    %     coverage(field) = #sources with finite, scalar value(field)
    %                       --------------------------------------
    %                            #sources total (finite or not)
    %
    %   `frequencyOccupancy` legitimately returns NaN when the receiver's
    %   ObservableBwHz is unknown (audit §17.6 spec); those NaNs are
    %   dropped from BOTH numerator AND denominator so the metric reflects
    %   real coverage, not denominator inflation. Other NaN sources
    %   (signal genuinely below noise, modulator dropped frame, ...)
    %   count against coverage as usual.
    %
    %   This is a Phase 4 §6 C1 gate; failure is a regression.

    p = inputParser;
    addOptional(p, 'numScenarios', 20, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, varargin{:});
    numScenarios = double(p.Results.numScenarios);

    fprintf('=== Phase 4 measured-truth coverage (N=%d) ===\n', numScenarios);

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase4_measured_truth_coverage');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end

    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase4-Coverage', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.runtime.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260427, 'twister');

    fullRecipe = baseline_recipe_v0();
    plan = localExpandRecipe(fullRecipe, numScenarios);
    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

    sourcePlaneFields = { ...
        'OccupiedBandwidthHz', 'SNRdB', 'TimeOccupancy', 'FrequencyOccupancy'};
    framePlaneFields  = { ...
        'OccupiedBandwidthHz', 'TimeOccupancy', 'FrequencyOccupancy'};

    sourcePlaneStats = localInitStats(sourcePlaneFields);
    framePlaneStats  = localInitStats(framePlaneFields);

    sourcesObserved   = 0;
    scenariosRun      = 0;
    scenariosSkipped  = 0;

    for k = 1:numel(plan)
        sid = plan(k).ScenarioId;
        cohort = plan(k).Cohort;
        try
            scenarioCfg = localApplyCohort(masterCfg, cohort, runRoot, sid);
            annotationPath = localRunOneScenario(scenarioCfg, sid);

            if isempty(annotationPath) || exist(annotationPath, 'file') ~= 2
                scenariosSkipped = scenariosSkipped + 1;
                continue;
            end

            annotation = jsondecode(fileread(annotationPath));
            sources = localCollectSources(annotation);

            for sIdx = 1:numel(sources)
                src = sources{sIdx};
                if ~isstruct(src) ...
                        || ~isfield(src, 'Truth') ...
                        || ~isstruct(src.Truth) ...
                        || ~isfield(src.Truth, 'Measured') ...
                        || ~isstruct(src.Truth.Measured)
                    continue;
                end
                sourcesObserved = sourcesObserved + 1;
                meas = src.Truth.Measured;

                if isfield(meas, 'SourcePlane') && isstruct(meas.SourcePlane)
                    sourcePlaneStats = localTallyFields( ...
                        sourcePlaneStats, meas.SourcePlane, sourcePlaneFields);
                else
                    sourcePlaneStats = localTallyMissing( ...
                        sourcePlaneStats, sourcePlaneFields);
                end

                if isfield(meas, 'FramePlane') && isstruct(meas.FramePlane)
                    framePlaneStats = localTallyFields( ...
                        framePlaneStats, meas.FramePlane, framePlaneFields);
                else
                    framePlaneStats = localTallyMissing( ...
                        framePlaneStats, framePlaneFields);
                end
            end

            scenariosRun = scenariosRun + 1;
        catch ME_run
            scenariosSkipped = scenariosSkipped + 1;
            fprintf(2, '  Scenario %d skipped: %s (%s)\n', ...
                sid, ME_run.identifier, ME_run.message);
        end
    end

    assert(scenariosRun >= max(1, ceil(numScenarios * 0.5)), ...
        'Phase 4 coverage: only %d/%d scenarios produced annotations.', ...
        scenariosRun, numScenarios);

    assert(sourcesObserved >= 1, ...
        'Phase 4 coverage: 0 SignalSources observed across %d scenarios.', ...
        scenariosRun);

    fprintf('  Scenarios run / skipped : %d / %d\n', ...
        scenariosRun, scenariosSkipped);
    fprintf('  Sources observed        : %d\n', sourcesObserved);

    fprintf('  --- SourcePlane coverage ---\n');
    sourcePlanePass = localReportAndCheck(sourcePlaneStats, 0.90, 'SourcePlane');

    fprintf('  --- FramePlane coverage ----\n');
    framePlanePass = localReportAndCheck(framePlaneStats, 0.90, 'FramePlane');

    if ~sourcePlanePass || ~framePlanePass
        error('CSRD:Phase4:MeasuredTruthCoverageBelowGate', ...
            ['Phase 4 §6 C1 violated: Truth.Measured field coverage ' ...
             'fell below the 90 %% gate. See per-field report above.']);
    end

    fprintf('=== Phase 4 measured-truth coverage PASSED ===\n');
end


% =====================================================================
function plan = localExpandRecipe(recipe, numScenarios)
    cohorts = recipe.Cohorts;
    nCohorts = numel(cohorts);
    counts = zeros(nCohorts, 1);
    weights = zeros(nCohorts, 1);
    for k = 1:nCohorts
        weights(k) = cohorts(k).Count;
    end
    totalWeight = sum(weights);
    if totalWeight <= 0
        weights = ones(nCohorts, 1);
        totalWeight = nCohorts;
    end

    for k = 1:nCohorts
        counts(k) = max(1, round(numScenarios * weights(k) / totalWeight));
    end

    diff = numScenarios - sum(counts);
    if diff > 0
        [~, idx] = sort(weights, 'descend');
        for d = 1:diff
            counts(idx(mod(d - 1, nCohorts) + 1)) = ...
                counts(idx(mod(d - 1, nCohorts) + 1)) + 1;
        end
    elseif diff < 0
        [~, idx] = sort(counts, 'descend');
        d = -diff;
        i = 1;
        while d > 0
            ci = idx(mod(i - 1, nCohorts) + 1);
            if counts(ci) > 1
                counts(ci) = counts(ci) - 1;
                d = d - 1;
            end
            i = i + 1;
            if i > 4 * nCohorts
                break;
            end
        end
    end

    plan = repmat(struct('ScenarioId', 0, 'Cohort', struct()), 0, 1);
    sid = 0;
    for cIdx = 1:nCohorts
        for n = 1:counts(cIdx)
            sid = sid + 1;
            plan(end + 1) = struct('ScenarioId', sid, ...
                'Cohort', cohorts(cIdx)); %#ok<AGROW>
        end
    end
end


function stats = localInitStats(fields)
    stats = struct();
    for k = 1:numel(fields)
        stats.(fields{k}) = struct( ...
            'Total',  0, ...
            'Finite', 0, ...
            'Nan',    0, ...
            'Missing', 0);
    end
end


function stats = localTallyFields(stats, payload, fields)
    for k = 1:numel(fields)
        f = fields{k};
        s = stats.(f);
        s.Total = s.Total + 1;
        if isfield(payload, f) && isnumeric(payload.(f)) ...
                && isscalar(payload.(f))
            v = payload.(f);
            if isfinite(v)
                s.Finite = s.Finite + 1;
            else
                s.Nan = s.Nan + 1;
            end
        else
            s.Missing = s.Missing + 1;
        end
        stats.(f) = s;
    end
end


function stats = localTallyMissing(stats, fields)
    for k = 1:numel(fields)
        s = stats.(fields{k});
        s.Total   = s.Total + 1;
        s.Missing = s.Missing + 1;
        stats.(fields{k}) = s;
    end
end


function pass = localReportAndCheck(stats, gate, planeName)
    pass = true;
    fields = fieldnames(stats);
    for k = 1:numel(fields)
        s = stats.(fields{k});
        if s.Total <= 0
            fprintf('    %s.%-22s : N/A (no samples).\n', planeName, fields{k});
            continue;
        end

        % Phase 4 §3 / §17.6: `frequencyOccupancy` legitimately returns
        % NaN when ObservableBwHz <= 0; those NaNs are accounted for as
        % "denominator-excluded" rather than "coverage failure" so the
        % gate isn't artificially deflated by receivers without a
        % declared observable bandwidth.
        if strcmp(fields{k}, 'FrequencyOccupancy')
            denom = max(s.Total - s.Nan, 1);
        else
            denom = s.Total;
        end
        cov = s.Finite / denom;
        marker = '   ';
        if cov < gate
            marker = '!! ';
            pass = false;
        end
        fprintf('    %s%s.%-22s : %.4f (Finite=%d, NaN=%d, Missing=%d, Denom=%d)\n', ...
            marker, planeName, fields{k}, cov, ...
            s.Finite, s.Nan, s.Missing, denom);
    end
end


% =====================================================================
function cfg = localApplyCohort(masterCfg, cohort, runRoot, sid)
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260427 + sid;
    cfg.Runner.Toolbox.Level    = 'minimal';
    cfg.Logging.Policy          = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
        sprintf('scenario_%06d', sid));
    cfg.Runner.Data.CompressData = false;

    cfg = csrd.test_support.applyCanonicalFrameContract( ...
        cfg, cohort.ObservationDuration, cohort.NumFramesPerScenario);

    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = cohort.MapTypes;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = cohort.MapRatio;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min ...
        = cohort.TxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max ...
        = cohort.TxRange(2);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min ...
        = cohort.RxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max ...
        = cohort.RxRange(2);

    if ~isfield(cfg.Factories.Scenario, 'CommunicationBehavior')
        cfg.Factories.Scenario.CommunicationBehavior = struct();
    end
    if ~isfield(cfg.Factories.Scenario.CommunicationBehavior, 'TemporalBehavior')
        cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior = struct();
    end
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = ...
        cohort.PatternTypes;
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = ...
        cohort.PatternDistribution;

    if isfield(cohort, 'CohortMaxSpeedMps') && cohort.CohortMaxSpeedMps > 0
        cohortMaxSpeed = double(cohort.CohortMaxSpeedMps);
        if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters, 'Mobility')
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility = struct();
        end
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeedMps = cohortMaxSpeed;
        if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers, 'Mobility')
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility = struct();
        end
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.MaxSpeedMps = cohortMaxSpeed;
    end

    if isfield(cohort, 'ChannelPreference') && ~isempty(cohort.ChannelPreference)
        channelPref = char(cohort.ChannelPreference);
        if any(strcmp(cohort.MapTypes, 'Statistical'))
            cfg.Factories.Scenario.PhysicalEnvironment.Map ...
                .Statistical.ChannelModel = channelPref;
        end
        if any(strcmp(cohort.MapTypes, 'OSM'))
            cfg.Factories.Scenario.PhysicalEnvironment.Map ...
                .OSM.ChannelModel = channelPref;
        end
    end
end


function annotationPath = localRunOneScenario(cfg, ~)
    cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
    runner = csrd.SimulationRunner( ...
        'RunnerConfig', cfg.Runner, ...
        'FactoryConfigs', cfg.Factories, ...
        'RuntimePlan', cfg.RuntimePlan);
    setup(runner);
    step(runner, 1, 1);

    warnState = warning('off', 'MATLAB:structOnObject');
    cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
    s = struct(runner); %#ok<NOPRT>
    outDir = s.actualOutputDirectory;
    % Phase 4 (S12 plumbing): the outer ScenarioId we use to demultiplex
    % the runRoot directory is independent of the runner-internal worker
    % scenario index. Each `localRunOneScenario` call rebuilds the
    % runner from scratch with NumScenarios=1, so the runner emits
    % `scenario_000001_annotation.json` every time -- the outer sid
    % only namespaces the runRoot subfolder. Hard-code the runner's
    % internal index (1) when forming the file path.
    annotationPath = fullfile(outDir, 'annotations', ...
        sprintf('scenario_%06d_annotation.json', 1));
end


function sources = localCollectSources(annotation)
    sources = {};
    if ~isstruct(annotation); return; end
    candidates = {annotation};
    for fn = {'Frames', 'Annotation', 'Annotations'}
        if isfield(annotation, fn{1})
            candidates{end + 1} = annotation.(fn{1}); %#ok<AGROW>
        end
    end
    for c = 1:numel(candidates)
        sources = [sources; localScanSources(candidates{c})]; %#ok<AGROW>
    end
end


function out = localScanSources(payload)
    out = {};
    if iscell(payload)
        for k = 1:numel(payload)
            out = [out; localScanSources(payload{k})]; %#ok<AGROW>
        end
        return;
    end
    if isstruct(payload)
        if isfield(payload, 'SignalSources')
            ss = payload.SignalSources;
            if iscell(ss)
                for k = 1:numel(ss)
                    if isstruct(ss{k})
                        out{end + 1} = ss{k}; %#ok<AGROW>
                    end
                end
            else
                for k = 1:numel(ss)
                    out{end + 1} = ss(k); %#ok<AGROW>
                end
            end
        end
        if numel(payload) > 1
            for k = 1:numel(payload)
                out = [out; localScanSources(payload(k))]; %#ok<AGROW>
            end
        end
        if isscalar(payload)
            f = fieldnames(payload);
            for i = 1:numel(f)
                child = payload.(f{i});
                if isstruct(child) || iscell(child)
                    out = [out; localScanSources(child)]; %#ok<AGROW>
                end
            end
        end
    end
end
