function results = run_all_tests(varargin)
    % run_all_tests - Execute all unit and integration tests for the CSRD frequency translation system
    %
    % Usage:
    %   results = run_all_tests()                    % Run all tests
    %   results = run_all_tests('unit')              % Run only unit tests
    %   results = run_all_tests('integration')      % Run only integration tests
    %   results = run_all_tests('verbose', true)    % Run with verbose output
    %   results = run_all_tests('parallel', true)   % Run tests in parallel (if possible)
    %
    % Output:
    %   results - Test results structure with detailed information

    % Parse input arguments
    p = inputParser;
    addOptional(p, 'testType', 'all', @(x) any(validatestring(x, {'all', 'unit', 'integration'})));
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'parallel', false, @islogical);
    addParameter(p, 'outputFormat', 'text', @(x) any(validatestring(x, {'text', 'junit', 'pdf'})));
    parse(p, varargin{:});

    testType = p.Results.testType;
    verbose = p.Results.verbose;
    useParallel = p.Results.parallel;
    outputFormat = p.Results.outputFormat;

    % Setup test environment
    fprintf('=== CSRD Frequency Translation System Test Suite ===\n\n');

    % Get test directory and project root
    testDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(testDir);

    % Add necessary paths
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'config', 'csrd2025'));

    % Initialize test suite
    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.CodeCoveragePlugin;
    import matlab.unittest.plugins.TestReportPlugin;

    suite = TestSuite.empty;

    % Build test suite based on test type
    try

        switch testType
            case 'unit'
                fprintf('Building unit test suite...\n');
                suite = [suite, buildUnitTestSuite(testDir)];

            case 'integration'
                fprintf('Building integration test suite...\n');
                suite = [suite, buildIntegrationTestSuite(testDir)];

            case 'all'
                fprintf('Building complete test suite...\n');
                suite = [suite, buildUnitTestSuite(testDir)];
                suite = [suite, buildIntegrationTestSuite(testDir)];
        end

    catch ME
        fprintf('❌ Error building test suite: %s\n', ME.message);
        results = struct('Success', false, 'Error', ME.message);
        return;
    end

    if isempty(suite)
        fprintf('⚠️ No tests found for type: %s\n', testType);
        results = struct('Success', false, 'Error', 'No tests found');
        return;
    end

    fprintf('Found %d test methods across %d test classes\n\n', length(suite), getNumTestClasses(suite));

    % Create test runner
    runner = TestRunner.withTextOutput('Verbosity', getVerbosityLevel(verbose));

    % Add plugins based on configuration
    if useParallel && hasParallelToolbox()
        fprintf('Configuring parallel test execution...\n');

        try
            runner.addPlugin(matlab.unittest.plugins.codecoverage.CoberturaFormat('coverage.xml'));
        catch
            % Parallel execution might not support all plugins
        end

    end

    % Add output format plugins
    switch outputFormat
        case 'junit'

            try
                runner.addPlugin(TestReportPlugin.producingJUnitFormat('test_results.xml'));
                fprintf('JUnit XML report will be saved to: test_results.xml\n');
            catch ME
                fprintf('⚠️ Could not add JUnit plugin: %s\n', ME.message);
            end

        case 'pdf'

            try
                runner.addPlugin(TestReportPlugin.producingPDFReport('test_results.pdf'));
                fprintf('PDF report will be saved to: test_results.pdf\n');
            catch ME
                fprintf('⚠️ Could not add PDF plugin: %s\n', ME.message);
            end

    end

    % Add code coverage if available
    try

        if exist(fullfile(projectRoot, '+csrd'), 'dir')
            runner.addPlugin(CodeCoveragePlugin.forFolder(fullfile(projectRoot, '+csrd')));
            fprintf('Code coverage enabled for +csrd folder\n');
        end

    catch ME
        fprintf('⚠️ Could not enable code coverage: %s\n', ME.message);
    end

    fprintf('\n');

    % Run tests
    fprintf('🚀 Starting test execution...\n');
    startTime = tic;

    try

        if useParallel && hasParallelToolbox()
            % Note: Parallel execution might not be supported for all test configurations
            fprintf('Attempting parallel execution...\n');
            testResults = run(runner, suite);
        else
            testResults = run(runner, suite);
        end

        executionTime = toc(startTime);

    catch ME
        fprintf('❌ Test execution failed: %s\n', ME.message);
        fprintf('Detailed error:\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        results = struct('Success', false, 'Error', ME.message, 'Results', []);
        return;
    end

    % Analyze results
    fprintf('\n=== Test Results Summary ===\n');

    numTests = length(testResults);
    numPassed = sum([testResults.Passed]);
    numFailed = sum([testResults.Failed]);
    numIncomplete = sum([testResults.Incomplete]);

    fprintf('Total tests run: %d\n', numTests);
    fprintf('✅ Passed: %d (%.1f%%)\n', numPassed, 100 * numPassed / numTests);

    if numFailed > 0
        fprintf('❌ Failed: %d (%.1f%%)\n', numFailed, 100 * numFailed / numTests);
    end

    if numIncomplete > 0
        fprintf('⚠️ Incomplete: %d (%.1f%%)\n', numIncomplete, 100 * numIncomplete / numTests);
    end

    fprintf('⏱️ Execution time: %.2f seconds\n', executionTime);

    % Show detailed failure information
    if numFailed > 0
        fprintf('\n=== Failed Test Details ===\n');
        failedTests = testResults([testResults.Failed]);

        for i = 1:length(failedTests)
            test = failedTests(i);
            fprintf('\n❌ %s\n', test.Name);

            if ~isempty(test.Details)
                fprintf('   Details: %s\n', test.Details.DiagnosticText);
            end

        end

    end

    % Show performance insights
    if verbose
        fprintf('\n=== Performance Insights ===\n');

        durations = [testResults.Duration];
        [~, slowestIdx] = max(durations);

        fprintf('Fastest test: %.3f seconds (%s)\n', min(durations), testResults(durations == min(durations)).Name);
        fprintf('Slowest test: %.3f seconds (%s)\n', max(durations), testResults(slowestIdx).Name);
        fprintf('Average test duration: %.3f seconds\n', mean(durations));
    end

    % Determine overall success
    overallSuccess = numFailed == 0 && numIncomplete == 0;

    if overallSuccess
        fprintf('\n🎉 All tests passed successfully!\n');
    else
        fprintf('\n💥 Some tests failed or were incomplete.\n');
    end

    % Package results
    results = struct();
    results.Success = overallSuccess;
    results.TotalTests = numTests;
    results.Passed = numPassed;
    results.Failed = numFailed;
    results.Incomplete = numIncomplete;
    results.ExecutionTime = executionTime;
    results.TestResults = testResults;
    results.TestType = testType;

    % Save results to file
    try
        resultsFile = sprintf('test_results_%s_%s.mat', testType, datestr(now, 'yyyymmdd_HHMMSS'));
        save(resultsFile, 'results');
        fprintf('\nResults saved to: %s\n', resultsFile);
    catch ME
        fprintf('⚠️ Could not save results file: %s\n', ME.message);
    end

    fprintf('\n=== Test Suite Complete ===\n');
end

function suite = buildUnitTestSuite(testDir)
    % Build unit test suite
    import matlab.unittest.TestSuite;

    unitTestDir = fullfile(testDir, 'unit');
    suite = TestSuite.empty;

    if exist(unitTestDir, 'dir')
        % Add TRFSimulator tests
        trfTestFile = fullfile(unitTestDir, 'TRFSimulatorTest.m');

        if exist(trfTestFile, 'file')
            suite = [suite, TestSuite.fromFile(trfTestFile)];
        end

        % Add ParameterDrivenPlanner tests
        plannerTestFile = fullfile(unitTestDir, 'ParameterDrivenPlannerTest.m');

        if exist(plannerTestFile, 'file')
            suite = [suite, TestSuite.fromFile(plannerTestFile)];
        end

        % Discover any other unit test files
        otherTests = dir(fullfile(unitTestDir, '*Test.m'));

        for i = 1:length(otherTests)
            testFile = fullfile(unitTestDir, otherTests(i).name);

            if ~strcmp(otherTests(i).name, 'TRFSimulatorTest.m') && ...
                    ~strcmp(otherTests(i).name, 'ParameterDrivenPlannerTest.m')

                try
                    suite = [suite, TestSuite.fromFile(testFile)];
                catch ME
                    fprintf('⚠️ Could not load test file %s: %s\n', otherTests(i).name, ME.message);
                end

            end

        end

    end

end

function suite = buildIntegrationTestSuite(testDir)
    % Build integration test suite
    import matlab.unittest.TestSuite;

    integrationTestDir = fullfile(testDir, 'integration');
    suite = TestSuite.empty;

    if exist(integrationTestDir, 'dir')
        % Add frequency translation system integration test
        freqSysTestFile = fullfile(integrationTestDir, 'FrequencyTranslationSystemTest.m');

        if exist(freqSysTestFile, 'file')
            suite = [suite, TestSuite.fromFile(freqSysTestFile)];
        end

        % Discover any other integration test files
        otherTests = dir(fullfile(integrationTestDir, '*Test.m'));

        for i = 1:length(otherTests)
            testFile = fullfile(integrationTestDir, otherTests(i).name);

            if ~strcmp(otherTests(i).name, 'FrequencyTranslationSystemTest.m')

                try
                    suite = [suite, TestSuite.fromFile(testFile)];
                catch ME
                    fprintf('⚠️ Could not load test file %s: %s\n', otherTests(i).name, ME.message);
                end

            end

        end

    end

end

function numClasses = getNumTestClasses(suite)
    % Count unique test classes in suite
    if isempty(suite)
        numClasses = 0;
        return;
    end

    classNames = {suite.TestClass};
    uniqueClasses = unique(classNames);
    numClasses = length(uniqueClasses);
end

function verbosity = getVerbosityLevel(verbose)
    % Get appropriate verbosity level
    if verbose
        verbosity = matlab.unittest.Verbosity.Detailed;
    else
        verbosity = matlab.unittest.Verbosity.Concise;
    end

end

function hasToolbox = hasParallelToolbox()
    % Check if Parallel Computing Toolbox is available
    try
        hasToolbox = license('test', 'Distrib_Computing_Toolbox') && ...
            ~isempty(ver('parallel'));
    catch
        hasToolbox = false;
    end

end
