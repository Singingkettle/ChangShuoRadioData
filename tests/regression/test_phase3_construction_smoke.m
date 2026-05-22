function test_phase3_construction_smoke()
    %TEST_PHASE3_CONSTRUCTION_SMOKE Phase 3 multi-Rx construction smoke test.
    %
    %   Phase 3 (audit §17.5 / phase-3-construction.md §3.6.C / §7) end-to-end
    %   smoke that runs ONE deterministic 1 Tx / 2 Rx scenario through
    %   SimulationRunner and asserts the Phase 3 strict-construction
    %   contracts on the resulting annotation JSON:
    %
    %     C1   - Emitters[k].ReceiverViews exists with NumReceivers
    %            entries when the scenario carries multiple receivers
    %            (proves S2 ReceiverViews projection wired through the
    %            assembled blueprint and survived the annotation pipeline).
    %     C5   - Header.Runtime carries non-empty BlueprintHash and
    %            ValidatorVersion (proves S7 LastGlobalLayout +
    %            extractProvenanceFromGlobalLayout dataflow is wired all
    %            the way to the saver path).
    %     C4   - No SignalSource carries a Phase 3-removed legacy
    %            error sentinel (Status='Error_*' or Error='ReceiverBlockStepFailed'
    %            etc); a clean run must surface only well-formed
    %            sources.
    %     C3   - At least one source has a numeric, finite FrequencyOffset
    %            (proves the ReceiverViews projection actually fed
    %            ChannelFactory + buildSegmentConfig correctly).
    %
    %   The smoke deliberately uses Sub-3GHz_AWGN_PSKQAM with TxRange
    %   [2, 3] and forces RxRange = [2, 2] so it always drives the
    %   multi-Rx path independent of which baseline_recipe_v0 cohort is
    %   currently relaxed.

    fprintf('=== Phase 3 construction smoke (multi-Rx) ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase3_smoke');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end

    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase3-Smoke', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.runtime.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260425, 'twister');

    fullRecipe = baseline_recipe_v0();
    cohort = fullRecipe.Cohorts(1);
    cohort.RxRange = [2, 2];

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    sid = 1;
    scenarioCfg = localApplyCohort(masterCfg, cohort, runRoot, sid);

    t0 = tic;
    [annotationPath, annotation] = localRunOneScenario(scenarioCfg, sid);
    wallclock = toc(t0);

    assert(~isempty(annotationPath) && exist(annotationPath, 'file') == 2, ...
        'Phase 3 smoke: annotation file was not written: %s', annotationPath);
    assert(wallclock < 90, ...
        'Phase 3 smoke: wallclock %.2fs exceeded 90s budget for 1 multi-Rx scenario.', ...
        wallclock);

    raw = fileread(annotationPath);
    % Phase 4 (audit §17.6 / S13): the v2 SanitizeManifest legitimately
    % records reason strings like "NaN->null" / "+Inf->null" inside
    % Header.Runtime.SanitizeManifest entries. The smoke test only
    % cares about *bare* JSON value-position NaN / Infinity tokens (i.e.
    % MATLAB jsonencode emitting `: NaN,` instead of `: null,`); strip
    % JSON string literals before checking so manifest reasons no longer
    % over-match.
    stripped = regexprep(raw, '"(\\.|[^"\\])*"', '""');
    nanHits = numel(regexp(stripped, '(?<![\w.])NaN(?![\w.])', 'match'));
    infHits = numel(regexp(stripped, '(?<![\w.])Infinity(?![\w.])', 'match'));
    assert(nanHits == 0, ...
        'Phase 3 smoke: %d bare NaN tokens leaked into the annotation JSON.', nanHits);
    assert(infHits == 0, ...
        'Phase 3 smoke: %d bare Infinity tokens leaked into the annotation JSON.', infHits);

    % C5: provenance dataflow.
    assert(isfield(annotation, 'Header') && isfield(annotation.Header, 'Runtime'), ...
        'Phase 3 smoke: annotation lacks Header.Runtime (Phase 2 schema regression).');
    rt = annotation.Header.Runtime;
    assert(isfield(rt, 'BlueprintHash') && ~isempty(rt.BlueprintHash), ...
        'Phase 3 smoke / C5: BlueprintHash must be non-empty.');
    assert(isfield(rt, 'ValidatorVersion') && ~isempty(rt.ValidatorVersion), ...
        'Phase 3 smoke / C5: ValidatorVersion must be non-empty.');

    % C1: ReceiverViews fan-out (best-effort: only check if Emitters
    % were serialised into the annotation under any of the known keys).
    [hasEmitters, receiverViewCounts] = localCollectReceiverViews(annotation);
    if hasEmitters
        assert(any(receiverViewCounts >= 2), ...
            ['Phase 3 smoke / C1: no Emitter carried >= 2 ReceiverViews ' ...
             'entries even though RxRange forced 2 receivers (counts: %s).'], ...
            mat2str(receiverViewCounts));
    end

    % C4 + C3: per-source assertions.
    sources = localCollectSources(annotation);
    assert(~isempty(sources), ...
        'Phase 3 smoke: annotation contained no SignalSources.');
    [hasError, finiteOffsets] = localCheckSourceContracts(sources);
    assert(~hasError, ...
        ['Phase 3 smoke / C4: at least one SignalSource carried a Phase 3-removed ' ...
         'legacy error sentinel (Status=Error_* / Error=ReceiverBlockStepFailed).']);
    assert(finiteOffsets >= 1, ...
        ['Phase 3 smoke / C3: no SignalSource carried a finite numeric ' ...
         'FrequencyOffset; ReceiverViews projection likely did not feed ' ...
         'ChannelFactory.']);

    fprintf('  Wallclock           : %.2fs\n', wallclock);
    fprintf('  Annotation bytes    : %d\n', numel(raw));
    fprintf('  Sources captured    : %d\n', numel(sources));
    fprintf('  ReceiverViews counts: %s\n', mat2str(receiverViewCounts));
    fprintf('=== Phase 3 construction smoke PASSED ===\n');
