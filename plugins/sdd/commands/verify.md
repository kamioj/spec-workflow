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
下一步：<继续 apply / 修 X / 走 /sdd:revise / 问用户>
```

## 失败处理

- 三维任一 fail → 按 `/sdd:apply` 的失败定层归类处理
- 全 pass → 提示"可走 /sdd:archive 归档"

## 反作弊

- **未实际跑通的测试不许标 pass**——肉眼通读代码不算 Correctness pass
- partial 必须说清楚哪里 partial，不许笼统说"基本通过"
- "测试失败但与本次改动无关"必须**实证**（跑 main 分支或对照实验），不许凭印象写

## 不做的事

- 不修代码（修是 `/sdd:apply` 的事）
- 不改 proposal（改是 `/sdd:revise` 的事）
- 不归档（归档是 `/sdd:archive` 的事）
