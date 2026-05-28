---
description: 实施代码，按 proposal/tasks 推进。命令前 hook 检查 proposal.md 含 APPROVED 标记。增量验证：每节点做完就近调 /sdd:verify，不攒到最后
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /sdd:apply

## 前置检查 + 自动批准

1. **检查 proposal.md 存在性**：
   - 不存在 → 报错，提示用户先调 `/sdd:propose`
   - 存在但缺四段（Why / What / How / Risk 任一缺失）→ 报错，提示先调 `/sdd:revise` 补全

2. **自动追加 APPROVED 标记**（视用户主动调用 `/sdd:apply` 为批准动作）：
   - proposal.md 末尾**无** `<!-- APPROVED: ... -->` 标记 → 立即追加：
     ```markdown
     <!-- APPROVED: YYYY-MM-DD HH:mm -->
     ```
     时间戳用当前 ISO 本地时间
   - 已有 APPROVED 标记（来自 `/sdd:auto` 流程或上次 apply）→ 不重复追加

3. **hook 校验**：`check-gate.ps1` 仍在 `UserPromptSubmit` 时机检查 —— apply 自动追加后 hook 顺利放行（作为审计层和兜底防御）。

   罕见情况下 hook 阻断（如 proposal.md 缺失 / 名字不对）→ 按 hook 错误信息处理，不强行绕过。

## 范围确定

读 proposal.md 的 `## What`：
- **无 tasks.md** → 全量按 proposal 推进
- **有 tasks.md 单执行体** → 按 tasks 顺序
- **有 tasks.md 多执行体** → 只做本 owner 任务（先 checkout `feat/<name>-<owner>`）

## 派遣专属 agent

按 proposal `## What` 涉及的代码类型派单：

| What 涉及 | 派单方式 |
|---|---|
| UI / 路由 / 组件 / 样式 / 客户端交互 | `sdd-frontend-dev` |
| 服务端逻辑 / API / 数据模型 / DB 迁移 / 中间件 | `sdd-backend-dev` |
| **跨前后端（含接口契约改动）** | **契约先固化 → 并行派单**（见下） |
| 配置 / 脚本 / CI / 文档 | 主对话自理 |

### 跨前后端：契约先行 + 并行实施

**禁止串行做法**（先后端再前端 = 浪费 50% 时间）。正确流程：

1. **前置检查**：`design.md` 的 `## Interfaces` 段必须已写明：
   - endpoint / method / path
   - 输入 schema
   - 输出 schema
   - 错误码 + 错误响应结构

   缺则**拒绝派单**，先走 `/sdd:design` 把契约固化。

2. **并发派单**（同一条消息发出两个 Agent 调用）：
   - `sdd-backend-dev`：实现服务端，先返回符合契约的 mock 数据，再接真实数据源
   - `sdd-frontend-dev`：实现客户端骨架，用 mock 数据 / TypeScript 类型对接契约

   两个 agent **不互相等待**，各自按 design.md `## Interfaces` 推进。

3. **联调阶段**（两个 agent 都报"实施完成"后）：
   - 后端切真实数据
   - 前端切真实接口
   - 端到端测试

**契约 = 高扇出节点**：tasks.md 应明确：

```
- [ ] 1. 接口契约（已在 design.md ## Interfaces 落地）
- [ ] 2. 后端实现        owner: backend   deps: 1
- [ ] 3. 前端骨架(mock)  owner: frontend  deps: 1
- [ ] 4. 联调切真实接口   deps: 2, 3
```

第 2 和第 3 步**互不依赖**（都只依赖第 1 步），所以并行。

### 专属 agent 的优势

agent 自动加载对应技术栈 references（vue-style / java-conventions 等）+ 继承 sdd plugin 共享精神（反作弊 / 卡死保护 / 任务不可行叫停）。

### 可选 flag：principles 加强

`/sdd:apply` 支持三个 flag，空格分隔，可组合，可省略。

| flag | 启用项 | 效果 |
|---|---|---|
| `design` | anti-ai-slop | sdd-frontend-dev 读 `skills/sdd/references/frontend-aesthetics.md` |
| `solid` | anti-laziness | agent 读 `skills/sdd/references/agent-principles.md` § 一 |
| `verify` | anti-hallucination | agent 读 `skills/sdd/references/agent-principles.md` § 二 |

**$ARGUMENTS 解析**：split 空格，对每个 token 检查是否在 `{design, solid, verify}` 集合里。命中的转成派遣 prompt 的"启用 anti-X"指令，没命中的 token 当作错别字提示用户。

**用法示例**：

| 命令 | 行为 |
|---|---|
| `/sdd:apply` | 默认，轻量实施 |
| `/sdd:apply design` | 前端 agent 加载反 AI slop |
| `/sdd:apply solid verify` | 反偷懒 + 反幻觉 |
| `/sdd:apply design solid verify` | 三件套全启用 |

**默认不带任何 flag**——避免在常规工具型 UI / 内部页 / 后端服务里过度保守。

主对话只在派单失败 / 跨执行体协调 / agent 报告卡死时介入。

## 实施 + 增量验证

- 按 deps 推进，只动 deps 已完成的任务
- 多个 deps 满足且互不依赖 → **优先派两个专属 agent 并发**（前后端独立的话）
- 每完成一个（或一组并行）节点 → 就近调 `/sdd:verify`，**不攒到最后**
- 完成的任务在 tasks.md 标 `[x]` —— **谁完成谁标**：dev agent 标自己 owner 的子任务；主对话标自理项（如配置 / 脚本 / 跨模块协调类）

## 失败定层

跑 verify 失败 → 先诊断后修，按归类处理：

| 现象 | 归类 | 处理 |
|---|---|---|
| 没实现到 proposal 要求 | 实施未完成 | 继续 apply |
| 语法 / 类型 / 边界错 | 单点 bug | 直接修 |
| 做了 proposal 没要求的事 | 偏离 | 回到 proposal 重新对齐 |
| 完全照 proposal 做仍不对 | proposal 错 | 停下走 `/sdd:revise`（多半 ask 漏问到这点） |

**严禁默改 proposal 适配已写的代码**——proposal 是"该做什么"的真理。

## 卡死保护

同一报错 / 用例，连续 **3 次**修复尝试仍失败 → 立即停下汇报。

一次尝试 = 新假设 + 改码 + 验证；重跑同样代码 / 修 typo / 调日志**不算**。

```
=== 卡死自检 ===
现象：<一句话>
已试三个假设：
  1. <假设> → <结果>
  2. <假设> → <结果>
  3. <假设> → <结果>
推断真因：<能推断写真因，否则"未知">
建议换方向：<有则写，否则"等用户指示">
```

等用户决策，**禁止无限 patch**。

## 反作弊

- 未实际跑通的命令 / 测试**不许汇报为"成功"**
- workaround 让"看起来通过"（mock 假响应、改 assert、patch 检查函数返回 true）**必须明说**"绕过，真因未解"
- 硬编码（偏移、固定 hash）若必要必须在代码注释 + tasks.md 标注"仅适用本场景"

## 不做的事

- 不执行 `git commit` / `git push`（仅用户要求时）
- 不归档（仅用户说"归档"时走 `/sdd:archive`）
- 不改 proposal 适配代码（应反向：改代码符合 proposal，或 `/sdd:revise` 改 proposal）
