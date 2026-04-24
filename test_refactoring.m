function test_refactoring()
    % test_refactoring - Comprehensive end-to-end test for refactored CSRD pipeline
    %
    % Tests multiple configurations with deterministic temporal patterns:
    %   1. Basic test: 2 Tx, 1 Rx, 2 frames, ALL Continuous
    %   2. Single Tx test: 1 Tx, 1 Rx, 1 frame
    %   3. Many Tx test: 4 Tx, 2 Rx, 3 frames, ALL Continuous
    %   4. Burst pattern test: 2 Tx, 1 Rx, 2 frames, ALL Burst
    %
    % Run from the project root directory:
    %   cd c:\Users\lenovo\ChangShuoRadioData
    %   test_refactoring

    fprintf('=== CSRD Refactoring Comprehensive Test Suite ===\n\n');

    clear classes;
    csrd.utils.logger.GlobalLogManager.reset();

    % Load base configuration
    fprintf('Loading base configuration...\n');
    try
        masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
        fprintf('  [OK] Configuration loaded.\n\n');
    catch ME
        fprintf('  [FAIL] Config loading failed: %s\n', ME.message);
        return;
    end

    % Initialize logging
    masterConfig.Log.Level = 'INFO';
    csrd.utils.logger.GlobalLogManager.initialize(masterConfig.Log);

    totalPassed = 0;
    totalFailed = 0;

    % ===== TEST 1: Basic 2Tx, 1Rx, 2 frames, ALL Continuous =====
    [passed, failed] = runTestCase(masterConfig, 'Test 1: Basic 2Tx/1Rx/2frames Continuous', struct(...
        'NumScenarios', 1, ...
        'NumFrames', 2, ...
        'ObservationDuration', 0.01, ...
        'TxMin', 2, 'TxMax', 2, ...
        'RxMin', 1, 'RxMax', 1, ...
        'MapTypes', {{'Statistical'}}, ...
        'MapRatio', [1.0], ...
        'PatternTypes', {{'Continuous'}}, ...
        'PatternDistribution', [1.0]));
    totalPassed = totalPassed + passed;
    totalFailed = totalFailed + failed;

    % ===== TEST 2: Single Tx, 1 frame =====
    [passed, failed] = runTestCase(masterConfig, 'Test 2: Single 1Tx/1Rx/1frame', struct(...
        'NumScenarios', 1, ...
        'NumFrames', 1, ...
        'ObservationDuration', 0.005, ...
        'TxMin', 1, 'TxMax', 1, ...
        'RxMin', 1, 'RxMax', 1, ...
        'MapTypes', {{'Statistical'}}, ...
        'MapRatio', [1.0], ...
        'PatternTypes', {{'Continuous'}}, ...
        'PatternDistribution', [1.0]));
    totalPassed = totalPassed + passed;
    totalFailed = totalFailed + failed;

    % ===== TEST 3: Many Tx, 2 Rx, 3 frames, ALL Continuous =====
    [passed, failed] = runTestCase(masterConfig, 'Test 3: Multi 4Tx/2Rx/3frames Continuous', struct(...
        'NumScenarios', 1, ...
        'NumFrames', 3, ...
        'ObservationDuration', 0.01, ...
        'TxMin', 4, 'TxMax', 4, ...
        'RxMin', 2, 'RxMax', 2, ...
        'MapTypes', {{'Statistical'}}, ...
        'MapRatio', [1.0], ...
        'PatternTypes', {{'Continuous'}}, ...
        'PatternDistribution', [1.0]));
    totalPassed = totalPassed + passed;
    totalFailed = totalFailed + failed;

    % ===== TEST 4: Burst pattern only =====
    [passed, failed] = runTestCase(masterConfig, 'Test 4: Burst only 2Tx/1Rx/2frames', struct(...
        'NumScenarios', 1, ...
        'NumFrames', 2, ...
        'ObservationDuration', 0.01, ...
        'TxMin', 2, 'TxMax', 2, ...
        'RxMin', 1, 'RxMax', 1, ...
        'MapTypes', {{'Statistical'}}, ...
        'MapRatio', [1.0], ...
        'PatternTypes', {{'Burst'}}, ...
        'PatternDistribution', [1.0]));
    totalPassed = totalPassed + passed;
    totalFailed = totalFailed + failed;

    % ===== TEST 5: Mixed patterns (40% Continuous, 30% Burst, 20% Scheduled, 10% Random) =====
    [passed, failed] = runTestCase(masterConfig, 'Test 5: Mixed patterns 3Tx/1Rx/2frames', struct(...
        'NumScenarios', 1, ...
        'NumFrames', 2, ...
        'ObservationDuration', 0.01, ...
        'TxMin', 3, 'TxMax', 3, ...
        'RxMin', 1, 'RxMax', 1, ...
        'MapTypes', {{'Statistical'}}, ...
        'MapRatio', [1.0], ...
        'PatternTypes', {{'Continuous', 'Burst', 'Scheduled', 'Random'}}, ...
        'PatternDistribution', [0.4, 0.3, 0.2, 0.1]));
    totalPassed = totalPassed + passed;
    totalFailed = totalFailed + failed;

    % ===== SUMMARY =====
    fprintf('\n===================================================================\n');
    fprintf('TOTAL: %d passed, %d failed out of %d tests\n', ...
        totalPassed, totalFailed, totalPassed + totalFailed);
    fprintf('===================================================================\n');
