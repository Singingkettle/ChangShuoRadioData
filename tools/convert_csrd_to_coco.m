function coco = convert_csrd_to_coco(annotationInput, outputPath, varargin)
%CONVERT_CSRD_TO_COCO Convert CSRD annotation to minimal COCO JSON.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
%   COCO = convert_csrd_to_coco(ANNOTATION_INPUT) validates a CSRD
%   annotation payload or JSON file and returns a COCO-style struct.
%
%   COCO = convert_csrd_to_coco(ANNOTATION_INPUT, OUTPUT_PATH) also writes
%   the JSON output to OUTPUT_PATH.
%
%   This Phase 6 converter intentionally exports a receiver-frequency
%   canvas: the x axis is the receiver observable frequency window and the
%   y axis is a one-row minimal canvas. Annotation v2 does not persist
%   burst start/stop times, so time occupancy is preserved as metadata
%   rather than projected into a synthetic 2-D time extent.

if nargin < 1 || isempty(annotationInput)
    error('CSRD:Tools:CocoMissingInput', ...
        'convert_csrd_to_coco requires an annotation path or struct.');
end
if nargin < 2
    outputPath = '';
end
if isNameValueToken(outputPath)
    varargin = [{outputPath}, varargin];
    outputPath = '';
end

p = inputParser;
addParameter(p, 'ImageWidth', 1024, @isPositiveScalar);
addParameter(p, 'ImageHeight', 1, @isPositiveScalar);
parse(p, varargin{:});

imageWidth = double(p.Results.ImageWidth);
imageHeight = double(p.Results.ImageHeight);

reader = csrd.pipeline.annotation.readAnnotation(annotationInput, ...
    'RequireSources', true);

state = struct();
state.images = localEmptyImages();
state.annotations = localEmptyAnnotations();
state.categories = localEmptyCategories();
state.skippedSources = localEmptySkippedSources();
state.categoryNames = {};
state.nextAnnotationId = 1;

for frameIdx = 1:numel(reader.Frames)
    frame = reader.Frames{frameIdx};
    imageId = frameIdx;
    observableRangeHz = resolveObservableRange(frame);

    image = struct();
    image.id = imageId;
    image.file_name = makeVirtualFileName(frame);
    image.width = imageWidth;
    image.height = imageHeight;
    image.csrd = struct( ...
        'frame_id', frame.FrameId, ...
        'receiver_id', char(frame.ReceiverID), ...
        'sample_rate_hz', getOptionalScalar(frame, 'SampleRate'), ...
        'observable_range_hz', observableRangeHz, ...
        'coordinate_system', 'receiver_frequency_canvas', ...
        'time_axis', 'not_localized_in_s5_minimal_export');
    state.images(end + 1) = image;

    sources = localFlattenStructs(frame.SignalSources, ...
        sprintf('Frames{%d}.SignalSources', frameIdx));
    for sourceIdx = 1:numel(sources)
        source = sources{sourceIdx};
        [state, annotation] = convertSource(state, source, frame, ...
            imageId, observableRangeHz, imageWidth, imageHeight);
        if ~isempty(annotation)
            state.annotations(end + 1) = annotation;
        end
    end
end

coco = struct();
coco.info = struct( ...
    'description', 'CSRD annotation receiver-frequency COCO export', ...
    'version', 'csrd-coco-v2-minimal', ...
    'source_schema', reader.Summary.Schema, ...
    'coordinate_system', 'receiver_frequency_canvas');
coco.licenses = localEmptyLicenses();
coco.images = state.images;
coco.annotations = state.annotations;
coco.categories = state.categories;
coco.csrd_export = struct( ...
    'schema', 'csrd.coco.v2.minimal', ...
    'source_path', reader.Summary.SourcePath, ...
    'num_frames', numel(state.images), ...
    'num_sources', reader.Summary.NumSources, ...
    'num_annotations', numel(state.annotations), ...
    'num_skipped_sources', numel(state.skippedSources), ...
    'skipped_sources', state.skippedSources, ...
    'field_sources', localFieldSources());

if ~isempty(outputPath)
    coco = writeCocoJson(coco, outputPath);
