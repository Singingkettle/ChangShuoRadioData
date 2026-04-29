function test_phase1_dataflow_smoke()
%TEST_PHASE1_DATAFLOW_SMOKE End-to-end dataflow smoke test for Phase 1.
%
%   Runs ONE deterministic scenario through SimulationRunner using the
%   smallest cohort from baseline_recipe_v0 and asserts the six Phase 1
%   contracts on the resulting annotation JSON:
%
%     A1 / H1  - RxImpairments must be present on at least one source
%                (proves NumAntennas alias did not silently break the
%                receiver chain).
%     A2 / H3  - the per-source BurstId field is non-empty for every
%                emitted source, proving multi-burst-per-frame plumbing
%                (or its happy-path fallback) does not produce sources
%                with missing identifiers.
%     A4       - SimulationRunner did not crash; if entity sync had
%                returned empty, an EmptyEntities/EntityDriftDetected
%                exception would have aborted the scenario long before
%                annotations were written.
%     H13      - the annotation contains a ChannelModel field on every
%                source, proving channel processing actually ran (the
%                burst-aware seed path requires step() to execute).
%     H14      - upstream-owned identifier fields (TxId, BurstId) are
%                preserved on at least one source, proving the channel
%                output merge does not wipe out the upstream metadata.
%     C1       - RxImpairments contains the FULL six-field set when
%                present.
%
%   Plus two cross-cutting Phase 0 invariants the smoke also checks:
%     - JSON contains no bare NaN / Infinity tokens.
%     - SimulationRunner finishes within a reasonable wallclock for
%       a 1-scenario smoke (60s budget, much higher than typical).

    fprintf('=== Phase 1 dataflow smoke test ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    csrd.utils.logger.GlobalLogManager.reset();
    csrd.utils.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase1_smoke');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end
    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase1-Smoke', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.utils.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.utils.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260424, 'twister');

    fullRecipe = baseline_recipe_v0();
    cohorts = fullRecipe.Cohorts;
    cohort = cohorts(1);

    masterCfg = csrd.utils.config_loader('csrd2025/csrd2025.m');
    sid = 1;
    scenarioCfg = localApplyCohort(masterCfg, cohort, runRoot, sid);

    t0 = tic;
    [annotationPath, annotation] = localRunOneScenario(scenarioCfg, sid);
    wallclock = toc(t0);

    assert(~isempty(annotationPath) && exist(annotationPath, 'file') == 2, ...
        'Phase 1 smoke: annotation file was not written: %s', annotationPath);
    assert(wallclock < 60, ...
        'Phase 1 smoke: wallclock %.2fs exceeded 60s budget for 1 scenario.', ...
        wallclock);

    raw = fileread(annotationPath);
    % Phase 4 (audit §17.6 / S13): the v2 SanitizeManifest legitimately
    % records reason strings like "NaN->null" / "+Inf->null" inside
    % Header.Runtime.SanitizeManifest entries. The smoke test only
    % cares about *bare* JSON value-position NaN / Infinity tokens (i.e.
    % MATLAB jsonencode emitting `: NaN,` instead of `: null,`); strip
    % JSON string literals before checking so manifest reasons no longer
    % over-match. Mirrors the fix applied to test_phase3_construction_smoke.
    stripped = regexprep(raw, '"(\\.|[^"\\])*"', '""');
    nanHits = numel(regexp(stripped, '(?<![\w.])NaN(?![\w.])', 'match'));
    infHits = numel(regexp(stripped, '(?<![\w.])Infinity(?![\w.])', 'match'));
    assert(nanHits == 0, ...
        'Phase 1 smoke: %d bare NaN tokens leaked into the annotation JSON.', nanHits);
    assert(infHits == 0, ...
        'Phase 1 smoke: %d bare Infinity tokens leaked into the annotation JSON.', infHits);

    sources = localCollectSources(annotation);
    assert(~isempty(sources), ...
        'Phase 1 smoke: annotation contained no SignalSources (frame would be empty).');

    [allHaveTxId, allHaveChannelModel, sourcesWithTxRFI] = ...
        localCheckCoreIdentifiers(sources);
    assert(allHaveTxId, ...
        ['Phase 1 smoke: at least one source has an empty/missing TxID. ' ...
         'H14 mergeChannelOutput likely overwrote upstream metadata.']);
    assert(allHaveChannelModel, ...
        ['Phase 1 smoke: at least one source has no Channel.Model field. ' ...
         'Channel block did not execute or was wiped (H13/H14 regressed).']);
    assert(sourcesWithTxRFI >= 1, ...
        ['Phase 1 smoke: no source carried TX-side RFImpairments. ' ...
         'mergeChannelOutput (H14) likely dropped the upstream chain.']);

    [hasRxImp, fullRxImpFrames, missingRxImpFields] = ...
        localCheckFrameRxImpairments(annotation);
    assert(hasRxImp, ...
        ['Phase 1 smoke: no frame annotation carried frame-level ' ...
         'RxImpairments. C1 (RxImpairments full set) regressed or the ' ...
         'receiver chain was bypassed.']);
    assert(fullRxImpFrames >= 1, ...
        ['Phase 1 smoke: no frame carried the full 6-field RxImpairments ' ...
         'set (missing in last failing frame: %s).'], ...
        strjoin(missingRxImpFields, ','));

    fprintf('  Wallclock           : %.2fs\n', wallclock);
    fprintf('  Annotation bytes    : %d\n', numel(raw));
    fprintf('  Sources captured    : %d\n', numel(sources));
    fprintf('  Frames w/ Rx 6-set  : %d\n', fullRxImpFrames);
    fprintf('=== Phase 1 dataflow smoke PASSED ===\n');
end


function cfg = localApplyCohort(masterCfg, cohort, runRoot, sid)
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260424 + sid;
    cfg.Runner.Toolbox.Level    = 'minimal';
    cfg.Runner.Log.Policy       = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
        sprintf('scenario_%06d', sid));
    cfg.Runner.Data.CompressData = false;

    cfg.Factories.Scenario.Global.NumFramesPerScenario = ...
        cohort.NumFramesPerScenario;
    cfg.Factories.Scenario.Global.ObservationDuration = ...
        cohort.ObservationDuration;

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

    % Phase 8 made regulatory planning the default public path. This Phase 1
    % smoke is a dataflow contract test, not a wideband IMT stress test, so
    % keep it regulatory-backed but pin it to a narrow SRD band. Leaving the
    % weighted catalog selector unconstrained can pick tens-of-MHz IMT bands
    % and turn the historical 1-scenario smoke into a performance sweep.
    if isfield(cfg.Factories.Scenario.CommunicationBehavior, 'Regulatory') && ...
            isstruct(cfg.Factories.Scenario.CommunicationBehavior.Regulatory)
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = 'Fixed';
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = 'CN';
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = 'Tier1';
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.FixedBandId = ...
            'CN_SRD_433';
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.RestrictEmittersToFixedBand = true;
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = ...
            {'Radar', 'Radiolocation', 'Radionavigation'};
        cfg.Factories.Scenario.CommunicationBehavior.Regulatory.MaxBandwidthFractionOfSampleRate = 0.5;
    end
