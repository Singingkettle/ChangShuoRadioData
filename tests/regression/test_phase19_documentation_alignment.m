function test_phase19_documentation_alignment()
%TEST_PHASE19_DOCUMENTATION_ALIGNMENT Guard current documentation layout.
% 中文说明：防止当前入口文档再次漂移到已删除目录、失效链接或生成型审计清单。

fprintf('=== Phase 19 documentation alignment ===\n');

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

localAssertActiveDocsDoNotReferenceRemovedPaths(projectRoot);
localAssertDocsReadmeLinksExist(projectRoot);
localAssertNoGeneratedAuditJson(projectRoot);
localAssertSourceLayoutMatchesPackages(projectRoot);

fprintf('=== Phase 19 documentation alignment PASSED ===\n');
end


function localAssertActiveDocsDoNotReferenceRemovedPaths(projectRoot)
% localAssertActiveDocsDoNotReferenceRemovedPaths - Check current docs only.
% 输入 / Inputs: projectRoot is the repository root.
% 输出 / Outputs: raises assertion failures on stale current-doc references.
activeDocs = {
    fullfile(projectRoot, 'README.md')
    fullfile(projectRoot, 'docs', 'README.md')
    fullfile(projectRoot, 'docs', 'configuration.md')
    fullfile(projectRoot, 'docs', 'architecture', 'source-layout.md')
    fullfile(projectRoot, 'docs', 'README_Weather.md')
    fullfile(projectRoot, 'docs', 'README_Refactoring.md')
    };

for k = 1:numel(activeDocs)
    path = activeDocs{k};
    assert(isfile(path), 'Missing active documentation file: %s', path);
    text = fileread(path);
    forbidden = {
        '+csrd/+utils'
        'csrd.utils.'
        'UpdateAntennaConfigTest.m'
        'updateTransmitterAntennaConfig.m'
        'applyAntennaConfigFromSegments.m'
        'README_CommunicationBehavior.md'
        };
    for f = 1:numel(forbidden)
        assert(~contains(text, forbidden{f}), ...
            'Active documentation %s still references removed path/token: %s', ...
            path, forbidden{f});
    end
end
end


function localAssertDocsReadmeLinksExist(projectRoot)
% localAssertDocsReadmeLinksExist - Validate local links in docs/README.md.
% 输入 / Inputs: projectRoot is the repository root.
% 输出 / Outputs: raises assertion failures on missing local Markdown links.
docsReadme = fullfile(projectRoot, 'docs', 'README.md');
text = fileread(docsReadme);
matches = regexp(text, '\[[^\]]+\]\(([^\)]+)\)', 'tokens');
baseDir = fileparts(docsReadme);
for k = 1:numel(matches)
    target = strtrim(matches{k}{1});
    if startsWith(target, "http") || startsWith(target, "mailto:") || ...
            startsWith(target, "#")
        continue;
    end
    target = regexp(target, '#', 'split');
    target = strtrim(target{1});
    if isempty(target)
        continue;
    end
    target = regexprep(target, '^<|>$', '');
    resolved = fullfile(baseDir, char(target));
    assert(isfile(resolved) || isfolder(resolved), ...
        'docs/README.md links to missing local target: %s', char(target));
end
end


function localAssertNoGeneratedAuditJson(projectRoot)
% localAssertNoGeneratedAuditJson - Ensure generated audit manifests are not committed.
% 输入 / Inputs: projectRoot is the repository root.
% 输出 / Outputs: raises assertion failures when JSON reports are committed.
reportDir = fullfile(projectRoot, 'docs', 'audits', 'reports');
jsonFiles = dir(fullfile(reportDir, '*.json'));
assert(isempty(jsonFiles), ...
    'Generated audit JSON manifests must live under ignored artifacts/, not docs/audits/reports/.');
end


function localAssertSourceLayoutMatchesPackages(projectRoot)
% localAssertSourceLayoutMatchesPackages - Check one-level +csrd packages.
% 输入 / Inputs: projectRoot is the repository root.
% 输出 / Outputs: raises assertion failures if architecture docs omit a package.
sourceLayout = fileread(fullfile(projectRoot, 'docs', 'architecture', 'source-layout.md'));
listing = dir(fullfile(projectRoot, '+csrd', '+*'));
names = sort(string({listing([listing.isdir]).name}));
for k = 1:numel(names)
    token = "+csrd/" + names(k);
    assert(contains(sourceLayout, token), ...
        'docs/architecture/source-layout.md does not document package %s.', token);
end
assert(~contains(sourceLayout, '+csrd/+utils'), ...
    'Current source layout must not document a production +utils package.');
end
