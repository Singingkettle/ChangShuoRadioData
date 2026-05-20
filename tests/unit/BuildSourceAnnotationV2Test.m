classdef BuildSourceAnnotationV2Test < matlab.unittest.TestCase
    %BUILDSOURCEANNOTATIONV2TEST Phase 4 §5 / S5 v2 schema contract.
    %
    %   Pin the v2 SignalSources schema produced by
    %   processReceiverProcessing/buildSourceAnnotation:
    %
    %     SignalSources(k) = struct( ...
    %         'TxID',         char, ...
    %         'SegmentId',    int|char, ...
    %         'BurstId',      int|char, ...
    %         'Truth',        struct('Design', .., 'Execution', .., 'Measured', ..), ...
    %         'RFImpairments',struct(...), ...
    %         'ReceiverView', struct(...));
    %
    %   The v1 top-level keys must NOT exist any more (decision A_full_replace):
    %     Realized / Planned / Temporal / Spatial / LinkBudget / Channel.
    %
    %   This test stands up an end-to-end smoke (1 Tx / 1 Rx) and asserts
    %   field-set equality on the resulting annotation, plus deep-checks
    %   the Truth.{Design,Execution,Measured.{SourcePlane,FramePlane}}
    %   sub-schemas.

    properties (Constant, Access = private)
        ExpectedTopFields = { ...
            'TxID', 'SegmentId', 'BurstId', 'Truth', ...
            'RFImpairments', 'ReceiverView'};

        ForbiddenV1TopFields = { ...
            'Realized', 'Planned', 'Temporal', 'Spatial', ...
            'LinkBudget', 'Channel'};

        ExpectedDesignFields = { ...
            'PlannedCenterFrequencyHz', 'PlannedBandwidthHz', ...
            'PlannedSampleRate', 'ModulationFamily', ...
            'ModulationOrder', 'PayloadLengthBits', ...
            'NumTransmitAntennas', 'Regulatory'};

        ExpectedExecutionFields = { ...
            'ModulatedBandwidthHz', 'CenterFrequencyOffsetHz', ...
            'SampleRate', 'StartTimeSec', 'EndTimeSec', 'DurationSec', ...
            'FrameStartSample', 'FrameEndSample', 'FrameSampleCount', ...
            'FrameLengthSamples', 'ChannelModel', 'PathLossDB', ...
            'AnalyticalSNRdB', 'AppliedSNRdB', 'DopplerShiftHz', ...
            'RadialVelocityMps', 'GeometrySnapshot'};

        ExpectedMeasuredFields = {'SourcePlane', 'FramePlane'};

        ExpectedSourcePlaneFields = { ...
            'OccupiedBandwidthHz', 'CenterFrequencyHz', 'SNRdB', ...
            'TimeOccupancy', 'FrequencyOccupancy', ...
            'MeasurementStatus', ...
            'MeasurementSemantics'};

        ExpectedFramePlaneFields = { ...
            'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
            'TimeOccupancy', 'FrequencyOccupancy', ...
            'MeasurementStatus', ...
            'MeasurementSemantics'};

        ExpectedGeometryFields = { ...
            'TxPositionM', 'TxVelocityMps', 'RxPositionM', ...
            'RxVelocityMps', 'LinkDistanceM'};
    end

    methods (TestClassSetup)
        function suppressMatlabStructWarning(testCase)
            ws = warning('off', 'MATLAB:structOnObject');
            testCase.addTeardown(@(s) warning(s), ws);
        end
    end

    methods (Test)

        function annotationCarriesV2TopLevelOnly(testCase)
            % End-to-end run: assert every SignalSource in the annotation
            % has exactly the v2 top-level field set and none of the v1
            % top-level keys.
            sources = runSmokeAndCollect(testCase);
            testCase.assertNotEmpty(sources, ...
                'V2 schema test: SignalSources cell was empty.');

            for k = 1:numel(sources)
                src = sources{k};
                fns = fieldnames(src);
                for f = 1:numel(testCase.ExpectedTopFields)
                    expected = testCase.ExpectedTopFields{f};
                    testCase.verifyTrue(any(strcmp(fns, expected)), ...
                        sprintf('Source %d missing v2 top-level field "%s".', ...
                            k, expected));
                end
                for f = 1:numel(testCase.ForbiddenV1TopFields)
                    forbidden = testCase.ForbiddenV1TopFields{f};
                    testCase.verifyFalse(any(strcmp(fns, forbidden)), ...
                        sprintf('Source %d carries forbidden v1 top-level field "%s" (decision A_full_replace).', ...
                            k, forbidden));
                end
            end
        end

        function truthDesignBlockComplete(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                src = sources{k};
                testCase.assertTrue(isstruct(src.Truth), ...
                    sprintf('Source %d Truth is not a struct.', k));
                testCase.assertTrue(isfield(src.Truth, 'Design'), ...
                    sprintf('Source %d Truth.Design missing.', k));
                fns = fieldnames(src.Truth.Design);
                for f = 1:numel(testCase.ExpectedDesignFields)
                    expected = testCase.ExpectedDesignFields{f};
                    testCase.verifyTrue(any(strcmp(fns, expected)), ...
                        sprintf('Source %d Truth.Design missing "%s".', ...
                            k, expected));
                end
                d = src.Truth.Design;
                testCase.verifyTrue(isnumeric(d.PlannedCenterFrequencyHz) && ...
                    isscalar(d.PlannedCenterFrequencyHz) && ...
                    isfinite(d.PlannedCenterFrequencyHz), ...
                    sprintf('Source %d PlannedCenterFrequencyHz is empty/non-finite.', k));
                testCase.verifyGreaterThan(d.PlannedBandwidthHz, 0, ...
                    sprintf('Source %d PlannedBandwidthHz must come from Blueprint.', k));
                testCase.verifyGreaterThan(d.PlannedSampleRate, 0, ...
                    sprintf('Source %d PlannedSampleRate must come from Blueprint.', k));
                testCase.verifyNotEmpty(char(d.ModulationFamily), ...
                    sprintf('Source %d ModulationFamily must come from Blueprint.', k));
                testCase.verifyGreaterThanOrEqual(d.ModulationOrder, 0, ...
                    sprintf('Source %d ModulationOrder must be populated.', k));
                testCase.verifyGreaterThanOrEqual(d.PayloadLengthBits, 0, ...
                    sprintf('Source %d PayloadLengthBits must be populated.', k));
                testCase.verifyGreaterThan(d.NumTransmitAntennas, 0, ...
                    sprintf('Source %d NumTransmitAntennas must be populated.', k));
            end
        end

        function truthExecutionBlockComplete(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                src = sources{k};
                testCase.assertTrue(isfield(src.Truth, 'Execution'), ...
                    sprintf('Source %d Truth.Execution missing.', k));
                fns = fieldnames(src.Truth.Execution);
                for f = 1:numel(testCase.ExpectedExecutionFields)
                    expected = testCase.ExpectedExecutionFields{f};
                    testCase.verifyTrue(any(strcmp(fns, expected)), ...
                        sprintf('Source %d Truth.Execution missing "%s".', ...
                            k, expected));
                end
                geom = src.Truth.Execution.GeometrySnapshot;
                testCase.assertTrue(isstruct(geom), ...
                    sprintf('Source %d Truth.Execution.GeometrySnapshot is not a struct.', k));
                gfns = fieldnames(geom);
                for f = 1:numel(testCase.ExpectedGeometryFields)
                    expected = testCase.ExpectedGeometryFields{f};
                    testCase.verifyTrue(any(strcmp(gfns, expected)), ...
                        sprintf('Source %d GeometrySnapshot missing "%s".', ...
                            k, expected));
                end
            end
        end

        function truthMeasuredBlockComplete(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                src = sources{k};
                testCase.assertTrue(isfield(src.Truth, 'Measured'), ...
                    sprintf('Source %d Truth.Measured missing.', k));
                m = src.Truth.Measured;
                fns = fieldnames(m);
                for f = 1:numel(testCase.ExpectedMeasuredFields)
                    expected = testCase.ExpectedMeasuredFields{f};
                    testCase.verifyTrue(any(strcmp(fns, expected)), ...
                        sprintf('Source %d Truth.Measured missing "%s".', ...
                            k, expected));
                end
                spfns = fieldnames(m.SourcePlane);
                for f = 1:numel(testCase.ExpectedSourcePlaneFields)
                    expected = testCase.ExpectedSourcePlaneFields{f};
                    testCase.verifyTrue(any(strcmp(spfns, expected)), ...
                        sprintf('Source %d SourcePlane missing "%s".', ...
                            k, expected));
                end
                fpfns = fieldnames(m.FramePlane);
                for f = 1:numel(testCase.ExpectedFramePlaneFields)
                    expected = testCase.ExpectedFramePlaneFields{f};
                    testCase.verifyTrue(any(strcmp(fpfns, expected)), ...
                        sprintf('Source %d FramePlane missing "%s".', ...
                            k, expected));
                end
                testCase.verifyEqual(m.SourcePlane.MeasurementSemantics, ...
                    'receiver_view_isolated');
                testCase.verifyEqual(m.FramePlane.MeasurementSemantics, ...
                    'post_rx_combined_pre_rfchain');
            end
        end

        function measuredFieldsHaveFinitePopulatedValuesForLiveSignals(testCase)
            % Live emitters with non-empty isolated signals should report
            % finite OccupiedBandwidthHz / CenterFrequencyHz / TimeOccupancy
            % on at least one source -- pure-NaN measurements would mean
            % the measurement helpers are not actually wired into the
            % builder.
            sources = runSmokeAndCollect(testCase);
            anyFiniteObw = false;
            anyFiniteCenter = false;
            anyFiniteToc = false;
            for k = 1:numel(sources)
                m = sources{k}.Truth.Measured;
                if isnumeric(m.SourcePlane.OccupiedBandwidthHz) && ...
                        isscalar(m.SourcePlane.OccupiedBandwidthHz) && ...
                        isfinite(m.SourcePlane.OccupiedBandwidthHz)
                    anyFiniteObw = true;
                end
                if isnumeric(m.SourcePlane.CenterFrequencyHz) && ...
                        isscalar(m.SourcePlane.CenterFrequencyHz) && ...
                        isfinite(m.SourcePlane.CenterFrequencyHz)
                    anyFiniteCenter = true;
                end
                if isnumeric(m.SourcePlane.TimeOccupancy) && ...
                        isscalar(m.SourcePlane.TimeOccupancy) && ...
                        isfinite(m.SourcePlane.TimeOccupancy)
                    anyFiniteToc = true;
                end
            end
            testCase.verifyTrue(anyFiniteObw, ...
                'No SignalSource published a finite SourcePlane.OccupiedBandwidthHz.');
            testCase.verifyTrue(anyFiniteCenter, ...
                'No SignalSource published a finite SourcePlane.CenterFrequencyHz.');
            testCase.verifyTrue(anyFiniteToc, ...
                'No SignalSource published a finite SourcePlane.TimeOccupancy.');
        end

        function executionTimesMatchSampleGrid(testCase)
            sources = runSmokeAndCollect(testCase);
            for k = 1:numel(sources)
                ex = sources{k}.Truth.Execution;
                testCase.verifyEqual(ex.StartTimeSec, ...
                    ex.FrameStartSample / ex.SampleRate, 'AbsTol', 1e-12);
                testCase.verifyEqual(ex.EndTimeSec, ...
                    ex.FrameEndSample / ex.SampleRate, 'AbsTol', 1e-12);
                testCase.verifyEqual(ex.DurationSec, ...
                    ex.FrameSampleCount / ex.SampleRate, 'AbsTol', 1e-12);
                testCase.verifyGreaterThanOrEqual(ex.FrameStartSample, 0);
                testCase.verifyLessThanOrEqual(ex.FrameEndSample, ...
                    ex.FrameLengthSamples);
            end
        end

        function framePlaneIsSharedAcrossSourcesPerReceiver(testCase)
            % Per Phase 4 §3.2 / §3.4 the FramePlane is computed once per
            % receiver from the combined waveform; every SignalSource on
            % the SAME receiver MUST publish the same FramePlane snapshot
            % (object identity not required, value equality is).
            [annotationCell, ~] = runSmoke(testCase);
            for r = 1:numel(annotationCell)
                rxAnno = annotationCell{r};
                if ~isstruct(rxAnno) || ~isfield(rxAnno, 'SignalSources') ...
                        || isempty(rxAnno.SignalSources)
                    continue;
                end
                ssRaw = rxAnno.SignalSources;
                ss = {};
                if iscell(ssRaw)
                    for k = 1:numel(ssRaw)
                        if isstruct(ssRaw{k}); ss{end+1} = ssRaw{k}; end %#ok<AGROW>
                    end
                else
                    for k = 1:numel(ssRaw)
                        ss{end + 1} = ssRaw(k); %#ok<AGROW>
                    end
                end
                if numel(ss) < 2
                    continue;
                end
                ref = ss{1}.Truth.Measured.FramePlane;
                for k = 2:numel(ss)
                    cur = ss{k}.Truth.Measured.FramePlane;
                    testCase.verifyEqual(cur.OccupiedBandwidthHz, ...
                        ref.OccupiedBandwidthHz, ...
                        sprintf('Receiver %d source %d FramePlane.OccupiedBandwidthHz drifted.', r, k));
                    testCase.verifyEqual(cur.CenterFrequencyHz, ...
                        ref.CenterFrequencyHz, ...
                        sprintf('Receiver %d source %d FramePlane.CenterFrequencyHz drifted.', r, k));
                    testCase.verifyEqual(cur.TimeOccupancy, ...
                        ref.TimeOccupancy, ...
                        sprintf('Receiver %d source %d FramePlane.TimeOccupancy drifted.', r, k));
                end
            end
        end

    end

end


% ------------------------------------------------------------------
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

    csrd.runtime.logger.GlobalLogManager.reset();
    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase4_v2_schema');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end
    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end

    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase4-V2', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.runtime.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260425, 'twister');

    fullRecipe = baseline_recipe_v0();
    cohort = fullRecipe.Cohorts(1);
    cohort.RxRange = [1, 1];

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    sid = 1;
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260425 + sid;
    cfg.Runner.Toolbox.Level    = 'minimal';
    cfg.Runner.Log.Policy       = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
        sprintf('scenario_%06d', sid));
    cfg.Runner.Data.CompressData = false;

    cfg = csrd.test_support.applyCanonicalFrameContract( ...
        cfg, cohort.ObservationDuration, cohort.NumFramesPerScenario);
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
    cfg = csrd.test_support.buildRuntimePlanForTest(cfg);

    runner = csrd.SimulationRunner( ...
        'RunnerConfig', cfg.Runner, ...
        'FactoryConfigs', cfg.Factories, ...
        'RuntimePlan', cfg.RuntimePlan);
    setup(runner);
    step(runner, 1, 1);

    warnState = warning('off', 'MATLAB:structOnObject');
    cleanup = onCleanup(@() warning(warnState));
    s = struct(runner);
    outDir = s.actualOutputDirectory;
    annotationPath = fullfile(outDir, 'annotations', ...
        sprintf('scenario_%06d_annotation.json', sid));

    testCase.assertTrue(exist(annotationPath, 'file') == 2, ...
        sprintf('V2 schema test: annotation file not produced at %s.', annotationPath));

    raw = fileread(annotationPath);
    annotation = jsondecode(raw);
    [annotationCell, frameDataCell] = locateFrameAnnotation(annotation);

    CACHED_ANNOTATION = annotationCell;
    CACHED_FRAMES = frameDataCell;
end


function [annotationCell, frameDataCell] = locateFrameAnnotation(annotation)
    % The annotation JSON puts each FrameAnnotation directly under
    % `annotation.Frames`. After ScenarioAnnotation =
    % cell(1,frames){cell(1,numRx){FrameAnnotation}} is sanitised then
    % jsondecode'd, the shape can be a scalar struct (1f x 1rx), a
    % struct array (1f x Nrx OR Nf x 1rx), or a cell array (Nf x Nrx).
    % Walk recursively to collect every leaf struct that carries a
    % `SignalSources` field -- that is the canonical anchor for a per-
    % receiver FrameAnnotation in the v2 schema.
    annotationCell = {};
    frameDataCell = {};
    if isempty(annotation)
        return;
    end
    annotationCell = walkForSignalSourceCarriers(annotation);
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
