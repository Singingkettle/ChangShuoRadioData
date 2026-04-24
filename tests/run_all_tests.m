function results = run_all_tests(varargin)
    % run_all_tests - Execute maintained regression tests for the CSRD project.
    %
    % Usage:
    %   results = run_all_tests()
    %   results = run_all_tests('regression')
    %   results = run_all_tests('verbose', true)

    p = inputParser;
    addOptional(p, 'testType', 'regression', @(x) any(validatestring(x, {'regression', 'all'})));
    addParameter(p, 'verbose', false, @islogical);
    parse(p, varargin{:});

    testType = p.Results.testType;
    verbose = p.Results.verbose;

    testsDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(testsDir);
    regressionDir = fullfile(testsDir, 'regression');

    addpath(projectRoot);
    addpath(regressionDir);

    regressionTests = { ...
        'test_empty_osm_raytracing', ...
        'test_osm_building_raytracing', ...
        'test_entity_snapshot_consistency', ...
        'test_bandwidth_consistency', ...
        'test_map_config_validation', ...
        'test_refactoring'};

    fprintf('=== CSRD Regression Test Suite ===\n');
    fprintf('Project root: %s\n', projectRoot);
    fprintf('Regression directory: %s\n\n', regressionDir);

    switch testType
        case {'regression', 'all'}
            testsToRun = regressionTests;
        otherwise
            error('Unsupported test type: %s', testType);
    end

    records = repmat(struct( ...
        'Name', "", ...
        'Category', "regression", ...
        'Passed', false, ...
        'DurationSeconds', 0, ...
        'Error', ""), 0, 1);

    totalStart = tic;
    for i = 1:numel(testsToRun)
        testName = testsToRun{i};
        fprintf('Running %s ... ', testName);
        testStart = tic;

        try
            feval(testName);
            duration = toc(testStart);
            fprintf('PASS (%.2fs)\n', duration);
            records(end+1) = buildRecord(testName, true, duration, ""); %#ok<AGROW>
        catch ME
            duration = toc(testStart);
            fprintf('FAIL (%.2fs)\n', duration);
            records(end+1) = buildRecord(testName, false, duration, string(ME.message)); %#ok<AGROW>

            if verbose
                fprintf('%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
            else
                fprintf('  %s\n', ME.message);
            end
        end
    end

    totalDuration = toc(totalStart);
    numPassed = sum([records.Passed]);
    numFailed = numel(records) - numPassed;

    fprintf('\n=== Regression Summary ===\n');
    fprintf('Passed: %d\n', numPassed);
    fprintf('Failed: %d\n', numFailed);
    fprintf('Total: %d\n', numel(records));
    fprintf('Elapsed: %.2f seconds\n', totalDuration);

    results = struct( ...
        'Success', numFailed == 0, ...
        'TestType', "regression", ...
        'TotalTests', numel(records), ...
        'Passed', numPassed, ...
        'Failed', numFailed, ...
        'ExecutionTime', totalDuration, ...
        'Records', records);
end

function record = buildRecord(name, passed, duration, errMsg)
    record = struct( ...
        'Name', string(name), ...
        'Category', "regression", ...
        'Passed', passed, ...
        'DurationSeconds', duration, ...
        'Error', string(errMsg));
end
