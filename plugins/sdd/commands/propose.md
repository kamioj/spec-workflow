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

## proposal.md 格式

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

每段 ≤5 行。撑爆 → 该写 design.md，**不要塞 proposal**。

## 何时同时生成 tasks.md

满足任一条件时，**propose 阶段一并生成** `spec/changes/<name>/tasks.md`：

- 跨前后端项目（apply 阶段要派 sdd-frontend-dev + sdd-backend-dev 并行实施）
- 任务可拆 >5 个独立子任务（线性大改动）
- 多执行体协作（需要 owner 字段——给不同 agent / 不同人）

**简单单线程实施不生成** —— apply 直接按 proposal `## What` 列表推进。

### tasks.md 格式

```markdown
# Tasks: <change-name>

> deps 缺省 = 顺序接上一条；只在并行 / 跨枝门控时显式标
> owner 仅多执行体协作时出现

- [ ] 1. 用户认证模块
  - [ ] 1.1 DB schema 设计
  - [ ] 1.2 接口契约 OpenAPI（同步落 design.md ## Interfaces）
  - [ ] 1.3 后端 API 实现            owner: backend
- [ ] 2. 前端
  - [ ] 2.1 页面骨架 + mock 数据     owner: frontend  deps: 1.2
  - [ ] 2.2 接真实接口               owner: frontend  deps: 1.3, 2.1
- [ ] 3. 集成
  - [ ] 3.1 e2e 测试                                  deps: 1.3, 2.2
```

### tasks.md 规则

- **嵌套编号** = 分解层级，父任务子任务全勾才算完
- **deps 缺省** = 顺序执行；`deps: X` = 越过中间任务与之并行；`deps: X,Y` = 门控多前置
- **owner** = 执行体（`frontend` / `backend` / 人名等）—— 不写则默认主执行体
- **契约任务 = 高扇出节点**（多任务 deps 指向）→ 天然成 gate，跨前后端时**必须先于依赖它的任务落盘**
- **集成 / e2e** = deps 列全部前置的末端节点
- 任务太大 → 拆更细子节点

## HARD GATE 输出（固定收尾）

写完 proposal.md 后**必须输出**：

```
<HARD-GATE>
=== 提案就绪 ===
路径：spec/changes/<name>/proposal.md
回复"开始|go|实施"继续，或指出要改处。
</HARD-GATE>
```

**收到"开始|go|实施"前绝不写代码**。

用户回"go" → 在 proposal.md 末尾追加批准标记（hook 检查这个）：

```markdown
<!-- APPROVED: YYYY-MM-DD HH:mm -->
```

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
- ❌ 自己在 proposal 末尾加 APPROVED 标记替用户批准
