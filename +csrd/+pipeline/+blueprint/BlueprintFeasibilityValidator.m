classdef BlueprintFeasibilityValidator < handle
    %BLUEPRINTFEASIBILITYVALIDATOR Phase 3 static-only feasibility validator.
    %
    % Runs all 20 in-process checks against a ScenarioBlueprint struct
    % (Phase 3 ReceiverViews-aware schema, see phase-3-construction.md §3.1.A)
    % and returns a structured ValidationReport (§16.7.2 / §3.3.2).
    %
    % The 21st check (`ChannelStateContinuity`) is a runtime invariant and
    % lives in tests/regression/test_channel_state_continuity.m, NOT here.
    %
    % Soft-import contract (§1.4 Q1=A): when an optional blueprint field
    % is missing, the corresponding check returns an empty failure
    % (skipped) rather than rejecting. Phase 3 keeps this for synthetic
    % unit-test blueprints, but introduces ReceiverViews-aware projection
    % reading for #3 (TxBwInsideRxWindow) and tightens #13's audit
    % message to use the canonical `ProjectedCenterOffsetHz` field name.
    %
    % Stub contract (§1.4 Q2=A): MeasurementCompleteness and
    % DopplerSelfConsistency only register their interface with
    % Severity='Skip'. Phase 4 flips them to 'Reject' once the
    % measurement / Doppler subsystems land.
    %
    % See also: csrd.pipeline.blueprint.computeBlueprintHash

    properties (Constant)
        ValidatorVersion = 'p4-measurement-doppler-v2'
    end

    methods (Static)

        function report = validate(blueprint)
            %VALIDATE Run all 20 checks; return ValidationReport struct.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            checkList = {
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkFrameSampleConsistency
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkRxFsEqualsObservableBw
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkModulationAntennaCompatible
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkRFImpairmentRange
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkBurstTotalDurationFits
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkCrossFrameSegmentMinSamples
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkOsmFileExistsAndBuildings
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkChannelModelInRegistry
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkTrajectoryMonotonicAndCovers
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkLinkDistanceAboveMin
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkMemoryBudget
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkReceiverViewProjectionPresent
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkBurstOverlapsFrameExpansion
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkMeasurementPlanesSeparated
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkGeometryGranularityDeclared
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkReceiverOutputWindowConsistent
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkMeasurementCompleteness
                @csrd.pipeline.blueprint.BlueprintFeasibilityValidator.checkDopplerSelfConsistency
            };

            failures = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailureArray();
            for k = 1:numel(checkList)
                f = checkList{k}(blueprint);
                if ~isempty(f)
                    failures(end+1) = f; %#ok<AGROW>
                end
            end

            isReject = arrayfun(@(s) strcmp(s.Severity, 'Reject'), failures);
            isWarn   = arrayfun(@(s) strcmp(s.Severity, 'Warn'),   failures);
            rejects  = failures(isReject);
            warns    = failures(isWarn);

            report = struct( ...
                'IsFeasible',      isempty(rejects), ...
                'BlueprintHash',   csrd.pipeline.blueprint.computeBlueprintHash(blueprint), ...
                'NumChecksRun',    numel(checkList), ...
                'NumChecksPassed', numel(checkList) - numel(failures), ...
                'NumChecksFailed', numel(failures), ...
                'FailedChecks',    rejects, ...
                'WarnChecks',      warns, ...
                'Provenance',      struct( ...
                    'ValidatorVersion', csrd.pipeline.blueprint.BlueprintFeasibilityValidator.ValidatorVersion, ...
                    'Timestamp',        char(datetime('now', 'TimeZone', 'UTC', ...
                        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')) ));
        end

        % =================================================================
        % §4.bis B - 12 checks
        % =================================================================

        function failure = checkFrameSampleConsistency(blueprint)
            % checkFrameSampleConsistency - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            global_ = getOrEmpty(blueprint, 'Global');
            rx      = getReceivers(blueprint);
            if isempty(global_) || isempty(rx)
                return; % skip
            end
            if ~isfield(global_, 'FrameDuration') || ~isfield(global_, 'FrameNumSamples')
                return;
            end
            frameDuration   = global_.FrameDuration;
            frameNumSamples = global_.FrameNumSamples;
            for i = 1:numel(rx)
                cur = rx{i};
                if ~isfield(cur, 'SampleRate'); continue; end
                expected = frameDuration * cur.SampleRate;
                if abs(expected - frameNumSamples) > 1
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'FrameSampleConsistency', 'Reject', ...
                        sprintf(['Receiver %d: FrameDuration*SampleRate=%g but ', ...
                                 'FrameNumSamples=%g (diff > 1 sample).'], ...
                                 i, expected, frameNumSamples), ...
                        'Adjust FrameDuration / SampleRate / FrameNumSamples to be exact integer-aligned.', ...
                        sprintf('Receivers(%d)', i));
                    return;
                end
            end
        end

        function failure = checkRxFsEqualsObservableBw(blueprint)
            % checkRxFsEqualsObservableBw - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            rx = getReceivers(blueprint);
            for i = 1:numel(rx)
                cur = rx{i};
                if ~isfield(cur, 'SampleRate') || ~isfield(cur, 'ObservableBandwidth')
                    continue;
                end
                if isempty(cur.ObservableBandwidth)
                    continue;
                end
                if abs(cur.SampleRate - cur.ObservableBandwidth) > 1
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'RxFsEqualsObservableBw', 'Reject', ...
                        sprintf(['Receiver %d: SampleRate=%g != ObservableBandwidth=%g (equivalent ', ...
                                 'baseband contract violated, §6).'], ...
                                 i, cur.SampleRate, cur.ObservableBandwidth), ...
                        'Set ObservableBandwidth equal to SampleRate.', ...
                        sprintf('Receivers(%d).ObservableBandwidth', i));
                    return;
                end
            end
        end

        function failure = checkTxBwInsideRxWindow(blueprint)
            % Phase 3: prefers tx.ReceiverViews(r).ProjectedCenterOffsetHz
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % when present (per-pair projection); falls back to
            % tx.Spectrum.PlannedFreqOffset for synthetic blueprints
            % without explicit ReceiverViews (single-Rx tests).
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            rx = getReceivers(blueprint);
            if isempty(tx) || isempty(rx)
                return;
            end
            for r = 1:numel(rx)
                rxc = rx{r};
                if ~isfield(rxc, 'ObservableBandwidth') || isempty(rxc.ObservableBandwidth)
                    continue;
                end
                halfRxWin = rxc.ObservableBandwidth / 2;
                for t = 1:numel(tx)
                    txc = tx{t};
                    [centerOff, halfBw, source] = extractTxOffsetAndHalfBw(txc, rxc, r);
                    if isempty(centerOff) || isempty(halfBw)
                        continue;
                    end
                    if abs(centerOff) + halfBw > halfRxWin + 1
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'TxBwInsideRxWindow', 'Reject', ...
                            sprintf(['Tx %d projected onto Rx %d (%s) at offset=%.0f Hz with ', ...
                                     'halfBW=%.0f Hz exceeds Rx observable half-window %.0f Hz.'], ...
                                     t, r, source, centerOff, halfBw, halfRxWin), ...
                            'Reduce PlannedBandwidth or shift ProjectedCenterOffsetHz, or pick a wider Rx.', ...
                            sprintf('Emitters(%d).ReceiverViews(%d).ProjectedCenterOffsetHz', t, r));
                        return;
                    end
                end
            end
        end

        function failure = checkModulationAntennaCompatible(blueprint)
            % checkModulationAntennaCompatible - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            if isempty(tx)
                return;
            end
            try
                matrixProfile = csrd.catalog.profile.profileLoader('antennaCompat', ...
                    'AntennaModulationMatrix');
            catch
                return; % loader unavailable -> skip (test-only path)
            end
            for t = 1:numel(tx)
                txc = tx{t};
                family   = extractModulationFamily(txc);
                numAnt   = extractNumTxAntennas(txc);
                if isempty(family) || isempty(numAnt)
                    continue;
                end
                if ~isKey(matrixProfile.Matrix, family)
                    continue; % family not in matrix -> skip
                end
                row = matrixProfile.Matrix(family);
                bins = matrixProfile.AntennaBins;
                idx = find(bins == numAnt, 1);
                if isempty(idx)
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'ModulationAntennaCompatible', 'Reject', ...
                        sprintf('Tx %d: NumAntennas=%d not in matrix bins [%s].', ...
                            t, numAnt, num2str(bins)), ...
                        'Use one of the supported antenna counts.', ...
                        sprintf('Emitters(%d).Hardware.NumAntennas', t));
                    return;
                end
                state = row{idx};
                if strcmp(state, 'Forbidden')
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'ModulationAntennaCompatible', 'Reject', ...
                        sprintf('Tx %d: %s @ %d-Tx is Forbidden.', t, family, numAnt), ...
                        'Pick a different modulation family or antenna count.', ...
                        sprintf('Emitters(%d).Modulation.Family', t));
                    return;
                end
                if strcmp(state, 'Conditional')
                    if ~conditionalAntennaConstraintSatisfied(family, numAnt, txc, matrixProfile)
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'ModulationAntennaCompatible', 'Reject', ...
                            sprintf('Tx %d: %s @ %d-Tx is Conditional and the side-condition is not met.', ...
                                t, family, numAnt), ...
                            'Check antennaCompat.Conditions for required side-constraint.', ...
                            sprintf('Emitters(%d).Modulation.Family', t));
                        return;
                    end
                end
            end
        end

        function failure = checkRFImpairmentRange(blueprint)
            % checkRFImpairmentRange - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            for t = 1:numel(tx)
                txc = tx{t};
                if ~isfield(txc, 'RFImpairment')
                    continue;
                end
                rfi = txc.RFImpairment;
                if isfield(rfi, 'IIP3Dbm')
                    v = rfi.IIP3Dbm;
                    if isnumeric(v) && isscalar(v) && (v < -10 || v > 40)
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'RFImpairmentRange', 'Reject', ...
                            sprintf('Tx %d: IIP3=%.2f dBm outside [-10, 40].', t, v), ...
                            'Clamp IIP3Dbm to within [-10, 40].', ...
                            sprintf('Emitters(%d).RFImpairment.IIP3Dbm', t));
                        return;
                    end
                end
                if isfield(rfi, 'PhaseNoiseLevel')
                    lvl = rfi.PhaseNoiseLevel;
                    if ~ismember(lvl, {'Low','Mid','High'})
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'RFImpairmentRange', 'Reject', ...
                            sprintf('Tx %d: PhaseNoiseLevel=''%s'' not in {Low,Mid,High}.', t, lvl), ...
                            'Pick one of the registered PhaseNoise profiles.', ...
                            sprintf('Emitters(%d).RFImpairment.PhaseNoiseLevel', t));
                        return;
                    end
                end
                if isfield(rfi, 'IQImbalanceDb')
                    v = rfi.IQImbalanceDb;
                    if isnumeric(v) && isscalar(v) && (v < 0 || v > 3)
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'RFImpairmentRange', 'Reject', ...
                            sprintf('Tx %d: IQImbalanceDb=%.2f dB outside [0, 3].', t, v), ...
                            'Clamp IQImbalanceDb to within [0, 3].', ...
                            sprintf('Emitters(%d).RFImpairment.IQImbalanceDb', t));
                        return;
                    end
                end
            end
        end

        function failure = checkBurstTotalDurationFits(blueprint)
            % checkBurstTotalDurationFits - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            global_ = getOrEmpty(blueprint, 'Global');
            tx      = getEmitters(blueprint);
            if isempty(global_) || isempty(tx)
                return;
            end
            if ~isfield(global_, 'NumFrames') || ~isfield(global_, 'FrameDuration')
                return;
            end
            scenarioDuration = global_.NumFrames * global_.FrameDuration;
            for t = 1:numel(tx)
                txc = tx{t};
                bursts = extractBurstList(txc);
                if isempty(bursts)
                    continue;
                end
                totalDuration = 0;
                for b = 1:numel(bursts)
                    bd = getOrEmpty(bursts(b), 'Duration');
                    if ~isempty(bd) && isnumeric(bd)
                        totalDuration = totalDuration + bd;
                    end
                    et = getOrEmpty(bursts(b), 'EndTime');
                    if ~isempty(et) && isnumeric(et) && et > scenarioDuration + eps
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'BurstTotalDurationFits', 'Reject', ...
                            sprintf('Tx %d burst %d EndTime=%.3fs > scenario duration %.3fs.', ...
                                t, b, et, scenarioDuration), ...
                            'Move burst inside the scenario window or extend NumFrames.', ...
                            sprintf('Emitters(%d).BurstSchedule.Bursts(%d).EndTime', t, b));
                        return;
                    end
                end
                if totalDuration > scenarioDuration + eps
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'BurstTotalDurationFits', 'Reject', ...
                        sprintf('Tx %d: total burst duration %.3fs > scenario duration %.3fs.', ...
                            t, totalDuration, scenarioDuration), ...
                        'Reduce burst durations or extend NumFrames.', ...
                        sprintf('Emitters(%d).BurstSchedule.Bursts', t));
                    return;
                end
            end
        end

        function failure = checkCrossFrameSegmentMinSamples(blueprint)
            % checkCrossFrameSegmentMinSamples - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            for t = 1:numel(tx)
                txc = tx{t};
                if ~isfield(txc, 'PrecomputedSegments')
                    continue;
                end
                segs = txc.PrecomputedSegments;
                for s = 1:numel(segs)
                    seg = segs(s);
                    n = getOrEmpty(seg, 'VisibleSamples');
                    if ~isempty(n) && isnumeric(n) && n < 64
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'CrossFrameSegmentMinSamples', 'Reject', ...
                            sprintf('Tx %d segment %d: visibleSamples=%d < 64.', t, s, n), ...
                            'Increase segment duration or merge adjacent segments.', ...
                            sprintf('Emitters(%d).PrecomputedSegments(%d).VisibleSamples', t, s));
                        return;
                    end
                end
            end
        end

        function failure = checkOsmFileExistsAndBuildings(blueprint)
            % checkOsmFileExistsAndBuildings - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            cp = getOrEmpty(blueprint, 'ChannelPreference');
            if isempty(cp) || ~isfield(cp, 'Model')
                return;
            end
            if ~strcmp(cp.Model, 'RayTracing')
                return;
            end
            osmFile = getOrEmpty(cp, 'OSMFile');
            if isempty(osmFile) || ~ischar(osmFile)
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'OsmFileExistsAndBuildings', 'Reject', ...
                    'ChannelPreference.Model=RayTracing requires OSMFile path.', ...
                    'Provide ChannelPreference.OSMFile.', 'ChannelPreference.OSMFile');
                return;
            end
            if ~isfile(osmFile)
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'OsmFileExistsAndBuildings', 'Reject', ...
                    sprintf('OSM file not found: %s.', osmFile), ...
                    'Verify OSM file path or pick another scene.', 'ChannelPreference.OSMFile');
                return;
            end
            hasBuildings = getOrEmpty(cp, 'HasBuildings');
            terrainFb    = getOrEmpty(cp, 'TerrainFallback');
            if ~isempty(hasBuildings) && ~hasBuildings && ~strcmp(terrainFb, 'FlatTerrain')
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'OsmFileExistsAndBuildings', 'Reject', ...
                    sprintf('OSM file %s has no buildings; must declare TerrainFallback=FlatTerrain.', osmFile), ...
                    'Set ChannelPreference.TerrainFallback=''FlatTerrain'' or pick another OSM scene.', ...
                    'ChannelPreference.TerrainFallback');
                return;
            end
        end

        function failure = checkChannelModelInRegistry(blueprint)
            % checkChannelModelInRegistry - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            cp = getOrEmpty(blueprint, 'ChannelPreference');
            if isempty(cp) || ~isfield(cp, 'Model')
                return;
            end
            registry = getOrEmpty(blueprint, 'ChannelModelRegistry');
            if isempty(registry) || ~iscell(registry)
                return;
            end
            if ~any(strcmp(registry, cp.Model))
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'ChannelModelInRegistry', 'Reject', ...
                    sprintf('ChannelPreference.Model=''%s'' not in registry [%s].', ...
                        cp.Model, strjoin(registry, ', ')), ...
                    'Use a registered channel model or install the missing addon.', ...
                    'ChannelPreference.Model');
                return;
            end
        end

        function failure = checkTrajectoryMonotonicAndCovers(blueprint)
            % checkTrajectoryMonotonicAndCovers - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            global_ = getOrEmpty(blueprint, 'Global');
            entities = getEntitiesAll(blueprint);
            if isempty(global_) || ~isfield(global_, 'NumFrames') || ~isfield(global_, 'FrameDuration')
                return;
            end
            scenarioDuration = global_.NumFrames * global_.FrameDuration;
            for k = 1:numel(entities)
                ent = entities{k};
                traj = getOrEmpty(ent, 'Trajectory');
                if isempty(traj)
                    continue;
                end
                t_ = getOrEmpty(traj, 'SampleTimes');
                if isempty(t_) || ~isnumeric(t_) || numel(t_) < 2
                    continue;
                end
                if any(diff(t_) <= 0)
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'TrajectoryMonotonicAndCovers', 'Reject', ...
                        sprintf('Entity %d trajectory SampleTimes not strictly increasing.', k), ...
                        'Re-sample trajectory with strictly increasing timestamps.', ...
                        sprintf('Entities(%d).Trajectory.SampleTimes', k));
                    return;
                end
                if min(t_) > 0 + eps || max(t_) < scenarioDuration - eps
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'TrajectoryMonotonicAndCovers', 'Reject', ...
                        sprintf('Entity %d trajectory range [%.3f, %.3f] does not cover [0, %.3f].', ...
                            k, min(t_), max(t_), scenarioDuration), ...
                        'Extend trajectory to cover the full scenario duration.', ...
                        sprintf('Entities(%d).Trajectory.SampleTimes', k));
                    return;
                end
            end
        end

        function failure = checkLinkDistanceAboveMin(blueprint)
            % checkLinkDistanceAboveMin - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            rx = getReceivers(blueprint);
            if isempty(tx) || isempty(rx)
                return;
            end
            minDist = 1.0;
            v = getOrEmpty(blueprint, 'Validator');
            if isstruct(v) && isfield(v, 'MinDistanceMeters') && isnumeric(v.MinDistanceMeters)
                minDist = v.MinDistanceMeters;
            end
            for t = 1:numel(tx)
                txPos = extractEntityPosition(tx{t});
                if isempty(txPos), continue; end
                for r = 1:numel(rx)
                    rxPos = extractEntityPosition(rx{r});
                    if isempty(rxPos), continue; end
                    d = norm(txPos - rxPos);
                    if d < minDist
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'LinkDistanceAboveMin', 'Reject', ...
                            sprintf('Tx %d <-> Rx %d distance %.3f m < %.3f m.', t, r, d, minDist), ...
                            'Re-place entities so that pair-wise distance >= MinDistanceMeters.', ...
                            sprintf('Emitters(%d).Position', t));
                        return;
                    end
                end
            end
        end

        function failure = checkMemoryBudget(blueprint)
            % checkMemoryBudget - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            global_ = getOrEmpty(blueprint, 'Global');
            rx      = getReceivers(blueprint);
            if isempty(global_) || isempty(rx)
                return;
            end
            if ~isfield(global_, 'NumFrames') || ~isfield(global_, 'FrameNumSamples')
                return;
            end
            budgetMB = 4096;
            v = getOrEmpty(blueprint, 'Validator');
            if isstruct(v) && isfield(v, 'MemoryBudgetMB') && isnumeric(v.MemoryBudgetMB)
                budgetMB = v.MemoryBudgetMB;
            end
            budgetBytes = budgetMB * 1024 * 1024;
            for r = 1:numel(rx)
                cur = rx{r};
                numAnt = extractNumRxAntennas(cur);
                if isempty(numAnt), numAnt = 1; end
                bytes = global_.NumFrames * global_.FrameNumSamples * numAnt * 16;
                if bytes > budgetBytes
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'MemoryBudget', 'Reject', ...
                        sprintf(['Rx %d: estimated memory %.1f MB exceeds budget %.1f MB ', ...
                                 '(NumFrames=%d * FrameNumSamples=%d * NumAnt=%d * 16 B).'], ...
                                 r, bytes/1024/1024, budgetMB, ...
                                 global_.NumFrames, global_.FrameNumSamples, numAnt), ...
                        'Reduce NumFrames / FrameNumSamples / NumAntennas, or raise MemoryBudgetMB.', ...
                        sprintf('Receivers(%d).Hardware.NumAntennas', r));
                    return;
                end
            end
        end

        % =================================================================
        % §4.ter - 5 checks
        % =================================================================

        function failure = checkReceiverViewProjectionPresent(blueprint)
            % checkReceiverViewProjectionPresent - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            rx = getReceivers(blueprint);
            if numel(rx) <= 1 || isempty(tx)
                return; % single-receiver scenarios trivially satisfy
            end
            for t = 1:numel(tx)
                txc = tx{t};
                rvs = getOrEmpty(txc, 'ReceiverViews');
                if isempty(rvs)
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'ReceiverViewProjectionPresent', 'Reject', ...
                        sprintf(['Tx %d has no ReceiverViews despite scenario containing ', ...
                                 '%d receivers (multi-Rx scenarios must not fall back to a ', ...
                                 'single global PlannedFreqOffset; populate per-Rx ', ...
                                 'ProjectedCenterOffsetHz).'], t, numel(rx)), ...
                        'Project Tx onto every visible Receiver explicitly.', ...
                        sprintf('Emitters(%d).ReceiverViews', t));
                    return;
                end
            end
        end

        function failure = checkBurstOverlapsFrameExpansion(blueprint)
            % checkBurstOverlapsFrameExpansion - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            for t = 1:numel(tx)
                txc = tx{t};
                bursts = extractBurstList(txc);
                if isempty(bursts)
                    continue;
                end
                for b = 1:numel(bursts)
                    overlapping = getOrEmpty(bursts(b), 'OverlappingFramesIds');
                    expanded    = getOrEmpty(bursts(b), 'ExpandedSegments');
                    if isempty(overlapping) || isempty(expanded)
                        continue;
                    end
                    if numel(overlapping) ~= numel(expanded)
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'BurstOverlapsFrameExpansion', 'Reject', ...
                            sprintf(['Tx %d burst %d: %d overlapping frames but %d expanded ', ...
                                     'segments (must be 1:1).'], ...
                                     t, b, numel(overlapping), numel(expanded)), ...
                            'Expand a segment for every overlapping frame.', ...
                            sprintf('Emitters(%d).BurstSchedule.Bursts(%d)', t, b));
                        return;
                    end
                end
            end
        end

        function failure = checkMeasurementPlanesSeparated(blueprint)
            % checkMeasurementPlanesSeparated - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            mp = getOrEmpty(blueprint, 'MeasurementPolicy');
            if isempty(mp)
                return;
            end
            visiblePerRx = getOrEmpty(mp, 'MaxVisibleSourcesPerFrame');
            if isempty(visiblePerRx) || visiblePerRx <= 1
                return;
            end
            allowAggregateOnly = getOrEmpty(mp, 'AggregateOnly');
            if ~isempty(allowAggregateOnly) && allowAggregateOnly
                return;
            end
            planes = getOrEmpty(mp, 'Planes');
            if isempty(planes) || ~iscell(planes) || ...
                    ~any(strcmp(planes, 'SourcePlane')) || ...
                    ~any(strcmp(planes, 'FramePlane'))
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'MeasurementPlanesSeparated', 'Reject', ...
                    sprintf(['MeasurementPolicy.MaxVisibleSourcesPerFrame=%d but ', ...
                             'Planes does not contain both SourcePlane and FramePlane.'], visiblePerRx), ...
                    'Add both SourcePlane and FramePlane to MeasurementPolicy.Planes, or set AggregateOnly=true.', ...
                    'MeasurementPolicy.Planes');
                return;
            end
        end

        function failure = checkGeometryGranularityDeclared(blueprint)
            % checkGeometryGranularityDeclared - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            ann = getOrEmpty(blueprint, 'AnnotationPolicy');
            if isempty(ann) || ~isfield(ann, 'GeometryGranularity')
                return;
            end
            g = ann.GeometryGranularity;
            if ~ischar(g) || ~ismember(g, {'Frame', 'SegmentMidpoint'})
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'GeometryGranularityDeclared', 'Reject', ...
                    sprintf('AnnotationPolicy.GeometryGranularity=''%s'' invalid.', char(string(g))), ...
                    'Use ''Frame'' or ''SegmentMidpoint''.', ...
                    'AnnotationPolicy.GeometryGranularity');
                return;
            end
        end

        function failure = checkReceiverOutputWindowConsistent(blueprint)
            % checkReceiverOutputWindowConsistent - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            global_ = getOrEmpty(blueprint, 'Global');
            output  = getOrEmpty(blueprint, 'OutputPolicy');
            if isempty(global_) || isempty(output)
                return;
            end
            if ~isfield(output, 'OutputWindowPolicy') || ~strcmp(output.OutputWindowPolicy, 'ExactFrameClip')
                return;
            end
            if ~isfield(output, 'OutputLengthSamples') || ~isfield(global_, 'FrameNumSamples')
                return;
            end
            if output.OutputLengthSamples ~= global_.FrameNumSamples
                failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                    'ReceiverOutputWindowConsistent', 'Reject', ...
                    sprintf(['OutputPolicy.OutputWindowPolicy=ExactFrameClip but ', ...
                             'OutputLengthSamples=%d != FrameNumSamples=%d.'], ...
                             output.OutputLengthSamples, global_.FrameNumSamples), ...
                    'Set OutputLengthSamples to FrameNumSamples or change OutputWindowPolicy.', ...
                    'OutputPolicy.OutputLengthSamples');
                return;
            end
        end

        % =================================================================
        % §16.7.1 - 3 checks (real + 2 stubs; ChannelStateContinuity is a
        % regression test not a Validator method)
        % =================================================================

        function failure = checkOverlapAnnotationConsistent(blueprint)
            % Phase 4 (audit §3.6.C / P4-followup-5):
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %   Two-rail check that BurstSchedule's burst-level overlap
            %   annotation is consistent with the FrameExecutionPlan
            %   ground truth. Two annotations exist in the wild:
            %
            %     1. legacy explicit `OverlappingFramesIds(b)` per burst:
            %        must equal the set of FrameId values in the
            %        FrameExecutionPlan.Segments where BurstIndex==b.
            %        Implemented since Phase 2 (audit §16.7.1).
            %
            %     2. Phase 1 H3 implicit `ActiveIntervalIndices` per
            %        FrameExecutionPlan.Segments(s): the *count of
            %        unique* indices across all segments must equal
            %        `numel(BurstSchedule.Bursts)`. A drift here means
            %        a burst was authored without ever being scheduled
            %        (or vice versa) and the resulting annotation will
            %        mis-attribute symbols to the wrong burst.
            %
            %   Phase 4 elevates rail #2 from stub to Reject so the
            %   schedule -> burst correspondence is enforced before any
            %   measurement runs.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            for t = 1:numel(tx)
                txc = tx{t};
                bursts = extractBurstList(txc);
                fep    = getOrEmpty(txc, 'FrameExecutionPlan');
                if isempty(bursts) || isempty(fep)
                    continue;
                end

                % Rail #1 (legacy OverlappingFramesIds <-> FEP)
                for b = 1:numel(bursts)
                    declared = getOrEmpty(bursts(b), 'OverlappingFramesIds');
                    if isempty(declared)
                        continue;
                    end
                    actual = collectFramesForBurst(fep, b);
                    if isempty(actual)
                        continue;
                    end
                    if ~isequal(sort(declared(:)), sort(actual(:)))
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'OverlapAnnotationConsistent', 'Reject', ...
                            sprintf(['Tx %d burst %d: declared OverlappingFramesIds [%s] does not ', ...
                                     'match FrameExecutionPlan-derived [%s].'], ...
                                     t, b, num2str(declared(:)'), num2str(actual(:)')), ...
                            'Re-derive OverlappingFramesIds from FrameExecutionPlan.', ...
                            sprintf('Emitters(%d).BurstSchedule.Bursts(%d).OverlappingFramesIds', t, b));
                        return;
                    end
                end

                % Rail #2 (Phase 4: ActiveIntervalIndices cardinality)
                indices = collectActiveIntervalIndices(fep);
                if ~isempty(indices)
                    uniqueCount = numel(unique(indices));
                    if uniqueCount ~= numel(bursts)
                        failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                            'OverlapAnnotationConsistent', 'Reject', ...
                            sprintf(['Tx %d: FrameExecutionPlan declares %d distinct ', ...
                                     'ActiveIntervalIndices but BurstSchedule has ', ...
                                     '%d bursts (audit §3.6.C / P4-followup-5).'], ...
                                     t, uniqueCount, numel(bursts)), ...
                            'Align BurstSchedule.Bursts with FrameExecutionPlan ActiveIntervalIndices.', ...
                            sprintf('Emitters(%d).FrameExecutionPlan.Segments', t));
                        return;
                    end
                end
            end
        end

        function failure = checkMeasurementCompleteness(~) %#ok<INUSD>
            % Phase 4 (audit §3.6.A): blueprint-phase NoOp.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % The measurement-completeness contract is enforced post-
            % execution at annotation write-back time by the
            % `csrd.core.ChangShuo.validateMeasurementCompleteness`
            % static helper, which `SimulationRunner.saveScenarioData`
            % invokes after `sanitizeForJson`. Doing it there (and not
            % here) avoids the chicken-and-egg of asking the validator
            % to predict future measurement output: it can only see the
            % MeasurementPolicy declaration, which Phase 2's
            % `checkMeasurementPlanesSeparated` already enforces.
            %
            % Audit decision: keep the Validator stub registered (so
            % `validate()` reports it ran) but always PASS at blueprint
            % phase. Reject lives in the write-back hook.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
        end

        function failure = checkDopplerSelfConsistency(blueprint)
            % Phase 4 (audit §3.6.B):
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %   Predictive blueprint-phase check. When any Emitter
            %   declares `Mobility.MaxSpeedMps > 0` (or any of the
            %   legacy aliases TopSpeed / MaxSpeed) the blueprint MUST
            %   also declare `MeasurementPolicy.RequireDopplerShiftHz`
            %   = true so the runtime annotation is contractually
            %   obliged to publish `Truth.Execution.DopplerShiftHz`.
            %   Otherwise we would silently produce high-velocity
            %   scenarios with no way for downstream consumers to
            %   verify Doppler self-consistency.
            failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailure();
            tx = getEmitters(blueprint);
            mp = getOrEmpty(blueprint, 'MeasurementPolicy');
            requireDoppler = false;
            if isstruct(mp) && isfield(mp, 'RequireDopplerShiftHz') ...
                    && ~isempty(mp.RequireDopplerShiftHz) ...
                    && islogical(mp.RequireDopplerShiftHz)
                requireDoppler = mp.RequireDopplerShiftHz;
            end
            for t = 1:numel(tx)
                speed = extractEntityMaxSpeed(tx{t});
                if isempty(speed) || ~isnumeric(speed)
                    continue;
                end
                if speed > 0 && ~requireDoppler
                    failure = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.makeFailure( ...
                        'DopplerSelfConsistency', 'Reject', ...
                        sprintf(['Tx %d declares MaxSpeedMps=%.2f m/s but ', ...
                                 'MeasurementPolicy.RequireDopplerShiftHz is ', ...
                                 'not true; high-velocity scenarios MUST ', ...
                                 'publish Truth.Execution.DopplerShiftHz so ', ...
                                 'downstream consumers can verify ', ...
                                 'self-consistency (audit §3.6.B).'], ...
                                 t, speed), ...
                        'Set MeasurementPolicy.RequireDopplerShiftHz=true.', ...
                        'MeasurementPolicy.RequireDopplerShiftHz');
                    return;
                end
            end
        end

        % =================================================================
        % Internal helpers (public so tests can verify shape)
        % =================================================================

        function f = emptyFailure()
            % emptyFailure - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            f = repmat( ...
                struct('Code', '', 'Severity', '', 'Message', '', 'Hint', '', 'Field', ''), ...
                0, 1);
        end

        function arr = emptyFailureArray()
            % emptyFailureArray - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            arr = repmat( ...
                struct('Code', '', 'Severity', '', 'Message', '', 'Hint', '', 'Field', ''), ...
                0, 1);
        end

        function f = makeFailure(code, severity, message, hint, field)
            % makeFailure - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            f = struct( ...
                'Code',     char(code), ...
                'Severity', char(severity), ...
                'Message',  char(message), ...
                'Hint',     char(hint), ...
                'Field',    char(field));
        end

    end
