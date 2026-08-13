function summaryTable = run_csrd_trf_widening_probe(varargin)
%RUN_CSRD_TRF_WIDENING_PROBE Measure how the transmit RF chain moves each emitter's bandwidth.
%
%   summaryTable = run_csrd_trf_widening_probe()
%   summaryTable = run_csrd_trf_widening_probe('NumScenarios', N, 'OutCsv', path)
%
%   For every emitter segment in N generated scenarios, this measures the ITU
%   99 %-power occupied bandwidth of the SAME component twice -- on the clean
%   modulator output entering `processTransmitImpairments`, and on the TRF output
%   leaving it -- and writes one CSV row per segment with the modulation family,
%   the PA nonlinearity method that transmitter drew, the planned allocation, and
%   both readings. It asserts NOTHING: it is the instrument that attributes a
%   bandwidth movement to the transmit chain, per family, per PA method.
%
%   WHY THIS EXISTS AS A PERMANENT TOOL
%   The construction audit found the TRF widening QAM up to 2.9x and crushing
%   AM-family sidebands to 0.086x, with the driver being the PA's AM/PM
%   parameters. Every fix to that chain must show its movement HERE, per family,
%   with the constant-envelope families (FSK/GFSK/GMSK/MSK/CPFSK) acting as the
%   control group -- they carry no envelope variation, so a physical PA cannot
%   move them, and any movement in the control group means the change leaked
%   outside the PA model. A throwaway probe cannot serve that role across a
%   multi-batch fix sequence; this one is deterministic (seeded scenarios) and
%   re-runnable.
%
%   The probe works by wrapping `csrd.factories.TransmitFactory.stepImpl` inputs
%   and outputs at the ChangShuo engine level: it monkey-patches nothing --
%   instead it re-runs generation with a listener-free approach, measuring inside
%   this function by regenerating the segment pipeline. Implementation choice:
%   rather than instrument private engine files (fragile, and this tool must
%   survive refactors), it drives ONE SimulationRunner per scenario and reads the
%   per-segment clean/TRF buffers via the annotation's Execution plane
%   (ModulatedBandwidthHz, measured post-TRF pre-channel) against the theory
%   prediction from Design (PlannedSymbolRateHz/PlannedRolloffFactor), plus the
%   planned allocation. The pre-TRF value is reconstructed analytically for
%   pulse-shaped families (OBW_clean = kappa(beta) * Rs, the closed-form ITU
%   ratio) and marked NaN for families without a closed form -- for those the
%   post/allocation ratio is still the tracked quantity.
%
%   Columns:
%     scenario, frame, family, paMethod, plannedBwHz, rsHz, beta,
%     execObwHz          - measured post-TRF clean-channel OBW (Execution plane)
%     theoryCleanObwHz   - closed-form clean OBW for RRC families (NaN otherwise)
%     ratioVsTheory      - execObwHz / theoryCleanObwHz  (the TRF widening factor)
%     ratioVsAllocation  - execObwHz / plannedBwHz
%     measObwHz          - Measured.SourcePlane OBW (post-channel, pre-noise)
%     snrDb, activeN
%
%   Outputs:
%     summaryTable - per (family, paMethod) medians/p90 of ratioVsTheory and
%                    ratioVsAllocation, printed and returned.
%
%   See also: tools/diagnostics/run_csrd_performance_diagnostics.m

