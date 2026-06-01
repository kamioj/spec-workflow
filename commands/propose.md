---
description: 写或整体重写 proposal.md（## Why / ## What / ## How / ## Risk 四段）。写前 hook 强制扫描 research.md 的 [TBD] 必须清空。写完输出 HARD GATE 等用户批准
allowed-tools: Read, Write, Edit, Glob
---

# /spec:propose

## 前置检查

hook 已在命令前扫描 research.md。如果 hook 阻断 → 转 `/spec:ask` 消化 [TBD]。

精神层面也要自觉：

- `spec/changes/<name>/research.md` 必须存在
- `## Open [TBD]` 必须为空

## 流程

1. Read research.md：读 `## Decided` + `## Practices` / `## Constraints`（当前方向调研结论；`research/` 废稿不参与，除非已捞回 research.md）
2. Read design.md（若存在）
3. 写 `spec/changes/<name>/proposal.md`
4. **输出 HARD GATE 收尾**

**详细格式 + HARD GATE 批准标记规则 + 修订流程** → [`skills/core/references/proposal-spec.md`](../skills/core/references/proposal-spec.md)

## 何时同时生成 tasks.md

满足任一条件时，**propose 阶段一并生成** `spec/changes/<name>/tasks.md`：

- 跨前后端项目（apply 阶段要派 spec-frontend-dev + spec-backend-dev 并行实施）
- 任务可拆 >5 个独立子任务（线性大改动）
- 多执行体协作（需要 owner 字段——给不同 agent / 不同人）

**简单单线程实施不生成** —— apply 直接按 proposal `## What` 列表推进。

### tasks.md 生成步骤

1. **取信息源**（按优先级）：
   - 主源：proposal.md `## What` —— 每个 What 项 → 一级任务节点
   - 跨前后端：design.md `## Interfaces` 落**契约任务**（必须先于所有实施任务）
   - 决策细节：research.md `## Decided` 反映在子任务的具体动作上

2. **拆分粒度**：
   - 一级 = What 项的对应模块（如 "用户认证模块"、"前端"、"集成"）
   - 二级 = 可独立完成的子动作（如 "DB schema 设计"、"接口契约 OpenAPI"）
   - 粒度判据：单个子任务**预计 10 分钟 - 1 小时**。太小合并，太大继续拆

3. **owner 分配**：
   - 跨前后端：子任务标 `owner: frontend` / `owner: backend`
   - 单执行体：不标 owner
   - 接口契约 / DB 迁移 / 集成测试常**不标 owner**（主对话或共担）

4. **deps 推导**：
   - 缺省顺序执行（不写 deps）
   - **高扇出节点**（接口契约 / DB 迁移）→ 所有依赖它的子任务显式标 `deps: <node>`
   - **跨枝并行**（前端 mock 依赖 backend 契约任务）→ 显式 deps 跳过中间任务
   - **末端集成 / e2e 测试** → deps 列全部前置

5. **执行**：**主对话**（不派 dev agent）写 `spec/changes/<name>/tasks.md`，跟 proposal.md 同 propose 阶段产出

**详细格式 + 字段规则 + 完成标注 + 生命周期** → [`skills/core/references/tasks-spec.md`](../skills/core/references/tasks-spec.md)

## --codex：方案异构挑刺（可选）

带 `--codex` 时，proposal.md 写完后**显式**调 codex 对方案做 adversarial 挑刺——在 HARD GATE 决策前，用异构模型暴露方案的逻辑漏洞 / 被忽略的失败模式 / 过度乐观的假设。

**codex 只挑刺、不改方案**（方案是用户 HARD GATE 决策的产物，改走 `/spec:revise`，codex 不能绕过决策权动 proposal）。

调用统一封装脚本 `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1`（Windows 绕坑 #336/#337 + `effort=low` 控成本 + 超时防卡死 + 残留进程清理 + session 解析全在脚本里，"为什么必须这么调"见脚本头注释）：

```powershell
$prompt = @"
对以下技术方案做 adversarial 审查，只挑问题、不给改写：
逻辑漏洞、被忽略的失败模式、过度乐观的假设、风险点（auth / 数据丢失 / 并发 / 回滚）。
方案：<proposal.md 全文>
"@
pwsh -File ${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1 -Prompt $prompt -TimeoutSec 180
```

**存 session id**：脚本末行输出 `OK:session=<id>`，把 `<id>` 写入 `spec/changes/<name>/.codex-session`——供后续 `/spec:verify --codex` 用 resume 续会话，让 codex 审代码时记得它审过的方案。

**挑刺结果附 HARD GATE**：codex 的 findings 作为「⚠️ codex 异构挑刺」块附在下方 HARD GATE 输出里，供你决策（采纳哪条 → `/spec:revise`；不采纳的说明理由）。**codex 挑刺不阻断 HARD GATE**——你仍是最终决策者。

## HARD GATE 输出（固定收尾）

写完 proposal.md（+ 可能 tasks.md）后**必须输出**：

```
<HARD-GATE>
=== 提案就绪 ===
路径：spec/changes/<name>/proposal.md
（若同步生成 tasks.md → 加一行：+ tasks.md（<N> 阶段任务分解 + deps + owner））

变化点：<首版含什么 / 关键决策点摘要>

下一步：
  ✅ 满意 → 调 /spec:apply 进入实施
     apply 会自动在 proposal.md 末尾追加 <!-- APPROVED: ... --> 标记
  🔧 局部改某段 → /spec:revise [why | what | how | risk]
  💭 方向想再聊 → /spec:chat
  🔄 调研要重做 → /spec:research "<新方向>"
</HARD-GATE>
```

**HARD GATE 输出后绝不写代码**——等用户调 `/spec:apply` 或其他命令。

`<!-- APPROVED: ... -->` 标记由 **`/spec:apply` 命令在执行前自动追加**（视用户主动调用为批准动作）——propose 命令不直接追加。这样设计减少 UX 一步"回复 go"的冗余。

用户驳回 → 走 `/spec:revise [section]`（局部）或 `/spec:chat`（重聊方向）。

## 驳回处理

| 用户反应 | 处理 |
|---|---|
| 同一目标、方案微调（"X 改成 Y"） | `/spec:revise [section]`，重新过 HARD GATE |
| 目标 / 方向变了 | `/spec:chat` 聊清楚，再决定 `/spec:research <新方向>` 还是 `/spec:revise` 微调 |
| 含糊不明 | 问"局部调整还是换方向"，不猜 |

## 反模式

- ❌ 写代码（HARD GATE 没批准前禁止 Write/Edit 项目源码）
- ❌ research.md 还有 [TBD] 就开始写 proposal
- ❌ `## How` 复制 research.md `## Decided` 原文（要提炼，不搬运）
- ❌ proposal 段撑爆塞内容（该挪 design）
- ❌ **HARD GATE 等待期间**未经用户确认就提前自己加 APPROVED 标记（这才是"替用户批准"）
- ❌ 用户驳回 / 修订时仍保留旧 APPROVED（应被 `/spec:revise` 主动移除）

完整 proposal.md / tasks.md 反模式清单分别见各自 spec 文件。
