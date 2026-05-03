function test_no_dead_code_phase15_architecture()
%TEST_NO_DEAD_CODE_PHASE15_ARCHITECTURE Guard the post-utils package layout.
% 中文说明：防止生产代码重新引入已清理的 csrd.utils 命名空间或目录。

fprintf('=== Phase 15 architecture cleanup gate ===\n');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
utilsDir = fullfile(projectRoot, '+csrd', '+utils');
assert(~isfolder(utilsDir), '+csrd/+utils must not be recreated.');

src = stripComments(readMatlabSource({ ...
    fullfile(projectRoot, '+csrd'), ...
    fullfile(projectRoot, 'config'), ...
    fullfile(projectRoot, 'tools')}));
forbiddenNamespace = ['csrd.' 'utils.'];
forbiddenPath = ['+csrd' filesep '+utils'];
assert(~contains(src, forbiddenNamespace), ...
    'Production MATLAB source must use runtime/catalog/pipeline/support packages, not csrd.utils.');
assert(~contains(src, forbiddenPath), ...
    'Production MATLAB source must not reference +csrd/+utils paths.');

assert(isfolder(fullfile(projectRoot, '+csrd', '+runtime')), ...
    'Missing +csrd/+runtime package.');
assert(isfolder(fullfile(projectRoot, '+csrd', '+catalog')), ...
    'Missing +csrd/+catalog package.');
assert(isfolder(fullfile(projectRoot, '+csrd', '+pipeline')), ...
    'Missing +csrd/+pipeline package.');
assert(isfolder(fullfile(projectRoot, '+csrd', '+support')), ...
    'Missing +csrd/+support package.');

fprintf('=== Phase 15 architecture cleanup gate PASSED ===\n');
end


function src = readMatlabSource(roots)
% readMatlabSource - Concatenate MATLAB source under selected production roots.
% 中文说明：拼接生产目录下的 MATLAB 文件，用于静态架构门禁。
src = '';
for r = 1:numel(roots)
    if ~isfolder(roots{r})
        continue;
    end
    files = dir(fullfile(roots{r}, '**', '*.m'));
    for k = 1:numel(files)
        path = fullfile(files(k).folder, files(k).name);
        src = [src, newline, fileread(path)]; %#ok<AGROW>
    end
end
end


function code = stripComments(src)
% stripComments - Remove MATLAB line comments without touching strings.
% 中文说明：移除 MATLAB 行注释，避免注释中的历史路径影响架构门禁。
lines = regexp(src, '\r?\n', 'split');
code = '';
for k = 1:numel(lines)
    line = lines{k};
    inString = false;
    cutAt = numel(line) + 1;
    c = 1;
    while c <= numel(line)
        ch = line(c);
        if ch == ''''
            if c < numel(line) && line(c + 1) == ''''
                c = c + 2;
                continue;
            end
            inString = ~inString;
        elseif ch == '%' && ~inString
            cutAt = c;
            break;
        end
        c = c + 1;
    end
    code = [code, line(1:cutAt - 1), newline]; %#ok<AGROW>
end
end