end


% =====================================================================
% File-private helpers (not part of the class API)
% =====================================================================

function v = getOrEmpty(s, fname)
    % getOrEmpty - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fname)
        v = s.(fname);
    else
        v = [];
    end
end

function items = getReceivers(blueprint)
    % getReceivers - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    items = wrapAsCell(getOrEmpty(blueprint, 'Receivers'));
end

function items = getEmitters(blueprint)
    % getEmitters - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    items = wrapAsCell(getOrEmpty(blueprint, 'Emitters'));
end

function items = getEntitiesAll(blueprint)
    % getEntitiesAll - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    e = wrapAsCell(getOrEmpty(blueprint, 'Emitters'));
    r = wrapAsCell(getOrEmpty(blueprint, 'Receivers'));
    items = [e, r];
end

function c = wrapAsCell(value)
    % wrapAsCell - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isempty(value)
        c = {};
    elseif iscell(value)
        c = value(:)';
    elseif isstruct(value)
        c = arrayfun(@(i) value(i), 1:numel(value), 'UniformOutput', false);
    else
        c = {};
    end
end

function [centerOff, halfBw, source] = extractTxOffsetAndHalfBw(txc, rxc, rxIdx)
    % Phase 3: prefers ReceiverView-aware projection over the legacy
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    % emitter-global Spectrum.PlannedFreqOffset.
    %   source -- 'ReceiverView' when ProjectedCenterOffsetHz is read
    %             from txc.ReceiverViews; 'SpectrumLegacy' when the
    %             legacy emitter-global PlannedFreqOffset is used.
    centerOff = [];
    halfBw    = [];
    source    = '';
    sp = getOrEmpty(txc, 'Spectrum');
    bw = getOrEmpty(sp, 'PlannedBandwidth');
    if isempty(bw) || ~isnumeric(bw)
        return;
    end
    halfBw = bw / 2;
    rv = findReceiverView(txc, rxc, rxIdx);
    if ~isempty(rv)
        pco = getOrEmpty(rv, 'ProjectedCenterOffsetHz');
        if ~isempty(pco) && isnumeric(pco)
            centerOff = pco;
            source    = 'ReceiverView';
            return;
        end
    end
    foff = getOrEmpty(sp, 'PlannedFreqOffset');
    if ~isempty(foff) && isnumeric(foff)
        centerOff = foff;
    else
        centerOff = 0;
    end
    source = 'SpectrumLegacy';
