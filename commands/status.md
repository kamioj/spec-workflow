---
description: 报告当前 SDD change 在哪一步、有哪些产物、下一步可走哪些命令。被打断后回来不知道在哪时用
allowed-tools: Read, Glob, Bash(ls:*)
---

# /sdd:status

## 任务

读 `spec/changes/` 目录（不含 `archive/`），输出当前 change 状态。

## 检查流程

1. **Glob `spec/changes/*/`** 列出所有未归档 change
2. 对每个 change 检查产物存在性：
   - `research.md`、`design.md`、`proposal.md`、`tasks.md`
3. 读 `research.md` 统计 `[TBD-N]` 数量和 `## Decided` 段条目数
4. 读 `proposal.md` 检查是否含 HARD GATE 批准标记（`<!-- APPROVED: YYYY-MM-DD HH:mm -->`）

## 输出格式

无活跃 change：

```
无活跃 SDD change。
开新任务：/sdd:research "<方向>"
```

有活跃 change：

```
活跃 change：<kebab-name>
产物：
  research.md ✓
    Open [TBD]: <N> 个
    Decided:    <M> 条
  design.md   <✓/✗>（未产出时备注是否需要）
  proposal.md ✓（HARD GATE: <待批准 / 已批准 / 驳回>）
  tasks.md    <✓/✗>

当前阶段：<按下方状态机判定>
下一步推荐：<按下方状态机映射选具体内容，不要凭记忆生成>
```

多个未归档 change → 全部列出，让用户选用 `/sdd:switch <name>`（如未实现则提示用户手动指定）。

## 状态机映射（"当前阶段" + "下一步推荐"输出的权威定义）

**严格按下表生成输出**，不要基于训练数据凭记忆补——否则会输出已废弃的旧流程（如"回 开始|go|实施"）。

| 检测条件 | 当前阶段 | 下一步推荐（直接输出这段文本） |
|---|---|---|
| `spec/changes/` 空 | 无活跃 change | `/sdd:research "<方向>"` 开新调研 |
| `research.md` 存在 + `## Open [TBD]` 非空 | 调研含 TBD | `/sdd:ask` 消化待决点 |
| `research.md` 存在 + Open [TBD] 空 + 无 `proposal.md` | 拷问完待 propose | 复杂任务先 `/sdd:design`（架构 / 接口 >3 / 数据流图）；否则 `/sdd:propose` |
| `proposal.md` 存在 + **无** `<!-- APPROVED: ... -->` 标记 | 待批准 HARD GATE | ✅ 满意 → `/sdd:apply`（apply 自动追加 APPROVED 后实施）<br>🔧 局部改 → `/sdd:revise [why \| what \| how \| risk]`<br>💭 想讨论 → `/sdd:chat`<br>🔄 方向变了 → `/sdd:research "<新方向>"` |
| `proposal.md` 含 APPROVED + tasks.md（如有）有未勾任务，或代码改动未跑 verify | 实施中 | `/sdd:apply` 续做 / 每完成一节点就近 `/sdd:verify` |
| 主体实施完毕但未跑 verify | 待验证 | `/sdd:verify` 跑三维验证 |
| `/sdd:verify` 报告含 fail | 验证失败 | 看 verify 报告决定：`/sdd:apply` 续修 / `/sdd:revise` 改 proposal（若 proposal 错） |
| `/sdd:verify` 三维全 pass | 验证通过（自审） | 可选：codex 异构他审 → `/sdd:verify --codex`（补盲区，--fix 让 codex 改）。**不主动推 archive**——要归档时调 `/sdd:archive` |
| 用户说"归档" | 待归档 | `/sdd:archive` |

**关键反模式**：

- ❌ 待批准阶段输出"批准 → 回 开始/go/实施"（**已废弃**——现在 `/sdd:apply` 自动追加 APPROVED，不需要"回 go"中间步骤）
- ❌ 验证通过阶段主动推"可走 /sdd:archive 归档"（用户决定，不主动 push）
- ❌ 凭记忆补"下一步推荐"——必须按本表对照当前阶段输出

## 不做的事

- 不创建、不修改任何文件
- 只读不写
