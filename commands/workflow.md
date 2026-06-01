---
description: SDD 全流程一把梭。从调研到归档自动跑完，遇到拷问必停、遇到 HARD GATE 必停。兼容旧 /sdd 入口。触发词：先 spec / 提案 / 先设计 / 先出方案
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# /spec:workflow

任务：$ARGUMENTS

## 何时使用

大改动（>150 行 / 跨 3+ 文件 / 引入新依赖 / 架构选择）。trivial/small/medium 直接做，**绝不激活本流程**。

## 执行顺序

按下面顺序依次调用各阶段命令。**任一阶段遇到用户驳回或 placeholder scan / HARD GATE 失败 → 停下来汇报，不要硬推**。

1. **`/spec:research <方向>`** — 调研业界做法 + 关键约束 + 标记 `[TBD]` 待决点
2. **`/spec:ask`** — 用 AskUserQuestion 逐个消化 `[TBD]` → 移到 `## Decided`
   - 期间可能浮现新 [TBD]，加入清单继续问
3. **判断是否需要 `/spec:design`** — 满足任一则调：
   - **跨前后端**（同时改 UI 和服务端，含接口契约）← 此场景下 design 是**必须**，非可选
   - 接口数 >3 个
   - 需要架构图 / 数据流图 / 序列图
   - 决策深度论证 >300 字
4. **`/spec:propose`** — 写 proposal.md 四段（重大方案可加 `--codex` 让 codex 异构挑刺）
   - 写前 hook 会扫 research.md `[TBD]` 是否清空（placeholder scan）
5. **HARD GATE** — 输出固定收尾"=== 提案就绪 ==="，等用户确认
   - **确认前绝不写代码**；满意 → 直接进 `/spec:apply`（apply 自动追加 APPROVED，无需回 go）
   - 驳回 → 走 `/spec:revise [section]`（微调）或 `/spec:chat`（重聊方向）
6. **`/spec:apply`** — 实施代码，按 proposal/tasks 推进
   - 命令前 hook 会检查 proposal 含 APPROVED 标记
7. **`/spec:verify`** — 三维验证；关键改动可加 `--codex` 引入 codex 异构他审（`--fix` 让 codex 改）
8. **等用户说"归档"** → `/spec:archive`

## 中途允许的"插队"命令

- `/spec:chat` — 进入讨论模式，不动文档
- `/spec:ask` — 重新拷问一轮（新增 [TBD]）
- `/spec:research <新方向>` — 重新调研，旧产物归档不删
- `/spec:status` — 查当前在哪阶段

## 反作弊原则

- 未跑通的命令 / 未验证的输出**不许伪装为成功**
- workaround 让"看起来通过"必须明说"绕过，真因未解"
- 任务前提错（题目矛盾 / 范围外 / 工具不兼容）→ 立即停下汇报"任务不可行"
