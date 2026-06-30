function test_measured_truth_joint_dimension()
    %TEST_MEASURED_TRUTH_JOINT_DIMENSION Plausibility across untested dimension mixes.
    %
    %   The baseline cohorts never co-vary certain dimensions: high Doppler is
    %   pinned to AWGN, the fading cohorts are pinned to low speed, multi-frame
    %   lives only in isolated fixtures, and OSM RayTracing never flows through
    %   the measured-truth gate. This gate exercises those JOINT combinations and
    %   asserts the measured SourcePlane stays physically plausible
    %   (csrd.test_support.measuredPlausibilityViolations), so a bug that only
    %   appears at an untested intersection cannot pass silently.
    %
    %   OSM cohorts run only when local OSM map data is present; without it they
    %   are skipped (and logged) so the Statistical combinations still gate.

    fprintf('=== Measured-truth joint-dimension plausibility ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'measured_truth_joint_dimension');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end
    csrd.runtime.logger.GlobalLogManager.initialize(struct('Name', 'CSRD-JointDim', ...
        'Level', 'ERROR', 'SaveToFile', false, 'DisplayInConsole', false), runRoot);

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    osmAvailable = ~isempty(dir(fullfile(projectRoot, 'data', 'map', 'osm', '**', '*.osm')));

    cohorts = localJointCohorts();

    totalSources = 0;
    ranCohorts = 0;
    skipped = {};
    violations = {};

    for ci = 1:numel(cohorts)
        c = cohorts{ci};
        if c.RequiresOsm && ~osmAvailable
            skipped{end + 1} = c.Name; %#ok<AGROW>
            continue;
        end
        try
            cfg = localApplyJointCohort(masterCfg, c, runRoot, ci);
            annotationPath = localRunOneScenario(cfg);
            if exist(annotationPath, 'file') ~= 2
                skipped{end + 1} = [c.Name ' (no annotation)']; %#ok<AGROW>
                continue;
            end
            annotation = jsondecode(fileread(annotationPath));
            [n, vs] = localCheckAnnotation(annotation, c.Name);
            totalSources = totalSources + n;
            violations = [violations, vs]; %#ok<AGROW>
            ranCohorts = ranCohorts + 1;
            fprintf('  [%-30s] sources=%d\n', c.Name, n);
        catch ME_run
            % A generation failure on an untested intersection is itself a
            % finding worth surfacing, but keep the gate going for the others.
            violations{end + 1} = sprintf('%s GENERATION FAILED: %s', ...
                c.Name, ME_run.message); %#ok<AGROW>
        end
    end

    if ~isempty(skipped)
        fprintf('  Skipped (no OSM data): %s\n', strjoin(skipped, ', '));
    end

    assert(ranCohorts >= 1, ...
        'Joint-dimension gate: no cohort produced an annotation.');
    assert(totalSources >= 1, ...
        'Joint-dimension gate: 0 SignalSources observed across %d cohorts.', ranCohorts);

    fprintf('  Cohorts run       : %d\n', ranCohorts);
    fprintf('  Sources checked   : %d\n', totalSources);
    fprintf('  Bound violations  : %d\n', numel(violations));

    if ~isempty(violations)
        for v = 1:numel(violations)
            fprintf(2, '    !! %s\n', violations{v});
        end
        error('CSRD:Measurement:JointDimensionPlausibilityViolated', ...
            ['A joint dimension combination produced an implausible measured ', ...
             'value or failed to generate (%d findings). See report above.'], ...
            numel(violations));
    end

    fprintf('=== Measured-truth joint-dimension plausibility PASSED ===\n');
end


function cohorts = localJointCohorts()
    % Each cohort forces a combination the baseline cohorts never co-vary.
    mk = @(name, ch, rx, spd, nf, pat, osm) struct( ...
        'Name', name, 'MapTypes', {ternaryMap(osm)}, ...
        'ChannelModel', ch, 'RxRange', rx, 'MaxSpeedMps', spd, ...
        'NumFrames', nf, 'Patterns', {pat}, 'RequiresOsm', osm);
    cohorts = {
        mk('HiDoppler_x_Rayleigh',      'Rayleigh', [1, 1], 200, 1, {'Continuous'}, false)
        mk('HiDoppler_x_Rician',        'Rician',   [1, 1], 200, 1, {'Continuous'}, false)
        mk('MultiFrame_x_Mob_Rayleigh', 'Rayleigh', [1, 1], 120, 3, {'Continuous'}, false)
        mk('MultiRx_x_HiDoppler',       'Rayleigh', [2, 2], 150, 1, {'Continuous'}, false)
        mk('Burst_x_MultiFrame_x_Mob',  'Rayleigh', [1, 1],  80, 3, {'Burst'},      false)
        mk('OSM_RayTracing_x_gate',     '',         [1, 1],   0, 1, {'Continuous'}, true)
        mk('OSM_x_MultiFrame_x_Mob',    '',         [1, 1],  60, 2, {'Continuous'}, true)
    };
end


function m = ternaryMap(osm)
    if osm
        m = {'OSM'};
    else
        m = {'Statistical'};
    end
end


function cfg = localApplyJointCohort(masterCfg, c, runRoot, ci)
    cfg = masterCfg;
    cfg.Runner.NumScenarios = 1;
    cfg.Runner.RandomSeed = 20260630 + 23 * ci;
    cfg.Runner.Toolbox.Level = 'minimal';
    cfg.Logging.Policy = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, sprintf('cohort_%02d', ci));
    cfg.Runner.Data.CompressData = false;

    cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.005, c.NumFrames);

    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = c.MapTypes;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = c.RxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = c.RxRange(2);

    if c.MaxSpeedMps > 0
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeedMps = c.MaxSpeedMps;
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.MaxSpeedMps = c.MaxSpeedMps;
    end

    if ~isfield(cfg.Factories.Scenario, 'CommunicationBehavior')
        cfg.Factories.Scenario.CommunicationBehavior = struct();
    end
    if ~isfield(cfg.Factories.Scenario.CommunicationBehavior, 'TemporalBehavior')
        cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior = struct();
    end
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = c.Patterns;
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;

    if ~isempty(c.ChannelModel) && any(strcmp(c.MapTypes, 'Statistical'))
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = c.ChannelModel;
    end
end


function annotationPath = localRunOneScenario(cfg)
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
end


function [nSources, violations] = localCheckAnnotation(annotation, cohortName)
    nSources = 0;
    violations = {};
    if ~isfield(annotation, 'Frames'); return; end
    frames = annotation.Frames;
    for fi = 1:numel(frames)
        fr = frames(fi);
        if iscell(frames); fr = frames{fi}; end
        if ~isfield(fr, 'SampleRate') || ~isfield(fr, 'SignalSources'); continue; end
        Fs = double(fr.SampleRate);
        sources = fr.SignalSources;
        for si = 1:numel(sources)
            src = sources(si);
            if iscell(sources); src = sources{si}; end
            if ~isstruct(src) || ~isfield(src, 'Truth') || ~isstruct(src.Truth) ...
                    || ~isfield(src.Truth, 'Measured') || ~isstruct(src.Truth.Measured) ...
                    || ~isfield(src.Truth.Measured, 'SourcePlane') ...
                    || ~isstruct(src.Truth.Measured.SourcePlane)
                continue;
            end
            nSources = nSources + 1;
            tag = sprintf('%s/f%d/src%d', cohortName, fi, si);
            violations = [violations, ...
                csrd.test_support.measuredPlausibilityViolations( ...
                    src.Truth.Measured.SourcePlane, Fs, tag)]; %#ok<AGROW>
        end
    end
end
