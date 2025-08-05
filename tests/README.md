# CSRD Frequency Translation System Test Suite

This directory contains comprehensive unit and integration tests for the ChangShuoRadioData (CSRD) project's new complex exponential frequency translation system.

## Test Structure

```
tests/
├── run_all_tests.m                    # Main test runner script
├── README.md                          # This file
├── unit/                              # Unit tests directory
│   ├── TRFSimulatorTest.m             # TRFSimulator unit tests
│   └── ParameterDrivenPlannerTest.m   # ParameterDrivenPlanner unit tests
└── integration/                       # Integration tests directory
    └── FrequencyTranslationSystemTest.m  # End-to-end system tests
```

## Test Categories

### Unit Tests (`tests/unit/`)

Unit tests verify individual components in isolation:

#### `TRFSimulatorTest.m`
- **Purpose**: Tests the new complex exponential frequency translation system in TRFSimulator
- **Coverage**:
  - Constructor and basic functionality
  - Complex exponential frequency translation accuracy
  - Sample rate conversion
  - Multiple antenna processing
  - RF impairments application
  - Negative frequency offset support
  - Output field consistency
- **Key Features**:
  - Parameterized tests for different frequencies and sample rates
  - Spectral analysis validation
  - Proper test fixture management

#### `ParameterDrivenPlannerTest.m`
- **Purpose**: Tests the scenario planning and receiver-centric frequency allocation
- **Coverage**:
  - Scenario instance generation
  - Receiver-centric frequency allocation
  - Frequency range validation
  - Configuration handling
  - Multiple allocation strategies
  - Negative frequency support
  - Modulation and timing configuration
- **Key Features**:
  - Parameterized tests for different scenario sizes and strategies
  - Configuration validation
  - Multi-frame consistency testing

### Integration Tests (`tests/integration/`)

Integration tests verify end-to-end system functionality:

#### `FrequencyTranslationSystemTest.m`
- **Purpose**: Tests complete pipeline from scenario generation to receiver output
- **Coverage**:
  - Full processing pipeline integration
  - Multi-transmitter scenarios
  - Receiver-centric frequency management
  - Spectrum utilization analysis
  - Signal integrity validation
  - Negative frequency utilization
  - End-to-end performance verification
- **Key Features**:
  - Complex multi-component system testing
  - Spectral analysis and validation
  - Performance and efficiency metrics
  - Real signal processing verification

## Running Tests

### Quick Start

```matlab
% Run all tests
cd('tests')
results = run_all_tests();

% Run only unit tests
results = run_all_tests('unit');

% Run only integration tests
results = run_all_tests('integration');
```

### Advanced Usage

```matlab
% Run with verbose output
results = run_all_tests('all', 'verbose', true);

% Generate JUnit XML report
results = run_all_tests('all', 'outputFormat', 'junit');

% Generate PDF report (if supported)
results = run_all_tests('all', 'outputFormat', 'pdf');

% Run with parallel execution (if Parallel Computing Toolbox available)
results = run_all_tests('all', 'parallel', true);
```

### Individual Test Execution

```matlab
% Run individual test class
import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;

suite = TestSuite.fromFile('unit/TRFSimulatorTest.m');
runner = TestRunner.withTextOutput();
results = run(runner, suite);

% Run specific test method
suite = TestSuite.fromMethod('TRFSimulatorTest', 'testFrequencyTranslation');
results = run(runner, suite);
```

## Test Output and Reports

### Console Output
The test runner provides real-time progress updates and summary information:
- Test discovery and suite building
- Individual test progress
- Pass/fail summary with percentages
- Execution time reporting
- Detailed failure information

### Result Files
- **MAT file**: `test_results_[type]_[timestamp].mat` - Complete results structure
- **JUnit XML**: `test_results.xml` - For CI/CD integration
- **PDF Report**: `test_results.pdf` - Formatted test report
- **Coverage**: `coverage.xml` - Code coverage information

### Result Structure
```matlab
results = struct(
    'Success', logical,           % Overall success status
    'TotalTests', double,         % Total number of tests
    'Passed', double,             % Number of passed tests
    'Failed', double,             % Number of failed tests
    'Incomplete', double,         % Number of incomplete tests
    'ExecutionTime', double,      % Total execution time
    'TestResults', struct_array,  % Detailed test results
    'TestType', string           % Type of tests run
);
```

