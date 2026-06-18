function results = run_all_tests(varargin)
    % run_all_tests - Execute the maintained CSRD test suites.
    %
    %   results = run_all_tests()
    %   results = run_all_tests('regression')
    %   results = run_all_tests('unit')
    %   results = run_all_tests('integration')
    %   results = run_all_tests('all')
    %   results = run_all_tests(..., 'verbose', true)
    %
    %   The 'all' selector now genuinely sweeps tests/regression,
    %   tests/unit and tests/integration. Previously 'all' aliased to
    %   'regression', silently hiding every unit and integration test
    %   from CI runs.
    %
    %   Regression tests are simple top-level functions named
    %   ``test_*.m``. Unit and integration tests are matlab.unittest
    %   classes (``*Test.m``) executed via ``runtests``.

    p = inputParser;
    addOptional(p, 'testType', 'regression', ...
        @(x) any(validatestring(x, {'regression', 'unit', 'integration', ...
            'phase0', 'phase1', 'phase2', 'phase3', 'phase4', ...
            'phase6', 'phase7', 'phase8', 'phase9', 'all'})));
    addParameter(p, 'verbose', false, @islogical);
    parse(p, varargin{:});

    testType = p.Results.testType;
    verbose = p.Results.verbose;

    testsDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(testsDir);

    addpath(projectRoot);
    addpath(fullfile(testsDir, 'regression'));

    fprintf('=== CSRD Test Suite (%s) ===\n', upper(testType));
    fprintf('Project root: %s\n\n', projectRoot);

    selectedSuites = resolveSelectedSuites(testType);

    records = repmat(struct( ...
        'Name', "", ...
        'Category', "regression", ...
        'Passed', false, ...
        'DurationSeconds', 0, ...
        'Error', ""), 0, 1);

    totalStart = tic;
    for s = 1:numel(selectedSuites)
        suite = selectedSuites{s};
        suiteRecords = runSuite(suite, testsDir, verbose);
        if ~isempty(suiteRecords)
            records = [records; suiteRecords]; %#ok<AGROW>
        end
    end
    totalDuration = toc(totalStart);

    numPassed = sum([records.Passed]);
    numFailed = numel(records) - numPassed;

    fprintf('\n=== %s Summary ===\n', upper(testType));
    fprintf('Passed: %d\n', numPassed);
    fprintf('Failed: %d\n', numFailed);
    fprintf('Total: %d\n', numel(records));
    fprintf('Elapsed: %.2f seconds\n', totalDuration);

    results = struct( ...
        'Success', numFailed == 0, ...
        'TestType', string(testType), ...
        'TotalTests', numel(records), ...
        'Passed', numPassed, ...
        'Failed', numFailed, ...
        'ExecutionTime', totalDuration, ...
        'Records', records);
end


