function run_csrd_static_gates()
%RUN_CSRD_STATIC_GATES Cheap source checks for CI smoke.
% 中文说明：提供 CSRD 生产链路中的 run_csrd_static_gates 实现。

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
    % assertNoExecutablePattern - Production declaration in CSRD.
    % 中文说明：assertNoExecutablePattern 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % stripMatlabComments - Production declaration in CSRD.
    % 中文说明：stripMatlabComments 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
