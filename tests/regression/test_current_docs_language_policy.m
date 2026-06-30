function test_current_docs_language_policy()
%TEST_CURRENT_DOCS_LANGUAGE_POLICY Gate the bilingual documentation policy.
%   Every current operating doc must ship an English (`*.md`) and a
%   Simplified-Chinese (`*.zh-CN.md`) version, the Chinese version must contain
%   CJK text, and each version must link to the other.

fprintf('=== Current documentation language policy gate ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

% Live docs that must ship cross-linked English + Chinese versions. Historical
% audit material is archived off `main` (archive/history-2026-06-30) and is not
% part of the current doc set.
docs = [
    "README.md"
    "docs/README.md"
    "docs/GETTING_STARTED.md"
    "docs/configuration.md"
    "docs/architecture/source-layout.md"
    "docs/annotation-schema.md"
    "docs/README_Weather.md"
    "docs/examples/annotation-downstream.md"
];

for k = 1:numel(docs)
    enRel = char(docs(k));
    zhRel = regexprep(enRel, '\.md$', '.zh-CN.md');
    enPath = fullfile(projectRoot, enRel);
    zhPath = fullfile(projectRoot, zhRel);

    assert(isfile(enPath), 'Missing English doc: %s', enRel);
    assert(isfile(zhPath), 'Missing Chinese doc: %s', zhRel);

    assert(localHasCJK(fileread(zhPath)), ...
        'Chinese doc must contain Simplified-Chinese text: %s', zhRel);

    % Cross-links use the file basename (docs may sit in subdirectories).
    [~, enBase, enExt] = fileparts(enRel);
    [~, zhBase, zhExt] = fileparts(zhRel);
    assert(contains(fileread(enPath), [zhBase, zhExt]), ...
        'English doc must link to its Chinese version: %s', enRel);
    assert(contains(fileread(zhPath), [enBase, enExt]), ...
        'Chinese doc must link back to its English version: %s', zhRel);
end

fprintf('  [OK] %d docs ship cross-linked English + Chinese versions\n', numel(docs));
fprintf('=== Current documentation language policy gate PASSED ===\n');
end

function tf = localHasCJK(text)
% localHasCJK - Detect CJK characters in Markdown text.
chars = double(char(text));
tf = any(chars >= hex2dec('4E00') & chars <= hex2dec('9FFF'));
end