function selected = resolveSelectedSuites(testType)
    switch testType
        case 'regression'
            selected = {'regression'};
        case 'unit'
            selected = {'unit'};
        case 'integration'
            selected = {'integration'};
        case 'phase0'
            % Phase 0 (audit §17.2) curated subset: the 6 unit tests
            % covering validateRequiredToolboxes / LogPolicy /
            % sanitizeForJson plus the 2 regression tests
            % (startup_hooks, baseline_sweep). Used by Phase 0 freeze
            % gate; faster than a full 'all' sweep.
            selected = {'phase0'};
        case 'phase1'
            % Phase 1 (audit §17.3) curated subset: the 6 unit tests
            % covering RxNumAntennasAlias / ChannelSeedBurstAware /
            % MergeChannelOutputContract / SignalStructContract /
            % ReceiveFactoryRxImpairments / EntitySyncFailFast /
            % MultiBurstPerFrame, plus the dedicated regression smoke
            % test. Faster than a full 'all' sweep; used by Phase 1
            % freeze gate.
            selected = {'phase1'};
        case 'phase2'
            % Phase 2 (audit §17.4) curated subset: BlueprintFeasibilityValidator
            % + ValidationReport + ScenarioFactoryResampleLoop +
            % AnnotationHeaderBlueprintProvenance + ProfileLoader +
            % ComputeBlueprintHash + ChannelFactoryNoSilentFallback +
            % FrequencyAllocationStrategy unit tests, plus the Phase 2
            % dead-code regression. Faster than 'all'; used by Phase 2
            % freeze gate.
            selected = {'phase2'};
        case 'phase3'
            % Phase 3 (audit §17.5 / phase-3-construction.md §3.6)
            % curated subset: the 7 Phase 3 unit tests
            % (ReceiverViewProjection / ConstructionFailFast /
            % ChannelPropagationFailFast / SetupReceiversFailFast /
            % MobilityFromBlueprint / CatchSwallowRemoved /
            % ProvenanceDataflow) plus 2 regressions
            % (test_no_dead_code_phase3 + test_phase3_construction_smoke).
            selected = {'phase3'};
        case 'phase4'
            % Phase 4 (audit §17.6 / phase-4-measurement.md §6) curated
            % subset: the 6 Phase 4 unit tests pinning the measurement
            % package + Doppler + v2 schema + ReceiverView persistence +
            % MeasurementCompleteness hook contracts, plus 3 Phase 4
            % regressions (no_dead_code, doppler high-speed deterministic,
            % measured_truth_coverage). The 210-scenario baseline sweep
            % is intentionally excluded; it runs separately via
            % test_baseline_sweep_200(210, 'Mode', 'full') to gate the
            % Phase 4 freeze on the 9 §6 exit conditions.
            selected = {'phase4'};
        case 'phase6'
            % Phase 6 (audit §18 / phase-6-release-hardening.md) curated
            % release-hardening subset: annotation reader validation
            % plus the read-only release readiness regression. This suite
            % must not run a simulation or rewrite canonical baselines.
            selected = {'phase6'};
        case 'phase7'
            % Phase 7 (phase-7-downstream-release.md) curated subset:
            % downstream schema docs, release notes, and executable
            % annotation reader example. This suite is read-only except
            % for tempdir fixtures created by the regression itself.
            selected = {'phase7'};
        case 'phase8'
            % Phase 8 regulatory spectrum planning subset: catalog,
            % selector, validator, communication blueprint slice, and
            % end-to-end regulatory annotation smoke.
            selected = {'phase8'};
        case 'phase9'
            % Phase 9 public-entry coverage subset: every configured
            % modulation factory path plus the quick tools/simulation.m
            % multidimensional sweep.
            selected = {'phase9'};
        case 'all'
            selected = {'regression', 'unit', 'integration'};
        otherwise
            error('CSRD:Tests:UnsupportedType', ...
                'Unsupported test type: %s', testType);
    end
end


function records = runSuite(suite, testsDir, verbose)
    records = [];

    if strcmp(suite, 'phase0')
        % Phase 0 has no dedicated subfolder; it stitches together
        % curated tests from tests/unit and tests/regression.
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase0Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase1')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase1Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase2')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase2Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase3')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase3Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase4')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase4Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase6')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase6Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase7')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase7Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase8')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase8Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    if strcmp(suite, 'phase9')
        fprintf('-- Suite: %s (curated)\n', suite);
        records = runPhase9Suite(testsDir, verbose);
        fprintf('\n');
        return;
    end

    suiteDir = fullfile(testsDir, suite);
    if ~isfolder(suiteDir)
        fprintf('-- Skipping suite "%s" (no folder %s)\n\n', suite, suiteDir);
        return;
    end

    fprintf('-- Suite: %s (%s)\n', suite, suiteDir);

    switch suite
        case 'regression'
            records = runRegressionFiles(suiteDir, verbose);
        case {'unit', 'integration'}
            records = runUnittestSuite(suite, suiteDir, verbose);
    end
    fprintf('\n');
end


