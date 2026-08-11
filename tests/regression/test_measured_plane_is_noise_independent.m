function test_measured_plane_is_noise_independent(varargin)
    %TEST_MEASURED_PLANE_IS_NOISE_INDEPENDENT The ordering invariant, as a gate.
    %
    %   test_measured_plane_is_noise_independent()
    %   test_measured_plane_is_noise_independent(N)   % N scenarios per SNR cohort
    %
    %   This gate exists because nothing else in the suite would notice if the
    %   noise injector moved back ahead of the measurement. That ordering is the
    %   whole reason the measured labels are usable: a power-integral occupied
    %   bandwidth is not merely imprecise on a noisy buffer, it is UNDEFINED,
    %   because noise contributes power across the entire band and the 0.5 % edge
    %   walk then terminates in noise rather than in signal. ECC/REC/(06)01 states
    %   the same requirement from the metrology side: 99 % OBW measurement needs
    %   the peak at least 30 dB above the noise floor, which a dataset drawing
    %   target SNR from [-10, 30] dB cannot promise.
    %
    %   The historical defect this prevents is documented and quantified: with the
    %   measurement running after noise injection, a 7.31 MHz emitter was published
    %   as 23.18 MHz (worst case 45.43 MHz on a 50 MHz grid), and the low-SNR
    %   cohort's |measured - execution| / execution reached P95 = 1.979.
    %
    %   WHAT IS ASSERTED, AND WHY IT IS FORMULATED THIS WAY
    %
    %   The obvious test -- run the same scenario at two SNRs and compare the
    %   measured bandwidths directly -- would be unsound here. Changing the SNR
    %   target changes how many random draws the pipeline makes, so the two runs do
    %   not carry the same waveform, and a direct comparison would be measuring RNG
    %   drift rather than noise leakage.
    %
    %   So the statistic is taken WITHIN each run: the agreement between the two
    %   measured planes,
    %
    %       d = |Measured.SourcePlane.OBW - Execution.ModulatedBandwidthHz|
    %           / Execution.ModulatedBandwidthHz
    %
    %   and the assertion is that its distribution does not depend on SNR. Both
    %   planes measure noise-free buffers, so d reflects propagation and the bin
    %   grid only, and propagation does not know the SNR. If noise ever reaches the
    %   measured plane, d explodes in the low-SNR cohort and stays small in the
    %   high-SNR one -- which is exactly the signature of the original bug, and is
    %   immune to RNG drift because numerator and denominator come from the same
    %   run.
    %
    %   A one-sided check on the low-SNR cohort alone would be weaker: it could be
    %   satisfied by an estimator that simply reports the same wrong number
    %   everywhere. Requiring the two cohorts to AGREE catches that.

    p = inputParser;
    addOptional(p, 'numScenarios', 3, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, varargin{:});
    numScenarios = double(p.Results.numScenarios);

    % A 35 dB separation. The low cohort sits at the bottom of the dataset's own
    % declared range, where the defect was worst; the high cohort sits where even
    % the pre-fix estimator behaved.
    LOW_SNR_DB = -10;
    HIGH_SNR_DB = 25;

    % Tolerances. The low cohort's P95 must stay under 0.10 -- two orders of
    % magnitude below the pre-fix 1.979, and comfortably above the 0.0175 that
    % Rayleigh propagation alone produces. The cohort-to-cohort ratio bound is the
    % part that actually pins SNR-independence.
    MAX_LOW_SNR_P95 = 0.10;
    MAX_COHORT_RATIO = 8.0;

    fprintf('=== Measured plane is noise-independent (N=%d per cohort) ===\n', ...
        numScenarios);

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'measured_plane_noise_independence');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end
    csrd.runtime.logger.GlobalLogManager.initialize(struct('Name', 'CSRD-NoiseIndep', ...
        'Level', 'ERROR', 'SaveToFile', false, 'DisplayInConsole', false), runRoot);

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

    [lowDiffs, lowSnrs] = localCohortDiffs(masterCfg, runRoot, numScenarios, ...
        LOW_SNR_DB, 'low');
    [highDiffs, highSnrs] = localCohortDiffs(masterCfg, runRoot, numScenarios, ...
        HIGH_SNR_DB, 'high');

    % ANTI-VACUITY. Everything below asserts that a statistic does NOT move when
    % the SNR changes, so the gate is worthless unless the SNR actually changed.
    % Verify it from the published labels rather than trusting the config write:
    % the two cohorts' measured SNR must be separated by most of the intended
    % 35 dB. Without this check a silently ignored pin would make the whole gate
    % pass by construction, which is a worse outcome than failing.
    lowSnrMedian = localPercentile(lowSnrs, 50);
    highSnrMedian = localPercentile(highSnrs, 50);
    snrSeparation = highSnrMedian - lowSnrMedian;
    fprintf('  measured SNR     : low median %.2f dB, high median %.2f dB (gap %.2f dB)\n', ...
        lowSnrMedian, highSnrMedian, snrSeparation);
    minSeparation = 0.5 * (HIGH_SNR_DB - LOW_SNR_DB);
    assert(isfinite(snrSeparation) && snrSeparation >= minSeparation, ...
        ['Noise-independence gate is VACUOUS: the cohorts'' measured SNR differ ', ...
         'by only %.2f dB (need >= %.2f dB for a %d dB pin). The SNR target did ', ...
         'not take effect, so "the statistic did not move" proves nothing.'], ...
        snrSeparation, minSeparation, HIGH_SNR_DB - LOW_SNR_DB);

    assert(numel(lowDiffs) >= 10, ...
        ['Noise-independence gate: only %d low-SNR samples. Too few to make a ', ...
         'distributional claim -- fix the generation before trusting a green.'], ...
        numel(lowDiffs));
    assert(numel(highDiffs) >= 10, ...
        'Noise-independence gate: only %d high-SNR samples.', numel(highDiffs));

    lowP95 = localPercentile(lowDiffs, 95);
    highP95 = localPercentile(highDiffs, 95);
    lowP50 = localPercentile(lowDiffs, 50);
    highP50 = localPercentile(highDiffs, 50);

    fprintf('  low  SNR %+d dB : n=%4d  P50=%.6f  P95=%.6f  max=%.4f\n', ...
        LOW_SNR_DB, numel(lowDiffs), lowP50, lowP95, max(lowDiffs));
    fprintf('  high SNR %+d dB : n=%4d  P50=%.6f  P95=%.6f  max=%.4f\n', ...
        HIGH_SNR_DB, numel(highDiffs), highP50, highP95, max(highDiffs));

    assert(lowP95 <= MAX_LOW_SNR_P95, ...
        ['Noise-independence gate: low-SNR P95 = %.4f exceeds %.2f. The measured ', ...
         'plane is tracking the noise floor, which means the injector runs before ', ...
         'the measurement again. Pre-fix reference for this statistic: 1.979.'], ...
        lowP95, MAX_LOW_SNR_P95);

    % Guard the ratio in whichever direction it lands, using a floor so a cohort
    % that agrees to the bin grid (P95 ~ 1e-6) cannot make the ratio meaningless.
    floorP95 = 1e-3;
    ratio = max(lowP95, floorP95) / max(highP95, floorP95);
    if ratio < 1; ratio = 1 / ratio; end
    fprintf('  cohort P95 ratio : %.3f (bound %.1f)\n', ratio, MAX_COHORT_RATIO);
    assert(ratio <= MAX_COHORT_RATIO, ...
        ['Noise-independence gate: the two cohorts disagree by %.2fx (low P95 ', ...
         '%.6f vs high P95 %.6f). Both planes measure noise-free buffers, so this ', ...
         'statistic must not depend on SNR at all; a dependence means noise is ', ...
         'reaching one of them.'], ratio, lowP95, highP95);

    fprintf('=== Measured plane is noise-independent PASSED ===\n');
