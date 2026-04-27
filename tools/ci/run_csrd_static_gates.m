function run_csrd_static_gates()
%RUN_CSRD_STATIC_GATES Cheap source checks for CI smoke.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

sentinelChecks = {
    fullfile(projectRoot, '+csrd', '+factories', 'ChannelFactory.m'), ...
        'ChannelBlockStepFailed';
    fullfile(projectRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
        'generateSingleFrame.m'), 'FrameGenerationFailed';
    fullfile(projectRoot, '+csrd', '+core', '@ChangShuo', 'private', ...
        'processSingleTransmitter.m'), 'Error_MissingTxScenarioID'};

for k = 1:size(sentinelChecks, 1)
    assertNoExecutablePattern(sentinelChecks{k, 1}, sentinelChecks{k, 2});
end

converterPath = fullfile(projectRoot, 'tools', 'convert_csrd_to_coco.m');
assertNoExecutablePattern(converterPath, ...
    'meta\.annotation\.(rx|tx)|annotation\.(rx|tx)');
end


function assertNoExecutablePattern(path, pattern)
assert(exist(path, 'file') == 2, ...
    'CSRD:CI:MissingStaticGateFile', ...
    'Static gate file does not exist: %s', path);

code = stripMatlabComments(fileread(path));
hit = regexp(code, pattern, 'once');
assert(isempty(hit), ...
    'CSRD:CI:ForbiddenPattern', ...
    'Forbidden executable pattern "%s" found in %s.', pattern, path);
end


function stripped = stripMatlabComments(code)
lines = regexp(code, '\r\n|\n|\r', 'split');
for i = 1:numel(lines)
    line = lines{i};
    pct = regexp(line, '%', 'once');
    if ~isempty(pct)
        lines{i} = line(1:pct - 1);
    end
end
stripped = strjoin(lines, newline);
end
