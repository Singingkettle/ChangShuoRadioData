function results = test_channel_exception_propagation()
%TEST_CHANNEL_EXCEPTION_PROPAGATION Verify scenario-skip exceptions reach the runner.
%
%   Regression for the original H7 swallowed-exception bug. The fix is
%   layered:
%     1. Channel block raises ``RayTracing:NoValidPaths`` (or any
%        identifier containing the magic tokens).
%     2. ``csrd.factories.ChannelFactory.stepImpl`` rethrows when
%        ``csrd.utils.scenario.isScenarioSkipException`` matches.
%     3. ``processChannelPropagation`` rethrows.
%     4. ``generateSingleFrame`` rethrows.
%     5. ``SimulationRunner.runScenario`` catches and skips the scenario.
%
%   This test exercises layers 1-2 with a real ChannelFactory and a
%   stub channel block (csrd.test_support.ThrowingChannelBlock). It
%   then statically inspects the upstream files (layers 3-5) to make
%   sure they all delegate to the shared predicate. We deliberately do
%   NOT spin up a full ChangShuo / SimulationRunner here, because that
%   would require disk I/O, OSM data and toolboxes the unit harness
%   should not depend on.

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    repoRoot = fileparts(repoRoot);
    addpath(genpath(repoRoot));

    results = struct('Total', 0, 'Passed', 0, 'Failed', 0, 'Failures', {{}});

    tests = { ...
        'predicateRecognisesAllSkipTokens', @testPredicateRecognisesAllSkipTokens; ...
        'predicateIgnoresGenericIdentifiers', @testPredicateIgnoresGenericIdentifiers; ...
        'channelFactoryRethrowsNoValidPaths', @testChannelFactoryRethrowsNoValidPaths; ...
        'channelFactorySwallowsTransientError', @testChannelFactorySwallowsTransientError; ...
        'upstreamFilesUseSharedPredicate', @testUpstreamFilesUseSharedPredicate};

    for i = 1:size(tests, 1)
        name = tests{i, 1};
        fn = tests{i, 2};
        results.Total = results.Total + 1;
        try
            fn();
            results.Passed = results.Passed + 1;
            fprintf('  [PASS] %s\n', name);
        catch ME
            results.Failed = results.Failed + 1;
            results.Failures{end+1} = sprintf('%s: %s', name, ME.message); %#ok<AGROW>
            fprintf('  [FAIL] %s -- %s\n', name, ME.message);
        end
    end

    fprintf('\nChannel exception propagation regression: %d/%d passed\n', ...
        results.Passed, results.Total);
end


function testPredicateRecognisesAllSkipTokens()
    skipIds = { ...
        'RayTracing:NoValidPaths', ...
        'PhysicalEnvironmentSimulator:NoBuildingData', ...
        'ScenarioFactory:SkipScenario', ...
        'CSRD:Channel:NoValidPaths', ...
        'CSRD:Map:NoBuildingData'};
    for k = 1:numel(skipIds)
        ME = MException(skipIds{k}, 'simulated %s', skipIds{k});
        assert(csrd.utils.scenario.isScenarioSkipException(ME), ...
            sprintf('Predicate must accept %s', skipIds{k}));
    end
end


function testPredicateIgnoresGenericIdentifiers()
    nonSkipIds = { ...
        'CSRD:Channel:Generic', ...
        'MATLAB:notEnoughInputs', ...
        'CSRD:Whatever:Other'};
    for k = 1:numel(nonSkipIds)
        ME = MException(nonSkipIds{k}, 'msg');
        assert(~csrd.utils.scenario.isScenarioSkipException(ME), ...
            sprintf('Predicate must reject %s', nonSkipIds{k}));
    end
end


