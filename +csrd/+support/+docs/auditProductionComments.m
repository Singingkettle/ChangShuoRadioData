function summary = auditProductionComments(varargin)
%AUDITPRODUCTIONCOMMENTS Audit English-only MATLAB source comments.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
%
% This audit covers production MATLAB files under +csrd, config, and tools.
% It requires English file/declaration comments and rejects CJK characters in
% MATLAB comments. Historical docs are intentionally outside this scope.

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
    if p.Results.ApplyFixes
        fixedText = localApplyEnglishOnlyFixes(text);
        if ~strcmp(fixedText, text)
            localWriteText(path, fixedText);
            text = fixedText;
            changedCount = changedCount + 1;
        end
    end
    records(end + 1) = localAnalyzeFile(projectRoot, path, text); %#ok<AGROW>
end

summary = localBuildSummary(projectRoot, records, changedCount);

if p.Results.WriteManifest
    manifestPath = char(p.Results.ManifestPath);
    if isempty(manifestPath)
        manifestPath = fullfile(projectRoot, 'artifacts', 'audits', ...
            'reports', 'phase-14-production-english-comment-audit.json');
    end
    localWriteManifest(manifestPath, summary);
end
end

function projectRoot = localDefaultProjectRoot()
    % localDefaultProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
thisFile = mfilename('fullpath');
docsDir = fileparts(thisFile);
supportDir = fileparts(fileparts(docsDir));
projectRoot = fileparts(supportDir);
end

function files = localProductionFiles(projectRoot)
    % localProductionFiles - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
    % localAnalyzeFile - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
commentText = localAllCommentText(lines);
declarations = localAnalyzeDeclarations(relPath, lines);

record = localEmptyRecord();
record.Path = string(relPath);
record.EntryName = string(localEntryName(path, firstLine));
record.FirstLine = string(firstLine);
record.HasFunctionOrClassHeader = startsWith(firstLine, 'function') || ...
    startsWith(firstLine, 'classdef') || startsWith(firstLine, '%');
record.HasEnglishHeader = localHasEnglish(headerText);
record.HasChineseComment = localHasCJK(commentText);
record.HasDeprecatedReferenceHeading = contains(commentText, ...
    'References /') || contains(commentText, ['参考' '资料']);
record.NeedsHeaderFix = ~record.HasEnglishHeader;
record.NeedsChineseCommentRemoval = record.HasChineseComment;
record.NeedsReferenceFix = record.HasDeprecatedReferenceHeading;
record.Declarations = declarations;
record.DeclarationCount = numel(declarations);
if isempty(declarations)
    record.MissingDeclarationEnglishComment = 0;
    record.MissingDeclarationInputOutputComment = 0;
else
    record.MissingDeclarationEnglishComment = ...
        sum([declarations.NeedsEnglishComment]);
    record.MissingDeclarationInputOutputComment = ...
        sum([declarations.NeedsInputOutputComment]);
end
end

function declarations = localAnalyzeDeclarations(relPath, lines)
    % localAnalyzeDeclarations - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
    declaration.HasEnglishComment = localHasEnglish(commentText);
    declaration.HasChineseComment = localHasCJK(commentText);
    declaration.RequiresInputOutputComment = ...
        strcmp(kind, 'function') && localSignatureHasPayload(signature);
    declaration.HasInputOutputComment = ...
        ~declaration.RequiresInputOutputComment || ...
        localHasInputOutputComment(commentText);
    declaration.NeedsEnglishComment = ~declaration.HasEnglishComment;
    declaration.NeedsInputOutputComment = ...
        declaration.RequiresInputOutputComment && ...
        ~declaration.HasInputOutputComment;

    declarations(end + 1) = declaration; %#ok<AGROW>
    k = signatureEnd + 1;
end
end

function tf = localIsDeclarationLine(line)
    % localIsDeclarationLine - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
trimmed = strtrim(line);
tf = ~isempty(regexp(trimmed, '^(classdef|function)(\s|$)', 'once'));
end

function kind = localDeclarationKind(line)
    % localDeclarationKind - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if startsWith(strtrim(line), 'classdef')
    kind = 'classdef';