end


function cfg = localApplyCohort(masterCfg, cohort, runRoot, sid)
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260425 + sid;
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
end


function [annotationPath, annotation] = localRunOneScenario(cfg, sid)
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
    annotationPath = fullfile(outDir, 'annotations', ...
        sprintf('scenario_%06d_annotation.json', sid));

    annotation = struct();
    if exist(annotationPath, 'file')
        raw = fileread(annotationPath);
        try
            annotation = jsondecode(raw);
        catch
            annotation = struct();
        end
    end
end


function [hasEmitters, counts] = localCollectReceiverViews(annotation)
    % Walk the annotation looking for any field named 'Emitters' that
    % carries a struct array; each Emitter may carry a ReceiverViews
    % field of length numReceivers.
    hasEmitters = false;
    counts = [];

    payloads = {annotation};
    if isstruct(annotation)
        for fn = {'Frames', 'Annotation', 'Annotations', 'Header'}
            if isfield(annotation, fn{1})
                payloads{end + 1} = annotation.(fn{1}); %#ok<AGROW>
            end
        end
    end
    for c = 1:numel(payloads)
        emitters = localScanForField(payloads{c}, 'Emitters');
        if ~isempty(emitters)
            hasEmitters = true;
            for e = 1:numel(emitters)
                em = emitters{e};
                if isstruct(em) && isfield(em, 'ReceiverViews')
                    counts(end + 1) = numel(em.ReceiverViews); %#ok<AGROW>
                end
            end
        end
    end
end


function out = localScanForField(payload, fieldName)
    out = {};
    if iscell(payload)
        for k = 1:numel(payload)
            out = [out, localScanForField(payload{k}, fieldName)]; %#ok<AGROW>
        end
        return;
    end
    if isstruct(payload)
        if isfield(payload, fieldName)
            value = payload.(fieldName);
            if iscell(value)
                out = [out, value(:)']; %#ok<AGROW>
            elseif isstruct(value)
                for k = 1:numel(value)
                    out{end + 1} = value(k); %#ok<AGROW>
                end
            end
        end
        for k = 1:numel(payload)
            entry = payload(k);
            f = fieldnames(entry);
            for i = 1:numel(f)
                child = entry.(f{i});
                if isstruct(child) || iscell(child)
                    out = [out, localScanForField(child, fieldName)]; %#ok<AGROW>
                end
            end
        end
    end
end


function sources = localCollectSources(annotation)
    sources = {};
    if ~isstruct(annotation); return; end

    candidates = {};
    for fn = {'Frames', 'Annotation', 'Annotations'}
        if isfield(annotation, fn{1})
            candidates{end + 1} = annotation.(fn{1}); %#ok<AGROW>
        end
    end
    candidates{end + 1} = annotation; %#ok<AGROW>

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
    end
end


function [hasError, finiteOffsets] = localCheckSourceContracts(sources)
    hasError = false;
    finiteOffsets = 0;
    forbiddenStatus = {'Error_TransmitterProcessing', 'Error_ReceiverSetup', ...
        'Error_TxFrontend', 'ReceiverBlockStepFailed', 'ReceiverBlockInstantiationFailed'};

    for k = 1:numel(sources)
        src = sources{k};
        if ~isstruct(src); continue; end

        if isfield(src, 'Status') && ischar(src.Status) ...
                && any(strcmp(src.Status, forbiddenStatus))
            hasError = true;
        end
        if isfield(src, 'Error') && ischar(src.Error) ...
                && any(strcmp(src.Error, forbiddenStatus))
            hasError = true;
        end

        % Phase 4 (S13): v1 `Realized.FrequencyOffset` was deleted; the
        % v2 schema publishes the realised receiver-baseband offset under
        % `Truth.Execution.CenterFrequencyOffsetHz`.
        offset = NaN;
        if isfield(src, 'Truth') && isstruct(src.Truth) ...
                && isfield(src.Truth, 'Execution') && isstruct(src.Truth.Execution) ...
                && isfield(src.Truth.Execution, 'CenterFrequencyOffsetHz')
            offset = src.Truth.Execution.CenterFrequencyOffsetHz;
        elseif isfield(src, 'FrequencyOffset')
            offset = src.FrequencyOffset;
        end
        if isnumeric(offset) && isscalar(offset) && isfinite(offset)
            finiteOffsets = finiteOffsets + 1;
        end
    end
end