end
end


function tf = isNameValueToken(value)
    % isNameValueToken - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
tf = (ischar(value) || isstring(value)) && ...
    any(strcmpi(char(value), {'ImageWidth', 'ImageHeight'}));
end


function tf = isPositiveScalar(value)
    % isPositiveScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end


function items = localFlattenStructs(value, context)
    % localFlattenStructs - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
items = {};
if isempty(value)
    return;
end
if isstruct(value)
    cells = num2cell(value);
    items = reshape(cells, 1, []);
    return;
end
if iscell(value)
    for k = 1:numel(value)
        nested = localFlattenStructs(value{k}, ...
            sprintf('%s{%d}', context, k));
        items = [items, nested]; %#ok<AGROW>
    end
    return;
end
error('CSRD:Tools:CocoInvalidSignalSources', ...
    'Expected %s to contain structs, got %s.', context, class(value));
end


function [state, annotation] = convertSource(state, source, frame, imageId, ...
        observableRangeHz, imageWidth, imageHeight)
            % convertSource - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
annotation = [];

rv = source.ReceiverView;
if ~logicalScalar(rv.IsVisible)
    state.skippedSources(end + 1) = makeSkippedSource(source, frame);
    return;
end

categoryName = char(source.Truth.Design.ModulationFamily);
if isempty(categoryName)
    error('CSRD:Tools:CocoMissingCategory', ...
        ['Signal source TxID=%s BurstId=%s is missing ', ...
         'Truth.Design.ModulationFamily.'], ...
        char(source.TxID), char(source.BurstId));
end
[state, categoryId] = ensureCategory(state, categoryName);

[bbox, bboxHz] = makeFrequencyBbox(source, observableRangeHz, ...
    imageWidth, imageHeight);

annotation = struct();
annotation.id = state.nextAnnotationId;
annotation.image_id = imageId;
annotation.category_id = categoryId;
annotation.bbox = bbox;
annotation.area = bbox(3) * bbox(4);
annotation.iscrowd = 0;
annotation.csrd = makeAnnotationMetadata(source, frame, bboxHz);
state.nextAnnotationId = state.nextAnnotationId + 1;
end


function tf = logicalScalar(value)
    % logicalScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if islogical(value)
    tf = isscalar(value) && value;
elseif isnumeric(value)
    tf = isscalar(value) && value ~= 0;
else
    tf = false;
end
end


function skipped = makeSkippedSource(source, frame)
    % makeSkippedSource - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
skipped = struct( ...
    'frame_id', frame.FrameId, ...
    'receiver_id', char(frame.ReceiverID), ...
    'tx_id', char(source.TxID), ...
    'segment_id', source.SegmentId, ...
    'burst_id', char(source.BurstId), ...
    'visibility_reason', char(source.ReceiverView.VisibilityReason));
end


function [state, categoryId] = ensureCategory(state, categoryName)
    % ensureCategory - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
hit = find(strcmp(state.categoryNames, categoryName), 1);
if ~isempty(hit)
    categoryId = hit;
    return;
end

categoryId = numel(state.categoryNames) + 1;
state.categoryNames{end + 1} = categoryName;
category = struct( ...
    'id', categoryId, ...
    'name', categoryName, ...
    'supercategory', 'modulation_family');
state.categories(end + 1) = category;
end


function [bbox, bboxHz] = makeFrequencyBbox(source, observableRangeHz, ...
        imageWidth, imageHeight)
            % makeFrequencyBbox - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
rv = source.ReceiverView;
sourcePlane = source.Truth.Measured.SourcePlane;

% Center the box on the MEASURED center frequency (same receiver-baseband
% frame as the planned offset, but including the realized Doppler and carrier
% error), consistent with the measured width below and the project's
% measured-over-planned GT rule. ProjectedCenterOffsetHz is the planner's
% pre-Doppler offset and would mis-center the box on the realized lobe.
centerHz = requireFiniteScalar(sourcePlane.CenterFrequencyHz, ...
    'Truth.Measured.SourcePlane.CenterFrequencyHz');