end

function [passed, failed] = runTestCase(baseMasterConfig, testName, params)
    passed = 0;
    failed = 0;

    fprintf('------- %s -------\n', testName);

    mc = baseMasterConfig;
    mc.Runner.NumScenarios = params.NumScenarios;
    mc.Factories.Scenario.Global.NumFramesPerScenario = params.NumFrames;
    mc.Factories.Scenario.Global.ObservationDuration = params.ObservationDuration;
    mc.Factories.Scenario.PhysicalEnvironment.Map.Types = params.MapTypes;
    mc.Factories.Scenario.PhysicalEnvironment.Map.Ratio = params.MapRatio;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = params.TxMin;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = params.TxMax;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = params.RxMin;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = params.RxMax;

    % Set temporal behavior pattern types deterministically
    if ~isfield(mc.Factories.Scenario, 'CommunicationBehavior')
        mc.Factories.Scenario.CommunicationBehavior = struct();
    end
    if ~isfield(mc.Factories.Scenario.CommunicationBehavior, 'TemporalBehavior')
        mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior = struct();
    end
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = params.PatternTypes;
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = params.PatternDistribution;

    try
        engine = csrd.core.ChangShuo();
        engine.FactoryConfigs = mc.Factories;
        setup(engine, 1);
        fprintf('  [OK] Engine setup.\n');
    catch ME
        fprintf('  [FAIL] Engine setup: %s\n', ME.message);
        fprintf('  Stack: %s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        failed = failed + 1;
        return;
    end

    try
        [scenarioData, scenarioAnnotation] = step(engine, 1);
        fprintf('  [OK] Scenario execution complete.\n');
    catch ME
        fprintf('  [FAIL] Scenario execution: %s\n', ME.message);
        fprintf('  Stack: %s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        failed = failed + 1;
        return;
    end

    % Validate output
    if isempty(scenarioData)
        fprintf('  [FAIL] scenarioData is empty.\n');
        failed = failed + 1;
        return;
    end

    numFrames = length(scenarioData);
    if numFrames ~= params.NumFrames
        fprintf('  [FAIL] Expected %d frames, got %d.\n', params.NumFrames, numFrames);
        failed = failed + 1;
    else
        fprintf('  [OK] Got expected %d frames.\n', numFrames);
        passed = passed + 1;
    end

    allFramesValid = true;
    for f = 1:numFrames
        frameData = scenarioData{f};
        frameAnn = scenarioAnnotation{f};

        if isempty(frameData)
            fprintf('  [WARN] Frame %d: empty data.\n', f);
            allFramesValid = false;
            continue;
        end

        if iscell(frameData)
            for rxIdx = 1:length(frameData)
                rxData = frameData{rxIdx};
                if isstruct(rxData) && isfield(rxData, 'Signal')
                    sigLen = length(rxData.Signal);
                    fprintf('  Frame %d, Rx %d: Signal length=%d', f, rxIdx, sigLen);

                    if isfield(rxData, 'SampleRate')
                        fprintf(', SampleRate=%.0f Hz', rxData.SampleRate);
                    end

                    fprintf('\n');

                    if sigLen == 0
                        fprintf('  [WARN] Frame %d, Rx %d: Zero-length signal.\n', f, rxIdx);
                        allFramesValid = false;
                    end
                else
                    fprintf('  [WARN] Frame %d, Rx %d: unexpected format.\n', f, rxIdx);
                    allFramesValid = false;
                end
            end
        end

        % Validate annotations
        if iscell(frameAnn)
            for rxIdx = 1:length(frameAnn)
                ann = frameAnn{rxIdx};
                if isstruct(ann) && isfield(ann, 'Status')
                    fprintf('  Ann Frame %d, Rx %d: Status=%s', f, rxIdx, ann.Status);
                    if isfield(ann, 'NumSignalComponents')
                        fprintf(', NumComponents=%d', ann.NumSignalComponents);
                    end
                    if isfield(ann, 'SignalSources') && ~isempty(ann.SignalSources)
                        src = ann.SignalSources(1);
                        if isfield(src, 'Planned') && isfield(src, 'Realized')
                            pBW = src.Planned.Bandwidth;
                            rBW = src.Realized.Bandwidth;
                            bwRatio = abs(pBW - rBW) / max(pBW, 1);
                            fprintf(', PlannedBW=%.0f, RealizedBW=%.0f (diff=%.1f%%)', pBW, rBW, bwRatio*100);
                            if bwRatio > 0.2
                                fprintf(' [WARN: >20%% BW discrepancy]');
                            end
                        end
                    end
                    fprintf('\n');
                end
            end
        end
    end

    if allFramesValid
        fprintf('  [OK] All frames have valid signal data.\n');
        passed = passed + 1;
    else
        fprintf('  [FAIL] Some frames have invalid data.\n');
        failed = failed + 1;
    end

    % === Validate spatial annotation ===
    spatialValid = true;
    for f = 1:numFrames
        frameAnn = scenarioAnnotation{f};
        if ~iscell(frameAnn), continue; end
        for rxIdx = 1:length(frameAnn)
            ann = frameAnn{rxIdx};
            if ~isstruct(ann) || ~isfield(ann, 'SignalSources') || isempty(ann.SignalSources)
                continue;
            end
            for sIdx = 1:length(ann.SignalSources)
                src = ann.SignalSources(sIdx);
                if ~isfield(src, 'Spatial')
                    fprintf('  [WARN] Frame %d, Rx %d, Src %d: Missing Spatial field.\n', f, rxIdx, sIdx);
                    spatialValid = false;
                    continue;
                end
                sp = src.Spatial;
                hasTxPos = isfield(sp, 'TxPosition') && ~isempty(sp.TxPosition);
                hasRxPos = isfield(sp, 'RxPosition') && ~isempty(sp.RxPosition);
                hasDist = isfield(sp, 'LinkDistance');
                hasPL = isfield(sp, 'PathLoss');
                if hasTxPos && hasRxPos && hasDist && hasPL
                    fprintf('  Frame %d, Rx %d, Src %d: TxPos=[%.1f,%.1f,%.1f], Dist=%.1fm, PL=%.1fdB\n', ...
                        f, rxIdx, sIdx, sp.TxPosition(1), sp.TxPosition(2), sp.TxPosition(3), ...
                        sp.LinkDistance, sp.PathLoss);
                else
                    fprintf('  [WARN] Frame %d, Rx %d, Src %d: Incomplete spatial info.\n', f, rxIdx, sIdx);
                    spatialValid = false;
                end
            end
        end
    end
    if spatialValid
        fprintf('  [OK] Spatial annotation present and complete.\n');
        passed = passed + 1;
    else
        fprintf('  [WARN] Spatial annotation incomplete (non-blocking).\n');
    end

    % === Validate multi-frame position change (for tests with >1 frame and moving entities) ===
    if numFrames > 1
        posChanged = false;
        for rxIdx = 1:length(scenarioAnnotation{1})
            ann1 = scenarioAnnotation{1}{rxIdx};
            annN = scenarioAnnotation{numFrames}{rxIdx};
            if ~isstruct(ann1) || ~isfield(ann1, 'SignalSources') || isempty(ann1.SignalSources), continue; end
            if ~isstruct(annN) || ~isfield(annN, 'SignalSources') || isempty(annN.SignalSources), continue; end
            for sIdx = 1:min(length(ann1.SignalSources), length(annN.SignalSources))
                src1 = ann1.SignalSources(sIdx);
                srcN = annN.SignalSources(sIdx);
                if isfield(src1, 'Spatial') && isfield(srcN, 'Spatial') && ...
                   isfield(src1.Spatial, 'TxPosition') && isfield(srcN.Spatial, 'TxPosition')
                    pos1 = src1.Spatial.TxPosition;
                    posN = srcN.Spatial.TxPosition;
                    if norm(pos1 - posN) > 1e-6
                        posChanged = true;
                        fprintf('  [OK] TxID=%s position changed: Frame1=[%.1f,%.1f,%.1f] -> Frame%d=[%.1f,%.1f,%.1f]\n', ...
                            string(src1.TxID), pos1(1), pos1(2), pos1(3), ...
                            numFrames, posN(1), posN(2), posN(3));
                    end
                end
            end
        end
        if posChanged
            fprintf('  [OK] Multi-frame position change detected.\n');
            passed = passed + 1;
        else
            fprintf('  [INFO] No position change detected (entities may be stationary).\n');
        end
    end

    fprintf('\n');
end
