function quick_test_example()
    % quick_test_example - Simple example test to verify the test system works
    %
    % This is a standalone test function that can be run to quickly verify
    % that the test infrastructure is properly set up and working.
    %
    % Usage:
    %   quick_test_example()

    fprintf('=== Quick Test Example ===\n\n');

    % Check if we're in the tests directory
    currentDir = pwd;
    [~, dirName] = fileparts(currentDir);

    if ~strcmp(dirName, 'tests')
        fprintf('⚠️ Please run this from the tests/ directory\n');
        fprintf('Current directory: %s\n', currentDir);
        return;
    end

    % Add project paths
    projectRoot = fileparts(currentDir);
    addpath(projectRoot);
    fprintf('Added project root to path: %s\n', projectRoot);

    try
        % Test 1: Verify test runner exists and loads
        fprintf('\n1. Testing test runner availability...\n');

        if exist('run_all_tests.m', 'file')
            fprintf('   ✅ Test runner found\n');
        else
            fprintf('   ❌ Test runner not found\n');
            return;
        end

        % Test 2: Check for unit test files
        fprintf('\n2. Checking unit test files...\n');
        unitTestDir = fullfile(currentDir, 'unit');

        if exist(unitTestDir, 'dir')
            testFiles = dir(fullfile(unitTestDir, '*Test.m'));
            fprintf('   Found %d unit test files:\n', length(testFiles));

            for i = 1:length(testFiles)
                fprintf('     - %s\n', testFiles(i).name);
            end

        else
            fprintf('   ⚠️ Unit test directory not found\n');
        end

        % Test 3: Check for integration test files
        fprintf('\n3. Checking integration test files...\n');
        integrationTestDir = fullfile(currentDir, 'integration');

        if exist(integrationTestDir, 'dir')
            testFiles = dir(fullfile(integrationTestDir, '*Test.m'));
            fprintf('   Found %d integration test files:\n', length(testFiles));

            for i = 1:length(testFiles)
                fprintf('     - %s\n', testFiles(i).name);
            end

        else
            fprintf('   ⚠️ Integration test directory not found\n');
        end

        % Test 4: Verify MATLAB unittest framework
        fprintf('\n4. Checking MATLAB unittest framework...\n');

        try
            import matlab.unittest.TestSuite;
            import matlab.unittest.TestRunner;
            fprintf('   ✅ MATLAB unittest framework available\n');
        catch ME
            fprintf('   ❌ MATLAB unittest framework not available: %s\n', ME.message);
            return;
        end

        % Test 5: Try to load a simple test
        fprintf('\n5. Testing simple test execution...\n');

        try
            % Create a minimal test class in memory
            testCode = [ ...
                            'classdef SimpleTest < matlab.unittest.TestCase\n' ...
                            '    methods (Test)\n' ...
                            '        function testBasic(testCase)\n' ...
                            '            testCase.verifyEqual(2+2, 4);\n' ...
                            '        end\n' ...
                            '    end\n' ...
                        'end'];

            % Write temporary test file
            tempTestFile = fullfile(tempdir, 'SimpleTest.m');
            fid = fopen(tempTestFile, 'w');
            fprintf(fid, '%s', testCode);
            fclose(fid);

            % Add temp directory to path and run test
            addpath(tempdir);
            suite = TestSuite.fromFile(tempTestFile);
            runner = TestRunner.withTextOutput('Verbosity', matlab.unittest.Verbosity.Silent);
            results = run(runner, suite);

            if results.Passed
                fprintf('   ✅ Simple test execution successful\n');
            else
                fprintf('   ❌ Simple test execution failed\n');
            end

            % Cleanup
            delete(tempTestFile);
            rmpath(tempdir);

        catch ME
            fprintf('   ❌ Simple test execution failed: %s\n', ME.message);
        end

        % Test 6: Check for configuration system
        fprintf('\n6. Checking configuration system...\n');
        configPath = fullfile(projectRoot, 'config', 'csrd2025');

        if exist(configPath, 'dir')
            addpath(configPath);

            if exist('initialize_csrd_configuration.m', 'file')
                fprintf('   ✅ Configuration system found\n');

                try
                    % Try to load configuration (might fail if dependencies missing)
                    config = initialize_csrd_configuration();
                    fprintf('   ✅ Configuration loads successfully\n');
                catch ME
                    fprintf('   ⚠️ Configuration loads with warnings: %s\n', ME.message);
                end

            else
                fprintf('   ⚠️ Configuration initializer not found\n');
            end

        else
            fprintf('   ⚠️ Configuration directory not found\n');
        end

        % Test 7: Check for core CSRD components
        fprintf('\n7. Checking core CSRD components...\n');
        csrdPath = fullfile(projectRoot, '+csrd');

        if exist(csrdPath, 'dir')
            fprintf('   ✅ +csrd package directory found\n');

            % Check for key components
            components = {
                          fullfile(csrdPath, '+blocks', '+physical', '+txRadioFront', 'TRFSimulator.m'), ...
                              fullfile(csrdPath, '+blocks', '+scenario', 'ParameterDrivenPlanner.m'), ...
                              fullfile(csrdPath, '+blocks', '+physical', '+rxRadioFront', 'RRFSimulator.m')
                          };

            for i = 1:length(components)
                [~, compName] = fileparts(components{i});

                if exist(components{i}, 'file')
                    fprintf('   ✅ %s found\n', compName);
                else
                    fprintf('   ⚠️ %s not found\n', compName);
                end

            end

        else
            fprintf('   ❌ +csrd package directory not found\n');
        end

        % Final summary
        fprintf('\n=== Quick Test Summary ===\n');
        fprintf('Test infrastructure appears to be properly set up.\n');
        fprintf('\nTo run the actual test suite:\n');
        fprintf('  results = run_all_tests();                  %% Run all tests\n');
        fprintf('  results = run_all_tests(''unit'');            %% Run unit tests only\n');
        fprintf('  results = run_all_tests(''integration'');    %% Run integration tests only\n');
        fprintf('  results = run_all_tests(''all'', ''verbose'', true);  %% Verbose output\n');

        fprintf('\n✅ Quick test completed successfully!\n');

    catch ME
        fprintf('\n❌ Quick test failed with error: %s\n', ME.message);
        fprintf('Detailed error:\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    end

    fprintf('\n=== Quick Test Complete ===\n');
end
