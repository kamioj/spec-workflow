---
description: 拷问偏好型决策点。用 AskUserQuestion 逐个消化 research.md 的 [TBD]，回答后移到 ## Decided。可多次触发，过程中可新增 [TBD]
allowed-tools: Read, Edit, AskUserQuestion
---

# /spec:ask

## 流程

1. Read `spec/changes/<name>/research.md`，列出 `## Open [TBD]` 全部条目
2. 对每个 [TBD] 判断性质：
   - **事实型**（读代码 / 查文档能定死的）→ Claude 自己定，标"按现状定：X"移到 Decided
   - **偏好型**（多选项都成立，取决于用户取舍）→ 用 AskUserQuestion 问
   - **拿不准 → 当偏好型问**（不许跳过）
3. **偏好型问法**（继承全局《提问方式》）：
   - 单选（架构 A/B/C）或多选（边界 case scope）
   - 2-4 个选项；推荐项放第一并标"(推荐)"
   - 选项 >4 → 拆"多级窄化"：先问大类，再窄化
   - 相互依赖的决策点一次一问，按答案展开下一问（不预先列死）
   - 相互独立的可一次批量（AskUserQuestion 一次最多 4 问）
4. 第一问前一句声明：
   ```
   看到 N 个分歧，逐个问；不保证全，漏了你说。
   ```
5. **用户答完 → 写回 research.md**：
   - 从 `## Open [TBD]` 删除该条
   - 在 `## Decided` 追加：
     ```
     [DEC-N] <决策> | 来源 [TBD-N] | 理由：<用户回答提炼>
     ```
6. **过程中浮现新 [TBD]** → 主动追加到 `## Open`，告知"新发现 M 个 TBD"，继续问

## 停止条件

| 情况 | 处理 |
|---|---|
| Open [TBD] 清空 | 停，提示"可以 /spec:propose 了" |
| 用户说"别问了" / "够了" | 停，剩余条目留 Open（/spec:propose 前 hook 会拒绝执行） |
| 拷问发散收不拢 | 停，汇报"已收集 N 条，剩余 M 条建议下次再谈" |

## 反模式

- ❌ 默改 [TBD] 为已知答案（必须问用户）
- ❌ 把偏好型当事实型跳过
- ❌ 一次甩 5+ 问题给用户（违反 2-4 个选项 + 一次 4 问上限）
- ❌ 列"决策树" artifact（制造虚假覆盖感）

## 不做的事

- 不写 proposal.md（那是 /spec:propose 的事）
- 不修改方向正文（`research/` 下的 `## Practices` / `## Constraints`，那是 /spec:research 的事）
