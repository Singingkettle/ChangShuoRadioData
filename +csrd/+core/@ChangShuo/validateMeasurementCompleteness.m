function validateMeasurementCompleteness(annotation)
    %VALIDATEMEASUREMENTCOMPLETENESS Phase 4 §S7 / C4 annotation write-back hook.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   csrd.core.ChangShuo.validateMeasurementCompleteness(annotation)
    %
    %   Phase 4 (audit §17.6 / H17 / C4):
    %     Annotation write-back fail-fast contract for the v2 schema.
    %     Walks the (post-stampRuntimeHeader) annotation tree, locates
    %     every `SignalSources` carrier and asserts that each entry's
    %     `Truth.Measured.{SourcePlane,FramePlane}` is present and
    %     declares the required scalar measurement keys. The check is
    %     SCHEMA-strict (field presence), not value-strict: a NaN /
    %     null / empty value means "the measurement was attempted but
    %     produced no signal" and is acceptable per §7 of the Phase 4
    %     plan; what is NOT acceptable is the field being absent
    %     altogether, because that would mean buildSourceAnnotation
    %     forgot to publish it.
    %
    %     Required SourcePlane keys (per SignalSources entry):
    %         * OccupiedBandwidthHz
    %         * CenterFrequencyHz
    %         * SNRdB
    %         * TimeOccupancy
    %         * FrequencyOccupancy
    %         * MeasurementSemantics
    %
    %     Required FramePlane keys (per SignalSources entry):
    %         * OccupiedBandwidthHz
    %         * CenterFrequencyHz
    %         * TimeOccupancy
    %         * FrequencyOccupancy
    %         * MeasurementSemantics
    %
    %     OccupiedBandwidthHz "at least one plane finite" rule
    %     (audit §3.7.D test (b)/(c)):
    %         For each SignalSources(k), at least ONE of
    %         `Truth.Measured.SourcePlane.OccupiedBandwidthHz` /
    %         `Truth.Measured.FramePlane.OccupiedBandwidthHz` MUST be a
    %         finite, non-negative scalar. A signal source that left
    %         BOTH planes NaN/null indicates the measurement subsystem
    %         silently failed on every plane, which is exactly what the
    %         Phase 4 H17 audit was designed to catch -- so we reject.
    %         Other measurement scalars (SNRdB, TimeOccupancy,
    %         FrequencyOccupancy) are allowed to be NaN/null per the
    %         §7 risk note (legitimately unmeasurable).
    %
    %     Required SignalSources top-level keys (per Phase 4 v2 schema):
    %         * TxID
    %         * SegmentId
    %         * BurstId
    %         * Truth (struct with Design / Execution / Measured)
    %         * RFImpairments
    %         * ReceiverView
    %
    %   Errors raised use the `CSRD:Annotation:` namespace and are
    %   whitelisted by csrd.pipeline.scenario.isScenarioSkipException, so
    %   the SimulationRunner sweep can demote them to per-scenario skip
    %   instead of fatal-aborting the entire run.
    %
    %   Error identifiers:
    %     CSRD:Annotation:MeasurementIncomplete
    %         A SignalSources entry is missing one of the required
    %         Truth.Measured.{SourcePlane,FramePlane} keys.
    %     CSRD:Annotation:SchemaIncomplete
    %         A SignalSources entry is missing a v2 top-level key
    %         (TxID / SegmentId / BurstId / Truth / RFImpairments /
    %         ReceiverView) or `Truth.{Design,Execution,Measured}`
    %         itself.
    %
    %   The walker is robust to the variation between cell-array vs
    %   struct-array vs single-frame-flattened layouts that
    %   jsonencode / stampRuntimeHeader / per-receiver wrapping can
    %   produce, mirroring the BuildSourceAnnotationV2Test recursive
    %   locate strategy.

    if nargin < 1 || isempty(annotation)
        error('CSRD:Annotation:SchemaIncomplete', ...
            ['validateMeasurementCompleteness: annotation argument is ', ...
             'empty; saveScenarioData must produce a non-empty struct ', ...
             'before calling the hook.']);
    end

    sourceCarriers = collectSignalSourceCarriers(annotation);
    if isempty(sourceCarriers)
        error('CSRD:Annotation:SchemaIncomplete', ...
            ['validateMeasurementCompleteness: annotation tree carries ', ...
             'no `SignalSources` field at any depth; the v2 schema ', ...
             'requires every per-receiver Frame annotation to publish ', ...
             'SignalSources (even when empty it must be an explicit ', ...
             'field).']);
    end

    requiredTopKeys = {'TxID', 'SegmentId', 'BurstId', ...
        'Truth', 'RFImpairments', 'ReceiverView'};
    requiredTruthSubKeys = {'Design', 'Execution', 'Measured'};
    requiredSourcePlaneKeys = {'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
        'SNRdB', 'TimeOccupancy', 'FrequencyOccupancy', ...
        'MeasurementSemantics'};
    requiredFramePlaneKeys = {'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
        'TimeOccupancy', 'FrequencyOccupancy', 'MeasurementSemantics'};

    for cIdx = 1:numel(sourceCarriers)
        carrier = sourceCarriers(cIdx);
        sources = normaliseSignalSources(carrier.SignalSources);
        for sIdx = 1:numel(sources)
            source = sources{sIdx};
            if ~isstruct(source) || isempty(source)
                error('CSRD:Annotation:SchemaIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d) ', ...
                     'at carrier path %s is not a non-empty struct.'], ...
                    sIdx, carrier.Path);
            end

            for kIdx = 1:numel(requiredTopKeys)
                key = requiredTopKeys{kIdx};
                if ~isfield(source, key)
                    error('CSRD:Annotation:SchemaIncomplete', ...
                        ['validateMeasurementCompleteness: SignalSources(%d) ', ...
                         'at %s is missing required v2 top-level field ''%s''.'], ...
                        sIdx, carrier.Path, key);
                end
            end

            truth = source.Truth;
            if ~isstruct(truth) || isempty(truth)
                error('CSRD:Annotation:SchemaIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth at %s must be a non-empty struct (got %s).'], ...
                    sIdx, carrier.Path, class(truth));
            end
            for kIdx = 1:numel(requiredTruthSubKeys)
                key = requiredTruthSubKeys{kIdx};
                if ~isfield(truth, key)
                    error('CSRD:Annotation:SchemaIncomplete', ...
                        ['validateMeasurementCompleteness: SignalSources(%d).', ...
                         'Truth at %s is missing required sub-namespace ''%s''.'], ...
                        sIdx, carrier.Path, key);
                end
            end

            measured = truth.Measured;
            if ~isstruct(measured) || isempty(measured)
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth.Measured at %s must be a non-empty struct ', ...
                     '(got %s).'], sIdx, carrier.Path, class(measured));
            end

            if ~isfield(measured, 'SourcePlane')
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth.Measured at %s is missing the ''SourcePlane'' ', ...
                     'sub-struct.'], sIdx, carrier.Path);
            end
            if ~isfield(measured, 'FramePlane')
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth.Measured at %s is missing the ''FramePlane'' ', ...
                     'sub-struct.'], sIdx, carrier.Path);
            end

            sourcePlane = measured.SourcePlane;
            if ~isstruct(sourcePlane) || isempty(sourcePlane)
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth.Measured.SourcePlane at %s must be a non-', ...
                     'empty struct (got %s).'], sIdx, carrier.Path, ...
                    class(sourcePlane));
            end
            for kIdx = 1:numel(requiredSourcePlaneKeys)
                key = requiredSourcePlaneKeys{kIdx};
                if ~isfield(sourcePlane, key)
                    error('CSRD:Annotation:MeasurementIncomplete', ...
                        ['validateMeasurementCompleteness: SignalSources(%d).', ...
                         'Truth.Measured.SourcePlane at %s is missing ', ...
                         'required key ''%s''.'], sIdx, carrier.Path, key);
                end
            end

            framePlane = measured.FramePlane;
            if ~isstruct(framePlane) || isempty(framePlane)
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d).', ...
                     'Truth.Measured.FramePlane at %s must be a non-', ...
                     'empty struct (got %s).'], sIdx, carrier.Path, ...
                    class(framePlane));
            end
            for kIdx = 1:numel(requiredFramePlaneKeys)
                key = requiredFramePlaneKeys{kIdx};
                if ~isfield(framePlane, key)
                    error('CSRD:Annotation:MeasurementIncomplete', ...
                        ['validateMeasurementCompleteness: SignalSources(%d).', ...
                         'Truth.Measured.FramePlane at %s is missing ', ...
                         'required key ''%s''.'], sIdx, carrier.Path, key);
                end
            end

            % Phase 4 (audit §3.7.D test (b)/(c)): at-least-one-finite
            % rule for OccupiedBandwidthHz across the two planes.
            sourceOk = isFiniteNonNegativeScalar(sourcePlane.OccupiedBandwidthHz);
            frameOk  = isFiniteNonNegativeScalar(framePlane.OccupiedBandwidthHz);
            if ~sourceOk && ~frameOk
                error('CSRD:Annotation:MeasurementIncomplete', ...
                    ['validateMeasurementCompleteness: SignalSources(%d) ', ...
                     'at %s has BOTH planes with non-finite ', ...
                     'OccupiedBandwidthHz; the measurement subsystem ', ...
                     'must produce a finite, non-negative value on at ', ...
                     'least one plane (audit §3.7.D).'], sIdx, carrier.Path);
            end
        end
    end