end


function [diffs, snrs] = localCohortDiffs(masterCfg, runRoot, numScenarios, snrDb, tag)
    % localCohortDiffs - |measured - execution| / execution for one SNR cohort.
    %   The SNR range is pinned to a single value so every source in the cohort
    %   sits at the same operating point; a range would smear the two cohorts into
    %   each other and weaken the comparison.
    %   Also returns the published SourcePlane.SNRdB values, which the caller uses
    %   to prove the pin took effect before trusting any invariance claim.
    diffs = [];
    snrs = [];
    for k = 1:numScenarios
        try
            cfg = masterCfg;
            cfg.Runner.NumScenarios = 1;
            % Same seed sequence for both cohorts. It does NOT make the waveforms
            % identical across cohorts (the SNR draw shifts the stream), which is
            % why the statistic is taken within a run -- but it keeps each cohort
            % reproducible.
            cfg.Runner.RandomSeed = 20260811 + 31 * k;
            cfg.Runner.Toolbox.Level = 'minimal';
            cfg.Logging.Policy = 'Standard';
            cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
                sprintf('%s_%06d', tag, k));
            cfg.Runner.Data.CompressData = false;
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
            cfg = localPinTargetSnr(cfg, snrDb);

            cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
            runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner, ...
                'FactoryConfigs', cfg.Factories, 'RuntimePlan', cfg.RuntimePlan);
            setup(runner);

            % Clear before stepping. This gate compares two SNR cohorts, so a
            % scenario that silently reused another scenario's annotation would
            % contaminate one cohort with the other's data -- the one failure mode
            % that could make an SNR-invariance claim look true when it is not.
            ws = warning('off', 'MATLAB:structOnObject');
            s = struct(runner);
            warning(ws);
            annotationPath = fullfile(s.actualOutputDirectory, 'annotations', ...
                'scenario_000001_annotation.json');
            csrd.test_support.freshAnnotationReader('clear', annotationPath);

            step(runner, 1, 1);

            if exist(annotationPath, 'file') ~= 2
                fprintf(2, '  %s scenario %d: no annotation written\n', tag, k);
                continue;
            end
            [d, s] = localDiffsFromAnnotation(annotationPath);
            diffs = [diffs, d]; %#ok<AGROW>
            snrs = [snrs, s]; %#ok<AGROW>
        catch ME
            fprintf(2, '  %s scenario %d skipped: %s\n', tag, k, ME.message);
        end
    end
