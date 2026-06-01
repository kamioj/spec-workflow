---
description: 讨论模式。期间所有发言只作思考材料，不动任何文档。用于头脑风暴方向、对方案有疑虑想聊清楚再决定怎么改
allowed-tools: Read
---

# /sdd:chat

主题：$ARGUMENTS

## 进入讨论模式

期间所有用户发言**视为思考材料，不动任何文档**。
- 不写 research.md
- 不写 proposal.md
- 不调 /sdd:revise
- 不写项目源码

可以 Read 已有产物作为讨论上下文。

## 价值

把"讨论态"显式标记。避免 Claude 在你给意见时自动改文档——这是 sdd 工作流的"安全停顿区"。

## 退出条件

用户说出明确指令切换到其他模式：

| 用户说 | 进入 |
|---|---|
| "按刚才聊的改 proposal" / "改 X 段" | `/sdd:revise [section]` |
| "重新查 X" / "调研 Y" | `/sdd:research <方向>` |
| "刚才聊出 N 个 TBD，问我" | `/sdd:ask` |
| "需要画下架构图" | `/sdd:design` |
| "我们明天再聊" / "先这样" | 保持 chat 态 |

**没有明确切换指令 → 保持 chat 模式继续聊**。

## 反模式

- ❌ 用户给了观点 → 立刻去改 proposal（这不是 chat，是越权）
- ❌ 给方案 A / B / C → 没问用户偏好就帮他选了（这是 /sdd:ask 的事）
- ❌ 聊着聊着写代码（chat 期间禁止 Write/Edit 项目源码）
- ❌ 聊完总结一份"会议纪要 md"（不动文档就是不动文档）

## 跟其他命令的边界

| 命令 | 动 proposal | 动 research | 你给 Claude 的信号 |
|---|---|---|---|
| `/sdd:chat` | ❌ | ❌ | "只聊，先别动手" |
| `/sdd:ask` | ❌ | ✅（TBD→Decided） | "结构化问我偏好型决策" |
| `/sdd:revise [seg]` | ✅（局部） | ❌ | "我已经想清楚要改 X 段" |
| `/sdd:propose` | ✅（整体） | ❌ | "从头写或重写" |
