function test_phase13_production_comment_audit()
%TEST_PHASE13_PRODUCTION_COMMENT_AUDIT Gate production comments and references.
% 中文说明：验证生产 MATLAB 文件已完成双语头注释和参考资料字段审计。

fprintf('=== Phase 13 production comment audit ===\n');
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

summary = csrd.support.docs.auditProductionComments( ...
    'ProjectRoot', projectRoot, 'ApplyFixes', false);

assert(summary.FilesAudited >= 200, ...
    'Production comment audit covered too few MATLAB files.');
assert(summary.MissingBilingualHeader == 0, ...
    'Production files missing bilingual headers: %d.', ...
    summary.MissingBilingualHeader);
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