bandwidthHz = requireFiniteScalar(sourcePlane.OccupiedBandwidthHz, ...
    'Truth.Measured.SourcePlane.OccupiedBandwidthHz');
if bandwidthHz <= 0
    error('CSRD:Tools:CocoInvalidMeasuredBandwidth', ...
        'SourcePlane.OccupiedBandwidthHz must be positive, got %.17g.', ...
        bandwidthHz);
end

rangeMinHz = observableRangeHz(1);
rangeMaxHz = observableRangeHz(2);
rangeWidthHz = rangeMaxHz - rangeMinHz;
lowerHz = centerHz - bandwidthHz / 2;
upperHz = centerHz + bandwidthHz / 2;
clippedLowerHz = max(lowerHz, rangeMinHz);
clippedUpperHz = min(upperHz, rangeMaxHz);

if clippedUpperHz <= clippedLowerHz
    error('CSRD:Tools:CocoBBoxOutsideObservableRange', ...
        ['Visible source TxID=%s projects outside receiver observable ', ...
         'range [%.17g %.17g] Hz.'], ...
        char(source.TxID), rangeMinHz, rangeMaxHz);
end

x = (clippedLowerHz - rangeMinHz) / rangeWidthHz * imageWidth;
width = (clippedUpperHz - clippedLowerHz) / rangeWidthHz * imageWidth;
bbox = [x, 0, width, imageHeight];
bboxHz = struct( ...
    'lower_edge_hz', clippedLowerHz, ...
    'upper_edge_hz', clippedUpperHz, ...
    'center_hz', centerHz, ...
    'occupied_bandwidth_hz', bandwidthHz, ...
    'was_clipped_to_observable_range', ...
        clippedLowerHz ~= lowerHz || clippedUpperHz ~= upperHz);
end


function value = requireFiniteScalar(value, context)
    % requireFiniteScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('CSRD:Tools:CocoMissingFiniteScalar', ...
        '%s must be a finite numeric scalar.', context);
end
value = double(value);
end


function metadata = makeAnnotationMetadata(source, frame, bboxHz)
    % makeAnnotationMetadata - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
truth = source.Truth;
metadata = struct( ...
    'schema', 'annotation-derived', ...
    'frame_id', frame.FrameId, ...
    'receiver_id', char(frame.ReceiverID), ...
    'tx_id', char(source.TxID), ...
    'segment_id', source.SegmentId, ...
    'burst_id', char(source.BurstId), ...
    'visibility_reason', char(source.ReceiverView.VisibilityReason), ...
    'bbox_frequency_hz', bboxHz, ...
    'source_fields', localFieldSources(), ...
    'design', truth.Design, ...
    'execution', truth.Execution, ...
    'measured', truth.Measured, ...
    'receiver_view', source.ReceiverView);
end


function fieldSources = localFieldSources()
    % localFieldSources - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
fieldSources = struct( ...
    'category', 'Truth.Design.ModulationFamily', ...
    'bbox_center_hz', 'Truth.Measured.SourcePlane.CenterFrequencyHz', ...
    'bbox_width_hz', ...
        'Truth.Measured.SourcePlane.OccupiedBandwidthHz', ...
    'time_occupancy', ...
        'Truth.Measured.SourcePlane.TimeOccupancy', ...
    'execution_metadata', 'Truth.Execution', ...
    'measurement_metadata', 'Truth.Measured');
end


function rangeHz = resolveObservableRange(frame)
    % resolveObservableRange - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if isfield(frame, 'ObservableRange') && isnumeric(frame.ObservableRange) && ...
        numel(frame.ObservableRange) >= 2 && ...
        all(isfinite(frame.ObservableRange(1:2)))
    vals = double(frame.ObservableRange(1:2));
    rangeHz = [min(vals), max(vals)];
elseif isfield(frame, 'SampleRate') && isnumeric(frame.SampleRate) && ...
        isscalar(frame.SampleRate) && isfinite(frame.SampleRate) && ...
        frame.SampleRate > 0
    halfBw = double(frame.SampleRate) / 2;
    rangeHz = [-halfBw, halfBw];
