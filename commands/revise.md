---
description: 局部修改 proposal.md 某一段（why / what / how / risk）。整体重写走 /spec:propose。改完必须重新 HARD GATE
allowed-tools: Read, Edit
---

# /spec:revise

目标段：$ARGUMENTS

## 流程

1. 解析参数：

| 参数 | 改的段 |
|---|---|
| `why` | `## Why` |
| `what` | `## What` |
| `how` | `## How` |
| `risk` | `## Risk` |
| 无 | 询问用户改哪段（用 AskUserQuestion） |

2. Read `spec/changes/<name>/proposal.md`，定位目标段
3. **移除旧的 `<!-- APPROVED: ... -->` 批准标记**（任何修订作废旧批准）
4. Edit 目标段，**保留其他段不动**
5. **重新输出 HARD GATE**

## HARD GATE 重新输出

任何修订必须重过 HARD GATE：

```
<HARD-GATE>
=== 提案修订（<section>）===
路径：spec/changes/<name>/proposal.md
变化点：<改了什么>
（旧 APPROVED 标记已移除）

下一步：
  ✅ 满意 → 调 /spec:apply 进入实施
     apply 会自动追加新的 <!-- APPROVED: ... --> 标记
  🔧 还要再改某段 → /spec:revise [why | what | how | risk]
  💭 想再讨论 → /spec:chat
  🔄 方向变了，重做调研 → /spec:research "<新方向>"
</HARD-GATE>
```

**禁止沿用旧批准状态**。

## 适用场景

- HARD GATE 等批准时用户说"How 段把 Caffeine 改成 Redis" → `/spec:revise how`
- 实施中发现 Risk 漏了一项 → `/spec:revise risk` 补
- `/spec:chat` 头脑风暴完决定改 Why → `/spec:revise why`

## 跟其他命令的边界

| 场景 | 用什么 |
|---|---|
| 目标变了，需要重新调研 | `/spec:research <新方向>` |
| 只想聊不动文档 | `/spec:chat` |
| 整体重写 proposal | `/spec:propose`（revise 只改单段；propose 有 hook 守 TBD / 单-change，revise 无 hook） |
| 局部改 proposal 某段 | `/spec:revise [section]` |

## 反模式

- ❌ 改了某段没重过 HARD GATE 就继续推进
- ❌ 没移除旧 APPROVED 标记（让 `/spec:apply` hook 误以为已批准）
- ❌ 改了一段顺手"清理"其他段（用户没说就别动）
