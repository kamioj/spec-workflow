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

## design.md 格式

```markdown
# Design: <change-name>

## Architecture
（mermaid / ASCII 图。组件关系、数据流向、关键边界）

## Interfaces
- `<ServiceName>.<method>(params) → returnType`
  - 输入：<schema>
  - 输出：<schema>
  - 错误码：<列出>

## Data Model
- 表 / 实体 / 字段定义
- 索引 / 约束

## Key Decisions（深度论证）
- 决策：<选什么>
- 替代方案：<没选的 A/B/C 及拒绝理由>
- benchmark / 限制对比：<数据 / 引用>

## Migration / Compatibility
- 老数据如何迁移
- 旧接口如何兼容 / 何时下线
```

各段**非必填**——简单任务可能只画架构图。但至少一段，否则就是不该开 design。

## 边界：哪些不该写在 design

| 内容 | 应该写在哪 |
|---|---|
| 业务动机 / 时间窗口 | proposal `## Why` |
| 改什么文件 / 模块 | proposal `## What` |
| 风险 / 回滚 | proposal `## Risk` |
| 任务拆分 / deps | tasks.md |

design 专注**技术构造**：架构 / 接口 / 数据 / 深度论证。

## 反模式

- ❌ 为复杂而复杂：proposal 几句话能讲清的硬塞 design
- ❌ 把 proposal 的 How 段全文搬过来（design 装"为什么"的深度论证，不是结论复制）
- ❌ 凭空画架构图：没读 research.md / 没扫项目代码就画
