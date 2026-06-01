---
description: 派 researcher 子代理调研业界做法 + 关键约束，产出 research.md。首次进入或重指定方向都走这个；重做时旧产物归档不删
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(mkdir:*, cp:*, mv:*, date:*)
---

# /spec:research

调研方向：$ARGUMENTS

## 流程

1. **确认 change 目录**：
   - 有未归档 change 且方向相符 → 续做（在原 research.md 追加 / 修订）
   - 有未归档 change 但方向变了 → 走下方「重做调研」（旧产物链整体归档作废，不只 research.md）
   - 无 → 新开 `spec/changes/<kebab-name>/`，name 从用户描述提炼
2. **派 `@researcher` 子代理**调研业界做法：
   - WebSearch 关键技术决策点的 A/B/C 方案对比、踩坑、benchmark
   - 收集硬约束（兼容性 / 性能目标 / 安全要求 / 依赖版本）
   - 引用必须给 URL
3. 主对话 Grep / Glob 项目内相关模块，理清调用链
4. **写 research.md**——详细格式 + 段职责 + [TBD] 编号规则 → [`skills/core/references/research-spec.md`](../skills/core/references/research-spec.md)
5. 标 `[TBD-N]` 偏好型决策点：
   - **事实型**（读代码 / 查文档能定死）→ Claude 自己定，标"按现状定：X"
   - **偏好型**（多选项都成立，取决于用户取舍）→ 必须标 `[TBD]` 留给 `/spec:ask`
   - 拿不准当偏好型，**严禁把偏好型当事实型跳过**

## 重做调研（用户传入新方向）

方向变了 = **整条产物链作废**（旧 design/proposal 都是从旧方向推出来的）：

1. 旧 `research.md` → `spec/changes/<name>/archive/research-YYYYMMDD-HHMM.md`
2. **旧 `design.md` / `proposal.md` / `tasks.md`（若存在）一并移入 `archive/`** —— 不归档会让新一轮 `/spec:propose` 读到过时的 `## Interfaces`、`/spec:apply` 按过时契约派单
3. 旧 `[TBD]` / `Decided` 不沿用（除非用户明说"沿用"）
4. 重写 research.md，[TBD] 重新挖

## references 加载（按需）

只在写 Practices 时涉及具体技术栈才加载对应 reference：
- Java + Spring → `skills/core/references/alibaba-java.md` + `java-conventions.md`
- Vue / uni-app → `skills/core/references/vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md`（uni-app 加 `uniapp-miniprogram.md`）
- React → `skills/core/references/bulletproof-react.md` + `react-patterns.md`
- 任何 TS → 叠加 `skills/core/references/google-ts-style.md` + `ts-conventions.md`
- Python → `skills/core/references/python-conventions.md`
- PHP → `skills/core/references/php-conventions.md`
- Flutter → `skills/core/references/flutter-conventions.md`

`/spec:research` 阶段**不强制读 reference**（节省 token），只在写到具体决策时按需 Read。

## 反作弊

- 没真查到的链接 / benchmark 数字**禁止伪造**
- 调研覆盖不全主动说"未查到 X，建议用户补充"，不许凭印象写
- 项目内调用链没读全主动说"未扫描 Y 模块"，不许猜
