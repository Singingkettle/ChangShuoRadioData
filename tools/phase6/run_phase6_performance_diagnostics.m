function results = run_phase6_performance_diagnostics(varargin)
%RUN_PHASE6_PERFORMANCE_DIAGNOSTICS Read-only Phase 6 performance report.
%
%   RESULTS = run_phase6_performance_diagnostics() reads the frozen
%   final-v04 baseline and the Phase 4 reference baseline, checks that
%   correctness gates remain intact, and reports performance watch items.
%
%   This tool is diagnostic. It must not run simulations, change
%   measurement thresholds, or promote operator wallclock numbers into
%   label-correctness gates.

p = inputParser;
addParameter(p, 'FinalBaselinePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ReferenceBaselinePath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunMicrobench', false, @islogical);
addParameter(p, 'NumMicrobenchRepeats', 3, @isPositiveInteger);
addParameter(p, 'OutputJsonPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, varargin{:});

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
finalPath = resolvePath(projectRoot, p.Results.FinalBaselinePath, ...
    fullfile('docs', 'baselines', '2026-04-final-v04.json'));
referencePath = resolvePath(projectRoot, p.Results.ReferenceBaselinePath, ...
    fullfile('docs', 'baselines', '2026-04-baseline-v0.json'));

finalBaseline = readJsonStruct(finalPath, 'final baseline');
referenceBaseline = readJsonStruct(referencePath, 'reference baseline');

comparison = buildBaselineComparison(referenceBaseline, finalBaseline);
contracts = evaluateFrozenContracts(finalBaseline);
hotspots = inspectStaticHotspots(projectRoot);

microbench = struct('Ran', false);
if p.Results.RunMicrobench
    microbench = runMeasurementMicrobench(p.Results.NumMicrobenchRepeats);
end

results = struct();
results.Success = contracts.Success && hotspots.Success;
results.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
results.Schema = 'csrd.phase6.performance-diagnostics.v1';
results.ProjectRoot = projectRoot;
results.FinalBaselinePath = finalPath;
results.ReferenceBaselinePath = referencePath;
results.NonGoals = { ...
    'No simulation run', ...
    'No measurement threshold change', ...
    'No CI wallclock gate change', ...
    'No annotation correctness metric change'};
results.BaselineComparison = comparison;
results.FrozenContracts = contracts;
results.StaticHotspots = hotspots;
results.Microbench = microbench;

if strlength(string(p.Results.OutputJsonPath)) > 0
    writeResultsJson(results, char(p.Results.OutputJsonPath));
end

if p.Results.Verbose
    printSummary(results);
end
end


function tf = isPositiveInteger(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 1 ...
    && floor(value) == value;
end


function path = resolvePath(projectRoot, supplied, defaultRelative)
if strlength(string(supplied)) == 0
    path = fullfile(projectRoot, defaultRelative);
else
    path = char(supplied);
    if ~isfile(path)
        path = fullfile(projectRoot, path);
    end
end
assert(isfile(path), ...
    'CSRD:Phase6:MissingDiagnosticsInput', ...
    'Required diagnostics input does not exist: %s', path);
end


function payload = readJsonStruct(path, label)
payload = jsondecode(fileread(path));
assert(isstruct(payload), ...
    'CSRD:Phase6:InvalidDiagnosticsInput', ...
    'Expected %s to decode to a struct: %s', label, path);
end


function comparison = buildBaselineComparison(referenceBaseline, finalBaseline)
refMetrics = referenceBaseline.Metrics;
finalMetrics = finalBaseline.Metrics;

comparison = struct();
comparison.Reference = struct( ...
    'PathLabel', '2026-04-baseline-v0', ...
    'NumScenarios', double(referenceBaseline.Recipe.NumScenarios), ...
    'Mode', char(referenceBaseline.Mode));
comparison.Final = struct( ...
    'PathLabel', '2026-04-final-v04', ...
    'NumScenarios', double(finalBaseline.Recipe.NumScenarios), ...
    'Mode', char(finalBaseline.Mode));

comparison.WallclockSecPerScenarioP50 = compareMetric( ...
    refMetrics, finalMetrics, 'WallclockSecPerScenarioP50', 'watch-if-increased');
comparison.WallclockSecPerScenarioP95 = compareMetric( ...
    refMetrics, finalMetrics, 'WallclockSecPerScenarioP95', 'watch-if-increased');
comparison.AnnotationFileBytesP95 = compareMetric( ...
    refMetrics, finalMetrics, 'AnnotationFileBytesP95', 'watch-if-increased');
comparison.LogLinesPerScenarioP95 = compareMetric( ...
    refMetrics, finalMetrics, 'LogLinesPerScenarioP95', 'watch-if-increased');
comparison.ExecutionVsMeasuredBwAbsRelDiffP95 = compareMetric( ...
    refMetrics, finalMetrics, 'ExecutionVsMeasuredBwAbsRelDiffP95', ...
    'correctness-gate');
end


function out = compareMetric(refMetrics, finalMetrics, fieldName, policy)
refValue = double(refMetrics.(fieldName));
finalValue = double(finalMetrics.(fieldName));
if refValue == 0
    changePct = NaN;
else
    changePct = 100 * (finalValue - refValue) / refValue;
end

diagnostic = 'ok';
switch policy
    case 'watch-if-increased'
        if finalValue > refValue
            diagnostic = 'watch';
        end
    case 'correctness-gate'
        if finalValue >= 0.03
            diagnostic = 'fail';
        end
end

out = struct( ...
    'Reference', refValue, ...
    'Final', finalValue, ...
    'ChangePct', changePct, ...
    'Diagnostic', diagnostic, ...
    'Policy', policy);
end


function contracts = evaluateFrozenContracts(finalBaseline)
metrics = finalBaseline.Metrics;
diag = metrics.Diagnostics;
runRecovery = finalBaseline.RunRecovery;
numScenarios = double(finalBaseline.Recipe.NumScenarios);

checks = [
    makeCheck('BlueprintAcceptanceRate', ...
        metrics.BlueprintAcceptanceRate >= 0.98, metrics.BlueprintAcceptanceRate)
    makeCheck('ChannelFactoryFailureRate', ...
        metrics.ChannelFactoryFailureRate == 0, metrics.ChannelFactoryFailureRate)
    makeCheck('ExecutionVsMeasuredBwAbsRelDiffP95', ...
        metrics.ExecutionVsMeasuredBwAbsRelDiffP95 < 0.03, ...
        metrics.ExecutionVsMeasuredBwAbsRelDiffP95)
    makeCheck('EmptySignalSegmentRatio', ...
        metrics.EmptySignalSegmentRatio == 0, metrics.EmptySignalSegmentRatio)
    makeCheck('BlueprintProvenanceCoverage', ...
        metrics.BlueprintProvenanceCoverage == 1, ...
        metrics.BlueprintProvenanceCoverage)
    makeCheck('JsonNanCount', diag.JsonNanCount == 0, diag.JsonNanCount)
    makeCheck('JsonInfinityCount', ...
        diag.JsonInfinityCount == 0, diag.JsonInfinityCount)
    makeCheck('RunRecoveryResume', logical(runRecovery.Resume), ...
        runRecovery.Resume)
    makeCheck('RunRecoveryRecoveredScenarios', ...
        double(runRecovery.NumRecoveredScenarios) == numScenarios, ...
        runRecovery.NumRecoveredScenarios)
    ];

contracts = struct();
contracts.Success = all([checks.Passed]);
contracts.Checks = checks;
contracts.Note = ['These are frozen correctness contracts. Performance ', ...
    'diagnostics must not weaken them.'];
end


function check = makeCheck(name, passed, value)
check = struct( ...
    'Name', name, ...
    'Passed', logical(passed), ...
    'Value', value);
end


function hotspots = inspectStaticHotspots(projectRoot)
obwPath = fullfile(projectRoot, '+csrd', '+utils', '+measurement', ...
    'obwActual.m');
rxPath = fullfile(projectRoot, '+csrd', '+core', '@ChangShuo', ...
    'private', 'processReceiverProcessing.m');
rrfPath = fullfile(projectRoot, '+csrd', '+blocks', '+physical', ...
    '+rxRadioFront', 'RRFSimulator.m');

obwCode = stripMatlabComments(fileread(obwPath));
rxCode = stripMatlabComments(fileread(rxPath));
rrfCode = stripMatlabComments(fileread(rrfPath));

framePlaneCalls = regexp(rxCode, 'computeFramePlaneCache\s*\(', 'match');
hotspots = struct();
hotspots.Success = true;
hotspots.Items = [
    makeHotspot('obwActualUsesPwelch', contains(obwCode, 'pwelch('), ...
        obwPath, 'Measurement OBW currently depends on pwelch.')
    makeHotspot('obwActualPeakRelativeDefault', ...
        contains(obwCode, '''PeakRelativeDb'', -3'), obwPath, ...
        'Peak-relative -3 dBc default is frozen by Phase 4/5 evidence.')
    makeHotspot('FramePlaneCachePresent', ...
        contains(rxCode, 'framePlaneCache') && ~isempty(framePlaneCalls), ...
        rxPath, 'FramePlane should remain once-per-receiver cached.')
    makeHotspot('RRFReleaseThermalNoiseObserved', ...
        contains(rrfCode, 'release(obj.ThermalNoise)'), rrfPath, ...
        'Per-step release pattern is a profiling candidate, not a fix.')
    makeHotspot('RRFReleaseSampleShifterObserved', ...
        contains(rrfCode, 'release(obj.SampleShifter)'), rrfPath, ...
        'Per-step release pattern is a profiling candidate, not a fix.')
    ];
hotspots.FramePlaneComputeFramePlaneCacheTokenCount = numel(framePlaneCalls);
hotspots.Success = all([hotspots.Items.Observed]);
hotspots.Note = ['Static hotspot checks only locate known diagnostic ', ...
    'sites; they do not approve performance rewrites.'];
end


function item = makeHotspot(name, observed, path, note)
item = struct( ...
    'Name', name, ...
    'Observed', logical(observed), ...
    'Path', path, ...
    'Note', note);
end


function stripped = stripMatlabComments(code)
lines = regexp(code, '\r\n|\n|\r', 'split');
for i = 1:numel(lines)
    line = lines{i};
    pct = regexp(line, '%', 'once');
    if ~isempty(pct)
        lines{i} = line(1:pct - 1);
    end
end
stripped = strjoin(lines, newline);
end


function microbench = runMeasurementMicrobench(numRepeats)
rng(20260428, 'twister');
sampleRate = 50e6;
n = 2 ^ 15;
t = (0:n - 1).' / sampleRate;
signal = exp(1j * 2 * pi * 2e6 * t) + ...
    0.2 * exp(1j * 2 * pi * 2.3e6 * t);
signal = signal + 0.01 * complex(randn(n, 1), randn(n, 1));

obwTimes = zeros(numRepeats, 1);
centroidTimes = zeros(numRepeats, 1);
envelopeTimes = zeros(numRepeats, 1);
for k = 1:numRepeats
    t0 = tic;
    csrd.utils.measurement.obwActual(signal, sampleRate);
    obwTimes(k) = toc(t0);

    t0 = tic;
    csrd.utils.measurement.spectrumCentroid(signal, sampleRate);
    centroidTimes(k) = toc(t0);

    t0 = tic;
    csrd.utils.measurement.detectBurstEnvelope(signal, sampleRate);
    envelopeTimes(k) = toc(t0);
end

microbench = struct();
microbench.Ran = true;
microbench.NumRepeats = double(numRepeats);
microbench.SignalLength = double(n);
microbench.SampleRateHz = sampleRate;
microbench.ObwActualSecMedian = median(obwTimes);
microbench.SpectrumCentroidSecMedian = median(centroidTimes);
microbench.DetectBurstEnvelopeSecMedian = median(envelopeTimes);
microbench.Policy = 'diagnostic-only-no-threshold';
end


function writeResultsJson(results, outputPath)
outDir = fileparts(outputPath);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end
[clean, ~] = csrd.utils.annotation.sanitizeForJson(results);
fid = fopen(outputPath, 'w');
assert(fid > 0, 'CSRD:Phase6:DiagnosticsWriteFailed', ...
    'Could not open diagnostics output for writing: %s', outputPath);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(clean, 'PrettyPrint', true));
delete(cleanup);
end


function printSummary(results)
fprintf('=== CSRD Phase 6 performance diagnostics ===\n');
fprintf('Final baseline: %s\n', results.FinalBaselinePath);
fprintf('Reference baseline: %s\n', results.ReferenceBaselinePath);
fprintf('Wallclock P50: %.3fs -> %.3fs (%+.1f%%, %s)\n', ...
    results.BaselineComparison.WallclockSecPerScenarioP50.Reference, ...
    results.BaselineComparison.WallclockSecPerScenarioP50.Final, ...
    results.BaselineComparison.WallclockSecPerScenarioP50.ChangePct, ...
    results.BaselineComparison.WallclockSecPerScenarioP50.Diagnostic);
fprintf('Wallclock P95: %.3fs -> %.3fs (%+.1f%%, %s)\n', ...
    results.BaselineComparison.WallclockSecPerScenarioP95.Reference, ...
    results.BaselineComparison.WallclockSecPerScenarioP95.Final, ...
    results.BaselineComparison.WallclockSecPerScenarioP95.ChangePct, ...
    results.BaselineComparison.WallclockSecPerScenarioP95.Diagnostic);
fprintf('BW P95 diff: %.6f (policy %s)\n', ...
    results.BaselineComparison.ExecutionVsMeasuredBwAbsRelDiffP95.Final, ...
    results.BaselineComparison.ExecutionVsMeasuredBwAbsRelDiffP95.Policy);
fprintf('Frozen contracts: %s\n', passFail(results.FrozenContracts.Success));
fprintf('Static hotspots located: %s\n', passFail(results.StaticHotspots.Success));
if results.Microbench.Ran
    fprintf('Microbench obwActual median: %.6fs\n', ...
        results.Microbench.ObwActualSecMedian);
end
fprintf('=== Phase 6 performance diagnostics %s ===\n', ...
    passFail(results.Success));
end


function text = passFail(tf)
if tf
    text = 'PASS';
else
    text = 'FAIL';
end
end
