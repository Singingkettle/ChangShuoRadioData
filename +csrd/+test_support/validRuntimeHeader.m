function header = validRuntimeHeader(varargin)
%VALIDRUNTIMEHEADER Build a runtime header that readAnnotation accepts.
%
%   header = csrd.test_support.validRuntimeHeader()
%   header = csrd.test_support.validRuntimeHeader('BlueprintHash', 'my-fixture', ...)
%
%   Returns the `Header` struct (with its `Runtime` field) for a hand-built
%   annotation payload, populated with everything
%   `readAnnotation(..., 'RequireRuntimeHeader', true)` requires. Any name-value
%   pair is written into `Runtime`, overriding a default or adding a field.
%
%   WHY THIS EXISTS
%   Four test fixtures each hand-rolled their own `Header.Runtime`. When
%   MeasurementContract became mandatory, three of them broke and the fourth --
%   test_phase6_coco_converter_fixture -- kept passing only because its consumer
%   does not set RequireRuntimeHeader, leaving a latent failure for whoever enables
%   it later. Each break was individually trivial and collectively a scatter of
%   unrelated-looking red, found only by a full-suite run.
%
%   Routing every fixture through one builder makes the next mandatory field a
%   one-line change here instead of a hunt. It also removes the temptation to
%   hard-code a MeasurementContract literal in a fixture: a literal copy would let
%   the fixture keep validating against a contract the pipeline no longer writes,
%   which is precisely the drift the contract exists to detect.
%
%   Inputs:
%     varargin - name-value pairs merged into Runtime.
%
%   Outputs:
%     header - struct with a .Runtime field.
%
%   See also: csrd.pipeline.measurement.measurementContract
%             csrd.pipeline.annotation.readAnnotation

assert(mod(numel(varargin), 2) == 0, ...
    'CSRD:Test:InvalidRuntimeHeaderArgs', ...
    'validRuntimeHeader expects name-value pairs (got %d arguments).', ...
    numel(varargin));

runtime = struct( ...
    'ScenarioId', 1, ...
    'WorkerId', 1, ...
    'BlueprintHash', 'test-fixture', ...
    'BlueprintResamples', 0, ...
    'ValidatorVersion', 'test-fixture', ...
    'MeasurementContract', csrd.pipeline.measurement.measurementContract());

for k = 1:2:numel(varargin)
    name = varargin{k};
    assert(ischar(name) || (isstring(name) && isscalar(name)), ...
        'CSRD:Test:InvalidRuntimeHeaderArgs', ...
        'validRuntimeHeader field names must be char or scalar string.');
    runtime.(char(name)) = varargin{k + 1};
end

header = struct('Runtime', runtime);
end
