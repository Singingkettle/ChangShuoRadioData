function test_no_chinese_comments_in_matlab_sources()
%TEST_NO_CHINESE_COMMENTS_IN_MATLAB_SOURCES Gate MATLAB comment language.

fprintf('=== MATLAB source comment language gate ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
roots = {'+csrd', 'config', 'tools', 'tests'};
hits = strings(0, 1);

for r = 1:numel(roots)
    listing = dir(fullfile(projectRoot, roots{r}, '**', '*.m'));
    for k = 1:numel(listing)
        path = fullfile(listing(k).folder, listing(k).name);
        text = fileread(path);
        lines = regexp(text, '\r\n|\n|\r', 'split');
        if ~isempty(lines) && isempty(lines{end})
            lines(end) = [];
        end
        relPath = erase(path, [projectRoot filesep]);
        for lineIdx = 1:numel(lines)
            comment = localCommentPortion(lines{lineIdx});
            if localHasCJK(comment)
                hits(end + 1, 1) = sprintf('%s:%d:%s', ...
                    relPath, lineIdx, strtrim(comment)); %#ok<AGROW>
            end
        end
    end
end

assert(isempty(hits), ...
    'MATLAB comments must be English-only. First hit: %s', ...
    localFirstHit(hits));
fprintf('  [OK] no CJK characters found in MATLAB comments\n');
fprintf('=== MATLAB source comment language gate PASSED ===\n');
end

function comment = localCommentPortion(line)
% localCommentPortion - Return the MATLAB comment segment outside strings.
comment = '';
inString = false;
idx = 1;
while idx <= strlength(line)
    ch = extractBetween(string(line), idx, idx);
    if ch == "'"
        if inString && idx < strlength(line) && ...
                extractBetween(string(line), idx + 1, idx + 1) == "'"
            idx = idx + 2;
            continue;
        end
        inString = ~inString;
    elseif ch == "%" && ~inString
        comment = char(extractAfter(string(line), idx - 1));
        return;
    end
    idx = idx + 1;
end
end

function tf = localHasCJK(text)
% localHasCJK - Detect CJK characters in a text fragment.
chars = double(char(text));
tf = any(chars >= hex2dec('4E00') & chars <= hex2dec('9FFF'));
end

function hit = localFirstHit(hits)
% localFirstHit - Format the first language-gate hit for assertion output.
if isempty(hits)
    hit = "";
else
    hit = hits(1);
end
end
