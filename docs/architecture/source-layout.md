# CSRD Source Layout / 源码目录说明

This document describes the current source layout. Historical audit documents
may mention older paths; use this page and the root README for current structure.

本文描述当前源码结构。历史审计文档可能保留旧路径；当前目录以本文和根目录 README 为准。

## Production Entry Points / 生产入口

- `tools/simulation.m`: public generation entry point.
- `csrd.runtime.config_loader`: modular config loader and runtime contract normalizer.
- `+csrd/SimulationRunner.m`: multi-scenario orchestration, logging, save hooks, annotation validation.
- `+csrd/+core/@ChangShuo`: per-scenario frame generation engine.

## Package Responsibilities / 包职责

| Package | Responsibility |
| --- | --- |
| `+csrd/+blocks` | Scenario and physical System objects: environment, communication behavior, RF, channel, modulation, and messages. |
| `+csrd/+catalog` | Regulatory spectrum catalogs and reusable profile libraries. |
| `+csrd/+core` | `ChangShuo` engine and private helpers that connect planned scenario facts to executed frames. |
| `+csrd/+factories` | Factory objects that construct execution blocks from planned configuration. |
| `+csrd/+pipeline` | Cross-module contracts: annotation, blueprint, runtime, link budget, measurement, scenario, signal gating. |
| `+csrd/+runtime` | Runtime services: logging, config loading, toolbox checks, system information, RF capabilities, map helpers. |
| `+csrd/+support` | Validation, documentation, hashing, path, random, and optimization utilities. |
| `+csrd/+test_support` | Test-only helpers and failure stubs. |
| `+csrd/+tests` | Internal test harness support. |

Do not reintroduce a catch-all production utility package; it was removed.

不要重新引入泛化生产工具包；该包已经移除。

## Communication Behavior Layout / 通信行为模块

`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator` currently has a small
class shell plus `setupImpl.m`, `stepImpl.m`, and these private helpers:

| Group | Files |
| --- | --- |
| Scenario setup | `initializeScenarioConfigurations.m`, `generateFrameConfigurations.m`, `getDefaultConfiguration.m` |
| Entity planning | `separateEntitiesByType.m`, `generateScenarioReceiverConfigurations.m`, `generateScenarioTransmitterConfigurations.m` |
| Frequency planning | `performScenarioFrequencyAllocation.m`, `allocateFrequenciesReceiverCentric.m`, `allocateFrequenciesFromRegulatoryPlan.m`, `checkFrequencyOverlap.m` |
| Time and transmission state | `initializeTransmissionScheduler.m`, `calculateTransmissionState.m`, `updateEntityCommunicationState.m` |
| Parameter helpers | `calculateRequiredBandwidth.m`, `calculateAntennaGain.m`, `randomInRange.m` |

These files plan communication state. They must not silently execute RF effects
or backfill missing runtime facts from downstream blocks.

这些文件负责规划通信状态，不应悄悄执行 RF 效应，也不应从下游模块反向补运行事实。

## Generated Output Locations / 生成物位置

- Formal dataset generation writes under `data/<DatasetName>/`.
- Full validation summaries and probe outputs stay under ignored `data/`.
- Test diagnostics, generated configs, visual overlays, and regenerated audit manifests stay under ignored `artifacts/`.
- Durable conclusions should be copied into Markdown phase docs, not committed as large generated JSON.
- Legacy `csrd_simulation_output` folders are not valid output roots and can be removed with `tools/maintenance/clean_csrd_artifacts.m`.

正式生成数据写入 ignored 的 `data/`；临时诊断、可视化和再生成审计清单写入 ignored 的
`artifacts/`。长期结论应写入 Markdown 文档，而不是提交大型生成 JSON。

## Layout Rules / 目录规则

- Prefer explicit package ownership over catch-all utility folders.
- Runtime fallbacks must be visible in metadata or annotations.
- Public docs should use current paths only.
- Historical audits may preserve old paths when describing past work.
