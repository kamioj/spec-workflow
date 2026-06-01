# research.md spec

`spec/changes/<change-name>/research.md` 是 sdd 工作流的**调研工作台 + 待决点登记**。由 `/sdd:research` 产出，`/sdd:ask` 持续更新。

## 格式

```markdown
# Research: <change-name>

## Practices
- 方案 A：实现要点 / 性能 / 集成成本 / 踩坑
- 方案 B：...
- 方案 C：...
关键参考：<URL>

## Constraints
- 兼容性：...
- 性能目标：...
- 依赖版本：...
- 安全要求：...

## Open [TBD]
- [TBD-1] <偏好型决策点 1>（候选：A / B / C，倾向 X，需用户确认）
- [TBD-2] <偏好型决策点 2>

## Decided
（拷问后从 Open 移到这里。格式：[DEC-N] <决策> | 来源 [TBD-N] | 理由）
```

## 段职责

| 段 | 由谁产出 | 用途 |
|---|---|---|
| `## Practices` | `@researcher` 子代理 | 调研业界做法 / 方案对比 |
| `## Constraints` | `@researcher` + 主对话 Grep 项目内 | 硬约束清单（兼容性 / 性能 / 依赖 / 安全） |
| `## Open [TBD]` | `/sdd:research` 标，`/sdd:ask` 消化 | 待决偏好型决策 |
| `## Decided` | `/sdd:ask` 移入 | 拷问后的最终决策 |

## [TBD] 编号规则

- 格式：`[TBD-N]`，N 从 1 顺序编号
- **不重用编号**（即使删除后也不复用）
- 移到 `## Decided` 时改为 `[DEC-N]`，N 沿用原 TBD 编号

## 重做调研处理

`/sdd:research <新方向>` 重做时：

1. 旧 `research.md` 移到 `spec/changes/<name>/archive/research-YYYYMMDD-HHMM.md`
2. 旧 `[TBD]` / `Decided` **不沿用**（除非用户明说"沿用"）
3. 重写 research.md，[TBD] 重新挖

## hook 强制约束

`hooks/check-tbd.ps1` 在 `/sdd:propose` 执行**前**扫描 `## Open [TBD]` 段：

- 含 `[TBD-N]` → 拒绝 propose 命令（exit 2）
- 必须先走 `/sdd:ask` 消化所有 [TBD]

这是 sdd 防止"含未决问题就写方案"的硬约束。

## 跟 proposal.md 的关系

proposal.md `## How` 段必须**从 research.md `## Decided` 提炼**：

- 引用决策结论
- **不复制原文**（要精炼）
- 深度论证留在 research.md / design.md

## 反模式

- ❌ 把偏好型决策当事实型跳过（必须标 [TBD] 让用户确认）
- ❌ 重复使用已删除的 [TBD] 编号
- ❌ [TBD] 没消化就让用户走 /sdd:propose（hook 会拦但不应该让它发生）
- ❌ Practices 没真查到的链接 / benchmark 数字伪造
