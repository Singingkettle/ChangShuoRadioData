function assertSignalStructContract(signalStruct, boundary, contextLabel)
%ASSERTSIGNALSTRUCTCONTRACT Validate the schema of a signal struct at a pipeline boundary.
%
%   csrd.utils.contract.assertSignalStructContract(signalStruct, boundary)
%   csrd.utils.contract.assertSignalStructContract(signalStruct, boundary, contextLabel)
%
%   Inputs:
%     signalStruct : the struct flowing between two stages of the
%                    physical-layer pipeline. Must be a 1x1 struct.
%     boundary     : char/string identifying the boundary being checked.
%                    Recognised boundaries (Phase 1, see
%                    docs/audits/phases/phase-1-dataflow.md §3.6):
%                      'modulator-output' : output of ModulationFactory
%                      'trf-output'       : output of TransmitFactory  (post-TRF)
%                      'channel-input'    : input to ChannelFactory.step
%                      'channel-output'   : output of ChannelFactory.step
%                      'receive-output'   : output of ReceiveFactory.step
%                    Unknown boundaries raise CSRD:Contract:UnknownBoundary.
%     contextLabel : (optional) free-form string used in error messages
%                    so callers can pinpoint the failing tx/rx/frame.
%
%   Behaviour:
%     - On success, returns silently.
%     - On schema violation, throws an MException with identifier
%       CSRD:Contract:SignalStructViolation and a message that lists
%       every missing field for the given boundary.
%
%   Phase 1 scope note:
%     This helper is intentionally a TEST-FACING contract checker. It is
%     NOT yet wired as an always-on guard inside production code,
%     because incremental cleanup of pre-existing schema gaps is
%     deferred to Phase 2. The current invocation pattern is:
%       (a) unit / regression tests call it directly with synthetic and
%           real-pipeline structs;
%       (b) future production call sites can opt in by importing this
%           helper at their boundary.

    if nargin < 3
        contextLabel = '';
    end
    if ~ischar(contextLabel) && ~isstring(contextLabel)
        contextLabel = '';
    end
    contextLabel = char(string(contextLabel));

    requiredByBoundary = struct( ...
        'modulator_output', { { 'Signal', 'SampleRate', 'ID', 'TxId', 'BurstId', 'ModulatorConfig' } }, ...
        'trf_output',       { { 'Signal', 'SampleRate', 'ID', 'TxId', 'BurstId', 'CarrierFrequency' } }, ...
        'channel_input',    { { 'Signal', 'SampleRate', 'ID', 'TxId', 'BurstId', 'CarrierFrequency' } }, ...
        'channel_output',   { { 'Signal', 'SampleRate', 'ID', 'TxId', 'BurstId', 'PathLoss', 'ChannelModel' } }, ...
        'receive_output',   { { 'Signal', 'SampleRate', 'RxImpairments' } } ...
    );

    if isstring(boundary); boundary = char(boundary); end
    if ~ischar(boundary)
        error('CSRD:Contract:UnknownBoundary', ...
            'boundary must be char/string, got %s.', class(boundary));
    end
    canonical = strrep(lower(boundary), '-', '_');
    if ~isfield(requiredByBoundary, canonical)
        error('CSRD:Contract:UnknownBoundary', ...
            'Unknown signal-struct boundary "%s". Valid boundaries: %s.', ...
            boundary, strjoin(fieldnames(requiredByBoundary), ', '));
    end

    if ~isstruct(signalStruct) || ~isscalar(signalStruct)
        error('CSRD:Contract:SignalStructViolation', ...
            ['Boundary "%s"%s expected a 1x1 struct, got %s of size %s. ' ...
             'A scalar struct is required so callers can rely on field access.'], ...
            boundary, formatContext(contextLabel), class(signalStruct), ...
            mat2str(size(signalStruct)));
    end

    requiredFields = requiredByBoundary.(canonical);
    missing = {};
    for k = 1:numel(requiredFields)
        if ~isfield(signalStruct, requiredFields{k})
            missing{end+1} = requiredFields{k}; %#ok<AGROW>
        end
    end

    if ~isempty(missing)
        error('CSRD:Contract:SignalStructViolation', ...
            'Boundary "%s"%s missing required field(s): %s. Required full set: {%s}.', ...
            boundary, formatContext(contextLabel), ...
            strjoin(missing, ', '), strjoin(requiredFields, ', '));
    end
end

function s = formatContext(contextLabel)
    if isempty(contextLabel)
        s = '';
    else
        s = sprintf(' [%s]', contextLabel);
    end
end
