function summary = run_csrd_dataset_generation(varargin)
%RUN_CSRD_DATASET_GENERATION Multi-scenario dataset generation driver.
%
%   summary = run_csrd_dataset_generation()
%   summary = run_csrd_dataset_generation('NumScenarios', N, 'BaseSeed', S, ...)
%
%   Generates N scenarios of the csrd2025 dataset into per-scenario
%   directories, then (by default) audits the products from the CONSUMER's
%   side: every annotation must pass the strict reader
%   (csrd.pipeline.annotation.readAnnotation with RequireSources +
%   RequireRuntimeHeader), and the printed report summarizes family
%   coverage, SNR labels, and the measured occupied bandwidth against both
%   the allocation and the RRC closed-form theory.
%
%   WHY THIS EXISTS AS A PERMANENT TOOL
%   The SimulationRunner anchors its data session to the ROOT DIRECTORY the
%   GlobalLogManager was initialized with, not to Runner.Data.OutputDirectory
%   alone. A driver that initializes the logger once and loops scenarios
%   therefore writes every scenario into ONE session directory, silently
%   overwriting the same scenario_000001_annotation.json twenty times -- the
%   run "succeeds" and any audit of the collected paths reads the LAST
%   scenario N times. This driver initializes the logger PER SCENARIO with a
%   per-scenario root (the same discipline as
%   tools/diagnostics/run_csrd_trf_widening_probe.m), which is the entire
%   reason to use it instead of a hand-rolled loop.
%
%   Name-value options:
%     'NumScenarios'  - scenarios to generate (default 20)
%     'BaseSeed'      - first RandomSeed; scenario k uses BaseSeed + 101*(k-1)
%                       (default 20260814; the 101 stride decorrelates the
%                       per-scenario draws more than a small stride does)
%     'OutputRoot'    - dataset root directory (default
%                       artifacts/datasets/run_<timestamp>; an existing root
%                       is REFUSED rather than overwritten)
%     'MapType'       - 'Statistical' (default) or 'OSM'. Statistical uses
%                       the registered fading models below; OSM drives the
%                       RAY-TRACING channel from real building maps, and the
%                       channel model is then a property of the map (the
%                       ChannelModels option is ignored and says so).
%     'ChannelModels' - cellstr cycled across scenarios, Statistical only
%                       (default {'AWGN','Rayleigh','Rician'})
%     'OsmSets'       - OSM only: cellstr of map-set directory names under
%                       data/map/osm (default: every set found there). Each
%                       scenario cycles the sets, then the files within a
%                       set, so a long run covers set x file deterministically.
%                       BUDGET WARNING: ray-tracing cost scales with building
%                       density -- measured 3.8 s/scenario on open farmland
%                       but ~570 s/scenario in an urban canyon.
%     'CompressData'  - forwarded to Runner.Data.CompressData (default false)
%     'Audit'         - run the strict-reader audit after generation
%                       (default true). For OSM runs the audit additionally
%                       reports ChannelModel counts, RayCount, and the
%                       zero-ray FreeSpaceAttenuation fallbacks.
%
%   Output:
%     summary - struct with NumRequested, NumSucceeded, FailureMessages,
%               AnnotationPaths, IqBytes, WallclockSecPerScenario, and (when
%               Audit is on) the Audit sub-struct of the printed statistics.
%
%   Failed scenarios are reported and EXCLUDED from the audit, never
%   silently retried: a failure at this level is a generator defect the
%   operator must see.
%
%   See also: tools/diagnostics/run_csrd_trf_widening_probe.m,
%             csrd.pipeline.annotation.readAnnotation

p = inputParser;
addParameter(p, 'NumScenarios', 20, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'BaseSeed', 20260814, @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'OutputRoot', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'MapType', 'Statistical', ...
    @(x) any(strcmpi(char(string(x)), {'Statistical', 'OSM'})));