function records = runPhase0Suite(testsDir, verbose)
    % Phase 0 curated suite: 6 unit tests + the startup-hooks regression
    % test + a smoke baseline sweep. Skips the canonical 200-scenario
    % sweep because that one is operator-driven (see
    % phase-0-baseline.md §3 / §9). Use
    % `test_baseline_sweep_200(200, 'Mode', 'full')` directly to run
    % the full canonical sweep.

    suiteDir = fullfile(testsDir, 'unit');
    addpath(suiteDir);
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase0Unit = { ...
        'ValidateRequiredToolboxesTest', ...
        'LogPolicyDevTest', ...
        'LogPolicyLargeMCTest', ...
        'SanitizeForJsonBasicTest', ...
        'SanitizeForJsonRecursiveTest', ...
        'SanitizeForJsonComplexAllowlistTest'};

    for i = 1:numel(phase0Unit)
        className = phase0Unit{i};
        fprintf('  Running %s ... ', className);
        testStart = tic;
        try
            r = runtests(className);
            duration = toc(testStart);
            allPassed = ~any([r.Failed]) && ~any([r.Incomplete]);
            if allPassed
                fprintf('PASS (%d cases, %.2fs)\n', numel(r), duration);
                rec = buildRecord(className, 'phase0', true, duration, "");
            else
                failures = sum([r.Failed]) + sum([r.Incomplete]);
                fprintf('FAIL (%d/%d, %.2fs)\n', failures, numel(r), duration);
                rec = buildRecord(className, 'phase0', false, duration, ...
                    sprintf('%d failed cases', failures));
            end
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(className, 'phase0', false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end

    phase0Reg = { ...
        'test_simulation_runner_startup_hooks', ...
        'test_baseline_sweep_200'}; % default smoke mode (N=12)

    for i = 1:numel(phase0Reg)
        testName = phase0Reg{i};
        fprintf('  Running %s ... ', testName);
        testStart = tic;
        try
            feval(testName);
            duration = toc(testStart);
            fprintf('PASS (%.2fs)\n', duration);
            rec = buildRecord(testName, 'phase0', true, duration, "");
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(testName, 'phase0', false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('    %s\n', ME.message);
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function records = runPhase1Suite(testsDir, verbose)
    % Phase 1 curated suite: 7 unit tests (Phase 1 / A1 A2 A4 H13 H14
    % C1) + 1 regression smoke test (test_phase1_dataflow_smoke). The
    % 200-scenario baseline sweep is intentionally excluded here; it is
    % run separately via test_baseline_sweep_200(200, 'Mode', 'full')
    % to gate the Phase 1 freeze on the 7 exit criteria.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase1Unit = { ...
        'RxNumAntennasAliasTest', ...
        'ChannelSeedBurstAwareTest', ...
        'MergeChannelOutputContractTest', ...
        'SignalStructContractTest', ...
        'ReceiveFactoryRxImpairmentsTest', ...
        'EntitySyncFailFastTest', ...
        'MultiBurstPerFrameTest'};

    for i = 1:numel(phase1Unit)
        className = phase1Unit{i};
        fprintf('  Running %s ... ', className);
        testStart = tic;
        try
            r = runtests(className);
            duration = toc(testStart);
            allPassed = ~any([r.Failed]) && ~any([r.Incomplete]);
            if allPassed
                fprintf('PASS (%d cases, %.2fs)\n', numel(r), duration);
                rec = buildRecord(className, 'phase1', true, duration, "");
            else
                failures = sum([r.Failed]) + sum([r.Incomplete]);
                fprintf('FAIL (%d/%d, %.2fs)\n', failures, numel(r), duration);
                rec = buildRecord(className, 'phase1', false, duration, ...
                    sprintf('%d failed cases', failures));
            end
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(className, 'phase1', false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end

    phase1Reg = { 'test_phase1_dataflow_smoke' };
    for i = 1:numel(phase1Reg)
        testName = phase1Reg{i};
        fprintf('  Running %s ... ', testName);
        testStart = tic;
        try
            feval(testName);
            duration = toc(testStart);
            fprintf('PASS (%.2fs)\n', duration);
            rec = buildRecord(testName, 'phase1', true, duration, "");
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(testName, 'phase1', false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('    %s\n', ME.message);
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function records = runPhase2Suite(testsDir, verbose)
    % Phase 2 (audit §17.4) curated suite: the 8 unit tests covering the
    % BlueprintFeasibilityValidator + ValidationReport + ScenarioFactory
    % resample loop + Header.Runtime provenance + Profile loader +
    % BlueprintHash + ChannelFactory silent-fallback removal +
    % FrequencyAllocation strategy gate, plus the Phase 2 dead-code
    % regression. The 200-scenario baseline sweep is intentionally
    % excluded; it runs separately via test_baseline_sweep_200(200, 'Mode', 'full')
    % to gate the Phase 2 freeze.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase2Unit = { ...
        'BlueprintFeasibilityValidatorTest', ...
        'ValidationReportTest', ...
        'ScenarioFactoryResampleLoopTest', ...
        'AnnotationHeaderBlueprintProvenanceTest', ...
        'ProfileLoaderTest', ...
        'ComputeBlueprintHashTest', ...
        'ChannelFactoryNoSilentFallbackTest', ...
        'FrequencyAllocationStrategyTest'};
    records = appendUnittestClasses(records, phase2Unit, 'phase2', verbose);

    phase2Reg = { 'test_no_dead_code_phase2' };
    records = appendRegressionTests(records, phase2Reg, 'phase2', verbose);
end


function records = runPhase3Suite(testsDir, verbose)
    % Phase 3 (audit §17.5 / phase-3-construction.md §3.6) curated suite:
    % the 7 Phase 3 unit tests pinning the strict-construction +
    % ReceiverViews + provenance dataflow contracts, plus 2 Phase 3
    % regressions. The 200-scenario baseline sweep is intentionally
    % excluded; it runs separately via test_baseline_sweep_200(200, 'Mode', 'full')
    % to gate the Phase 3 freeze on the 9 §7 exit criteria.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase3Unit = { ...
        'ReceiverViewProjectionTest', ...
        'ConstructionFailFastTest', ...
        'ChannelPropagationFailFastTest', ...
        'SetupReceiversFailFastTest', ...
        'MobilityFromBlueprintTest', ...
        'CatchSwallowRemovedTest', ...
        'ProvenanceDataflowTest'};
    records = appendUnittestClasses(records, phase3Unit, 'phase3', verbose);

    phase3Reg = { ...
        'test_no_dead_code_phase3', ...
        'test_phase3_construction_smoke'};
    records = appendRegressionTests(records, phase3Reg, 'phase3', verbose);
end


function records = runPhase4Suite(testsDir, verbose)
    % Phase 4 (audit §17.6 / phase-4-measurement.md §6) curated suite.
    %
    %   Pins the Phase 4 measurement-layer + Doppler + Annotation v2
    %   contracts via 6 unit tests + 3 regression tests. The
    %   210-scenario baseline sweep is intentionally excluded here; it
    %   is operator-driven via `test_baseline_sweep_200(210, 'Mode',
    %   'full')` to gate the Phase 4 freeze on the 9 §6 exit
    %   conditions.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase4Unit = { ...
        'MeasurementPackageTest', ...
        'ApplyDopplerShiftTest', ...
        'ChannelPropagationFailFastTest', ...
        'BuildSourceAnnotationTest', ...
        'ReceiverViewPersistenceTest', ...
        'MeasurementCompletenessHookTest', ...
        'BlueprintFeasibilityValidatorTest'};
    records = appendUnittestClasses(records, phase4Unit, 'phase4', verbose);

    phase4Reg = { ...
        'test_no_dead_code_phase4', ...
        'test_doppler_high_speed', ...
        'test_measured_truth_coverage'};
    records = appendRegressionTests(records, phase4Reg, 'phase4', verbose);
end


function records = runPhase6Suite(testsDir, verbose)
    % Phase 6 (audit §18 / phase-6-release-hardening.md) curated suite.
    %
    %   Pins the release-hardening layer without running a simulation:
    %   annotation reader validation plus release readiness checks over
    %   the committed final-v04 baseline.

    projectRoot = fileparts(testsDir);
    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    addpath(fullfile(projectRoot, 'tools', 'release'));
    records = [];

    phase6Unit = {'ReadAnnotationTest', 'ConvertCsrdToCocoTest'};
    records = appendUnittestClasses(records, phase6Unit, 'phase6', verbose);

    phase6Reg = {'test_phase6_release_readiness', ...
        'test_phase6_coco_converter_fixture', ...
        'test_phase6_performance_diagnostics', ...
        'test_phase6_release_ci_readiness'};
    records = appendRegressionTests(records, phase6Reg, 'phase6', verbose);
end


function records = runPhase7Suite(testsDir, verbose)
    % Phase 7 (phase-7-downstream-release.md) curated suite.
    %
    %   Pins downstream release documentation and the executable annotation
    %   v2 reader example. No simulation or baseline rewrite is allowed.

    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase7Reg = {'test_phase7_downstream_docs_readiness'};
    records = appendRegressionTests(records, phase7Reg, 'phase7', verbose);
end


function records = runPhase8Suite(testsDir, verbose)
    % Phase 8 regulatory spectrum planning suite.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase8Unit = { ...
        'RegionSpectrumCatalogTest', ...
        'RegulatoryValidatorTest', ...
        'RegionSpectrumSelectorTest', ...
        'ScenarioFactoryRegulatoryChinaTest', ...
        'AllModulationFactorySmokeTest', ...
        'BuildSourceAnnotationTest', ...
        'ReadAnnotationTest'};
    records = appendUnittestClasses(records, phase8Unit, 'phase8', verbose);

    phase8Reg = {'test_phase8_regulatory_pipeline_smoke', ...
        'test_phase8_regulatory_region_matrix_smoke', ...
        'test_phase8_regulatory_unified_coverage_sweep'};
    records = appendRegressionTests(records, phase8Reg, 'phase8', verbose);
end


function records = runPhase9Suite(testsDir, verbose)
    % Phase 9 public simulation.m entrypoint coverage suite.

    addpath(fullfile(testsDir, 'unit'));
    addpath(fullfile(testsDir, 'regression'));
    records = [];

    phase9Unit = {'AllModulationFactorySmokeTest', ...
        'RFPropagationCapabilitiesTest'};
    records = appendUnittestClasses(records, phase9Unit, 'phase9', verbose);

    phase9Reg = {'test_phase13_full_coverage_config_load', ...
        'test_no_dead_code_phase15_architecture', ...
        'test_simulation_entrypoint_coverage_sweep'};
    records = appendRegressionTests(records, phase9Reg, 'phase9', verbose);
end


function records = appendUnittestClasses(records, classNames, category, verbose)
    %APPENDUNITTESTCLASSES Phase 2/3 curated-suite helper.
    %
    %   Runs each matlab.unittest class via runtests, prints PASS/FAIL,
    %   and appends a record (one per class) into the running records
    %   table. Uses the same exception handling shape as runPhase0Suite /
    %   runPhase1Suite so curated-suite output stays consistent across
    %   phases.
    for i = 1:numel(classNames)
        className = classNames{i};
        fprintf('  Running %s ... ', className);
        testStart = tic;
        try
            r = runtests(className);
            duration = toc(testStart);
            allPassed = ~any([r.Failed]) && ~any([r.Incomplete]);
            if allPassed
                fprintf('PASS (%d cases, %.2fs)\n', numel(r), duration);
                rec = buildRecord(className, category, true, duration, "");
            else
                failures = sum([r.Failed]) + sum([r.Incomplete]);
                fprintf('FAIL (%d/%d, %.2fs)\n', failures, numel(r), duration);
                rec = buildRecord(className, category, false, duration, ...
                    sprintf('%d failed cases', failures));
                if verbose
                    for k = 1:numel(r)
                        if r(k).Failed || r(k).Incomplete
                            fprintf('    - %s\n', r(k).Name);
                        end
                    end
                end
            end
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(className, category, false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function records = appendRegressionTests(records, testNames, category, verbose)
    %APPENDREGRESSIONTESTS Phase 2/3 curated-suite helper for regression
    %tests (top-level functions named test_*).
    for i = 1:numel(testNames)
        testName = testNames{i};
        fprintf('  Running %s ... ', testName);
        testStart = tic;
        try
            feval(testName);
            duration = toc(testStart);
            fprintf('PASS (%.2fs)\n', duration);
            rec = buildRecord(testName, category, true, duration, "");
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(testName, category, false, duration, ...
                string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('    %s\n', ME.message);
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function records = runRegressionFiles(suiteDir, verbose)
    addpath(suiteDir);
    files = dir(fullfile(suiteDir, 'test_*.m'));
    [~, idx] = sort({files.name});
    files = files(idx);
    records = [];

    for i = 1:numel(files)
        [~, testName] = fileparts(files(i).name);
        fprintf('  Running %s ... ', testName);
        testStart = tic;
        try
            feval(testName);
            duration = toc(testStart);
            fprintf('PASS (%.2fs)\n', duration);
            rec = buildRecord(testName, 'regression', true, duration, "");
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(testName, 'regression', false, duration, string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('    %s\n', ME.message);
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function records = runUnittestSuite(category, suiteDir, verbose)
    addpath(suiteDir);
    files = dir(fullfile(suiteDir, '*.m'));
    [~, idx] = sort({files.name});
    files = files(idx);
    records = [];

    for i = 1:numel(files)
        [~, className] = fileparts(files(i).name);
        fprintf('  Running %s ... ', className);
        testStart = tic;
        try
            r = runtests(className);
            duration = toc(testStart);
            allPassed = ~any([r.Failed]) && ~any([r.Incomplete]);
            if allPassed
                fprintf('PASS (%d cases, %.2fs)\n', numel(r), duration);
                rec = buildRecord(className, category, true, duration, "");
            else
                failures = sum([r.Failed]) + sum([r.Incomplete]);
                fprintf('FAIL (%d/%d cases failed, %.2fs)\n', ...
                    failures, numel(r), duration);
                rec = buildRecord(className, category, false, duration, ...
                    sprintf('%d failed cases', failures));
                if verbose
                    for k = 1:numel(r)
                        if r(k).Failed || r(k).Incomplete
                            fprintf('    - %s\n', r(k).Name);
                        end
                    end
                end
            end
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            rec = buildRecord(className, category, false, duration, string(ME.message));
            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('    %s\n', ME.message);
            end
        end
        records = [records; rec]; %#ok<AGROW>
    end
end


function record = buildRecord(name, category, passed, duration, errMsg)
    record = struct( ...
        'Name', string(name), ...
        'Category', string(category), ...
        'Passed', passed, ...
        'DurationSeconds', duration, ...
        'Error', string(errMsg));
end