else
    kind = 'function';
end
end

function idx = localSignatureEndLine(lines, startIdx)
    % localSignatureEndLine - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
idx = startIdx;
while idx < numel(lines) && ~isempty(regexp(lines{idx}, '\.\.\.\s*(%.*)?$', 'once'))
    idx = idx + 1;
end
end

function name = localDeclarationName(signature, kind)
    % localDeclarationName - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
            % localDeclarationCommentBlock - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
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
    % localSignatureHasPayload - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = contains(signature, '=') || ...
    ~isempty(regexp(signature, '\([^)]*\S[^)]*\)', 'once'));
end

function tf = localHasInputOutputComment(commentText)
    % localHasInputOutputComment - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = contains(commentText, 'Inputs:') || ...
    contains(commentText, 'Outputs:') || ...
    contains(commentText, 'Input Arguments') || ...
    contains(commentText, 'Output Arguments') || ...
    contains(commentText, 'Returns');
end

function text = localAllCommentText(lines)
    % localAllCommentText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
parts = {};
for k = 1:numel(lines)
    comment = localCommentPortion(lines{k});
    if ~isempty(comment)
        parts{end + 1, 1} = comment; %#ok<AGROW>
    end
end
text = strjoin(parts, newline);
end

function comment = localCommentPortion(line)
    % localCommentPortion - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
        comment = extractAfter(string(line), idx - 1);
        comment = char(comment);
        return;
    end
    idx = idx + 1;
end
end

function fixedText = localApplyEnglishOnlyFixes(text)
    % localApplyEnglishOnlyFixes - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
lines = regexp(text, '\r\n|\n|\r', 'split');
newlineText = localNewline(text);
if ~isempty(lines) && isempty(lines{end})
    trailingEmpty = true;
    lines(end) = [];
else
    trailingEmpty = false;
end

out = {};
for k = 1:numel(lines)
    line = lines{k};
    trimmed = strtrim(line);
    if startsWith(trimmed, '%')
        line = regexprep(line, 'Inputs\s*/\s*输入\s*:', 'Inputs:');
        line = regexprep(line, '输出\s*/\s*Outputs\s*:', 'Outputs:');
        line = regexprep(line, 'Outputs\s*/\s*输出\s*:', 'Outputs:');
        line = regexprep(line, ['References\s*/\s*' '参考' '资料\s*:'], 'References:');
        if localHasCJK(line)
            continue;
        end
    end
    out{end + 1, 1} = line; %#ok<AGROW>
end
declarations = localAnalyzeDeclarations("", out);
for k = numel(declarations):-1:1
    declaration = declarations(k);
    if declaration.NeedsEnglishComment || declaration.NeedsInputOutputComment
        out = localFixDeclaration(out, declaration);
    end
end
if trailingEmpty
    out{end + 1, 1} = ''; %#ok<AGROW>
end
fixedText = strjoin(out, newlineText);
end

function lines = localFixDeclaration(lines, declaration)
    % localFixDeclaration - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
signatureEnd = declaration.SignatureEndLine;
indent = localDeclarationCommentIndent(lines, declaration);
summaryName = char(declaration.Name);
englishLine = sprintf('%s%% %s - CSRD MATLAB declaration.', ...
    indent, summaryName);
ioLines = {};
if declaration.NeedsInputOutputComment
    ioLines = { ...
        sprintf('%s%% Inputs: see function signature and validation.', indent); ...
        sprintf('%s%% Outputs: see return values and contract fields.', indent)};
end

if ~declaration.HasCommentBlock
    insertLines = [{englishLine}; ioLines(:)];
    lines = [lines(1:signatureEnd); insertLines(:); ...
        lines(signatureEnd + 1:end)];
    return;
end

insertAfter = declaration.CommentStartLine;
insertLines = {};
if declaration.NeedsEnglishComment
    insertLines{end + 1, 1} = englishLine; %#ok<AGROW>
end
insertLines = [insertLines; ioLines(:)]; %#ok<AGROW>
if ~isempty(insertLines)
    lines = [lines(1:insertAfter); insertLines(:); ...
        lines(insertAfter + 1:end)];
