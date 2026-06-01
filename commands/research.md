---
description: 派 researcher 子代理调研业界做法 + 关键约束。每个方向产出 research/<title>-research.md，research.md 当索引。换方向 = 累积新方向，不覆盖不归档
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(mkdir:*, date:*)
---

# /spec:research

调研方向：$ARGUMENTS

## 产物结构（详见 [`research-spec.md`](../skills/core/references/research-spec.md)）

```
spec/changes/<name>/
├── research.md                       ← 索引：Directions + Open[TBD] + Decided
└── research/
    └── <title>-research.md           ← 每个方向一份：Practices + Constraints
```

## 流程

1. **确认 change 目录**：
   - 无活跃 change → 新开 `spec/changes/<kebab-name>/`，name 从用户描述提炼，建 `research/` 子目录
   - 有活跃 change 且**方向相符** → 续做：在该方向的 `research/<title>-research.md` 追加 / 修订
   - 有活跃 change 但**方向变了** → 走下方「换方向」（累积新方向，**不覆盖、不归档**）
2. **概括方向 → 定标题**：把 $ARGUMENTS 概括成一个英文 kebab 标题（如 `caffeine-vs-redis`），落 `research/<title>-research.md`
3. **派 `@researcher` 子代理**调研，写该方向正文：
   - WebSearch 关键技术决策点的 A/B/C 方案对比、踩坑、benchmark → `## Practices`
   - 收集硬约束（兼容性 / 性能 / 安全 / 依赖版本）→ `## Constraints`
   - 引用必须给 URL
4. 主对话 Grep / Glob 项目内相关模块，理清调用链
5. **更新索引 `research.md`**：
   - `## Directions` 追加一行指向新方向正文，标 `[active]`
   - 标 `[TBD-N]` 偏好型决策点到 `## Open`（编号全局续上）：
     - **事实型**（读代码 / 查文档能定死）→ Claude 自己定，标"按现状定：X"
     - **偏好型**（多选项都成立，取决于用户取舍）→ 必须标 `[TBD]` 留给 `/spec:ask`
     - 拿不准当偏好型，**严禁把偏好型当事实型跳过**

## 换方向（用户传入新方向）

调研产物独立自洽、互不污染——换方向是**累积**，不是作废：

1. 新建 `research/<新标题>-research.md`，写该方向的 Practices / Constraints
2. 索引 `## Directions`：新方向那行标 `[active]`，旧方向改标 `[superseded]`（**保留可查，不删不归档**）
3. 新方向的 [TBD] 追加进索引 `## Open`，编号续上（不重置）
4. **不动 design.md / proposal.md / tasks.md**——它们是已生成的独立方案，apply/verify 读 proposal+design 从不读 research，不会被新调研污染。要换方案是你主动重跑 `/spec:propose`

## references 加载（按需）

只在写 Practices 涉及具体技术栈才加载对应 reference：
- Java + Spring → `${CLAUDE_PLUGIN_ROOT}/skills/core/references/alibaba-java.md` + `java-conventions.md`
- Vue / uni-app → `vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md`（uni-app 加 `uniapp-miniprogram.md`）
- React → `bulletproof-react.md` + `react-patterns.md`
- 任何 TS → 叠加 `google-ts-style.md` + `ts-conventions.md`
- Python → `python-conventions.md`；PHP → `php-conventions.md`；Flutter → `flutter-conventions.md`

`/spec:research` 阶段**不强制读 reference**（省 token），只在写到具体决策时按需 Read。

## 反作弊

- 没真查到的链接 / benchmark 数字**禁止伪造**
- 调研覆盖不全主动说"未查到 X，建议用户补充"，不许凭印象写
- 项目内调用链没读全主动说"未扫描 Y 模块"，不许猜
