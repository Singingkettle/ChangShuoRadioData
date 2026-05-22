function test_phase13_production_comment_audit()
%TEST_PHASE13_PRODUCTION_COMMENT_AUDIT Gate production comments and references.

fprintf('=== Phase 13 production comment audit ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

summary = csrd.support.docs.auditProductionComments( ...
    'ProjectRoot', projectRoot, 'ApplyFixes', false);

assert(summary.FilesAudited >= 200, ...
    'Production comment audit covered too few MATLAB files.');
assert(summary.MissingEnglishHeader == 0, ...
    'Production files missing English headers: %d.', ...
    summary.MissingEnglishHeader);
assert(summary.FilesWithChineseComments == 0, ...
    'Production files with Chinese MATLAB comments: %d.', ...
    summary.FilesWithChineseComments);
assert(summary.ReferenceHeadingIssues == 0, ...
    'Production files with non-unified reference headings: %d.', ...
    summary.ReferenceHeadingIssues);

paths = string({summary.Records.Path});
assert(any(startsWith(paths, '+csrd')), 'Audit did not cover +csrd.');
assert(any(startsWith(paths, 'config')), 'Audit did not cover config.');
assert(any(startsWith(paths, 'tools')), 'Audit did not cover tools.');

fprintf('  [OK] production files audited: %d\n', summary.FilesAudited);
fprintf('=== Phase 13 production comment audit PASSED ===\n');
end