end


function cfg = localPinTargetSnr(cfg, snrDb)
    % localPinTargetSnr - pin the controlled SNR target to a single value.
    %   Fails loudly if the field is not where it is expected: a silently
    %   unpinned SNR would make both cohorts identical and the gate vacuous.
    pinned = false;
    if isfield(cfg.Factories, 'Channel') && isstruct(cfg.Factories.Channel) && ...
            isfield(cfg.Factories.Channel, 'LinkBudget') && ...
            isstruct(cfg.Factories.Channel.LinkBudget) && ...
            isfield(cfg.Factories.Channel.LinkBudget, 'TargetSnrRangeDb')
        cfg.Factories.Channel.LinkBudget.TargetSnrRangeDb = [snrDb, snrDb];
        pinned = true;
    end
    assert(pinned, ...
        ['Noise-independence gate: could not find ', ...
         'FactoryConfigs.Channel.LinkBudget.TargetSnrRangeDb to pin. Without ', ...
         'pinning, both cohorts draw the same distribution and the gate proves ', ...
         'nothing.']);
end


function [diffs, snrs] = localDiffsFromAnnotation(annotationPath)
    % localDiffsFromAnnotation - per-source Measured-vs-Execution relative gap.
    %   Sources whose bandwidth is quantised by their own burst length are
    %   excluded: their width is set by the analysis resolution rather than by the
    %   emitter, so including them would measure burst gating, not noise leakage.
    %   `snrs` collects the published measured SNR so the caller can prove the two
    %   cohorts really sit at different operating points.
    diffs = [];
    snrs = [];
    annotation = jsondecode(fileread(annotationPath));
    frames = annotation.Frames;
    for fi = 1:numel(frames)
        fr = frames(fi);
        if iscell(frames); fr = frames{fi}; end
        if ~isfield(fr, 'SignalSources'); continue; end
        sources = fr.SignalSources;
        for si = 1:numel(sources)
            src = sources(si);
            if iscell(sources); src = sources{si}; end
            if ~isstruct(src) || ~isfield(src, 'Truth'); continue; end
            T = src.Truth;
            if ~isfield(T, 'Measured') || ~isfield(T, 'Execution'); continue; end
            if ~isfield(T.Measured, 'SourcePlane'); continue; end
            sp = T.Measured.SourcePlane;
            if ~isfield(sp, 'MeasurementStatus') || ...
                    ~strcmpi(char(string(sp.MeasurementStatus)), 'Measured')
                continue;
            end
            measuredBw = localNumber(sp, 'OccupiedBandwidthHz');
            executionBw = localNumber(T.Execution, 'ModulatedBandwidthHz');
            if ~(measuredBw > 0) || ~(executionBw > 0); continue; end
            snrDbValue = localNumber(sp, 'SNRdB');
            if isfinite(snrDbValue)
                snrs(end + 1) = snrDbValue; %#ok<AGROW>
            end
            cells = localNumber(sp, 'BandwidthResolutionCells');
            if isfinite(cells) && cells < 8; continue; end
            diffs(end + 1) = abs(measuredBw - executionBw) / executionBw; %#ok<AGROW>
        end
    end
end


function v = localNumber(s, f)
    v = NaN;
    if isstruct(s) && isfield(s, f) && isnumeric(s.(f)) && isscalar(s.(f))
        v = double(s.(f));
    end
end


function v = localPercentile(x, pct)
    x = sort(x(:));
    if isempty(x); v = NaN; return; end
    idx = (numel(x) - 1) * pct / 100 + 1;
    lo = floor(idx);
    hi = min(lo + 1, numel(x));
    v = x(lo) + (x(hi) - x(lo)) * (idx - lo);
end