addParameter(p, 'ChannelModels', {'AWGN', 'Rayleigh', 'Rician'}, @iscellstr);
addParameter(p, 'OsmSets', {}, @iscellstr);
addParameter(p, 'CompressData', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Audit', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;
useOsm = strcmpi(char(string(opt.MapType)), 'OSM');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

osmFiles = {};
if useOsm
    if ~any(strcmp('ChannelModels', p.UsingDefaults))
        fprintf(['NOTE: MapType=OSM derives the channel from the map ', ...
            '(ray tracing); the ChannelModels option is ignored.\n']);
    end
    osmSets = opt.OsmSets;
    if isempty(osmSets)
        d = dir(fullfile(projectRoot, 'data', 'map', 'osm'));
        osmSets = {d([d.isdir] & ~startsWith({d.name}, '.')).name};
    end
    assert(~isempty(osmSets), 'CSRD:Generation:NoOsmSets', ...
        'No OSM map sets found under data/map/osm.');
    % Flatten to one deterministic (set, file) list: scenario k uses
    % osmFiles{mod(k-1, end)+1}, cycling sets first, then files within a set,
    % so a long run covers set x file without random draws.
    maxFiles = 0;
    perSet = cell(1, numel(osmSets));
    for i = 1:numel(osmSets)
        f = dir(fullfile(projectRoot, 'data', 'map', 'osm', osmSets{i}, '*.osm'));
        assert(~isempty(f), 'CSRD:Generation:EmptyOsmSet', ...
            'OSM set "%s" contains no .osm files.', osmSets{i});
        perSet{i} = arrayfun(@(x) fullfile(x.folder, x.name), f, ...
            'UniformOutput', false);
        maxFiles = max(maxFiles, numel(perSet{i}));
    end
    for j = 1:maxFiles
        for i = 1:numel(osmSets)
            files = perSet{i};
            osmFiles{end + 1} = files{mod(j - 1, numel(files)) + 1}; %#ok<AGROW>
        end
    end
end

outRoot = char(opt.OutputRoot);
if isempty(outRoot)
    outRoot = fullfile(projectRoot, 'artifacts', 'datasets', ...
        ['run_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
end
assert(~exist(outRoot, 'dir'), 'CSRD:Generation:OutputRootExists', ...
    ['Output root already exists: %s. Refusing to mix two generation ', ...
     'runs in one directory -- pick a fresh OutputRoot.'], outRoot);

numScenarios = double(opt.NumScenarios);
channelModels = opt.ChannelModels;

summary = struct('NumRequested', numScenarios, 'NumSucceeded', 0, ...
    'FailureMessages', {{}}, 'AnnotationPaths', {{}}, 'IqBytes', 0, ...
    'WallclockSecPerScenario', nan(1, numScenarios), 'OutputRoot', outRoot);

for k = 1:numScenarios
    scenRoot = fullfile(outRoot, sprintf('s%03d', k));
    % Per-scenario logger root: see the header. This line is load-bearing.
    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
        'Name', 'CSRD-DatasetGen', 'Level', 'ERROR', ...
        'SaveToFile', false, 'DisplayInConsole', false), scenRoot);

    cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    cfg.Runner.NumScenarios = 1;
    cfg.Runner.RandomSeed = opt.BaseSeed + 101 * (k - 1);
    cfg.Runner.Toolbox.Level = 'minimal';
    cfg.Logging.Policy = 'Standard';
    cfg.Runner.Data.OutputDirectory = scenRoot;
    cfg.Runner.Data.CompressData = opt.CompressData;
    if useOsm
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'OSM'};
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
        cfg.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = ...
            osmFiles{mod(k - 1, numel(osmFiles)) + 1};
    else
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ...
            channelModels{mod(k - 1, numel(channelModels)) + 1};
    end
    cfg = csrd.test_support.buildRuntimePlanForTest(cfg);

    runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner, ...
        'FactoryConfigs', cfg.Factories, 'RuntimePlan', cfg.RuntimePlan);
    setup(runner);
    ws = warning('off', 'MATLAB:structOnObject');
    runnerState = struct(runner);
    warning(ws);

    scenarioStart = tic;
    step(runner, 1, 1);
    summary.WallclockSecPerScenario(k) = toc(scenarioStart);

    runSummary = runner.LastRunSummary;
    if runSummary.Failed > 0
        msg = sprintf('scenario %d (seed %d): %s', k, ...
            cfg.Runner.RandomSeed, runSummary.FirstFailureMessage);
        summary.FailureMessages{end + 1} = msg;
        fprintf(2, '!! generation FAILED for %s\n', msg);
        continue;
    end
    summary.NumSucceeded = summary.NumSucceeded + 1;
    summary.AnnotationPaths{end + 1} = fullfile( ...
        runnerState.actualOutputDirectory, 'annotations', ...
        'scenario_000001_annotation.json');
    d = dir(fullfile(runnerState.actualOutputDirectory, 'scenarios', '*.mat'));
    summary.IqBytes = summary.IqBytes + sum([d.bytes]);
end

fprintf('GEN: %d/%d scenarios ok, wallclock med %.2fs, IQ data %.1f MB -> %s\n', ...
    summary.NumSucceeded, numScenarios, ...
    median(summary.WallclockSecPerScenario, 'omitnan'), ...
    summary.IqBytes / 1e6, outRoot);

if opt.Audit && ~isempty(summary.AnnotationPaths)
    summary.Audit = localAudit(summary.AnnotationPaths);
end
end


