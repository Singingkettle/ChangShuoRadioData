function results = test_channel_exception_propagation()
%TEST_CHANNEL_EXCEPTION_PROPAGATION Verify scenario-skip exceptions reach the runner.
%
%   Regression for the original H7 swallowed-exception bug. The fix is
%   layered:
%     1. Channel block raises ``RayTracing:NoValidPaths`` (or any
%        identifier containing the magic tokens).
%     2. ``csrd.factories.ChannelFactory.stepImpl`` rethrows
%        UNCONDITIONALLY -- it does not classify, because a failed channel
%        block must not produce a partial annotation whatever the cause.
%     3. ``processChannelPropagation`` rethrows.
%     4. ``generateSingleFrame`` rethrows.
%     5. ``SimulationRunner.runScenario`` classifies via the shared
%        predicate and skips the scenario.
%
%   This test exercises layers 1-2 with a real ChannelFactory and a
%   stub channel block (csrd.test_support.ThrowingChannelBlock). It
%   then statically inspects the upstream files: the layers that
%   classify must delegate to the ONE shared predicate, and
%   ChannelFactory must have no swallow path. We deliberately do
%   NOT spin up a full ChangShuo / SimulationRunner here, because that
%   would require disk I/O, OSM data and toolboxes the unit harness
%   should not depend on.
%
%   The fixtures here carry the FULL rxInfo and LinkBudget contract on
%   purpose. ChannelFactory resolves the carrier frequency and computes
%   the SNR label before stepping the channel block, so an incomplete
%   fixture makes it raise CSRD:Channel:Missing* first and the stub's
%   exception is never reached -- which is how two of these cases stopped
%   testing rethrow behaviour while the harness still reported a pass.

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    repoRoot = fileparts(repoRoot);
    addpath(genpath(repoRoot));

    results = struct('Total', 0, 'Passed', 0, 'Failed', 0, 'Failures', {{}});

    tests = { ...
        'predicateRecognisesAllSkipTokens', @testPredicateRecognisesAllSkipTokens; ...
        'predicateIgnoresGenericIdentifiers', @testPredicateIgnoresGenericIdentifiers; ...
        'channelFactoryRethrowsNoValidPaths', @testChannelFactoryRethrowsNoValidPaths; ...
        'channelFactoryRethrowsTransientError', @testChannelFactoryRethrowsTransientError; ...
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
            results.Failures{end+1} = sprintf('%s: %s', name, ME.message);
            fprintf('  [FAIL] %s -- %s\n', name, ME.message);
        end
    end

    fprintf('\nChannel exception propagation regression: %d/%d passed\n', ...
        results.Passed, results.Total);

    % RAISE on failure. Until this existed the harness counted its own failures,
    % printed them, and then returned normally -- so run_all_tests saw no exception
    % and recorded the whole script as PASS. Two of these five cases had been
    % failing since RealCarrierFrequency became mandatory upstream, and the suite
    % summary said nothing for as long as that was true. A gate that reports its own
    % failures as a pass is worse than no gate: it converts a real defect into
    % positive evidence.
    if results.Failed > 0
        error('CSRD:Test:ChannelExceptionPropagationFailed', ...
            'Channel exception propagation: %d of %d cases failed.\n  %s', ...
            results.Failed, results.Total, strjoin(results.Failures, '\n  '));
    end
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
        assert(csrd.pipeline.scenario.isScenarioSkipException(ME), ...
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
        assert(~csrd.pipeline.scenario.isScenarioSkipException(ME), ...
            sprintf('Predicate must reject %s', nonSkipIds{k}));
    end
end


function testChannelFactoryRethrowsNoValidPaths()
    factory = makeFactoryWithStub('throwSkip');
    cleanup = onCleanup(@() releaseFactory(factory));

    inputSignal = makeInputSignal();
    txInfo = makeTxInfo();
    rxInfo = makeRxInfo();
    % BurstId is required: it seeds the burst-deterministic channel noise, and the
    % factory demands it before the channel block runs.
    channelLinkInfo = struct( ...
        'ChannelModel', 'Stub', ...
        'BurstId', 'Tx1.Burst001', ...
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


function testChannelFactoryRethrowsTransientError()
    % Phase 5 removes the generic sentinel-output path. A non-scenario-level
    % channel error is still a real construction failure and must not write
    % ChannelBlockStepFailed into a partial annotation.
    factory = makeFactoryWithStub('throwGeneric');
    cleanup = onCleanup(@() releaseFactory(factory));

    inputSignal = makeInputSignal();
    txInfo = makeTxInfo();
    rxInfo = makeRxInfo();
    % BurstId is required: it seeds the burst-deterministic channel noise, and the
    % factory demands it before the channel block runs.
    channelLinkInfo = struct( ...
        'ChannelModel', 'Stub', ...
        'BurstId', 'Tx1.Burst001', ...
        'MapProfile', struct('Mode', 'FlatTerrain'));

    raised = false;
    try
        step(factory, inputSignal, 1, txInfo, rxInfo, channelLinkInfo);
    catch ME
        raised = true;
        assert(strcmp(ME.identifier, 'CSRD:Test:GenericError'), ...
            sprintf('Expected CSRD:Test:GenericError but got %s', ME.identifier));
    end
    assert(raised, 'ChannelFactory swallowed a generic channel exception.');
end


function testUpstreamFilesUseSharedPredicate()
    % Two different requirements, so two different checks.
    %
    % The layers that CLASSIFY must delegate to the one shared predicate rather
    % than re-implementing token matching, because a second copy of the token list
    % would drift and start disagreeing about which failures are skippable.
    %
    % ChannelFactory is deliberately NOT in that list any more. It does not
    % classify -- it rethrows everything, since a failed channel block must never
    % produce a partial annotation whatever the cause. It used to name the
    % predicate in a branch whose two arms were identical, which satisfied this
    % gate while proving nothing about behaviour. Requiring the name here actively
    % pushed toward keeping dead code, so the requirement for that file is now
    % stated as what it actually is: no catch block may swallow.
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    repoRoot = fileparts(repoRoot);

    classifiers = { ...
        fullfile(repoRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
            'processChannelPropagation.m'); ...
        fullfile(repoRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
            'generateSingleFrame.m'); ...
        fullfile(repoRoot, '+csrd', 'SimulationRunner.m'); ...
        fullfile(repoRoot, '+csrd', '+factories', 'ScenarioFactory.m')};

    needle = 'csrd.pipeline.scenario.isScenarioSkipException';
    for k = 1:numel(classifiers)
        text = fileread(classifiers{k});
        assert(contains(text, needle), ...
            sprintf('%s does not call %s', classifiers{k}, needle));
    end

    % ChannelFactory: every catch around the channel-block step must end in a
    % rethrow. A `catch` that falls through, warns, or assigns a sentinel output is
    % the original H7 swallowed-exception bug returning.
    factoryPath = fullfile(repoRoot, '+csrd', '+factories', 'ChannelFactory.m');
    factoryText = fileread(factoryPath);
    assert(contains(factoryText, 'rethrow(ME_step)'), ...
        sprintf('%s must rethrow the channel-block exception.', factoryPath));
    assert(~contains(factoryText, 'ChannelBlockStepFailed'), ...
        sprintf(['%s must not resurrect the sentinel-output path: a failed ', ...
                 'channel block must not write a partial annotation.'], factoryPath));
end


% --- helpers --------------------------------------------------------------

function factory = makeFactoryWithStub(mode)
    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.logger.GlobalLogManager.initialize(struct( ...
        'Level', 'CRITICAL', ...
        'SaveToFile', false, ...
        'DisplayInConsole', false));

    cfg = struct();
    cfg.ChannelModels.Stub = struct( ...
        'handle', 'csrd.test_support.ThrowingChannelBlock', ...
        'Config', struct('Mode', mode));
    cfg.NoValidPathFallback = 'NoFallback';
    % The full LinkBudget contract, not a token field. ChannelFactory computes the
    % SNR label before stepping the channel block, so an incomplete LinkBudget makes
    % it raise CSRD:Channel:Missing* first and the stub's exception is never reached.
    % The two rethrow cases below were doing exactly that -- passing a
    % single-field LinkBudget and then asserting on the wrong exception -- which is
    % how they stopped testing rethrow behaviour without anyone noticing.
    cfg.LinkBudget = struct( ...
        'EnableDistanceBasedSNR', false, ...
        'ThermalNoisePSD', -174, ...
        'NoiseFigure', 6, ...
        'NoiseBandwidth', 1e6, ...
        'MinDistance', 0.01, ...
        'TargetSnrRangeDb', [10, 10]);

    factory = csrd.factories.ChannelFactory('Config', cfg);
end


function releaseFactory(factory)
    try
        release(factory);
    catch
    end
    csrd.runtime.logger.GlobalLogManager.reset();
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
    % RealCarrierFrequency is REQUIRED, not optional decoration: ChannelFactory
    % resolves it while computing path loss, which happens BEFORE the channel block
    % is stepped. Without it the factory raised
    % CSRD:Channel:MissingCarrierFrequency and the stub never got the chance to
    % throw the exception this test exists to trace -- so the two rethrow cases were
    % asserting nothing about rethrow behaviour at all. A real receiver always has a
    % tuned frequency, so the fixture was simply incomplete.
    s = struct( ...
        'ID', 'Rx1', ...
        'Status', 'OK', ...
        'Position', [100, 0, 30], ...
        'SampleRate', 5e6, ...
        'RealCarrierFrequency', 2.4e9, ...
        'NumReceiveAntennas', 1);
end