function testChannelFactoryRethrowsNoValidPaths()
    factory = makeFactoryWithStub('throwSkip');
    cleanup = onCleanup(@() releaseFactory(factory)); %#ok<NASGU>

    inputSignal = makeInputSignal();
    txInfo = makeTxInfo();
    rxInfo = makeRxInfo();
    channelLinkInfo = struct( ...
        'ChannelModel', 'Stub', ...
        'MapProfile', struct('Mode', 'FlatTerrain'));

    raised = false;
    try
        step(factory, inputSignal, 1, txInfo, rxInfo, channelLinkInfo);
    catch ME
        raised = true;
        assert(contains(ME.identifier, 'NoValidPaths'), ...
            sprintf('Expected NoValidPaths but got %s', ME.identifier));
    end
    assert(raised, 'ChannelFactory swallowed the NoValidPaths exception.');
end


function testChannelFactorySwallowsTransientError()
    % A non-scenario-level error must NOT bring down the whole pipeline,
    % the factory should record it as ChannelBlockStepFailed and return
    % a degraded receivedSignal struct.
    factory = makeFactoryWithStub('throwGeneric');
    cleanup = onCleanup(@() releaseFactory(factory)); %#ok<NASGU>

    inputSignal = makeInputSignal();
    txInfo = makeTxInfo();
    rxInfo = makeRxInfo();
    channelLinkInfo = struct( ...
        'ChannelModel', 'Stub', ...
        'MapProfile', struct('Mode', 'FlatTerrain'));

    out = step(factory, inputSignal, 1, txInfo, rxInfo, channelLinkInfo);
    assert(isstruct(out), 'Factory must return a struct after generic errors.');
    assert(isfield(out, 'Error') && strcmp(out.Error, 'ChannelBlockStepFailed'), ...
        'Generic channel error should be tagged as ChannelBlockStepFailed.');
end


function testUpstreamFilesUseSharedPredicate()
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    repoRoot = fileparts(repoRoot);
    upstream = { ...
        fullfile(repoRoot, '+csrd', '+factories', 'ChannelFactory.m'); ...
        fullfile(repoRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
            'processChannelPropagation.m'); ...
        fullfile(repoRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
            'generateSingleFrame.m'); ...
        fullfile(repoRoot, '+csrd', 'SimulationRunner.m'); ...
        fullfile(repoRoot, '+csrd', '+factories', 'ScenarioFactory.m')};

    needle = 'csrd.utils.scenario.isScenarioSkipException';
    for k = 1:numel(upstream)
        text = fileread(upstream{k});
        assert(contains(text, needle), ...
            sprintf('%s does not call %s', upstream{k}, needle));
    end
end


% --- helpers --------------------------------------------------------------

function factory = makeFactoryWithStub(mode)
    csrd.utils.logger.GlobalLogManager.reset();
    csrd.utils.logger.GlobalLogManager.initialize(struct( ...
        'Level', 'CRITICAL', ...
        'SaveToFile', false, ...
        'DisplayInConsole', false));

    cfg = struct();
    cfg.ChannelModels.Stub = struct( ...
        'handle', 'csrd.test_support.ThrowingChannelBlock', ...
        'Config', struct('Mode', mode));
    cfg.NoValidPathFallback = 'NoFallback';
    cfg.LinkBudget = struct('EnableDistanceBasedSNR', false);

    factory = csrd.factories.ChannelFactory('Config', cfg);
end


function releaseFactory(factory)
    try
        release(factory);
    catch
    end
    csrd.utils.logger.GlobalLogManager.reset();
end


function s = makeInputSignal()
    s = struct();
    s.Signal = (1 + 1j) * ones(64, 1);
    s.SampleRate = 1e6;
    s.Bandwidth = 1e5;
    s.FrequencyOffset = 0;
end


function s = makeTxInfo()
    s = struct( ...
        'ID', 'Tx1', ...
        'Position', [0, 0, 30], ...
        'Power', 20, ...
        'NumTransmitAntennas', 1);
end


function s = makeRxInfo()
    s = struct( ...
        'ID', 'Rx1', ...
        'Status', 'OK', ...
        'Position', [100, 0, 30], ...
        'SampleRate', 5e6, ...
        'NumReceiveAntennas', 1);
end
