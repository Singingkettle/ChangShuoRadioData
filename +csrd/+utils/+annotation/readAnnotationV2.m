function result = readAnnotationV2(input, varargin)
%READANNOTATIONV2 Read and validate a CSRD annotation v2 document.
%
%   RESULT = csrd.utils.annotation.readAnnotationV2(PATH) reads a JSON
%   annotation file and validates the frozen v0.4
%   Truth.{Design,Execution,Measured} schema.
%
%   RESULT = csrd.utils.annotation.readAnnotationV2(STRUCT) validates an
%   already decoded annotation payload. RESULT.Payload contains the original
%   payload, RESULT.Frames and RESULT.Sources are flattened cell arrays, and
%   RESULT.Summary contains basic counts.

p = inputParser;
addParameter(p, 'RequireSources', false, @islogical);
addParameter(p, 'RequireRuntimeHeader', false, @islogical);
parse(p, varargin{:});

[payload, sourcePath] = localLoadPayload(input);
localRequireFields(payload, {'Frames'}, 'annotation root');
if p.Results.RequireRuntimeHeader
    localRequireFields(payload, {'Header'}, 'annotation root');
    localRequireFields(payload.Header, {'Runtime'}, 'annotation Header');
end

frames = localFlattenStructs(payload.Frames, 'Frames');
assert(~isempty(frames), ...
    'CSRD:AnnotationV2:NoFrames', ...
    'Annotation v2 document contains no frames.');

sources = {};
receiverIds = {};
for frameIdx = 1:numel(frames)
    frame = frames{frameIdx};
    localValidateFrame(frame, frameIdx);
    receiverIds{end + 1} = char(frame.ReceiverID); %#ok<AGROW>

    frameSources = localFlattenStructs(frame.SignalSources, ...
        sprintf('Frames{%d}.SignalSources', frameIdx));
    for sourceIdx = 1:numel(frameSources)
        source = frameSources{sourceIdx};
        localValidateSource(source, frameIdx, sourceIdx);
        sources{end + 1} = source; %#ok<AGROW>
    end
end

if p.Results.RequireSources
    assert(~isempty(sources), ...
        'CSRD:AnnotationV2:NoSources', ...
        'Annotation v2 document contains no signal sources.');
end

summary = struct( ...
    'Schema', 'annotation-v2', ...
    'SourcePath', sourcePath, ...
    'NumFrames', numel(frames), ...
    'NumSources', numel(sources), ...
    'NumReceivers', numel(unique(receiverIds)), ...
    'ReceiverIDs', {unique(receiverIds)});

result = struct( ...
    'Payload', payload, ...
    'Frames', {frames}, ...
    'Sources', {sources}, ...
    'Summary', summary);
end


function [payload, sourcePath] = localLoadPayload(input)
sourcePath = '';
if isstruct(input)
    payload = input;
    return;
end

assert(ischar(input) || isstring(input), ...
    'CSRD:AnnotationV2:InvalidInput', ...
    'Input must be an annotation path or decoded struct.');
sourcePath = char(input);
assert(exist(sourcePath, 'file') == 2, ...
    'CSRD:AnnotationV2:MissingFile', ...
    'Annotation file does not exist: %s', sourcePath);
payload = jsondecode(fileread(sourcePath));
end


function items = localFlattenStructs(value, context)
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

error('CSRD:AnnotationV2:InvalidArrayShape', ...
    'Expected %s to contain structs, got %s.', context, class(value));
end


function localValidateFrame(frame, frameIdx)
context = sprintf('Frames{%d}', frameIdx);
localRequireFields(frame, ...
    {'FrameId', 'ReceiverID', 'Status', 'SignalSources'}, context);
assert(strcmp(char(frame.Status), 'Success'), ...
    'CSRD:AnnotationV2:FrameNotSuccess', ...
    '%s has non-success Status="%s".', context, char(frame.Status));
end


function localValidateSource(source, frameIdx, sourceIdx)
context = sprintf('Frames{%d}.SignalSources{%d}', frameIdx, sourceIdx);
localRejectV1Fields(source, context);
localRequireFields(source, ...
    {'TxID', 'SegmentId', 'BurstId', 'Truth', 'RFImpairments', ...
     'ReceiverView'}, context);

localRequireFields(source.Truth, ...
    {'Design', 'Execution', 'Measured'}, [context '.Truth']);
localValidateDesign(source.Truth.Design, [context '.Truth.Design']);
localValidateExecution(source.Truth.Execution, [context '.Truth.Execution']);
localValidateMeasured(source.Truth.Measured, [context '.Truth.Measured']);
localValidateReceiverView(source.ReceiverView, [context '.ReceiverView']);
end


function localValidateDesign(design, context)
localRequireFields(design, ...
    {'PlannedCenterFrequencyHz', 'PlannedBandwidthHz', ...
     'PlannedSampleRate', 'ModulationFamily', 'ModulationOrder', ...
     'PayloadLengthBits', 'NumTransmitAntennas'}, context);
localRequireFiniteScalar(design.PlannedCenterFrequencyHz, ...
    [context '.PlannedCenterFrequencyHz']);
localRequirePositiveScalar(design.PlannedBandwidthHz, ...
    [context '.PlannedBandwidthHz']);
localRequirePositiveScalar(design.PlannedSampleRate, ...
    [context '.PlannedSampleRate']);
localRequireNonemptyText(design.ModulationFamily, ...
    [context '.ModulationFamily']);
localRequireNonnegativeScalar(design.ModulationOrder, ...
    [context '.ModulationOrder']);
localRequireNonnegativeScalar(design.PayloadLengthBits, ...
    [context '.PayloadLengthBits']);
