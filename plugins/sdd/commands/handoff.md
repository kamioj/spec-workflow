---
description: 生成或刷新 handoff.md，用短摘要承接新会话，降低 context window 压力。适合切项目、结束长会话、验证后或卡死前使用
allowed-tools: Read, Write, Edit, Glob, Bash(git:*)
---

# /sdd:handoff

## 任务

为当前活跃 change 生成 / 刷新：

```
spec/changes/<name>/handoff.md
```

目标是让新会话只读一个短文件即可接续，不依赖长聊天历史。

## 何时使用

满足任一就建议调：
- 准备切项目 / 结束当前会话
- 一个 change 已经历 research / propose / apply 任一阶段
- 对话已经很长，开始出现重复读文件 / 重复解释背景
- 即将跑大日志、大 diff、大范围验证
- 出现 `context_too_large` 或用户担心上下文过大

## 流程

1. 定位 `spec/changes/` 下未归档 change。
2. 读取已有产物：
   - `research.md`：只提炼 Practices / Constraints / Decided / Open [TBD] 数量
   - `design.md`：只提炼接口、数据模型、关键决策
   - `proposal.md`：只提炼 Why / What / How / Risk 和 APPROVED 状态
   - `tasks.md`：只提炼未完成任务、阻塞任务、owner / deps
3. 读取 `git status --short --branch`，记录分支和未提交改动摘要。
4. 汇总最近子代理 / worker 的短结论：只记录结论、证据路径、未覆盖风险，不贴完整输出。
5. 写入 `handoff.md`，控制在 **120 行以内**。
6. 输出一句新会话引导语，方便用户直接复制。

## handoff.md 格式

````markdown
# Handoff: <change-name>

## Goal
- <当前 change 的一句话目标>

## Current State
- 阶段：<research / ask / design / proposed / applying / verifying / blocked>
- 分支：<git branch>
- 产物：research <✓/✗> / design <✓/✗> / proposal <✓/✗> / tasks <✓/✗>
- APPROVED：<yes / no / n/a>

## Key Decisions
- [DEC-N] <关键决策，最多 6 条>

## Open Questions
- [TBD-N] <仍需用户决策，最多 6 条>

## Next Step
- <下一条最建议执行的 /sdd 命令或普通动作>

## Files To Read First
- `spec/changes/<name>/proposal.md`
- `spec/changes/<name>/tasks.md`
- `<关键源码路径，最多 8 个>`

## Delegated Work
- <子代理任务一句话>：<结论 + 证据路径；最多 6 条>

## Do Not Re-read Unless Needed
- <大 reference / 大日志 / 大 diff 路径>

## Last Verification
- <最近验证命令 + 结果；没跑就写"未验证">

## Resume Prompt
```
读取 spec/changes/<name>/handoff.md，按 Next Step 继续。不要重读大 reference，除非 handoff 指明需要。
```
````

## 上下文瘦身规则

- 不粘贴大日志：写路径 + 错误摘要。
- 不粘贴大 diff：先看 `git diff --stat`，再点读相关文件。
- 不全量读 references：只读当前技术栈需要的 1-3 个文件。
- 不把聊天历史当状态源：状态以 `handoff.md` / `proposal.md` / `tasks.md` 为准。
- 不把验证输出全文塞进 handoff：只记录命令、结论、关键错误路径。

## 反模式

- ❌ handoff 写成会议纪要长文
- ❌ 把完整日志 / 完整 diff / 完整 research 复制进去
- ❌ 没写 Next Step，导致新会话重新判断阶段
- ❌ Files To Read First 列 20+ 文件