end

function rv = findReceiverView(txc, rxc, rxIdx)
    % findReceiverView - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    rv = [];
    rvs = getOrEmpty(txc, 'ReceiverViews');
    if isempty(rvs)
        return;
    end
    if isstruct(rvs)
        rvList = arrayfun(@(i) rvs(i), 1:numel(rvs), 'UniformOutput', false);
    elseif iscell(rvs)
        rvList = rvs(:)';
    else
        return;
    end
    targetId = '';
    if isstruct(rxc) && isfield(rxc, 'EntityID') && ischar(rxc.EntityID)
        targetId = rxc.EntityID;
    end
    if ~isempty(targetId)
        for k = 1:numel(rvList)
            cur = rvList{k};
            if isstruct(cur) && isfield(cur, 'ReceiverId') && ischar(cur.ReceiverId) ...
                    && strcmp(cur.ReceiverId, targetId)
                rv = cur;
                return;
            end
        end
    end
    if rxIdx >= 1 && rxIdx <= numel(rvList)
        rv = rvList{rxIdx};
    end
end

function fam = extractModulationFamily(txc)
    % extractModulationFamily - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    fam = '';
    m = getOrEmpty(txc, 'Modulation');
    if isstruct(m) && isfield(m, 'Family') && ischar(m.Family)
        fam = m.Family;
    end
