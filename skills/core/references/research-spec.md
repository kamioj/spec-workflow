# research 产物 spec

调研产物分两层：

- `spec/changes/<change-name>/research.md` —— **索引**（方向清单 + 待决点登记 + 决策登记）。由 `/spec:research` 维护，`/spec:ask` 更新 Open/Decided。
- `spec/changes/<change-name>/research/<title>-research.md` —— **每个调研方向一份**正文（Practices / Constraints）。换方向 = 新增一份,不覆盖、不删旧。

为什么分层：调研天然是**多方向、多轮**的（先探 Caffeine 再探 Redis）。这些方向是**对比关系不是替换关系**——正因为研究过 Caffeine 才知道为什么选 Redis。一份会被覆盖的 research.md 会把"为什么不选 X"的论证弄丢。文件夹累积 + 索引,让每个旧方向永远可查。

## 索引格式（research.md）

```markdown
# Research Index: <change-name>

## Directions
- [<title-1>](research/<title-1>-research.md) — <一句话概括该方向> [active]
- [<title-2>](research/<title-2>-research.md) — <一句话概括> [superseded]

## Open [TBD]
- [TBD-1] <偏好型决策点 1>（候选：A / B / C，倾向 X，需用户确认）
- [TBD-2] <偏好型决策点 2>

## Decided
（拷问后从 Open 移到这里。格式：[DEC-N] <决策> | 来源 [TBD-N] | 理由）
```

- `## Directions` 永远**至少一行**，标 `[active]`（当前方向）/ `[superseded]`（旧方向，仍保留可查）。
- `## Open [TBD]` / `## Decided` 是**跨方向合并**的决策态——`/spec:ask` 和 `check-tbd.ps1` hook 都只认这里。

## 每方向正文格式（research/<title>-research.md）

```markdown
# Research: <title>

## Practices
- 方案 A：实现要点 / 性能 / 集成成本 / 踩坑
- 方案 B：...
关键参考：<URL>

## Constraints
- 兼容性：...
- 性能目标：...
- 依赖版本：...
- 安全要求：...
```

正文**不含** `## Open [TBD]` / `## Decided`——那两段统一在索引里合并。

## 命名

- 每方向正文文件名 = **概括该方向的标题（英文 kebab）+ `-research.md`**，如 `caffeine-vs-redis-research.md`、`redis-cluster-research.md`。
- 文件名（机器读）英文；正文内 H1 标题（人读）可中文。
- 文件名**不许**直接叫 `research.md`（那是索引）。

## 段职责

| 段 | 在哪 | 由谁产出 | 用途 |
|---|---|---|---|
| `## Directions` | 索引 | `/spec:research` | 方向清单 + active/superseded 状态 |
| `## Practices` | 方向正文 | `@researcher` 子代理 | 该方向的业界做法 / 方案对比 |
| `## Constraints` | 方向正文 | `@researcher` + 主对话 Grep 项目内 | 该方向暴露的硬约束 |
| `## Open [TBD]` | 索引 | `/spec:research` 标，`/spec:ask` 消化 | 待决偏好型决策（跨方向合并） |
| `## Decided` | 索引 | `/spec:ask` 移入 | 拷问后的最终决策（跨方向合并） |

## [TBD] 编号规则

- 格式：`[TBD-N]`，N 从 1 全局顺序编号（跨方向连续，不按方向重置）
- **不重用编号**（即使删除后也不复用）
- 移到 `## Decided` 时改为 `[DEC-N]`，N 沿用原 TBD 编号

## 换方向处理（`/spec:research <新方向>`）

调研产物**独立自洽、互不污染**——所以换方向是"**累积**",不是"作废/归档"：

1. 新建 `research/<新标题>-research.md`，写该方向的 Practices / Constraints
2. 索引 `## Directions` 追加一行指向它,标 `[active]`；旧方向那行改标 `[superseded]`
3. 新方向浮现的 [TBD] 追加进索引 `## Open`（编号续上,不重置）
4. **不动 design.md / proposal.md / tasks.md** —— 它们是已生成的独立方案快照,不会被新调研污染（apply/verify 读的是 proposal+design,从不读 research）。要换方案是你**主动**重跑 `/spec:propose`，不是被动被污染。
5. **不归档、不删任何旧方向**——旧方向正文永久留在 `research/` 可查

## hook 强制约束

`hooks/check-tbd.ps1` 在 `/spec:propose` 执行**前**扫描 `research.md`（索引）的 `## Open [TBD]` 段：

- 含 `[TBD-N]` → 拒绝 propose 命令（exit 2）
- 必须先走 `/spec:ask` 消化所有 [TBD]

这是防止"含未决问题就写方案"的硬约束。索引持有合并后的 `## Open [TBD]`，hook 无需改。

## 跟 proposal.md 的关系

proposal.md `## How` 段从 research **active 方向正文的结论 + 索引 `## Decided`** 提炼：

- 引用决策结论
- **不复制原文**（要精炼）
- 深度论证留在方向正文 / design.md

## 反模式

- ❌ 把偏好型决策当事实型跳过（必须标 [TBD] 让用户确认）
- ❌ 换方向时覆盖/删除旧方向正文（要累积,不要替换）
- ❌ 换方向时去归档/动 design/proposal（它们独立自洽,不需要保护）
- ❌ 方向正文文件直接命名 `research.md`（那是索引）
- ❌ 重复使用已删除的 [TBD] 编号
- ❌ Practices 伪造没真查到的链接 / benchmark 数字
