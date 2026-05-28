# proposal.md spec

`spec/changes/<change-name>/proposal.md` 是 sdd 工作流的**方案终态产物**。由 `/sdd:propose` 生成，含 HARD GATE 批准标记。

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
- 理由：精炼一句话（深度论证见 research.md / design.md）
- 失效策略 / 关键算法 / 关键参数 ...

## Risk
- 影响范围：哪些模块 / 接口 / 用户场景受影响
- 风险：风险点 + mitigation
- 回滚方案：怎么撤回
```

## 段约束

- 每段 **≤ 5 行**
- 撑爆 → 该写 `design.md`，**不要塞 proposal**
- `## How` 提炼 `research.md ## Decided`，不复制原文

## HARD GATE 批准标记

用户回 "开始 / go / 实施" 后，**主对话立刻**在 proposal.md 末尾追加：

```markdown
<!-- APPROVED: YYYY-MM-DD HH:mm -->
```

时间戳用当前 ISO 本地时间。

此标记是 `check-gate.ps1` hook 放行 `/sdd:apply` 的契约——**没有这一行所有后续 apply 都会被 hook 拒绝**。

## /sdd:revise 修订

任何修订必须：

1. 主动**移除旧的 `<!-- APPROVED: ... -->` 标记**
2. 改完重新输出 HARD GATE 等批准
3. 收到新批准词后追加新 APPROVED 标记

revise 后不移除旧 APPROVED → hook 误判为已批准 → apply 会跑改前的旧 proposal 逻辑。

## /sdd:revise 的可修订段

| 参数 | 改的段 |
|---|---|
| `why` | `## Why` |
| `what` | `## What` |
| `how` | `## How` |
| `risk` | `## Risk` |
| `all` | 整体重写（等价 `/sdd:propose` 重跑） |

revise 时**保留其他段不动**——只动指定段。

## 反模式

- ❌ HARD GATE 等待期间未收到批准词就提前自己加 APPROVED 标记
- ❌ 用户驳回 / 修订时仍保留旧 APPROVED
- ❌ `## How` 复制 `research.md ## Decided` 原文（要提炼）
- ❌ 段撑爆塞内容（该挪 design.md）