end

function n = extractNumTxAntennas(txc)
    % extractNumTxAntennas - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    n = [];
    h = getOrEmpty(txc, 'Hardware');
    if isstruct(h) && isfield(h, 'NumAntennas') && isnumeric(h.NumAntennas)
        n = h.NumAntennas;
    end
end

function n = extractNumRxAntennas(rxc)
    % extractNumRxAntennas - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    n = [];
    h = getOrEmpty(rxc, 'Hardware');
    if isstruct(h) && isfield(h, 'NumAntennas') && isnumeric(h.NumAntennas)
        n = h.NumAntennas;
        return;
    end
    if isfield(rxc, 'NumAntennas') && isnumeric(rxc.NumAntennas)
        n = rxc.NumAntennas;
    end
end

function pos = extractEntityPosition(ent)
    % extractEntityPosition - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    pos = [];
    p = getOrEmpty(ent, 'Position');
    if ~isempty(p) && isnumeric(p)
        pos = p(:)';
        return;
    end
    traj = getOrEmpty(ent, 'Trajectory');
    if isstruct(traj) && isfield(traj, 'Positions') && isnumeric(traj.Positions) && size(traj.Positions, 1) >= 1
        pos = traj.Positions(1, :);
    end
end

function bursts = extractBurstList(txc)
    % extractBurstList - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    bursts = struct([]);
    bs = getOrEmpty(txc, 'BurstSchedule');
    if isempty(bs), return; end
    bursts = getOrEmpty(bs, 'Bursts');
    if isempty(bursts) || ~isstruct(bursts)
        bursts = struct([]);
    end
