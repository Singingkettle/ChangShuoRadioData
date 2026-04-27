classdef ReceiverViewPersistenceTest < matlab.unittest.TestCase
    %RECEIVERVIEWPERSISTENCETEST Phase 4 §S6 / P4-followup-3 contract.
    %
    %   Pin the ReceiverView 5-field persistence wired through
    %   processChannelPropagation -> processReceiverProcessing ->
    %   SignalSources(k).ReceiverView.
    %
    %   The 6 canonical fields populated upstream by
    %   allocateFrequenciesReceiverCentric.projectReceiverViews are:
    %     ReceiverId / ProjectedCenterOffsetHz / ProjectedLowerEdgeHz /
    %     ProjectedUpperEdgeHz / IsVisible / VisibilityReason
    %
    %   Phase 4 plan §5 schema lists 5 of those (ReceiverId implicit via
    %   the FrameAnnotation key); persisting all 6 is the strictly
    %   stronger contract and the v2 schema accepts the extra field.
    %
    %   This test asserts:
    %     C5-A: Every SignalSources(k).ReceiverView is a non-empty struct.
    %     C5-B: The 6 canonical fields are present and have expected types
    %           (numeric scalar / logical / char).
    %     C5-C: ProjectedCenterOffsetHz on the persisted ReceiverView
    %           equals the realised CenterFrequencyOffsetHz in
    %           Truth.Execution (proves the projection survived
    %           buildSourceAnnotation rather than being re-derived).

    properties (Constant, Access = private)
        ExpectedFields = { ...
            'ReceiverId', 'ProjectedCenterOffsetHz', ...
            'ProjectedLowerEdgeHz', 'ProjectedUpperEdgeHz', ...
            'IsVisible', 'VisibilityReason'};
    end

    methods (TestClassSetup)
        function suppressMatlabStructWarning(testCase)
            ws = warning('off', 'MATLAB:structOnObject');
            testCase.addTeardown(@(s) warning(s), ws);
        end
    end

    methods (Test)

        function receiverViewIsNonEmptyOnEverySource(testCase)
            sources = runSmokeAndCollect(testCase);
            testCase.assertNotEmpty(sources, ...
                'C5-A: smoke produced no SignalSources to inspect.');
            for k = 1:numel(sources)
                src = sources{k};
                testCase.assertTrue(isfield(src, 'ReceiverView'), ...
                    sprintf('Source %d missing ReceiverView field.', k));
                testCase.verifyTrue(isstruct(src.ReceiverView), ...
                    sprintf('Source %d ReceiverView is not a struct.', k));
                testCase.verifyTrue(~isempty(fieldnames(src.ReceiverView)), ...
                    sprintf('Source %d ReceiverView is an empty struct (S6 plumbing did not fire).', k));
            end
        end

        function receiverViewCarriesCanonicalFields(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                src = sources{k};
                fns = fieldnames(src.ReceiverView);
                for f = 1:numel(testCase.ExpectedFields)
                    expected = testCase.ExpectedFields{f};
                    testCase.verifyTrue(any(strcmp(fns, expected)), ...
                        sprintf('Source %d ReceiverView missing canonical field "%s".', ...
                            k, expected));
                end
                testCase.verifyTrue(ischar(src.ReceiverView.ReceiverId) || ...
                    isstring(src.ReceiverView.ReceiverId), ...
                    sprintf('Source %d ReceiverView.ReceiverId is not text.', k));
                testCase.verifyTrue(isnumeric(src.ReceiverView.ProjectedCenterOffsetHz) && ...
                    isscalar(src.ReceiverView.ProjectedCenterOffsetHz), ...
                    sprintf('Source %d ReceiverView.ProjectedCenterOffsetHz is not a numeric scalar.', k));
                testCase.verifyTrue(islogical(src.ReceiverView.IsVisible) || ...
                    (isnumeric(src.ReceiverView.IsVisible) && isscalar(src.ReceiverView.IsVisible)), ...
                    sprintf('Source %d ReceiverView.IsVisible is not a logical/scalar.', k));
            end
        end

        function projectedCenterOffsetMatchesExecutionOffset(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                src = sources{k};
                rvOff = src.ReceiverView.ProjectedCenterOffsetHz;
                exeOff = src.Truth.Execution.CenterFrequencyOffsetHz;
                testCase.verifyEqual(rvOff, exeOff, 'AbsTol', 1e-6, ...
                    sprintf(['Source %d: ReceiverView.ProjectedCenterOffsetHz (%g) ', ...
                             'diverged from Truth.Execution.CenterFrequencyOffsetHz (%g) > 1 uHz; ', ...
                             'the v2 ReceiverView projection is not the source of truth.'], ...
                        k, rvOff, exeOff));
            end
        end

    end

end


function sources = runSmokeAndCollect(testCase)
    [annotationCell, ~] = runSmoke(testCase);
    sources = {};
    for r = 1:numel(annotationCell)
        rxAnno = annotationCell{r};
        if ~isstruct(rxAnno) || ~isfield(rxAnno, 'SignalSources') ...
                || isempty(rxAnno.SignalSources)
            continue;
        end
        ss = rxAnno.SignalSources;
        if iscell(ss)
            for k = 1:numel(ss)
                if isstruct(ss{k})
                    sources{end + 1} = ss{k}; %#ok<AGROW>
                end
            end
        elseif isstruct(ss)
            for k = 1:numel(ss)
                sources{end + 1} = ss(k); %#ok<AGROW>
            end
        end
    end
end


function [annotationCell, frameDataCell] = runSmoke(testCase)
    persistent CACHED_ANNOTATION CACHED_FRAMES
    if ~isempty(CACHED_ANNOTATION)
        annotationCell = CACHED_ANNOTATION;
        frameDataCell = CACHED_FRAMES;
        return;
    end

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'tests', 'regression'));

    csrd.utils.logger.GlobalLogManager.reset();
    csrd.utils.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase4_receiverview');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end
    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end

    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase4-RV', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.utils.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.utils.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260425, 'twister');

    fullRecipe = baseline_recipe_v0();
    cohort = fullRecipe.Cohorts(1);
    cohort.RxRange = [2, 2];

    masterCfg = csrd.utils.config_loader('csrd2025/csrd2025.m');
    sid = 1;
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260425 + sid;
    cfg.Runner.Toolbox.Level    = 'minimal';
    cfg.Runner.Log.Policy       = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
        sprintf('scenario_%06d', sid));
    cfg.Runner.Data.CompressData = false;

    cfg.Factories.Scenario.Global.NumFramesPerScenario = ...
        cohort.NumFramesPerScenario;
    cfg.Factories.Scenario.Global.ObservationDuration = ...
        cohort.ObservationDuration;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types  = cohort.MapTypes;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio  = cohort.MapRatio;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min ...
        = cohort.TxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max ...
        = cohort.TxRange(2);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min ...
        = cohort.RxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max ...
        = cohort.RxRange(2);

    if ~isfield(cfg.Factories.Scenario, 'CommunicationBehavior')
        cfg.Factories.Scenario.CommunicationBehavior = struct();
    end
    if ~isfield(cfg.Factories.Scenario.CommunicationBehavior, 'TemporalBehavior')
        cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior = struct();
    end
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = ...
        cohort.PatternTypes;
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = ...
        cohort.PatternDistribution;

    runner = csrd.SimulationRunner( ...
        'RunnerConfig', cfg.Runner, 'FactoryConfigs', cfg.Factories);
    setup(runner);
    step(runner, 1, 1);

    warnState = warning('off', 'MATLAB:structOnObject');
    cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
    s = struct(runner);
    outDir = s.actualOutputDirectory;
    annotationPath = fullfile(outDir, 'annotations', ...
        sprintf('scenario_%06d_annotation.json', sid));

    testCase.assertTrue(exist(annotationPath, 'file') == 2, ...
        sprintf('ReceiverView test: annotation not produced at %s.', annotationPath));

    raw = fileread(annotationPath);
    annotation = jsondecode(raw);
    annotationCell = walkForSignalSourceCarriers(annotation);
    frameDataCell = {};

    CACHED_ANNOTATION = annotationCell;
    CACHED_FRAMES = frameDataCell;
end


function out = walkForSignalSourceCarriers(node)
    out = {};
    if isempty(node)
        return;
    end
    if iscell(node)
        for k = 1:numel(node)
            out = [out, walkForSignalSourceCarriers(node{k})]; %#ok<AGROW>
        end
        return;
    end
    if isstruct(node)
        for k = 1:numel(node)
            entry = node(k);
            if isfield(entry, 'SignalSources') && ~isempty(entry.SignalSources)
                out{end + 1} = entry; %#ok<AGROW>
            end
            fns = fieldnames(entry);
            for f = 1:numel(fns)
                child = entry.(fns{f});
                if isstruct(child) || iscell(child)
                    out = [out, walkForSignalSourceCarriers(child)]; %#ok<AGROW>
                end
            end
        end
    end
end