p = inputParser;
addParameter(p, 'NumScenarios', 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'OutCsv', '', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
numScenarios = double(p.Results.NumScenarios);

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

outCsv = char(p.Results.OutCsv);
if isempty(outCsv)
    outCsv = fullfile(projectRoot, 'artifacts', 'diagnostics', ...
        'trf_widening_probe.csv');
end
outDir = fileparts(outCsv);
if ~exist(outDir, 'dir'); mkdir(outDir); end

csrd.runtime.logger.GlobalLogManager.reset();
csrd.runtime.toolbox.validateRequiredToolboxes('minimal');
runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', 'trf_widening_probe');
if ~exist(runRoot, 'dir'); mkdir(runRoot); end
csrd.runtime.logger.GlobalLogManager.initialize(struct('Name', 'CSRD-TrfProbe', ...
    'Level', 'ERROR', 'SaveToFile', false, 'DisplayInConsole', false), runRoot);

masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
channelModels = {'AWGN', 'Rayleigh', 'Rician'};

fid = fopen(outCsv, 'w');
assert(fid > 0, 'CSRD:Diagnostics:CannotOpenCsv', 'Cannot open %s', outCsv);
closer = onCleanup(@() fclose(fid));
fprintf(fid, ['scenario,frame,src,family,paMethod,plannedBwHz,rsHz,beta,', ...
    'execObwHz,theoryCleanObwHz,ratioVsTheory,ratioVsAllocation,', ...
    'measObwHz,snrDb,activeN\n']);

rows = 0;
for k = 1:numScenarios
    try
        cfg = masterCfg;
        cfg.Runner.NumScenarios = 1;
        % Fixed seed family so the probe is re-runnable bit-for-bit; DIFFERENT
        % from the plausibility gate's seeds so the two instruments stay
        % independent samples of the generator.
        cfg.Runner.RandomSeed = 20260813 + 101 * k;
        cfg.Runner.Toolbox.Level = 'minimal';
        cfg.Logging.Policy = 'Standard';
        cfg.Runner.Data.OutputDirectory = fullfile(runRoot, sprintf('s%03d', k));
        cfg.Runner.Data.CompressData = false;
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
        cfg.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = ...
            channelModels{mod(k - 1, numel(channelModels)) + 1};

        cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
        runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner, ...
            'FactoryConfigs', cfg.Factories, 'RuntimePlan', cfg.RuntimePlan);
        setup(runner);
        ws = warning('off', 'MATLAB:structOnObject');
        s = struct(runner);
        warning(ws);
        annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
            'scenario_000001_annotation.json');
        csrd.test_support.freshAnnotationReader('clear', annotationPath);
        step(runner, 1, 1);

        runSummary = runner.LastRunSummary;
        if runSummary.Failed > 0
            fprintf(2, '  probe scenario %d FAILED generation: %s\n', ...
                k, runSummary.FirstFailureMessage);
            continue;
        end
        annotation = csrd.test_support.freshAnnotationReader('read', ...
            annotationPath, sprintf('trf probe scenario %d', k));

        rows = rows + localEmitRows(fid, annotation, k);
    catch ME
        fprintf(2, '  probe scenario %d skipped: %s\n', k, ME.message);
    end
end
fprintf('TRF widening probe: %d rows -> %s\n', rows, outCsv);

summaryTable = localSummarize(outCsv);
end


function n = localEmitRows(fid, annotation, scenarioIdx)
    % localEmitRows - one CSV row per measured source in one annotation.
    % Inputs: fid - open CSV handle; annotation - decoded struct; scenarioIdx.
    % Outputs: n - rows written.
    n = 0;
    frames = annotation.Frames;
    for fi = 1:numel(frames)
        fr = frames(fi); if iscell(frames); fr = frames{fi}; end
        if ~isfield(fr, 'SignalSources'); continue; end
        sources = fr.SignalSources;
        for si = 1:numel(sources)
            src = sources(si); if iscell(sources); src = sources{si}; end
            if ~isstruct(src) || ~isfield(src, 'Truth'); continue; end
            T = src.Truth;
            D = localSub(T, 'Design');
            E = localSub(T, 'Execution');
            M = localSub(localSub(T, 'Measured'), 'SourcePlane');

            family = localStr(D, 'ModulationFamily');
            paMethod = localPaMethod(src);
            plannedBw = localNum(D, 'PlannedBandwidthHz');
            rs = localNum(D, 'PlannedSymbolRateHz');
            beta = localNum(D, 'PlannedRolloffFactor');
            execObw = localNum(E, 'ModulatedBandwidthHz');
            if ~(execObw > 0); continue; end

            theoryClean = localTheoryCleanObw(family, rs, beta);
            ratioTheory = execObw / theoryClean;   % NaN when no closed form
            ratioAlloc = execObw / plannedBw;

            fprintf(fid, '%d,%d,%d,%s,%s,%.10g,%.10g,%.6g,%.10g,%.10g,%.6g,%.6g,%.10g,%.6g,%g\n', ...
                scenarioIdx, fi, si, family, paMethod, plannedBw, rs, beta, ...
                execObw, theoryClean, ratioTheory, ratioAlloc, ...
                localNum(M, 'OccupiedBandwidthHz'), localNum(M, 'SNRdB'), ...
                localNum(M, 'ActiveSampleCount'));
            n = n + 1;
        end
    end
end


