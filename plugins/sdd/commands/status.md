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
4. 读 `proposal.md` 检查是否含 HARD GATE 批准标记（`<!-- APPROVED -->` 或 `## HARD GATE: APPROVED`）

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
    Open [TBD]: N 个
    Decided:    M 条
  design.md   ✗（未产出，复杂任务可调 /sdd:design）
  proposal.md ✓（HARD GATE: 待批准 / 已批准 / 驳回）
  tasks.md    ✗

当前阶段：<研究 / 拷问 / 设计 / 提案 / 待批准 / 实施 / 验证 / 待归档>
下一步推荐：/sdd:xxx
```

多个未归档 change → 全部列出，让用户选用 `/sdd:switch <name>`（如未实现则提示用户手动指定）。

## 不做的事

- 不创建、不修改任何文件
- 只读不写