end

% =========================================================================
function tf = isFiniteNonNegativeScalar(value)
    %ISFINITENONNEGATIVESCALAR True iff value is numeric, scalar, finite, >=0.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Accepts the post-sanitize null sentinel ([]) as "not finite" so the
    % check uniformly fires whether validateMeasurementCompleteness is
    % invoked before or after sanitizeForJson.
    tf = false;
    if isempty(value)
        return;
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value)
        return;
    end
    if ~isfinite(value)
        return;
    end
    if value < 0
        return;
    end
    tf = true;
end

% =========================================================================
function carriers = collectSignalSourceCarriers(annotation)
    %COLLECTSIGNALSOURCECARRIERS Recursively locate any struct exposing
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    % a `SignalSources` field. Returns a struct array with .Path and
    % .SignalSources so the caller can produce useful error messages.

    template = struct('Path', '', 'SignalSources', []);
    state = struct('list', repmat(template, 0, 1));
    state = walkForCarriers(annotation, '$', state);
    carriers = state.list;
end

function state = walkForCarriers(node, path, state)
    % walkForCarriers - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(node)
        for nIdx = 1:numel(node)
            elem = node(nIdx);
            elemPath = path;
            if numel(node) > 1
                elemPath = sprintf('%s[%d]', path, nIdx);
            end
            if isfield(elem, 'SignalSources')
                entry = struct('Path', elemPath, ...
                    'SignalSources', {elem.SignalSources});
                state.list(end + 1, 1) = entry;
            end
            fnames = fieldnames(elem);
            for fIdx = 1:numel(fnames)
                fn = fnames{fIdx};
                if strcmp(fn, 'SignalSources')
                    continue;
                end
                state = walkForCarriers(elem.(fn), ...
                    sprintf('%s.%s', elemPath, fn), state);
            end
        end
    elseif iscell(node)
        for nIdx = 1:numel(node)
            state = walkForCarriers(node{nIdx}, ...
                sprintf('%s[%d]', path, nIdx), state);
        end
    end
end

function out = normaliseSignalSources(value)
    % normaliseSignalSources - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if iscell(value)
        out = value;
    elseif isstruct(value)
        out = cell(numel(value), 1);
        for k = 1:numel(value)
            out{k} = value(k);
        end
    elseif isempty(value)
        out = {};
    else
        out = {value};
    end
end
