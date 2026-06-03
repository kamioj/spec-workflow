# proposal.md spec

`spec/changes/<change-name>/proposal.md` 是 sdd 工作流的**方案终态产物**。由 `/spec:propose` 生成，含 HARD GATE 批准标记。

## 格式

```markdown
# Proposal: <change-name>

## Why
为什么做这次改动（业务动机 / 技术痛点 / 时间窗口）。1-3 段。

## What
具体改什么（文件 / 模块 / 接口 / 新增 / 删除 / 重命名）。可用列表。

## How
关键技术决策（从 research.md `## Decided` 提炼，**不复制原文**）：
- 选型：X（不选 Y）
- 理由：精炼一句话——**结论与理由必须自包含于此**，深度论证另见 design `## Key Decisions`（apply 不读 research，不可以指针代替结论）
- 失效策略 / 关键算法 / 关键参数 ...

## Risk
- 影响范围：哪些模块 / 接口 / 用户场景受影响
- 风险：**每个关键决策的具体隐患 + 触发场景**（非泛泛的"可能有风险"，须能说明"在何种操作下会以何种方式失败"）+ mitigation
- 回滚方案：怎么撤回
```

## 段约束

- 每段 **≤ 5 行**
- 内容超限 → 应移至 `design.md`，**不要塞入 proposal**
- `## How` 提炼 `research.md ## Decided`，不复制原文
- **What / How 须过第④问（删减）**：非平凡的 What 项 / How 决策落笔前先问"删除后会怎样"，删除无影响者不写（SKILL「主张自审」）——这是 HARD GATE 变化点能让用户一眼判断"是否批准"的前提

## HARD GATE 批准标记

`<!-- APPROVED: YYYY-MM-DD HH:mm -->` 标记由 **`/spec:apply` 命令在执行前自动追加**（视用户主动调用为批准动作）。

时间戳用当前 ISO 本地时间。

此标记同时是：
- `check-gate.ps1` hook 放行 `/spec:apply` 的契约
- **审计记录**：git log 能看到何时批准过

**propose 不直接追加 APPROVED**——HARD GATE 是用户决策节点，APPROVED 是 apply 的契约动作。两者分离使流程省去一步"回复 go"的冗余。

## /spec:revise 修订

任何修订必须：

1. 主动**移除旧的 `<!-- APPROVED: ... -->` 标记**（任何修订作废旧批准）
2. 改完重新输出 HARD GATE 等用户决策
3. 用户调 `/spec:apply` 时由 apply 自动追加新 APPROVED 标记（不需要回 "go"）

revise 后未移除旧 APPROVED → hook 误判为已批准 → apply 跳过新决策、径直执行修订前逻辑。

## /spec:revise 的可修订段

| 参数 | 改的段 |
|---|---|
| `why` | `## Why` |
| `what` | `## What` |
| `how` | `## How` |
| `risk` | `## Risk` |

revise 时**保留其他段不变**——仅修改指定段（整体重写走 `/spec:propose`）。

## 反模式

- ❌ HARD GATE 等待期间未收到批准词就提前自己加 APPROVED 标记
- ❌ 用户驳回 / 修订时仍保留旧 APPROVED
- ❌ `## How` 复制 `research.md ## Decided` 原文（应提炼）
- ❌ 段落超限仍塞入内容（应移至 design.md）
- ❌ Risk 写泛泛空话（"可能有性能风险"）而不锚定触发场景 / 具体隐患（SKILL 主张自审第③问）
- ❌ What 罗列"凡能想到的都改"、不经第④问删减（使 HARD GATE 变化点无法判断是否应批准）
