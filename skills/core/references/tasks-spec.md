# tasks.md spec

`spec/changes/<change-name>/tasks.md` 是 sdd 工作流中**可选**的任务追踪产物。仅在跨前后端、多执行体协作、或任务可拆 >5 个独立子任务时生成。

## 何时存在

由 `/spec:propose` 生成（触发条件 + 生成步骤详见 [`commands/propose.md`](../../../commands/propose.md) "何时同时生成 tasks.md" 段）。

后续 `/spec:apply` 按它推进、`/spec:status` 读它报告进度、`/spec:archive` 归档时打包。

## 格式

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

## 字段规则

### 嵌套编号

分解层级。父任务 = 子任务全勾才算完。

- 一级（1, 2, 3）= 模块 / 阶段
- 二级（1.1, 1.2）= 该模块的子动作
- 三级（1.1.1）= 极复杂时才用，一般不需要

### deps

依赖前置任务：

- **缺省**（不写）= 顺序执行（接上一条）
- `deps: X` = 越过中间任务，直接依赖 X
- `deps: X, Y` = 多前置门控（两个都完成才能开始）

### owner

执行体：

- 跨前后端：`owner: frontend` / `owner: backend`
- 单执行体：不标
- 接口契约 / DB 迁移 / 集成测试这类"共担任务"通常不标 owner

## 关键节点类型

### 高扇出节点（gate）

被多个任务依赖的"枢纽任务"，必须先于依赖者完成。典型：

- **接口契约**（design.md `## Interfaces` 落地）→ frontend 和 backend 都依赖
- **DB schema 迁移** → backend 实现的前置
- **共享 lib / SDK 发布** → 多模块依赖

跨前后端时**契约任务必须先于实施任务**，否则 frontend / backend agent 无法并行。

### 末端节点

deps 列全部前置的整合任务。典型：

- 集成测试 / e2e 测试
- 部署 / 发布
- 文档收尾

## 完成标注

任务完成时把 `- [ ]` 改成 `- [x]`。**谁完成谁标**：

- dev agent 标自己 owner 的子任务
- 主对话标自理项（配置 / 脚本 / 跨模块协调类）

父任务 `- [ ]` 改 `- [x]` 的条件：所有子任务都已 `[x]`。

## 生命周期

| 阶段 | 命令 | 操作 |
|---|---|---|
| 生成 | `/spec:propose` | 跟 proposal.md 同步产出 |
| 推进 | `/spec:apply` | 按 deps 推进 → 完成时标 [x] |
| 报告 | `/spec:status` | 统计 X/Y 完成进度 |
| 归档 | `/spec:archive` | 打包到 spec/archive/ |

## 反模式

- ❌ 单线程简单任务也生成 tasks.md（增加维护负担，apply 直接按 proposal What 走更轻）
- ❌ 子任务粒度过大（>1 小时）→ 应继续拆
- ❌ 子任务粒度过小（<10 分钟）→ 应合并
- ❌ 跨前后端项目不写 owner → apply 时无法决定派哪个 agent
- ❌ 高扇出节点不显式标 deps → 并行实施触发死锁
