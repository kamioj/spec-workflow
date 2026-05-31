---
description: 三维验证（completeness / correctness / coherence）。可独立重跑——想只重新验证不动实施时调
allowed-tools: Read, Bash, Grep, Glob
---

# /sdd:verify

## 三维验证框架

### 1. Completeness（完整性）

- proposal `## What` 的每个项都实现了吗？
- 接口契约（design.md 若有）的输入 / 输出都对齐？
- 测试覆盖关键路径？

### 2. Correctness（正确性）

- 编译 / 类型检查通过？
- 单元 / 集成测试通过？
- 边界 case（空 / 极值 / 异常输入）处理正确？
- 若验证输出很长，优先委派子代理归纳失败原因，只带回关键错误和证据路径。

### 3. Coherence（一致性）

- 改动跟 proposal `## How` 的决策一致？
- **没做 proposal 没要求的事**（scope creep）？
- 符合 `skills/sdd/references/<栈>.md` 的代码规范？

## 输出格式

```
=== Verify ===
Completeness: <pass / fail / partial> - <说明>
Correctness:  <pass / fail / partial> - <说明>
Coherence:    <pass / fail / partial> - <说明>

整体：<pass / fail>
```

**verify 不主动推荐"下一步用哪个命令"**——这是 `/sdd:status` 的职责。verify 只报告验证结果。用户拿到结果自己决定（继续修 / 归档 / 进新阶段），或调 `/sdd:status` 看推荐路径。

## 失败处理（定位，不修复）

verify 失败时**报告具体失败点**，不主动建议修复路径：

| 维度 fail | 报告内容 |
|---|---|
| **Completeness** | 列出 proposal `## What` 里**未实现**的项；列出 design.md `## Interfaces`（若有）里**未对齐**的接口 |
| **Correctness** | 贴**报错原文** + 文件 / 行号；列出测试 fail 的 case 名 + 期望 vs 实际 |
| **Coherence** | 指出与 proposal `## How` 决策**不一致**的地方；列出 scope creep（做了 proposal 没要求的事）；列出违反 `references/<栈>` 规范的点 |

**判定原则**：verify 描述**问题**，不规定**解决方案**——修复路径由用户 / 主对话决定（可能调 apply 续修 / revise 改 proposal / 主对话自理）。

## 反作弊

- **未实际跑通的测试不许标 pass**——肉眼通读代码不算 Correctness pass
- partial 必须说清楚哪里 partial，不许笼统说"基本通过"
- "测试失败但与本次改动无关"必须**实证**（跑 main 分支或对照实验），不许凭印象写

## 不做的事

- 不修代码（修是 `/sdd:apply` 的事）
- 不改 proposal（改是 `/sdd:revise` 的事）
- 不归档（归档是 `/sdd:archive` 的事）
