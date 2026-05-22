function test_no_dead_code_phase20_default_runtime_contracts()
%TEST_NO_DEAD_CODE_PHASE20_DEFAULT_RUNTIME_CONTRACTS Static guards for Phase 20.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

calcState = fileread(fullfile(root, '+csrd', '+blocks', '+scenario', ...
    '@CommunicationBehaviorSimulator', 'private', 'calculateTransmissionState.m'));
assert(~contains(stripComments(calcState), 'FrameWindow = [0, pattern.ObservationDuration]'), ...
    ['Continuous temporal behavior must not publish the whole observation ', ...
     'as a per-frame FrameWindow.']);

physicalFiles = {
    fullfile(root, '+csrd', '+blocks', '+scenario', ...
        '@PhysicalEnvironmentSimulator', 'PhysicalEnvironmentSimulator.m')
    fullfile(root, '+csrd', '+blocks', '+scenario', ...
        '@PhysicalEnvironmentSimulator', 'private', 'getDefaultConfiguration.m')
    fullfile(root, '+csrd', '+factories', 'ScenarioFactory.m')
    fullfile(root, 'config', '_base_', 'factories', 'scenario_factory.m')
};
for k = 1:numel(physicalFiles)
    code = stripComments(fileread(physicalFiles{k}));
    assert(~contains(code, 'TimeResolution = 0.1'), ...
        'Production code must not reintroduce TimeResolution=0.1 fallback.');
    assert(~contains(code, 'TimeResolution = 0.001'), ...
        'Production code must not reintroduce TimeResolution=0.001 fallback.');
end

skipCode = stripComments(fileread(fullfile(root, '+csrd', '+pipeline', ...
    '+scenario', 'isScenarioSkipException.m')));
assert(~contains(skipCode, '"CSRD:Measurement:"') && ...
       ~contains(skipCode, '''CSRD:Measurement:'''), ...
    'CSRD:Measurement:* must not be a scenario skip token.');
assert(~contains(skipCode, '"CSRD:Annotation:"') && ...
       ~contains(skipCode, '''CSRD:Annotation:'''), ...
    'CSRD:Annotation:* must not be a scenario skip token.');
assert(~contains(skipCode, '"CSRD:Construction:"') && ...
       ~contains(skipCode, '''CSRD:Construction:'''), ...
    'CSRD:Construction:* must not be a scenario skip token.');

fprintf('Phase 20 default runtime dead-code guard passed.\n');
end

function out = stripComments(src)
lines = regexp(src, '\r?\n', 'split');
out = '';
for k = 1:numel(lines)
    line = lines{k};
    inStr = false;
    cut = length(line) + 1;
    for j = 1:length(line)
        if line(j) == ''''
            inStr = ~inStr;
        elseif line(j) == '%' && ~inStr
            cut = j;
            break;
        end
    end
    out = sprintf('%s\n%s', out, line(1:cut - 1)); %#ok<AGROW>
end
end
