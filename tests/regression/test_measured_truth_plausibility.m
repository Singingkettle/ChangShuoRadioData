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
    % Low-precision notes are reported, never failed on. See
    % measuredPlausibilityViolations: a short narrow burst genuinely cannot have a
    % finely defined bandwidth, so counting those as defects would assert a
    % dataset-design choice as a correctness property.
    qualityNotes = {};

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

            % Resolve the output path BEFORE stepping and clear the target, so a
            % scenario that generates nothing cannot be scored on the previous
            % scenario's annotation. The runner writes into a session directory
            % shared across the scenarios of one process, and frame-level failures
            % do not raise the scenario-level skip counter -- so a stale read looks
            % exactly like a successful one. This silently produced a wrong
            % published number once already (see
            % csrd.test_support.freshAnnotationReader).
            warnState = warning('off', 'MATLAB:structOnObject');
            s = struct(runner);
            warning(warnState);
            annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
                'scenario_000001_annotation.json');
            csrd.test_support.freshAnnotationReader('clear', annotationPath);

            step(runner, 1, 1);

            % A scenario that failed generation must be a LOUD failure, not a
            % quietly smaller sample. step() returns normally either way and the
            % counts used to live only in a log line, so a gate looping over
            % scenarios lost data with no signal at all -- which is how an
            % intractable-resample-ratio failure (1 scenario in 24, ratio
            % 1902671/1179923) stayed hidden behind a stale annotation read.
            runSummary = runner.LastRunSummary;
            assert(runSummary.Failed == 0, ...
                ['Plausibility gate: scenario %d FAILED generation, so this gate ', ...
                 'would otherwise score fewer sources than it asked for and call ', ...
                 'that a result. Cause: %s'], k, runSummary.FirstFailureMessage);

            [annotation, annotationMeta] = csrd.test_support.freshAnnotationReader( ...
                'read', annotationPath, sprintf('scenario %d', k));
            fprintf('  s%-3d %-9s %8d bytes  %s\n', k, ...
                cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel, ...
                annotationMeta.Bytes, annotationMeta.DatenumStr);
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
                    tag = sprintf('s%d/f%d/src%d', k, fi, si);
                    [srcViolations, srcNotes] = ...
                        csrd.test_support.measuredPlausibilityViolations( ...
                            sp, Fs, tag, localPlausibilityContext(src, sp));
                    violations = [violations, srcViolations]; %#ok<AGROW>
                    qualityNotes = [qualityNotes, srcNotes]; %#ok<AGROW>
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
    fprintf('  Low-precision     : %d (%.1f%%, reported not failed)\n', ...
        numel(qualityNotes), 100 * numel(qualityNotes) / max(1, sourcesChecked));
    for v = 1:min(5, numel(qualityNotes))
        fprintf('    ~~ %s\n', qualityNotes{v});
    end
    if numel(qualityNotes) > 5
        fprintf('    ~~ ... and %d more\n', numel(qualityNotes) - 5);
    end

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


% Physical-bound checks live in csrd.test_support.measuredPlausibilityViolations
% so this gate and the joint-dimension gate share one definition.


function ctx = localPlausibilityContext(src, sourcePlane)
    % localPlausibilityContext - cross-plane inputs for the plausibility bounds.
    %   Supplies Truth.Execution.ModulatedBandwidthHz (the same estimator run on
    %   the clean pre-channel waveform) so the measured value can be checked
    %   against the emitter's own bandwidth, plus the measurement status so an
    %   explicitly unresolvable source is exempt from that comparison.
    ctx = struct('ExecutionBwHz', NaN, 'MeasurementStatus', '');
    if isstruct(src) && isfield(src, 'Truth') && isstruct(src.Truth) ...
            && isfield(src.Truth, 'Execution') && isstruct(src.Truth.Execution) ...
            && isfield(src.Truth.Execution, 'ModulatedBandwidthHz')
        ctx.ExecutionBwHz = src.Truth.Execution.ModulatedBandwidthHz;
    end
    if isstruct(sourcePlane) && isfield(sourcePlane, 'MeasurementStatus')
        ctx.MeasurementStatus = sourcePlane.MeasurementStatus;
    end
end