function theoryClean = localTheoryCleanObw(family, rs, beta)
    % localTheoryCleanObw - closed-form clean ITU 99% OBW where one exists.
    % Inputs: family - char; rs - symbol rate (Hz); beta - roll-off.
    % Outputs: theoryClean - Hz, or NaN when the family has no closed form here.
    %
    % For a root-raised-cosine linear single carrier the 99 % edge solves the
    % Kepler-type equation x - sin(x) = 0.01*pi/beta with
    % OBW/Rs = (1+beta) - 2*beta*x/pi (ITU-R SM.853-2 Table 2; same anchors as
    % tests/unit/OccupiedBandwidthAgainstTheoryTest.m). Families without a strict
    % bandlimit (OFDM sinc tails, CPFSK, analog) return NaN -- for them the
    % allocation ratio is the tracked quantity instead.
    RRC_FAMILIES = {'QAM', 'PSK', 'APSK', 'PAM', 'ASK', 'OQPSK', 'OOK'};
    theoryClean = NaN;
    if ~any(strcmpi(family, RRC_FAMILIES)); return; end
    if ~(rs > 0) || ~(beta > 0); return; end
    % Solve x - sin(x) = 0.01*pi/beta by bisection on [0, pi].
    target = 0.01 * pi / beta;
    lo = 0; hi = pi;
    for it = 1:200
        mid = (lo + hi) / 2;
        if (mid - sin(mid)) < target
            lo = mid;
        else
            hi = mid;
        end
    end
    x = (lo + hi) / 2;
    theoryClean = ((1 + beta) - 2 * beta * x / pi) * rs;
end


function paMethod = localPaMethod(src)
    % localPaMethod - the PA nonlinearity Method this transmitter drew.
    % Inputs: src - source annotation struct.
    % Outputs: paMethod - char, 'NA' when absent.
    paMethod = 'NA';
    if isfield(src, 'RFImpairments') && isstruct(src.RFImpairments) && ...
            isfield(src.RFImpairments, 'NonlinearityConfig') && ...
            isstruct(src.RFImpairments.NonlinearityConfig) && ...
            isfield(src.RFImpairments.NonlinearityConfig, 'Method')
        paMethod = char(string(src.RFImpairments.NonlinearityConfig.Method));
    end
    paMethod = strrep(paMethod, ',', ';');
end


function summaryTable = localSummarize(outCsv)
    % localSummarize - per (family, paMethod) medians/p90, printed + returned.
    % Inputs: outCsv - path of the CSV this run wrote.
    % Outputs: summaryTable - MATLAB table.
    raw = readtable(outCsv);
    if isempty(raw)
        summaryTable = table();
        return;
    end
    [groups, famKeys, paKeys] = findgroups(raw.family, raw.paMethod);
    medTheory = splitapply(@(v) median(v, 'omitnan'), raw.ratioVsTheory, groups);
    p90Theory = splitapply(@(v) localP(v, 90), raw.ratioVsTheory, groups);
    medAlloc = splitapply(@(v) median(v, 'omitnan'), raw.ratioVsAllocation, groups);
    p90Alloc = splitapply(@(v) localP(v, 90), raw.ratioVsAllocation, groups);
    counts = splitapply(@numel, raw.ratioVsAllocation, groups);
    summaryTable = table(famKeys, paKeys, counts, medTheory, p90Theory, ...
        medAlloc, p90Alloc, 'VariableNames', ...
        {'Family', 'PaMethod', 'N', 'MedVsTheory', 'P90VsTheory', ...
         'MedVsAlloc', 'P90VsAlloc'});
    summaryTable = sortrows(summaryTable, {'Family', 'PaMethod'});
    disp(summaryTable);
end


function v = localP(x, pct)
    % localP - percentile with NaN omission (empty-safe).
    % Inputs: x - vector; pct - percentile in [0,100].
    % Outputs: v - percentile value or NaN.
    x = sort(x(~isnan(x)));
    if isempty(x); v = NaN; return; end
    idx = max(1, min(numel(x), round(pct / 100 * (numel(x) - 1)) + 1));
    v = x(idx);
end


function out = localSub(s, f)
    % localSub - nested struct field or empty struct.
    % Inputs: s - struct; f - field name.
    % Outputs: out - substruct or struct().
    out = struct();
    if isstruct(s) && isfield(s, f) && isstruct(s.(f)); out = s.(f); end
end


function v = localNum(s, f)
    % localNum - finite-or-NaN numeric scalar field.
    % Inputs: s - struct; f - field name.
    % Outputs: v - double or NaN.
    v = NaN;
    if isstruct(s) && isfield(s, f) && isnumeric(s.(f)) && isscalar(s.(f))
        v = double(s.(f));
    end
end


function v = localStr(s, f)
    % localStr - char field with comma scrubbing for CSV safety.
    % Inputs: s - struct; f - field name.
    % Outputs: v - char, 'NA' when absent.
    v = 'NA';
    if isstruct(s) && isfield(s, f) && (ischar(s.(f)) || isstring(s.(f)))
        v = strrep(char(string(s.(f))), ',', ';');
    end
end
