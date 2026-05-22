function test_current_docs_language_policy()
%TEST_CURRENT_DOCS_LANGUAGE_POLICY Gate current documentation language policy.

fprintf('=== Current documentation language policy gate ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

englishDocs = [
    "README.md"
    "docs/README.md"
    "docs/configuration.md"
    "docs/architecture/source-layout.md"
    "docs/annotation-v2-schema.md"
    "docs/README_Refactoring.md"
    "docs/README_Weather.md"
];
for k = 1:numel(englishDocs)
    path = fullfile(projectRoot, char(englishDocs(k)));
    assert(isfile(path), 'Missing current documentation file: %s', path);
    text = fileread(path);
    assert(~localHasCJK(text), ...
        'Current English documentation contains CJK characters: %s', ...
        englishDocs(k));
end

zhPath = fullfile(projectRoot, 'README.zh-CN.md');
assert(isfile(zhPath), 'Missing Chinese root README.');
assert(localHasCJK(fileread(zhPath)), ...
    'README.zh-CN.md must contain the current Chinese overview.');

readmeText = fileread(fullfile(projectRoot, 'README.md'));
zhText = fileread(zhPath);
assert(contains(readmeText, 'README.zh-CN.md'), ...
    'English README must link to README.zh-CN.md.');
assert(contains(zhText, 'README.md'), ...
    'Chinese README must link back to README.md.');

fprintf('  [OK] current docs follow the English/Chinese split\n');
fprintf('=== Current documentation language policy gate PASSED ===\n');
end

function tf = localHasCJK(text)
% localHasCJK - Detect CJK characters in Markdown text.
chars = double(char(text));
tf = any(chars >= hex2dec('4E00') & chars <= hex2dec('9FFF'));
end
