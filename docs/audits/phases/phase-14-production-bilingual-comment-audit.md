# Phase 14：生产全链路函数/方法级中英文双语注释补救

## Scope / 范围

- Production scope / 生产范围：`+csrd/`、`config/`、`tools/` 下全部 `.m` 文件。
- Excluded scope / 排除范围：`tests/` 不作为强制双语注释对象，仅新增门禁测试。
- Required level / 验收粒度：文件头、`classdef`、每个 `function`/方法/local helper 都必须有英文职责说明和中文职责说明；有参数或返回值的函数还必须有简短双语输入输出说明。
- References / 参考资料：只在文件确实引用外部标准、法规、MathWorks API 或工程资料时保留文件级 `References / 参考资料`，不强行填空引用块。

## Investigation / 调研记录

Phase 13 的 `auditProductionComments` 只检查文件头附近是否同时出现英文和中文，因此像 `DSBAM.m` 这种“文件头中文、类/方法说明仍基本英文”的情况会被误判为通过。Phase 14 将审计口径改为声明级：解析每个 `classdef` 和 `function`，读取其完整声明结束行之后的紧邻注释块，分别检查英文、中文和输入输出说明。

初次声明级审计结果：

- Files / 文件数：234
- Declarations / 声明数：923
- Missing declaration bilingual comments / 缺声明级双语说明：645
- Missing bilingual I/O comments / 缺双语输入输出说明：808
- Reference heading issues / 参考资料标题问题：0

## Design / 设计决定

- `csrd.support.docs.auditProductionComments` 保留 Phase 13 兼容字段，同时新增 `DeclarationsAudited`、`MissingDeclarationBilingualComment`、`MissingDeclarationInputOutputComment` 和 `DeclarationRecords`。
- 解析 MATLAB 续行声明，确保注释插入到完整 `classdef/function ...` 声明之后，不落入 `...` 中间。
- 对 `DSBAM.m`、`SSBAM.m`、`PM.m`、`BaseModulator.m` 做人工样板修订，覆盖职责、输入、输出和关键算法步骤。
- 对剩余生产声明执行机械补齐：优先保留已有英文说明，只补缺失的中文职责和简短 I/O 行；没有说明块的声明补一组短双语说明，避免逐行灌注释。

## Implementation / 实施记录

- Upgraded audit tool / 升级审计工具：
  - `+csrd/+support/+docs/auditProductionComments.m`
- Added regression gate / 新增回归门禁：
  - `tests/regression/test_phase14_production_bilingual_comment_audit.m`
- Generated manifest / 生成审计清单：
  - Regenerate under `artifacts/audits/reports/phase-14-production-comment-audit.json`.
  - The JSON manifest is not committed because it is large and reproducible.
- Manual sample remediation / 人工样板补救：
  - `+csrd/+blocks/+physical/+modulate/+analog/+AM/DSBAM.m`
  - `+csrd/+blocks/+physical/+modulate/+analog/+AM/SSBAM.m`
  - `+csrd/+blocks/+physical/+modulate/+analog/+PM/PM.m`
  - `+csrd/+blocks/+physical/+modulate/BaseModulator.m`
- Reference remediation / 参考资料补救：
  - Added explicit `References / 参考资料` blocks for obvious MathWorks API dependencies in `BaseModulator.m` and the analog AM/FM/PM modulators that rely on `obw`, `hilbert`, `fft/ifft`, or `comm.OSTBCEncoder`.

## Current Result / 当前结果

After applying Phase 14 fixes / 应用补救后：

- Files / 文件数：234
- Declarations / 声明数：923
- Missing declaration bilingual comments / 缺声明级双语说明：0
- Missing bilingual I/O comments / 缺双语输入输出说明：0
- Reference heading issues / 参考资料标题问题：0
- Anonymous declaration names / 匿名声明名：0

## Verification Plan / 验证计划

- Targeted static gate / 静态门禁：
  - `test_phase14_production_bilingual_comment_audit`
  - `test_phase13_production_comment_audit`
- Syntax and pipeline protection / 语法与链路保护：
  - `git diff --check`
  - modulation smoke or affected unit gates
  - `run_all_tests('phase2')`
  - `run_all_tests('phase3')`
  - `run_all_tests('phase4')`
  - `run_all_tests('phase8')`
  - `run_all_tests('phase9')`
  - `run_all_tests('unit')`
  - `run_all_tests('regression')`
- Formal entry validation / 正式入口验证：
  - `simulation(1, 1, 'csrd2025/csrd2025_full_coverage_validation.m')`

## Verification Results / 验证结果

Completed on 2026-04-30 / 已于 2026-04-30 完成：

- `test_phase14_production_bilingual_comment_audit`：PASS，234 files / 923 declarations，0 missing bilingual declarations，0 missing bilingual I/O comments。
- `test_phase13_production_comment_audit`：PASS，Phase 13 文件级门禁仍兼容。
- `git diff --check`：PASS；仅 Git 提示部分文件未来触碰时 LF 会被替换为 CRLF，无 whitespace error。
- `run_all_tests('phase2')`：PASS，9/9。
- `run_all_tests('phase3')`：PASS，9/9，包含一次 simulation construction smoke。
- `run_all_tests('phase4')`：PASS，10/10，包含 measured truth coverage N=20。
- `run_all_tests('phase8')`：PASS，10/10，法规 catalog/selector/pipeline/region matrix/unified coverage 均通过。
- `run_all_tests('phase9')`：PASS，2/2，从 `tools/simulation.m` 入口完成 quick coverage sweep。
- `run_all_tests('unit')`：PASS，53/53。
- `test_phase13_full_coverage_config_load`：PASS，构建 47 个 full coverage validation cases；building OSM case 因当前 MATLAB runtime 缺少 RF propagation site functions 被显式 skip。
- Formal full coverage entry / 正式入口：
  - Command / 命令：`simulation(1, 1, 'csrd2025/csrd2025_full_coverage_validation.m')`
  - Result / 结果：46 passed, 1 skipped, 0 failed。
  - Skip reason / 跳过原因：building OSM runtime dependency unavailable，按设计显式记录，不伪装为通过。
- Hygiene / 卫生检查：
  - `csrd_simulation_output`：not found / 未发现。
  - Final declaration audit / 最终声明审计：234 files / 923 declarations / 0 missing bilingual declarations / 0 missing bilingual I/O comments / 0 reference heading issues。

One attempted full directory regression run (`run_all_tests('regression')`) exceeded the 20 minute tool timeout and was stopped. Its heavy coverage overlaps the phase gates above; the timeout is recorded as incomplete rather than passed or failed.

一次完整目录级 `run_all_tests('regression')` 在 20 分钟工具超时后被终止。本阶段不把它记为通过或失败；其主要重型路径已由 Phase4/8/9、unit 与正式 full coverage 入口覆盖。

## Notes / 备注

This phase only changes comments and the static audit gate. No signal-generation logic, regulatory planning logic, channel logic, or annotation field contract is intentionally changed in Phase 14.

本阶段只改注释与静态审计门禁，不有意改变信号生成、法规频谱规划、信道执行或 annotation 字段契约。