end
end

function indent = localDeclarationCommentIndent(lines, declaration)
    % localDeclarationCommentIndent - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if declaration.HasCommentBlock && declaration.CommentStartLine > 0
    indent = regexp(lines{declaration.CommentStartLine}, '^\s*', ...
        'match', 'once');
    return;
end
signatureIndent = regexp(lines{declaration.SignatureEndLine}, '^\s*', ...
    'match', 'once');
if declaration.Line == 1 && isempty(signatureIndent)
    indent = '';
else
    indent = [signatureIndent '    '];
end
end

function tf = localHasEnglish(text)
    % localHasEnglish - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = ~isempty(regexp(text, '[A-Za-z]{3,}', 'once'));
end

function tf = localHasCJK(text)
    % localHasCJK - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
chars = double(char(text));
tf = any(chars >= hex2dec('4E00') & chars <= hex2dec('9FFF'));
end

function name = localEntryName(path, firstLine)
    % localEntryName - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
[~, fileName] = fileparts(path);
name = fileName;
tokens = regexp(firstLine, ...
    '^function\s+(?:\[[^\]]+\]|\w+)\s*=\s*(\w+)|^function\s+(\w+)|^classdef\s+(\w+)', ...
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

function record = localEmptyRecord()
    % localEmptyRecord - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
record = struct( ...
    'Path', "", ...
    'EntryName', "", ...
    'FirstLine', "", ...
    'HasFunctionOrClassHeader', false, ...
    'HasEnglishHeader', false, ...
    'HasChineseComment', false, ...
    'HasDeprecatedReferenceHeading', false, ...
    'NeedsHeaderFix', false, ...
    'NeedsChineseCommentRemoval', false, ...
    'NeedsReferenceFix', false, ...
    'DeclarationCount', 0, ...
    'MissingDeclarationEnglishComment', 0, ...
    'MissingDeclarationInputOutputComment', 0, ...
    'Declarations', repmat(localEmptyDeclarationRecord(), 0, 1));
end

function declaration = localEmptyDeclarationRecord()
    % localEmptyDeclarationRecord - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
    'NeedsEnglishComment', false, ...
    'NeedsInputOutputComment', false);
end

function summary = localBuildSummary(projectRoot, records, changedCount)
    % localBuildSummary - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
summary = struct();
summary.ProjectRoot = string(projectRoot);
summary.GeneratedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
summary.FilesAudited = numel(records);
summary.FilesChanged = changedCount;
summary.MissingEnglishHeader = sum([records.NeedsHeaderFix]);
summary.FilesWithChineseComments = sum([records.NeedsChineseCommentRemoval]);
summary.ReferenceHeadingIssues = sum([records.NeedsReferenceFix]);
summary.DeclarationsAudited = sum([records.DeclarationCount]);
summary.MissingDeclarationEnglishComment = ...
    sum([records.MissingDeclarationEnglishComment]);
summary.MissingDeclarationInputOutputComment = ...
    sum([records.MissingDeclarationInputOutputComment]);
summary.Records = records;
summary.DeclarationRecords = localFlattenDeclarations(records);
end

function declarations = localFlattenDeclarations(records)
    % localFlattenDeclarations - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
declarations = repmat(localEmptyDeclarationRecord(), 0, 1);
for k = 1:numel(records)
    current = records(k).Declarations;
    if isempty(current)
        continue;
    end
    declarations = [declarations; current(:)]; %#ok<AGROW>
end
end

function localWriteText(path, text)
    % localWriteText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid > 0, 'Could not write %s.', path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end

function localWriteManifest(path, summary)
    % localWriteManifest - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
parent = fileparts(path);
if ~exist(parent, 'dir')
    mkdir(parent);
end
[clean, ~] = csrd.pipeline.annotation.sanitizeForJson(summary);
txt = jsonencode(clean, 'PrettyPrint', true);
localWriteText(path, txt);
end

function newlineText = localNewline(text)
    % localNewline - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if contains(text, sprintf('\r\n'))
    newlineText = sprintf('\r\n');
else
    newlineText = newline;
end
end