function audit = localAudit(annPaths)
    % localAudit - consumer-view audit through the STRICT reader.
    % Inputs: annPaths - cell array of annotation JSON paths.
    % Outputs: audit - struct of the printed statistics.
    %
    % Sliced deliberately: the GLOBAL OBW/allocation quantiles are dominated
    % by narrowband short-window rows whose reported width is the honest
    % measurement floor (~33 analysis cells), so the wideband and
    % resolved-rows slices are the ones that state whether construction is
    % clean; the RRC closed-form slice is the absolute, external-theory
    % anchor (ITU-R SM.853-2 Table 2, same kernel as
    % OccupiedBandwidthAgainstTheoryTest).
    families = containers.Map('KeyType', 'char', 'ValueType', 'double');
    channelModelCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    fallbackCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    rayCounts = [];
    snrs = []; allocRatio = []; theoryResolved = [];
    allocWide = []; ctrRelWide = []; frameNoiseCount = 0;
    nSources = 0; nFrames = 0; readerRejects = 0;
    for a = 1:numel(annPaths)
        try
            reader = csrd.pipeline.annotation.readAnnotation(annPaths{a}, ...
                'RequireSources', true, 'RequireRuntimeHeader', true);
        catch readerError
            readerRejects = readerRejects + 1;
            fprintf(2, '!! reader REJECTED %s: %s\n', annPaths{a}, ...
                readerError.message);
            continue;
        end
        nFrames = nFrames + reader.Summary.NumFrames;
        for si = 1:numel(reader.Sources)
            src = reader.Sources{si};
            nSources = nSources + 1;
            design = src.Truth.Design;
            execution = src.Truth.Execution;
            measured = src.Truth.Measured.SourcePlane;
            cm = 'missing';
            if isfield(execution, 'ChannelModel')
                cm = char(string(execution.ChannelModel));
            end
            if isKey(channelModelCounts, cm)
                channelModelCounts(cm) = channelModelCounts(cm) + 1;
            else
                channelModelCounts(cm) = 1;
            end
            if isfield(execution, 'ChannelFallback') && ...
                    ~isempty(execution.ChannelFallback)
                fb = char(string(execution.ChannelFallback));
                if isKey(fallbackCounts, fb)
                    fallbackCounts(fb) = fallbackCounts(fb) + 1;
                else
                    fallbackCounts(fb) = 1;
                end
            end
            if isfield(execution, 'RayCount') && ...
                    isnumeric(execution.RayCount) && isscalar(execution.RayCount)
                rayCounts(end + 1) = double(execution.RayCount); %#ok<AGROW>
            end
            fam = char(string(design.ModulationFamily));
            if isKey(families, fam)
                families(fam) = families(fam) + 1;
            else
                families(fam) = 1;
            end
            if isfinite(localNum(measured, 'SNRdB'))
                snrs(end + 1) = measured.SNRdB; %#ok<AGROW>
            end
            ob = localNum(measured, 'OccupiedBandwidthHz');
            rbw = localNum(measured, 'BandwidthResolutionHz');
            if isfinite(ob) && ob > 0
                allocRatio(end + 1) = ob / design.AllocatedBandwidthHz; %#ok<AGROW>
                if design.AllocatedBandwidthHz >= 1e6
                    allocWide(end + 1) = ob / design.AllocatedBandwidthHz; %#ok<AGROW>
                    ctrRelWide(end + 1) = abs(localNum(measured, 'CenterFrequencyHz') - ...
                        design.PlannedCenterFrequencyHz) / ...
                        design.AllocatedBandwidthHz; %#ok<AGROW>
                end
            end
            th = localRrcTheoryObwHz(design);
            if isfinite(th) && th > 0 && isfinite(ob) && ...
                    isfinite(rbw) && rbw > 0 && th / rbw >= 33
                theoryResolved(end + 1) = ob / th; %#ok<AGROW>
            end
            if isfield(src.Truth.Measured, 'FramePlane') && ...
                    localFiniteField(src.Truth.Measured.FramePlane, ...
                        'FrameChannelNoisePowerW')
                frameNoiseCount = frameNoiseCount + 1;
            end
        end
    end

    fprintf('READ: %d annotations accepted, %d rejected by the strict reader\n', ...
        numel(annPaths) - readerRejects, readerRejects);
    fprintf('SOURCES: %d across %d receiver frames\n', nSources, nFrames);
    fams = keys(families);
    fprintf('FAMILIES (%d):', numel(fams));
    for i = 1:numel(fams)
        fprintf(' %s=%d', fams{i}, families(fams{i}));
    end
    fprintf('\n');
    fprintf('SNRdB: n=%d med %.1f [p10 %.1f, p90 %.1f]\n', numel(snrs), ...
        median(snrs), prctile(snrs, 10), prctile(snrs, 90));
    fprintf('OBW/Alloc all rows: med %.3f (floor-bound narrowband reads wide honestly)\n', ...
        median(allocRatio));
    fprintf('OBW/Alloc wideband (>=1MHz): n=%d med %.3f p95 %.3f max %.3f\n', ...
        numel(allocWide), median(allocWide), prctile(allocWide, 95), ...
        max([allocWide, -Inf]));
    fprintf('OBW/RRC-theory RESOLVED rows (>=33 cells): n=%d med %.4f p95 %.4f max %.4f\n', ...
        numel(theoryResolved), median(theoryResolved), ...
        prctile(theoryResolved, 95), max([theoryResolved, -Inf]));
    fprintf('|measCtr-plannedCtr|/alloc wideband: med %.4f p95 %.4f\n', ...
        median(ctrRelWide), prctile(ctrRelWide, 95));
    fprintf('FrameChannelNoisePowerW: finite on %d/%d source records\n', ...
        frameNoiseCount, nSources);
    cmk = keys(channelModelCounts);
    fprintf('ChannelModel:');
    for i = 1:numel(cmk)
        fprintf(' %s=%d', cmk{i}, channelModelCounts(cmk{i}));
    end
    fprintf('\n');
    if ~isempty(rayCounts)
        fbk = keys(fallbackCounts);
        fbTotal = 0;
        for i = 1:numel(fbk); fbTotal = fbTotal + fallbackCounts(fbk{i}); end
        fprintf(['RayCount: med %g [min %g, max %g]; zero-ray links %d, ', ...
            'explicit fallbacks %d'], median(rayCounts), min(rayCounts), ...
            max(rayCounts), nnz(rayCounts == 0), fbTotal);
        for i = 1:numel(fbk)
            fprintf(' (%s=%d)', fbk{i}, fallbackCounts(fbk{i}));
        end
        fprintf('\n');
    end

    audit = struct( ...
        'ReaderRejects', readerRejects, ...
        'NumSources', nSources, ...
        'NumFrames', nFrames, ...
        'Families', {fams}, ...
        'SnrMedianDb', median(snrs), ...
        'ObwOverAllocWidebandP95', prctile(allocWide, 95), ...
        'ObwOverRrcTheoryResolvedMedian', median(theoryResolved), ...
        'ObwOverRrcTheoryResolvedP95', prctile(theoryResolved, 95), ...
        'FrameNoiseCoverage', frameNoiseCount / max(nSources, 1), ...
        'ChannelModelCounts', channelModelCounts, ...
        'ZeroRayLinks', nnz(rayCounts == 0), ...
        'FallbackCounts', fallbackCounts);