end


function [annotationPath, annotation] = localRunOneScenario(cfg, sid)
    runner = csrd.SimulationRunner( ...
        'RunnerConfig', cfg.Runner, 'FactoryConfigs', cfg.Factories);
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


function [allTx, allChannel, sourcesWithTxRFI] = localCheckCoreIdentifiers(sources)
    % H14 contract surface visible in sourceInfo:
    %   * TxID                         - upstream identifier preservation
    %   * Channel model identifier     - channel block actually ran
    %   * RFImpairments (TX side)      - upstream chain not wiped on merge
    %
    % Phase 4 (audit §17.6 / S13): the v1 top-level `Channel` sub-struct
    % was deleted in favour of the unified Truth.Execution.ChannelModel
    % string. The H14 "channel block actually ran" check now reads
    % `Truth.Execution.ChannelModel` instead of `Channel.Model`.
    allTx = true;
    allChannel = true;
    sourcesWithTxRFI = 0;
    for k = 1:numel(sources)
        src = sources{k};
        if ~isstruct(src); continue; end
        if ~isfield(src, 'TxID') || isempty(src.TxID)
            allTx = false;
        end
        hasModel = false;
        if isfield(src, 'Truth') && isstruct(src.Truth) ...
                && isfield(src.Truth, 'Execution') ...
                && isstruct(src.Truth.Execution) ...
                && isfield(src.Truth.Execution, 'ChannelModel')
            cm = src.Truth.Execution.ChannelModel;
            hasModel = (ischar(cm) || isstring(cm)) && ~isempty(char(cm));
        end
        if ~hasModel
            allChannel = false;
        end
        if isfield(src, 'RFImpairments') && isstruct(src.RFImpairments)
            sourcesWithTxRFI = sourcesWithTxRFI + 1;
        end
    end
end


function [anyHave, fullCount, missingFields] = localCheckFrameRxImpairments(annotation)
    % §3.6.2 surfaces RX-side RxImpairments at frame level (not on
    % SignalSources). Walks the same Frames-wrapped structure used by
    % localCollectSources and counts frames whose RxImpairments contains
    % the full Phase 1 6-field set.
    anyHave = false;
    fullCount = 0;
    missingFields = {};
    requiredFields = {'Type', 'DCOffset', 'IqImbalanceConfig', ...
        'ThermalNoiseConfig', 'MemoryLessNonlinearityConfig', 'SampleRateOffset'};

    if ~isstruct(annotation); return; end
    candidates = {};
    for fn = {'Frames', 'Annotation', 'Annotations'}
        if isfield(annotation, fn{1})
            candidates{end + 1} = annotation.(fn{1}); %#ok<AGROW>
        end
    end
    candidates{end + 1} = annotation; %#ok<AGROW>

    [anyHave, fullCount, missingFields] = ...
        localScanRxImpairments(candidates, requiredFields, ...
        anyHave, fullCount, missingFields);
end


function [anyHave, fullCount, missingFields] = ...
        localScanRxImpairments(payloads, requiredFields, anyHave, fullCount, missingFields)
    for c = 1:numel(payloads)
        payload = payloads{c};
        if iscell(payload)
            [anyHave, fullCount, missingFields] = ...
                localScanRxImpairments(payload(:)', requiredFields, ...
                anyHave, fullCount, missingFields);
            continue;
        end
        if ~isstruct(payload); continue; end
        for k = 1:numel(payload)
            entry = payload(k);
            if isfield(entry, 'RxImpairments') && isstruct(entry.RxImpairments)
                anyHave = true;
                imp = entry.RxImpairments;
                missing = requiredFields(~isfield(imp, requiredFields));
                if isempty(missing)
                    fullCount = fullCount + 1;
                else
                    missingFields = missing;
                end
            end
        end
    end
end
