---
description: 写或整体重写 proposal.md（## Why / ## What / ## How / ## Risk 四段）。写前 hook 强制扫描 research.md 的 [TBD] 必须清空。写完输出 HARD GATE 等用户批准
allowed-tools: Read, Write, Edit, Glob
---

# /sdd:propose

## 前置检查

hook 已在命令前扫描 research.md。如果 hook 阻断 → 转 `/sdd:ask` 消化 [TBD]。

精神层面也要自觉：

- `spec/changes/<name>/research.md` 必须存在
- `## Open [TBD]` 必须为空

## 流程

1. Read research.md（含 Practices / Constraints / Decided 三段）
2. Read design.md（若存在）
3. 写 `spec/changes/<name>/proposal.md`
4. **输出 HARD GATE 收尾**

**详细格式 + HARD GATE 批准标记规则 + 修订流程** → [`skills/sdd/references/proposal-spec.md`](../skills/sdd/references/proposal-spec.md)

## 何时同时生成 tasks.md

满足任一条件时，**propose 阶段一并生成** `spec/changes/<name>/tasks.md`：

- 跨前后端项目（apply 阶段要派 sdd-frontend-dev + sdd-backend-dev 并行实施）
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

**详细格式 + 字段规则 + 完成标注 + 生命周期** → [`skills/sdd/references/tasks-spec.md`](../skills/sdd/references/tasks-spec.md)

## HARD GATE 输出（固定收尾）

写完 proposal.md（+ 可能 tasks.md）后**必须输出**：

```
<HARD-GATE>
=== 提案就绪 ===
路径：spec/changes/<name>/proposal.md
（若同步生成 tasks.md → 加一行：+ tasks.md（<N> 阶段任务分解 + deps + owner））

变化点：<首版含什么 / 关键决策点摘要>

下一步：
  ✅ 满意 → 回复 "开始 | go | 实施"
     我立刻在 proposal.md 末尾追加 <!-- APPROVED: ... --> 标记
     之后你调 /sdd:apply 进入实施
  🔧 局部改某段 → /sdd:revise [why | what | how | risk]
  💭 方向想再聊 → /sdd:chat
  🔄 调研要重做 → /sdd:research "<新方向>"
</HARD-GATE>
```

**收到"开始|go|实施"前绝不写代码**。

收到批准词后，**主对话立刻**在 proposal.md 末尾追加（时间戳用当前 ISO 本地时间）：

```markdown
<!-- APPROVED: YYYY-MM-DD HH:mm -->
```

这是触发 `check-gate.ps1` hook 放行 `/sdd:apply` 的契约——**没有这一步，所有后续 apply 都会被 hook 拒绝**。

用户驳回 → 走 `/sdd:revise [section]`（局部）或 `/sdd:chat`（重聊方向）。

## 驳回处理

| 用户反应 | 处理 |
|---|---|
| 同一目标、方案微调（"X 改成 Y"） | `/sdd:revise [section]`，重新过 HARD GATE |
| 目标 / 方向变了 | `/sdd:chat` 聊清楚，再决定 `/sdd:research <新方向>` 还是 `/sdd:revise` 微调 |
| 含糊不明 | 问"局部调整还是换方向"，不猜 |

## 反模式

- ❌ 写代码（HARD GATE 没批准前禁止 Write/Edit 项目源码）
- ❌ research.md 还有 [TBD] 就开始写 proposal
- ❌ `## How` 复制 research.md `## Decided` 原文（要提炼，不搬运）
- ❌ proposal 段撑爆塞内容（该挪 design）
- ❌ **HARD GATE 等待期间**未收到"开始|go|实施"就提前自己加 APPROVED 标记（这才是"替用户批准"）
- ❌ 用户驳回 / 修订时仍保留旧 APPROVED（应被 `/sdd:revise` 主动移除）

完整 proposal.md / tasks.md 反模式清单分别见各自 spec 文件。
