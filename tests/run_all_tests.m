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
        @(x) any(validatestring(x, {'regression', 'unit', 'integration', 'all'})));
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
        case 'all'
            selected = {'regression', 'unit', 'integration'};
        otherwise
            error('CSRD:Tests:UnsupportedType', ...
                'Unsupported test type: %s', testType);
    end
end


function records = runSuite(suite, testsDir, verbose)
    records = [];
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