end


function theoryHz = localRrcTheoryObwHz(design)
    % localRrcTheoryObwHz - closed-form clean ITU 99% OBW from Design facts.
    % Inputs: design - Truth.Design struct.
    % Outputs: theoryHz - kappa(beta)*Rs for RRC single-carrier families,
    %          NaN otherwise (same Kepler solve as the widening probe and
    %          the baseline sweep's Measured-vs-Design metric).
    theoryHz = NaN;
    rrcFamilies = {'QAM', 'PSK', 'APSK', 'PAM', 'ASK', 'OQPSK', 'OOK', 'Mill88QAM'};
    if ~ismember(char(string(design.ModulationFamily)), rrcFamilies)
        return;
    end
    rs = localNum(design, 'PlannedSymbolRateHz');
    beta = localNum(design, 'PlannedRolloffFactor');
    if ~(isfinite(rs) && rs > 0 && isfinite(beta) && beta > 0)
        return;
    end
    target = 0.01 * pi / beta;
    lo = 0; hi = pi;
    for it = 1:60
        mid = (lo + hi) / 2;
        if mid - sin(mid) < target
            lo = mid;
        else
            hi = mid;
        end
    end
    theoryHz = ((1 + beta) - 2 * beta * ((lo + hi) / 2) / pi) * rs;
end


function v = localNum(s, fieldName)
    % localNum - finite-or-NaN scalar field accessor.
    % Inputs: s - struct; fieldName - char.
    % Outputs: v - double(s.(fieldName)) when a numeric scalar, else NaN.
    v = NaN;
    if isfield(s, fieldName) && isnumeric(s.(fieldName)) && ...
            isscalar(s.(fieldName))
        v = double(s.(fieldName));
    end
end


function tf = localFiniteField(s, fieldName)
    % localFiniteField - true when s.(fieldName) is a finite numeric scalar.
    % Inputs: s - struct; fieldName - char.
    % Outputs: tf - logical.
    tf = isfield(s, fieldName) && isnumeric(s.(fieldName)) && ...
        isscalar(s.(fieldName)) && isfinite(s.(fieldName));
end
