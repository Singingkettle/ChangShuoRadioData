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
%     'ChannelModels' - cellstr cycled across scenarios
%                       (default {'AWGN','Rayleigh','Rician'})
%     'CompressData'  - forwarded to Runner.Data.CompressData (default false)
%     'Audit'         - run the strict-reader audit after generation
%                       (default true)
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
addParameter(p, 'ChannelModels', {'AWGN', 'Rayleigh', 'Rician'}, @iscellstr);
addParameter(p, 'CompressData', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Audit', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

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
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ...
        channelModels{mod(k - 1, numel(channelModels)) + 1};
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
            measured = src.Truth.Measured.SourcePlane;
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

    audit = struct( ...
        'ReaderRejects', readerRejects, ...
        'NumSources', nSources, ...
        'NumFrames', nFrames, ...
        'Families', {fams}, ...
        'SnrMedianDb', median(snrs), ...
        'ObwOverAllocWidebandP95', prctile(allocWide, 95), ...
        'ObwOverRrcTheoryResolvedMedian', median(theoryResolved), ...
        'ObwOverRrcTheoryResolvedP95', prctile(theoryResolved, 95), ...
        'FrameNoiseCoverage', frameNoiseCount / max(nSources, 1));
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
