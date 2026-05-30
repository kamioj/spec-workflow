# design.md spec

`spec/changes/<change-name>/design.md` 是 sdd 工作流的**可选技术设计产物**。由 `/sdd:design` 按需触发，仅在复杂任务 / 跨前后端协作时生成。

## 何时生成

满足任一才触发（详见 [`commands/design.md`](../../../commands/design.md)）：

- **跨前后端项目**（必须，落接口契约让前后端并行）
- 接口数 >3 个
- 需要架构图 / 数据流图 / 序列图（mermaid / ASCII）
- 决策深度论证 >300 字（benchmark / 限制对比 / 性能模型）

**简单单栈任务不生成** —— `proposal.md ## How` 几句话讲清就够。

## 格式

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

## 段约束

各段**非必填** —— 简单任务可能只画架构图。但**至少一段**，否则就是不该开 design.md。

## 边界：哪些不该写在 design.md

| 内容 | 应该写在哪 |
|---|---|
| 业务动机 / 时间窗口 | proposal.md `## Why` |
| 改什么文件 / 模块 | proposal.md `## What` |
| 风险 / 回滚 | proposal.md `## Risk` |
| 任务拆分 / deps | tasks.md |

design.md 专注**技术构造**：架构 / 接口 / 数据 / 深度论证。

## 跨前后端的特殊职责

design.md 的 `## Interfaces` 段是**前后端并行实施的契约源头**：

- **必须先于 `/sdd:apply` 落地**
- frontend agent 用 mock 数据先跑骨架（基于 `## Interfaces` 定义的 schema）
- backend agent 实现服务端（同样基于 `## Interfaces`）
- 联调时双方对齐到真实接口

不写 `## Interfaces` → frontend / backend agent 无法并行（退化成串行实施）。

## 跟 proposal.md / research.md 的关系

| 文件 | 关系 |
|---|---|
| research.md | 上游（外部信息） |
| design.md | **中游**（内部技术构造，深度展开） |
| proposal.md | 下游（精炼决策书，引用 design 的关键结论） |

proposal.md `## How` 引用 design.md `## Key Decisions` 的结论；不复制深度论证。

## 反模式

- ❌ 为复杂而复杂：proposal 几句话能讲清的硬塞 design.md
- ❌ 把 proposal `## How` 全文搬到 design `## Key Decisions`（design 装"为什么"的深度论证，不是结论复制）
- ❌ 凭空画架构图：没读 research.md / 没扫项目代码就画
- ❌ 跨前后端项目跳过 design.md（导致没契约，前后端无法并行）
