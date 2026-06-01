---
description: 技术设计梳理。按需触发——架构复杂、接口 >3 个、需要序列图 / 数据流图、决策深度论证 >300 字时调。产出 design.md
allowed-tools: Read, Write, Edit, Glob
---

# /sdd:design

聚焦：$ARGUMENTS

## 何时使用

满足任一才调：
- **跨前后端**（同时改 UI 和服务端，含接口契约）← **此场景下 design 不是可选，是必须**
- 接口数 >3 个
- 需要架构图 / 数据流图 / 序列图（mermaid / ASCII）
- 决策深度论证 >300 字（benchmark / 限制对比 / 性能模型）
- 涉及跨服务 / 跨进程协议设计

**纯前端 / 纯后端的简单任务**：直接 research → propose，不要为开 design 而开。

**跨前后端任务必须开 design** 的理由：
- 接口契约是前后端**并行实施的唯一协调介质**
- 没有契约 → 前后端只能串行（后端先做出来前端再对接），浪费 50% 时间
- 契约写在 design.md `## Interfaces`，固化后 `/sdd:apply` 才能派两个 agent 并发

## 流程

1. Read `spec/changes/<name>/research.md` 拿调研结果
2. Read `spec/changes/<name>/design.md`（若已存在则在原基础修订）
3. 写 / 更新 `spec/changes/<name>/design.md`

**详细格式 + 段约束 + 边界规则 + 反模式** → [`skills/workflow/references/design-spec.md`](../skills/workflow/references/design-spec.md)

## 反模式（概要）

- ❌ 为复杂而复杂：proposal 几句话能讲清的硬塞 design
- ❌ 把 proposal 的 How 段全文搬过来（design 装"为什么"的深度论证，不是结论复制）
- ❌ 凭空画架构图：没读 research.md / 没扫项目代码就画

完整反模式清单见 [`design-spec.md`](../skills/workflow/references/design-spec.md)。