## Test Development Guidelines

### Writing New Tests

1. **Follow naming convention**: `*Test.m` for test files
2. **Inherit from TestCase**: `classdef MyTest < matlab.unittest.TestCase`
3. **Use descriptive method names**: `testSpecificFunctionality`
4. **Include setup/teardown**: Use `TestMethodSetup` and `TestMethodTeardown`
5. **Parameterize when useful**: Use `TestParameter` properties

### Test Class Template

```matlab
classdef MyComponentTest < matlab.unittest.TestCase
    % MyComponentTest - Unit tests for MyComponent
    
    properties (TestParameter)
        % Test parameters for different scenarios
        Parameter1 = {value1, value2, value3}
    end
    
    properties
        % Test fixtures
        TestObject
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            % Setup for each test method
            testCase.TestObject = MyComponent();
        end
    end
    
    methods (TestMethodTeardown)
        function teardownTest(testCase)
            % Cleanup after each test method
            if ~isempty(testCase.TestObject)
                % Cleanup code
                testCase.TestObject = [];
            end
        end
    end
    
    methods (Test)
        function testBasicFunctionality(testCase)
            % Test basic functionality
            result = testCase.TestObject.someMethod();
            testCase.verifyEqual(result, expectedValue);
        end
        
        function testParameterized(testCase, Parameter1)
            % Test with different parameter values
            result = testCase.TestObject.methodWithParameter(Parameter1);
            testCase.verifyGreaterThan(result, 0);
        end
    end
end
```

### Verification Methods

Common verification methods used in tests:
- `verifyEqual(actual, expected)` - Exact equality
- `verifyTrue(condition)` - Boolean true
- `verifyFalse(condition)` - Boolean false
- `verifyGreaterThan(actual, threshold)` - Numeric comparison
- `verifyLessThan(actual, threshold)` - Numeric comparison
- `verifyError(function, identifier)` - Expected error
- `verifyWarning(function, identifier)` - Expected warning
- `verifyClass(object, className)` - Object type

## Dependencies

### Required
- MATLAB R2019b or later (for unittest framework features)
- ChangShuoRadioData project (+csrd package)
- DSP System Toolbox (for signal processing functions)

### Optional
- Parallel Computing Toolbox (for parallel test execution)
- Signal Processing Toolbox (for advanced spectral analysis)

## Continuous Integration

### Running in CI/CD

```bash
# Example CI script
matlab -batch "cd('tests'); results = run_all_tests('all', 'outputFormat', 'junit'); exit(double(~results.Success))"
```

### Test Coverage

The test suite includes code coverage analysis when run with appropriate plugins:
- Covers `+csrd` package functionality
- Generates coverage reports in XML format
- Integrates with common CI/CD coverage tools

## Troubleshooting

### Common Issues

1. **Path Issues**: Ensure project root is in MATLAB path
2. **Missing Dependencies**: Install required toolboxes
3. **Configuration Errors**: Check `initialize_csrd_configuration.m` availability
4. **Memory Issues**: Run tests individually for large scenarios

### Debug Mode

For detailed debugging:
```matlab
% Enable detailed diagnostics
results = run_all_tests('all', 'verbose', true);

% Run individual failing test with debugging
dbstop if error
suite = TestSuite.fromMethod('TRFSimulatorTest', 'testFrequencyTranslation');
results = run(TestRunner.withTextOutput(), suite);
```

## Performance Considerations

- **Unit tests**: Fast execution (< 1 second per test)
- **Integration tests**: Longer execution (1-10 seconds per test)
- **Parallel execution**: Can reduce total execution time
- **Large scenarios**: May require significant memory

## Contributing

When adding new tests:
1. Follow the established patterns and structure
2. Include both positive and negative test cases
3. Test edge cases and error conditions
4. Update this README if adding new test categories
5. Ensure tests are deterministic and repeatable

## Version History

- **v1.0**: Initial test suite for frequency translation system
- **v1.1**: Added integration tests and advanced runner features
- **v1.2**: Enhanced parameterized testing and coverage reporting 