function summary = auditProductionComments(varargin)
%AUDITPRODUCTIONCOMMENTS Audit production MATLAB comments and references.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：逐文件和逐声明审计生产 MATLAB 代码的中英文注释与参考资料字段。

p = inputParser;
addParameter(p, 'ProjectRoot', localDefaultProjectRoot(), ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'ApplyFixes', false, @islogical);
addParameter(p, 'WriteManifest', false, @islogical);
addParameter(p, 'ManifestPath', '', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

projectRoot = char(p.Results.ProjectRoot);
files = localProductionFiles(projectRoot);
records = repmat(localEmptyRecord(), 0, 1);
changedCount = 0;

for k = 1:numel(files)
    path = files{k};
    text = fileread(path);
    fixedText = text;
    record = localAnalyzeFile(projectRoot, path, text);

    if p.Results.ApplyFixes
        [fixedText, continuationChanged] = localMoveHeaderAfterContinuation(fixedText);
        [fixedText, orderChanged] = localEnsureEnglishThenChineseHeader(fixedText);
        [fixedText, headerChanged] = localEnsureChineseHeader(fixedText, record.EntryName);
        [fixedText, indentChanged] = localNormalizeChineseHeaderIndent(fixedText);
        [fixedText, refsChanged] = localNormalizeReferenceHeading(fixedText);
        [fixedText, declarationsChanged] = localEnsureDeclarationComments(fixedText);
        record.HeaderFixed = continuationChanged || orderChanged || ...
            headerChanged || indentChanged;
        record.DeclarationsFixed = declarationsChanged;
        record.ReferencesFixed = refsChanged;
        if continuationChanged || orderChanged || headerChanged || ...
                indentChanged || refsChanged || declarationsChanged
            localWriteText(path, fixedText);
            changedCount = changedCount + 1;
            record = localAnalyzeFile(projectRoot, path, fixedText);
            record.HeaderFixed = continuationChanged || orderChanged || ...
                headerChanged || indentChanged;
            record.DeclarationsFixed = declarationsChanged;
            record.ReferencesFixed = refsChanged;
        end
    end

    records(end + 1) = record; %#ok<AGROW>
end

summary = localBuildSummary(projectRoot, records, changedCount);

if p.Results.WriteManifest
    manifestPath = char(p.Results.ManifestPath);
    if isempty(manifestPath)
        manifestPath = fullfile(projectRoot, 'docs', 'audits', 'reports', ...
            'phase-14-production-comment-audit.json');
    end
    localWriteManifest(manifestPath, summary);
end
end


function projectRoot = localDefaultProjectRoot()
% localDefaultProjectRoot - Resolve the repository root from this package file.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：根据当前工具文件位置反推出项目根目录，避免依赖调用者工作目录。
thisFile = mfilename('fullpath');
docsDir = fileparts(thisFile);
utilsDir = fileparts(fileparts(docsDir));
projectRoot = fileparts(utilsDir);
end


function files = localProductionFiles(projectRoot)
% localProductionFiles - Enumerate production MATLAB files covered by Phase 14.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：枚举 Phase 14 强制审计的生产 MATLAB 文件，排除数据和生成产物目录。
roots = {'+csrd', 'config', 'tools'};
files = {};
for r = 1:numel(roots)
    listing = dir(fullfile(projectRoot, roots{r}, '**', '*.m'));
    for k = 1:numel(listing)
        fullPath = fullfile(listing(k).folder, listing(k).name);
        if contains(fullPath, [filesep 'artifacts' filesep]) || ...
                contains(fullPath, [filesep 'data' filesep])
            continue;
        end
        files{end + 1, 1} = fullPath; %#ok<AGROW>
    end
end
files = sort(files);
end


function record = localAnalyzeFile(projectRoot, path, text)
% localAnalyzeFile - Build one file-level and declaration-level audit record.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：生成单个文件的文件头、参考资料和 class/function 声明级审计记录。
relPath = erase(path, [projectRoot filesep]);
lines = regexp(text, '\r\n|\n|\r', 'split');
if ~isempty(lines) && isempty(lines{end})
    lines(end) = [];
end
firstIdx = find(~cellfun(@(x) isempty(strtrim(x)), lines), 1, 'first');
if isempty(firstIdx)
    firstLine = '';
else
    firstLine = strtrim(lines{firstIdx});
end

headerEnd = min(numel(lines), max(firstIdx + 12, 12));
if isempty(lines)
    headerText = '';
else
    headerText = strjoin(lines(1:headerEnd), newline);
end
hasEnglishHeader = ~isempty(regexp(headerText, '[A-Za-z]{3,}', 'once'));
hasChineseHeader = localHasCJK(headerText);
hasExternalReferences = localHasExternalReferences(text);
hasUnifiedReferences = contains(text, 'References / 参考资料');
declarations = localAnalyzeDeclarations(relPath, lines);

record = localEmptyRecord();
record.Path = string(relPath);
record.EntryName = string(localEntryName(path, firstLine));
record.FirstLine = string(firstLine);
record.HasFunctionOrClassHeader = startsWith(firstLine, 'function') || ...
    startsWith(firstLine, 'classdef') || startsWith(firstLine, '%');
record.HasEnglishHeader = hasEnglishHeader;
record.HasChineseHeader = hasChineseHeader;
record.HasExternalReferences = hasExternalReferences;
record.HasUnifiedReferences = hasUnifiedReferences || ~hasExternalReferences;
record.NeedsHeaderFix = ~(hasEnglishHeader && hasChineseHeader);
record.NeedsReferenceFix = hasExternalReferences && ~hasUnifiedReferences;
record.Declarations = declarations;
record.DeclarationCount = numel(declarations);
if isempty(declarations)
    record.MissingDeclarationBilingualComment = 0;
    record.MissingDeclarationInputOutputComment = 0;
else
    record.MissingDeclarationBilingualComment = ...
        sum([declarations.NeedsBilingualComment]);
    record.MissingDeclarationInputOutputComment = ...
        sum([declarations.NeedsInputOutputComment]);
end
end


function declarations = localAnalyzeDeclarations(relPath, lines)
% localAnalyzeDeclarations - Parse classdef/function declarations and comments.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：解析 MATLAB classdef/function 声明，并检查紧邻声明的说明块是否双语。
declarations = repmat(localEmptyDeclarationRecord(), 0, 1);
k = 1;
while k <= numel(lines)
    line = lines{k};
    if ~localIsDeclarationLine(line)
        k = k + 1;
        continue;
    end

    signatureEnd = localSignatureEndLine(lines, k);
    signature = strjoin(lines(k:signatureEnd), ' ');
    kind = localDeclarationKind(line);
    name = localDeclarationName(signature, kind);
    [commentText, commentStart, commentEnd] = ...
        localDeclarationCommentBlock(lines, signatureEnd);

    declaration = localEmptyDeclarationRecord();
    declaration.Path = string(relPath);
    declaration.Line = k;
    declaration.SignatureEndLine = signatureEnd;
    declaration.Kind = string(kind);
    declaration.Name = string(name);
    declaration.Signature = string(strtrim(signature));
    declaration.CommentStartLine = commentStart;
    declaration.CommentEndLine = commentEnd;
    declaration.HasCommentBlock = ~isempty(strtrim(commentText));
    declaration.HasEnglishComment = ...
        ~isempty(regexp(commentText, '[A-Za-z]{3,}', 'once'));
    declaration.HasChineseComment = localHasCJK(commentText);
    declaration.RequiresInputOutputComment = ...
        strcmp(kind, 'function') && localSignatureHasPayload(signature);
    declaration.HasInputOutputComment = ...
        ~declaration.RequiresInputOutputComment || ...
        localHasBilingualInputOutputComment(commentText);
    declaration.NeedsBilingualComment = ...
        ~(declaration.HasEnglishComment && declaration.HasChineseComment);
    declaration.NeedsInputOutputComment = ...
        declaration.RequiresInputOutputComment && ...
        ~declaration.HasInputOutputComment;

    declarations(end + 1) = declaration; %#ok<AGROW>
    k = signatureEnd + 1;
end
end


function tf = localIsDeclarationLine(line)
% localIsDeclarationLine - Return true for executable class/function headers.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：识别需要声明级注释审计的 classdef 与 function 起始行。
trimmed = strtrim(line);
tf = ~isempty(regexp(trimmed, '^(classdef|function)(\s|$)', 'once'));
end


function kind = localDeclarationKind(line)
% localDeclarationKind - Classify a MATLAB declaration line.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：区分当前声明是 classdef 还是 function，供审计记录使用。
if ~isempty(regexp(strtrim(line), '^classdef(\s|$)', 'once'))
    kind = 'classdef';
else
    kind = 'function';
end
end


function idx = localSignatureEndLine(lines, startIdx)
% localSignatureEndLine - Follow MATLAB continuation markers to signature end.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：沿着 MATLAB 续行符号找到完整声明结束行，避免把注释插入续行中间。
idx = startIdx;
while idx < numel(lines) && ~isempty(regexp(lines{idx}, '\.\.\.\s*(%.*)?$', 'once'))
    idx = idx + 1;
end
end


function name = localDeclarationName(signature, kind)
% localDeclarationName - Extract a stable display name from a declaration.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：从 classdef/function 声明中提取用于审计和自动注释的名称。
name = 'anonymousDeclaration';
signature = regexprep(signature, '\.\.\.\s*', ' ');
if strcmp(kind, 'classdef')
    tokens = regexp(signature, ...
        '^\s*classdef(?:\s*\([^)]*\))?\s*([A-Za-z]\w*)', ...
        'tokens', 'once');
else
    tokens = regexp(signature, ...
        '^\s*function\s+(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*([A-Za-z]\w*(?:\.[A-Za-z]\w*)?)', ...
        'tokens', 'once');
    if isempty(tokens)
        tokens = regexp(signature, ...
            '^\s*function\s+([A-Za-z]\w*(?:\.[A-Za-z]\w*)?)', ...
            'tokens', 'once');
    end
end
if ~isempty(tokens) && ~isempty(tokens{1})
    name = tokens{1};
end
end


function [commentText, commentStart, commentEnd] = ...
        localDeclarationCommentBlock(lines, signatureEnd)
% localDeclarationCommentBlock - Read the comment block directly after a declaration.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：读取声明后紧邻的注释块，只用该块判断声明级说明是否达标。
commentText = '';
commentStart = 0;
commentEnd = 0;
idx = signatureEnd + 1;
while idx <= numel(lines) && isempty(strtrim(lines{idx}))
    idx = idx + 1;
end
if idx > numel(lines) || isempty(regexp(lines{idx}, '^\s*%', 'once'))
    return;
end

commentStart = idx;
block = {};
while idx <= numel(lines)
    trimmed = strtrim(lines{idx});
    if isempty(trimmed) || startsWith(trimmed, '%')
        block{end + 1, 1} = lines{idx}; %#ok<AGROW>
        idx = idx + 1;
        continue;
    end
    break;
end
commentEnd = idx - 1;
commentText = strjoin(block, newline);
end


function tf = localSignatureHasPayload(signature)
% localSignatureHasPayload - Decide whether a function needs compact I/O notes.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：根据签名判断函数是否有参数或返回值，需要补充简短输入输出说明。
tf = contains(signature, '=') || ~isempty(regexp(signature, '\([^)]*\S[^)]*\)', 'once'));
end


function tf = localHasBilingualInputOutputComment(commentText)
% localHasBilingualInputOutputComment - Detect bilingual I/O notes in a help block.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：检测声明说明块中是否已经包含中英文输入输出说明。
hasInputOutputHeading = contains(commentText, 'Inputs / 输入') || ...
    contains(commentText, 'Outputs / 输出') || ...
    contains(commentText, 'Input Arguments') || ...
    contains(commentText, 'Output Arguments') || ...
    contains(commentText, 'Returns');
tf = hasInputOutputHeading && localHasCJK(commentText);
end


function name = localEntryName(path, firstLine)
% localEntryName - Resolve the file-level entry name used by legacy reports.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：解析文件级入口名称，兼容 Phase 13 已有报告字段。
[~, fileName] = fileparts(path);
name = fileName;
tokens = regexp(firstLine, '^function\s+(?:\[[^\]]+\]|\w+)\s*=\s*(\w+)|^function\s+(\w+)|^classdef\s+(\w+)', ...
    'tokens', 'once');
if ~isempty(tokens)
    for k = 1:numel(tokens)
        if ~isempty(tokens{k})
            name = tokens{k};
            return;
        end
    end
end
end


function tf = localHasCJK(text)
% localHasCJK - Detect Chinese/Japanese/Korean unified ideographs.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：检测文本中是否包含 CJK 统一表意文字，用于中文注释判定。
chars = double(char(text));
tf = any(chars >= hex2dec('4E00') & chars <= hex2dec('9FFF'));
end


function tf = localHasExternalReferences(text)
% localHasExternalReferences - Detect reference sections that need normalization.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：检测已有外部参考资料标题，便于统一为 References / 参考资料。
patterns = { ...
    'Technical References:', ...
    'Standards Reference:', ...
    'References:', ...
    'References / 参考资料', ...
    '官方文档', ...
    '参考了这个链接'};
tf = false;
for k = 1:numel(patterns)
    if contains(text, patterns{k})
        tf = true;
        return;
    end
end
end


function [text, changed] = localEnsureChineseHeader(text, entryName)
% localEnsureChineseHeader - Preserve the Phase 13 file-level Chinese header gate.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：保留 Phase 13 文件级中文头注释门禁，作为声明级审计之外的兼容检查。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
headerEnd = min(numel(lines), 12);
if localHasCJK(strjoin(lines(1:headerEnd), newlineText))
    changed = false;
    return;
end

insertLine = sprintf('%% 中文说明：提供 CSRD 生产链路中的 %s 实现。', char(entryName));
firstIdx = find(~cellfun(@(x) isempty(strtrim(x)), lines), 1, 'first');
if isempty(firstIdx)
    lines = {insertLine};
elseif startsWith(strtrim(lines{firstIdx}), '%')
    lines = [lines(1:firstIdx), {insertLine}, lines(firstIdx + 1:end)];
elseif firstIdx < numel(lines) && startsWith(strtrim(lines{firstIdx + 1}), '%')
    lines = [lines(1:firstIdx + 1), {insertLine}, lines(firstIdx + 2:end)];
else
    lines = [lines(1:firstIdx), {insertLine}, lines(firstIdx + 1:end)];
end
text = strjoin(lines, newlineText);
changed = true;
end


function [text, changed] = localMoveHeaderAfterContinuation(text)
% localMoveHeaderAfterContinuation - Keep inserted comments outside continuations.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：修正早期自动插入可能落入续行声明中间的中文头注释。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
changed = false;
limit = min(numel(lines), 20);
idx = 2;
while idx <= limit
    if ~isempty(regexp(lines{idx}, '^\s*%\s*中文说明：', 'once')) && ...
            ~isempty(regexp(lines{idx - 1}, '\.\.\.\s*$', 'once'))
        chineseLine = lines{idx};
        lines(idx) = [];
        endIdx = idx - 1;
        while endIdx <= numel(lines) && ...
                ~isempty(regexp(lines{endIdx}, '\.\.\.\s*$', 'once'))
            endIdx = endIdx + 1;
        end
        if endIdx > numel(lines)
            lines{end + 1} = chineseLine; %#ok<AGROW>
        else
            lines = [lines(1:endIdx), {chineseLine}, lines(endIdx + 1:end)];
        end
        changed = true;
        limit = min(numel(lines), 20);
    end
    idx = idx + 1;
end
if changed
    text = strjoin(lines, newlineText);
end
end


function [text, changed] = localEnsureEnglishThenChineseHeader(text)
% localEnsureEnglishThenChineseHeader - Keep file headers English first, Chinese second.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：整理文件头顺序，保持英文职责说明在前、中文职责说明紧随其后。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
changed = false;
for k = 1:min(numel(lines) - 1, 20)
    if ~isempty(regexp(lines{k}, '^\s*%\s*中文说明：', 'once')) && ...
            ~isempty(regexp(lines{k + 1}, '^\s*%[A-Za-z0-9_]', 'once'))
        tmp = lines{k};
        lines{k} = lines{k + 1};
        lines{k + 1} = tmp;
        changed = true;
        break;
    end
end
if changed
    text = strjoin(lines, newlineText);
end
end


function [text, changed] = localNormalizeChineseHeaderIndent(text)
% localNormalizeChineseHeaderIndent - Align early Chinese header indentation.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：修正文件头前二十行中中文说明的缩进，使其贴合邻近注释。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
changed = false;
for k = 1:min(numel(lines), 20)
    if isempty(regexp(lines{k}, '^\s*%\s*中文说明：', 'once'))
        continue;
    end
    indent = localNeighborCommentIndent(lines, k);
    normalized = regexprep(strtrim(lines{k}), '^%\s*', [indent '% ']);
    if ~strcmp(lines{k}, normalized)
        lines{k} = normalized;
        changed = true;
    end
end
if changed
    text = strjoin(lines, newlineText);
end
end


function [text, changed] = localEnsureDeclarationComments(text)
% localEnsureDeclarationComments - Add compact bilingual comments to declarations.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：为缺少声明级中英文说明的 class/function 自动补充紧邻注释块。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
if ~isempty(lines) && isempty(lines{end})
    trailingEmpty = true;
    lines(end) = [];
else
    trailingEmpty = false;
end
declarations = localAnalyzeDeclarations("", lines);
changed = false;

for k = numel(declarations):-1:1
    declaration = declarations(k);
    if ~(declaration.NeedsBilingualComment || declaration.NeedsInputOutputComment)
        continue;
    end
    [lines, didChange] = localFixDeclaration(lines, declaration);
    changed = changed || didChange;
end

if changed
    if trailingEmpty
        lines{end + 1} = ''; %#ok<AGROW>
    end
    text = strjoin(lines, newlineText);
end
end


function [lines, changed] = localFixDeclaration(lines, declaration)
% localFixDeclaration - Insert or extend one declaration comment block.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：针对单个 class/function 声明插入或扩展双语说明块。
changed = false;
signatureEnd = declaration.SignatureEndLine;
commentIndent = localDeclarationCommentIndent(lines, declaration);
summaryName = char(declaration.Name);
englishLine = sprintf('%s%% %s - Production declaration in CSRD.', ...
    commentIndent, summaryName);
chineseLine = sprintf('%s%% 中文说明：%s 在 CSRD 生产链路中执行对应处理。', ...
    commentIndent, summaryName);
[ioLines, needsIoLines] = localDeclarationIOLines(commentIndent, declaration);

if ~declaration.HasCommentBlock
    insertLines = {englishLine; chineseLine};
    if needsIoLines
        insertLines = [insertLines; ioLines]; %#ok<AGROW>
    end
    lines = [lines(1:signatureEnd), insertLines(:).', lines(signatureEnd + 1:end)];
    changed = true;
    return;
end

insertAfter = declaration.CommentStartLine;
insertLines = {};
if ~declaration.HasEnglishComment
    insertLines{end + 1, 1} = englishLine; %#ok<AGROW>
end
if ~declaration.HasChineseComment
    insertLines{end + 1, 1} = chineseLine; %#ok<AGROW>
end
if needsIoLines
    insertLines = [insertLines; ioLines]; %#ok<AGROW>
end

if ~isempty(insertLines)
    lines = [lines(1:insertAfter), insertLines(:).', lines(insertAfter + 1:end)];
    changed = true;
end
end


function indent = localDeclarationCommentIndent(lines, declaration)
% localDeclarationCommentIndent - Choose indentation for inserted declaration comments.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：根据已有注释、声明位置和局部函数位置选择新注释缩进。
if declaration.HasCommentBlock && declaration.CommentStartLine > 0
    indent = regexp(lines{declaration.CommentStartLine}, '^\s*', 'match', 'once');
    return;
end
signatureIndent = regexp(lines{declaration.SignatureEndLine}, '^\s*', 'match', 'once');
if declaration.Line == 1 && isempty(signatureIndent)
    indent = '';
else
    indent = [signatureIndent '    '];
end
end


function [ioLines, shouldInsert] = localDeclarationIOLines(indent, declaration)
% localDeclarationIOLines - Create compact bilingual I/O notes when required.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：为有参数或返回值的函数生成简短双语输入输出说明。
shouldInsert = declaration.NeedsInputOutputComment;
ioLines = {};
if ~shouldInsert
    return;
end
ioLines = { ...
    sprintf('%s%% Inputs / 输入: see signature arguments and local validation.', indent); ...
    sprintf('%s%% 输出 / Outputs: see signature return values and contract fields.', indent)};
end


function indent = localNeighborCommentIndent(lines, idx)
% localNeighborCommentIndent - Reuse indentation from nearby comments.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：复用邻近注释缩进，避免自动修订制造突兀格式。
indent = '';
for k = idx - 1:-1:1
    if ~isempty(regexp(lines{k}, '^\s*%', 'once'))
        indent = regexp(lines{k}, '^\s*', 'match', 'once');
        return;
    end
    if ~isempty(strtrim(lines{k})) && ~startsWith(strtrim(lines{k}), 'function') && ...
            ~startsWith(strtrim(lines{k}), 'classdef')
        break;
    end
end
for k = idx + 1:min(numel(lines), idx + 5)
    if ~isempty(regexp(lines{k}, '^\s*%', 'once'))
        indent = regexp(lines{k}, '^\s*', 'match', 'once');
        return;
    end
end
end


function [text, changed] = localNormalizeReferenceHeading(text)
% localNormalizeReferenceHeading - Normalize external reference section headings.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把已有外部资料标题统一为 References / 参考资料，便于后续审计。
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
changed = false;
hasUnified = contains(text, 'References / 参考资料');
for k = 1:numel(lines)
    line = lines{k};
    if ~isempty(regexp(line, '^\s*%\s*(Technical References|Standards Reference|References)\s*:', 'once'))
        indent = regexp(line, '^\s*', 'match', 'once');
        lines{k} = [indent '% References / 参考资料:'];
        changed = true;
        hasUnified = true;
    end
end

if ~hasUnified
    for k = 1:numel(lines)
        if contains(lines{k}, '官方文档') || contains(lines{k}, '参考了这个链接')
            indent = regexp(lines{k}, '^\s*', 'match', 'once');
            lines = [lines(1:k - 1), {[indent '% References / 参考资料:']}, ...
                lines(k:end)];
            changed = true;
            break;
        end
    end
end

if changed
    text = strjoin(lines, newlineText);
end
end


function newlineText = localNewline(text)
% localNewline - Preserve the dominant newline convention while rewriting files.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：写回文件时保留原有主导换行符风格，减少无关 diff。
if contains(text, sprintf('\r\n'))
    newlineText = sprintf('\r\n');
else
    newlineText = newline;
end
end


function localWriteText(path, text)
% localWriteText - Write UTF-8 text through MATLAB file I/O.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：使用 MATLAB 文件接口写回 UTF-8 文本，保证中文注释可保存。
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid > 0, 'Could not write %s.', path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end


function record = localEmptyRecord()
% localEmptyRecord - Return the file-level audit record template.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：返回文件级审计记录模板，保持 manifest 字段稳定。
record = struct( ...
    'Path', "", ...
    'EntryName', "", ...
    'FirstLine', "", ...
    'HasFunctionOrClassHeader', false, ...
    'HasEnglishHeader', false, ...
    'HasChineseHeader', false, ...
    'HasExternalReferences', false, ...
    'HasUnifiedReferences', false, ...
    'NeedsHeaderFix', false, ...
    'NeedsReferenceFix', false, ...
    'HeaderFixed', false, ...
    'DeclarationsFixed', false, ...
    'ReferencesFixed', false, ...
    'DeclarationCount', 0, ...
    'MissingDeclarationBilingualComment', 0, ...
    'MissingDeclarationInputOutputComment', 0, ...
    'Declarations', repmat(localEmptyDeclarationRecord(), 0, 1));
end


function declaration = localEmptyDeclarationRecord()
% localEmptyDeclarationRecord - Return the declaration-level audit template.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：返回 class/function 声明级审计记录模板，用于逐声明 manifest。
declaration = struct( ...
    'Path', "", ...
    'Line', 0, ...
    'SignatureEndLine', 0, ...
    'Kind', "", ...
    'Name', "", ...
    'Signature', "", ...
    'CommentStartLine', 0, ...
    'CommentEndLine', 0, ...
    'HasCommentBlock', false, ...
    'HasEnglishComment', false, ...
    'HasChineseComment', false, ...
    'RequiresInputOutputComment', false, ...
    'HasInputOutputComment', false, ...
    'NeedsBilingualComment', false, ...
    'NeedsInputOutputComment', false);
end


function summary = localBuildSummary(projectRoot, records, changedCount)
% localBuildSummary - Aggregate file and declaration audit results.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：汇总文件级与声明级审计结果，兼容 Phase 13 并新增 Phase 14 字段。
summary = struct();
summary.ProjectRoot = string(projectRoot);
summary.GeneratedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
summary.FilesAudited = numel(records);
summary.FilesChanged = changedCount;
summary.MissingBilingualHeader = sum([records.NeedsHeaderFix]);
summary.ReferenceHeadingIssues = sum([records.NeedsReferenceFix]);
summary.DeclarationsAudited = sum([records.DeclarationCount]);
summary.MissingDeclarationBilingualComment = ...
    sum([records.MissingDeclarationBilingualComment]);
summary.MissingDeclarationInputOutputComment = ...
    sum([records.MissingDeclarationInputOutputComment]);
summary.Records = records;
summary.DeclarationRecords = localFlattenDeclarations(records);
end


function declarations = localFlattenDeclarations(records)
% localFlattenDeclarations - Flatten nested declaration records for tests/reports.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：把每个文件中的声明审计记录展平成数组，便于测试和报告检索。
declarations = repmat(localEmptyDeclarationRecord(), 0, 1);
for k = 1:numel(records)
    current = records(k).Declarations;
    if isempty(current)
        continue;
    end
    declarations = [declarations; current(:)]; %#ok<AGROW>
end
end


function localWriteManifest(path, summary)
% localWriteManifest - Write a JSON manifest for comment audit evidence.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：输出 JSON 审计清单，作为 Phase 14 注释补救证据。
parent = fileparts(path);
if ~exist(parent, 'dir'); mkdir(parent); end
[clean, ~] = csrd.pipeline.annotation.sanitizeForJson(summary);
txt = jsonencode(clean, 'PrettyPrint', true);
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid > 0, 'Could not write audit manifest: %s', path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end