localRequirePositiveScalar(design.NumTransmitAntennas, ...
    [context '.NumTransmitAntennas']);
if isfield(design, 'Regulatory') && ~isempty(design.Regulatory)
    localValidateRegulatoryDesign(design.Regulatory, [context '.Regulatory']);
end
end


function localValidateRegulatoryDesign(reg, context)
localRequireFields(reg, ...
    {'RegionId', 'Authority', 'BandId', 'ServiceClass', 'Application', ...
     'AllocationStatus', 'SourceRefs', 'EvidenceLevel', 'ChannelRasterHz', ...
     'SelectedCenterFrequencyHz', 'AllowedBandwidthHz', ...
     'AllowedModulationFamilies'}, context);
localRequireNonemptyText(reg.RegionId, [context '.RegionId']);
localRequireNonemptyText(reg.EvidenceLevel, [context '.EvidenceLevel']);
if ~strcmp(char(reg.RegionId), 'UNSPECIFIED')
    localRequireNonemptyText(reg.Authority, [context '.Authority']);
    localRequireNonemptyText(reg.BandId, [context '.BandId']);
    localRequireNonemptyText(reg.ServiceClass, [context '.ServiceClass']);
    localRequireNonemptyText(reg.Application, [context '.Application']);
    localRequireFiniteScalar(reg.SelectedCenterFrequencyHz, ...
        [context '.SelectedCenterFrequencyHz']);
    localRequirePositiveScalar(reg.AllowedBandwidthHz, ...
        [context '.AllowedBandwidthHz']);
end
end


function localValidateExecution(execution, context)
localRequireFields(execution, ...
    {'ModulatedBandwidthHz', 'CenterFrequencyOffsetHz', 'SampleRate', ...
     'ChannelModel', 'PathLossDB', 'AnalyticalSNRdB', 'AppliedSNRdB', ...
     'DopplerShiftHz', 'RadialVelocityMps', 'GeometrySnapshot'}, context);
localRequireFields(execution.GeometrySnapshot, ...
    {'TxPositionM', 'TxVelocityMps', 'RxPositionM', 'RxVelocityMps', ...
     'LinkDistanceM'}, ...
    [context '.GeometrySnapshot']);
end


function localValidateMeasured(measured, context)
localRequireFields(measured, {'SourcePlane', 'FramePlane'}, context);
localRequireFields(measured.SourcePlane, ...
    {'OccupiedBandwidthHz', 'CenterFrequencyHz', 'SNRdB', ...
     'TimeOccupancy', 'FrequencyOccupancy', 'MeasurementSemantics'}, ...
    [context '.SourcePlane']);
localRequireFields(measured.FramePlane, ...
    {'OccupiedBandwidthHz', 'CenterFrequencyHz', 'TimeOccupancy', ...
     'FrequencyOccupancy', 'MeasurementSemantics'}, ...
    [context '.FramePlane']);

localAssertTextEquals(measured.SourcePlane.MeasurementSemantics, ...
    'receiver_view_isolated', [context '.SourcePlane.MeasurementSemantics']);
localAssertTextEquals(measured.FramePlane.MeasurementSemantics, ...
    'post_rx_combined_pre_rfchain', ...
    [context '.FramePlane.MeasurementSemantics']);
end


function localValidateReceiverView(receiverView, context)
localRequireFields(receiverView, ...
    {'ReceiverId', 'ProjectedCenterOffsetHz', 'ProjectedLowerEdgeHz', ...
     'ProjectedUpperEdgeHz', 'IsVisible', 'VisibilityReason'}, context);
end


function localRejectV1Fields(source, context)
forbidden = {'Realized', 'Planned', 'Temporal', 'Spatial', ...
    'LinkBudget', 'Channel'};
for k = 1:numel(forbidden)
    assert(~isfield(source, forbidden{k}), ...
        'CSRD:AnnotationV2:LegacyFieldPresent', ...
        '%s contains forbidden v1 top-level field "%s".', ...
        context, forbidden{k});
end
end


function localRequireFields(s, fields, context)
assert(isstruct(s), ...
    'CSRD:AnnotationV2:ExpectedStruct', ...
    '%s must be a struct.', context);
for k = 1:numel(fields)
    assert(isfield(s, fields{k}), ...
        'CSRD:AnnotationV2:MissingField', ...
        '%s missing required field "%s".', context, fields{k});
end
end


function localAssertTextEquals(actual, expected, context)
assert(strcmp(char(actual), expected), ...
    'CSRD:AnnotationV2:UnexpectedSemantics', ...
    '%s expected "%s", got "%s".', context, expected, char(actual));
end


function localRequireFiniteScalar(value, context)
assert(isnumeric(value) && isscalar(value) && isfinite(value), ...
    'CSRD:AnnotationV2:InvalidDesignValue', ...
    '%s must be a finite numeric scalar.', context);
end


function localRequirePositiveScalar(value, context)
localRequireFiniteScalar(value, context);
assert(double(value) > 0, ...
    'CSRD:AnnotationV2:InvalidDesignValue', ...
    '%s must be positive.', context);
end


function localRequireNonnegativeScalar(value, context)
localRequireFiniteScalar(value, context);
assert(double(value) >= 0, ...
    'CSRD:AnnotationV2:InvalidDesignValue', ...
    '%s must be non-negative.', context);
end


function localRequireNonemptyText(value, context)
assert(ischar(value) || isstring(value), ...
    'CSRD:AnnotationV2:InvalidDesignValue', ...
    '%s must be non-empty text.', context);
textValue = string(value);
assert(isscalar(textValue) && strlength(strtrim(textValue)) > 0, ...
    'CSRD:AnnotationV2:InvalidDesignValue', ...
    '%s must be non-empty text.', context);
end