else
    error('CSRD:Tools:CocoMissingObservableRange', ...
        ['FrameId=%s ReceiverID=%s lacks ObservableRange and valid ', ...
         'SampleRate.'], mat2str(frame.FrameId), char(frame.ReceiverID));
end
if rangeHz(2) <= rangeHz(1)
    error('CSRD:Tools:CocoInvalidObservableRange', ...
        'Frame observable range must be increasing after normalization.');
end
end


function value = getOptionalScalar(s, fieldName)
    % getOptionalScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
if isfield(s, fieldName) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    value = double(s.(fieldName));
else
    value = [];
end
end


function name = makeVirtualFileName(frame)
    % makeVirtualFileName - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
name = sprintf('frame_%06d_%s_frequency_canvas', ...
    double(frame.FrameId), sanitizeName(char(frame.ReceiverID)));
end


function out = sanitizeName(value)
    % sanitizeName - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = regexprep(value, '[^A-Za-z0-9_=-]', '_');
if isempty(out)
    out = 'receiver';
end
end


function coco = writeCocoJson(coco, outputPath)
    % writeCocoJson - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
assert(ischar(outputPath) || isstring(outputPath), ...
    'CSRD:Tools:CocoInvalidOutputPath', ...
    'OUTPUT_PATH must be a character vector or string scalar.');
outputPath = char(outputPath);
outDir = fileparts(outputPath);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

[clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(coco);
clean.csrd_export.sanitize_manifest = manifest;

fid = fopen(outputPath, 'w');
assert(fid > 0, 'CSRD:Tools:CocoWriteFailed', ...
    'Could not open COCO output for writing: %s', outputPath);
cleanup = onCleanup(@() fclose(fid));
% COCO requires images/annotations/categories to be JSON arrays. jsonencode
% emits an array only for a non-scalar struct array (or a cell of structs); a
% single-element collection would otherwise serialize as a bare JSON object and
% break pycocotools (createIndex iterates these as lists). Encode from a
% cell-wrapped copy so the on-disk JSON is always an array of objects, while the
% returned struct keeps its original shape (callers/tests are unaffected).
forJson = clean;
forJson.images = localAsObjectArray(forJson.images);
forJson.annotations = localAsObjectArray(forJson.annotations);
forJson.categories = localAsObjectArray(forJson.categories);
forJson.licenses = localAsObjectArray(forJson.licenses);
fprintf(fid, '%s', jsonencode(forJson, 'PrettyPrint', true));
delete(cleanup);
coco = clean;
end


function out = localAsObjectArray(value)
% localAsObjectArray - Force a struct array (including 0- or 1-element) into a
% cell of scalar structs so jsonencode always emits a JSON array of objects,
% never a bare object. Non-struct values pass through unchanged.
if iscell(value) || ~isstruct(value)
    out = value;
else
    out = num2cell(reshape(value, 1, []));
end
end


function out = localEmptyImages()
    % localEmptyImages - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = repmat(struct( ...
    'id', [], ...
    'file_name', '', ...
    'width', [], ...
    'height', [], ...
    'csrd', struct()), 0, 1);
end


function out = localEmptyAnnotations()
    % localEmptyAnnotations - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = repmat(struct( ...
    'id', [], ...
    'image_id', [], ...
    'category_id', [], ...
    'bbox', [], ...
    'area', [], ...
    'iscrowd', [], ...
    'csrd', struct()), 0, 1);
end


function out = localEmptyCategories()
    % localEmptyCategories - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = repmat(struct( ...
    'id', [], ...
    'name', '', ...
    'supercategory', ''), 0, 1);
end


function out = localEmptyLicenses()
    % localEmptyLicenses - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = repmat(struct( ...
    'id', [], ...
    'name', '', ...
    'url', ''), 0, 1);
end


function out = localEmptySkippedSources()
    % localEmptySkippedSources - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
out = repmat(struct( ...
    'frame_id', [], ...
    'receiver_id', '', ...
    'tx_id', '', ...
    'segment_id', [], ...
    'burst_id', '', ...
    'visibility_reason', ''), 0, 1);
end