end

function frames = collectFramesForBurst(fep, burstIdx)
    % collectFramesForBurst - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    frames = [];
    if ~isstruct(fep) || ~isfield(fep, 'Segments')
        return;
    end
    segs = fep.Segments;
    for i = 1:numel(segs)
        bi = getOrEmpty(segs(i), 'BurstIndex');
        if ~isempty(bi) && isnumeric(bi) && bi == burstIdx
            fid = getOrEmpty(segs(i), 'FrameId');
            if ~isempty(fid) && isnumeric(fid)
                frames(end+1) = fid; %#ok<AGROW>
            end
        end
    end
end

function indices = collectActiveIntervalIndices(fep)
    %COLLECTACTIVEINTERVALINDICES Phase 4 §3.6.C / P4-followup-5 helper.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   Walks FrameExecutionPlan.Segments and concatenates all
    %   ActiveIntervalIndices entries (each segment may carry a
    %   scalar or a vector of burst indices). Returns a numeric row
    %   vector; empty when no segment publishes the field.
    indices = [];
    if ~isstruct(fep) || ~isfield(fep, 'Segments')
        return;
    end
    segs = fep.Segments;
    for i = 1:numel(segs)
        ai = getOrEmpty(segs(i), 'ActiveIntervalIndices');
        if isempty(ai) || ~isnumeric(ai)
            continue;
        end
        indices = [indices, ai(:)']; %#ok<AGROW>
    end
end

function speed = extractEntityMaxSpeed(ent)
    %EXTRACTENTITYMAXSPEED Phase 4 §3.6.B helper.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   Returns the declared maximum speed (m/s) for an emitter/receiver.
    %   Looks for `Mobility.MaxSpeedMps` first (the Phase 3+4 canonical
    %   field), falling back to `MaxSpeedMps` / `TopSpeed` / `MaxSpeed`
    %   for legacy synthetic blueprints used by unit tests. Returns []
    %   when none of these are populated.
    speed = [];
    candidates = {'MaxSpeedMps', 'TopSpeed', 'MaxSpeed'};
    mob = getOrEmpty(ent, 'Mobility');
    if isstruct(mob)
        for k = 1:numel(candidates)
            v = getOrEmpty(mob, candidates{k});
            if ~isempty(v) && isnumeric(v) && isscalar(v)
                speed = v;
                return;
            end
        end
    end
    for k = 1:numel(candidates)
        v = getOrEmpty(ent, candidates{k});
        if ~isempty(v) && isnumeric(v) && isscalar(v)
            speed = v;
            return;
        end
    end
end

function ok = conditionalAntennaConstraintSatisfied(family, numAnt, txc, profile)
    % conditionalAntennaConstraintSatisfied - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    ok = true;
    if ~isstruct(profile.Conditions)
        return;
    end
    if any(strcmp(family, {'PSK','QAM','PAM','APSK','OOK','ASK'})) && numAnt == 8
        m = getOrEmpty(txc, 'Modulation');
        sr = getOrEmpty(m, 'SymbolRate');
        if isempty(sr) || ~isnumeric(sr) || sr < 1e6
            ok = false;
        end
        return;
    end
    if strcmp(family, 'OFDM') && numAnt == 16
        m = getOrEmpty(txc, 'Modulation');
        ns = getOrEmpty(m, 'NumSubcarriers');
        if isempty(ns) || ~isnumeric(ns) || ns < 512
            ok = false;
        end
        return;
    end
end
