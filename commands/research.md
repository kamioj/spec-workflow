---
description: 派 researcher 子代理调研业界做法 + 关键约束，写进 research.md（单文件，Open[TBD]/Decided 照旧维护）。换方向 = 先把当前 research.md 存成 research/ 废稿，再覆盖写新方向；旧废稿可随时捞回复活
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(mkdir:*, date:*)
---

# /spec:research

调研方向：$ARGUMENTS

## 产物结构

```
spec/changes/<name>/
├── research.md                   ← 当前调研（单文件：Practices + Constraints + Open[TBD] + Decided）
└── research/                     ← 本次提案的「调研方向废稿堆」（可选，换方向才产生）
    └── <title>-research.md       ← 被弃方向的 research.md 整篇快照，无标记、无链接、可复活
```

- **research.md** 是**当前**调研，单文件，所有内容内联。`## Open [TBD]` / `## Decided` 维护方式跟以往一致。
- **research/** 只放**废稿**——换方向时被弃的旧 research.md 整篇挪进来。**不做关联**：research.md 不链接它们，废稿也不挂任何状态标记。
- 想回到旧方案 → 把对应废稿**捞回 research.md**（复活）。废稿只属于本次 change，归档时跟着走。

## research.md 格式

```markdown
# Research: <change-name>

## Practices
- 方案 A：实现要点 / 性能 / 集成成本 / 已知问题 ｜ 为何纳入候选（在何种约束下值得考虑）
- 方案 B：...
关键参考：<URL>

## Constraints
- <约束>：兼容性 / 性能目标 / 依赖版本 / 安全要求 ｜ 违反的后果（说不出后果的约束多为冗余）

## Open [TBD]
- [TBD-1] <偏好型决策点>（候选 A / B / C，倾向 X，需用户确认）

## Decided
（拷问后从 Open 移来。格式：[DEC-N] <决策> | 来源 [TBD-N] | 理由）
```

**只写外部信息**（见 SKILL「阶段职责矩阵」）：架构 / 接口 / schema 属 design、变更文件清单属 proposal `## What`——不写入 research；原始检索过程不留于正文（换方向时移入 `research/` 废稿堆）。`## Decided` 的 DEC-N 是**决策登记**（结论 + 一句理由），**不是深度论证的真相源**（深度论证仅 1-2 个争议决策、在 design `## Key Decisions`）；proposal `## How` 须**前递结论 + 一句理由**至 apply（apply 不读 research），不使执行者仅得到"见 DEC-N"的空指针。

## 流程

1. **确认 change 目录**：无活跃 change → 新开 `spec/changes/<kebab-name>/`，name 从用户描述提炼；有活跃 change 且方向相符 → 在 research.md 续写
2. **派 `@researcher` 子代理**调研，写进 research.md：
   - WebSearch 方案 A/B/C 对比、已知问题、benchmark → `## Practices`
   - 硬约束（兼容性 / 性能 / 安全 / 依赖版本）→ `## Constraints`
   - 引用必须给 URL
   - **先过四问再落笔**（SKILL「主张自审」）：查得的内容不全部写入——每条 practice / constraint 先问"删除后会怎样"，删除无影响者不写；约束须能说明"违反后在何处出问题"。杜绝"百科式堆砌"。
3. 主对话 Grep / Glob 项目内相关模块，**理清现有调用链 / 约束**（写入 `## Constraints`——这是"理解现状"，不是"设计新架构"；新架构属 design）
4. **标 [TBD]**：偏好型决策点写进 `## Open`：
   - 事实型（读代码 / 查文档能定死）→ 自己定，标"按现状定：X"
   - 偏好型（多选项都成立，取决于用户取舍）→ 必须标 `[TBD]` 留给 `/spec:ask`
   - 拿不准当偏好型，**严禁把偏好型当事实型跳过**

## 换方向（用户传入新方向）

**硬性步骤，顺序不可颠倒**——research.md 将被覆盖，若遗漏存稿则旧方向丢失：

1. **先存废稿**：把当前 research.md **整篇**另存为 `research/<旧方向标题>-research.md`（`research/` 不存在先 mkdir）
2. **再覆写**：把 research.md 重写为新方向的调研（Practices / Constraints）
3. `## Open` / `## Decided` 更新到新方向当前思考
4. **不动 design.md / proposal.md / tasks.md**——它们是已生成的独立方案，apply/verify 读 proposal+design 不读 research，不会被新调研污染

## 复活旧方向（用户要回到之前方案）

1. （当前方向还想留）→ 先按「换方向」第 1 步把当前 research.md 存成废稿
2. 把目标废稿 `research/<title>-research.md` 内容**捞回 research.md**
3. 按需更新 `## Open` / `## Decided`

## references 加载（按需）

只在写 Practices 涉及具体技术栈才加载对应 reference：
- Java + Spring → `${CLAUDE_PLUGIN_ROOT}/skills/core/references/alibaba-java.md` + `java-conventions.md`
- Vue / uni-app → `vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md`（uni-app 加 `uniapp-miniprogram.md`）
- React → `bulletproof-react.md` + `react-patterns.md`
- 任何 TS → 叠加 `google-ts-style.md` + `ts-conventions.md`
- Python → `python-conventions.md`；PHP → `php-conventions.md`；Flutter → `flutter-conventions.md`

`/spec:research` 阶段**不强制读 reference**（省 token），只在写到具体决策时按需 Read。

## 反作弊

- 未真正查到的链接 / benchmark 数字**禁止伪造**
- 调研覆盖不全须主动说明"未查到 X，建议用户补充"，不得凭印象编写
- 项目内调用链未读全须主动说明"未扫描 Y 模块"，不得臆测
- ❌ 百科式堆砌：将检索到的所有方案 / 约束不经第④问（能否删减）尽数罗列——经删减后仍保留者才写（SKILL「主张自审」）
