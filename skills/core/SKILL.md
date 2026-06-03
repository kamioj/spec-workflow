---
name: core
description: Spec-driven development 工作流总览。当用户说"先 spec / 先出方案 / 先设计 / 提案"或任务规模 >150 行 / 跨 3+ 文件 / 引入新依赖 / 涉及架构选择时，加载此 skill 了解 sdd plugin 的 11 个命令、产物地图、共享精神（HARD GATE / 拷问 / 卡死保护 / 反作弊）
---

# SDD Plugin 总览

Spec-driven development 工作流：调研 → 拷问 → 提案 → HARD GATE → 实施 → 验证 → 归档。多命令 plugin 形态，每阶段独立触发。

## 何时使用

**激活**（满足任一）：
- 改动预计 >150 行
- 跨 3+ 文件
- 引入新依赖
- 架构选择（多方案权衡）
- 用户主动说 "先 spec | 提案 | 先设计 | 先出方案"

**不激活**：
- trivial（typo / log / 样式）
- small（<30 行单文件）
- medium（30-150 行 / 2-3 文件 / 不跨模块）

→ 直接改，**绝不激活本流程**。误激活重流程是本 plugin 最大失败模式。

## 命令索引

| 类别 | 命令 | 职责 |
|---|---|---|
| 入口 | `/spec:workflow <任务>` | 全流程一把梭，兼容旧 /sdd |
|  | `/spec:status` | 报告当前阶段 |
| 信息收集 | `/spec:research <方向>` | 调研业界做法 + 关键约束 |
|  | `/spec:ask` | 拷问消化 [TBD] |
|  | `/spec:chat` | 讨论模式，不动文档 |
| 设计 & 方案 | `/spec:design` | 技术设计梳理（按需） |
|  | `/spec:propose [--codex]` | 写 proposal.md；--codex 让 codex 挑刺方案 |
|  | `/spec:revise [section]` | 局部改 proposal（why/what/how/risk） |
| 执行 & 验证 | `/spec:apply` | 实施代码 |
|  | `/spec:verify [--codex] [--fix]` | 自审三维；--codex 加 codex 他审，--fix 让 codex 改 |
| 收尾 | `/spec:archive` | 归档 |

## 产物地图

```
spec/
├── changes/                          活跃 change 工作区
│   └── <change-name>/
│       ├── research.md   必有        当前调研（Practices + Constraints + Open[TBD] + Decided，单文件）
│       ├── research/     可选        调研方向废稿堆（被弃方向的 research.md 快照，无标记无链接，可复活）
│       ├── design.md     可选        技术设计（架构 / 接口 / 数据模型）
│       ├── proposal.md   必有        方案终态（含 HARD GATE 批准标记）
│       └── tasks.md      可选        多执行体协作的任务清单
│
└── archive/                          归档目录
    └── YYYY-MM-DD-<name>/            归档后的整个 change 目录
```

**产物固定为这四件 + 废稿堆**。模型自行增设计划外文件（如 app-current / decisions / migration-inventory）是文档过多的直接来源——新增第五类文件须经**用户显式批准**，否则相关内容并入四件之一。

## 阶段职责矩阵（各产物各司其职，越界即臃肿之源）

大改动文档臃肿的主要成因是**阶段越界**：调研内容混入 design、代码与 DDL 误置于 design、同一决策在 research 与 design 重复记述。**原则：每项内容只在其唯一真相源完整写明，他处仅引用、不重述。**

| 产物 | **只写**（唯一真相源） | **不写**（挪到哪） | 软预算 |
|---|---|---|---|
| research.md | 外部信息：Practices / Constraints / Open[TBD] / Decided（DEC-N 结论 + 一句理由） | 架构·接口·schema→design ｜ 变更文件→proposal What ｜ 原始检索过程→废稿堆 | 每条一行 |
| design.md | 内部技术构造：架构图（结构，无字段）/ 接口契约（精确 schema）/ 数据模型 / **仅争议决策**深度论证 | 业务动机→proposal Why ｜ 风险·回滚→proposal Risk ｜ 完整代码·DDL→apply ｜ 复制 DEC-N 结论（只引不抄）｜ 展开非争议决策 | **叙述/论证 ≤150 行**（契约不计入、按需精确）；图 >20 节点拆；展开决策 1-2 个、每个 ≤12 行 |
| proposal.md | 决策书：Why / What / How（结论 + 指针）/ Risk | 深论证→design ｜ schema→design ｜ 重述 design 决策 | 每段 ≤5 行 |
| tasks.md | 协作清单：owner / deps / 验收 | 重述方案 → 指回 proposal/design | 每任务一行 |

**软预算只约束"叙述/论证"、不约束"契约"**：`## Interfaces` / `## Data Model` 契约按需充分精确、**不计入预算**——契约不够精确，才是真正的交代不清。design 的具体行数与"契约过大则拆 change"等细则见 `references/design-spec.md`「段约束」（数值以那里为准）——**此处只立原则、不重抄**。

**去重去除的是"深度论证"（仅保留一处），而非"结论"。** 结论须**前递**至执行者实际会读的文档——`/spec:apply` **只读 proposal + design，不读 research**，二者合并须能独立交代清任务。以下三项最易重复记述，真相源固定如下：
- **决策**：research `## Decided`（DEC-N）是**决策登记**（结论 + 一句理由），**不是深度论证的真相源**；**结论 + 理由前递至 proposal `## How`**（如"选型 X，理由一句"），**不得仅以"见 DEC-N"指代、致 apply 无从着手**。**深度论证**（benchmark / 多方案权衡）的真相源是 design `## Key Decisions`，且仅就 1-2 个**争议**决策展开。
- **动机** = proposal `## Why`。design 不写 Context 业务叙述。
- **风险** = proposal `## Risk`。design 不单列 Risks 段（决策的"代价"一句并入该决策，不另起清单）。

## 共享精神

### HARD GATE 流程

`/spec:propose` / `/spec:revise` 写完 proposal 必须输出固定收尾：

```
<HARD-GATE>
=== 提案就绪 ===
路径：spec/changes/<name>/proposal.md
（若同步生成 tasks.md → 加一行：+ tasks.md（<N> 阶段任务分解 + deps + owner））

变化点：<关键决策逐点写实质，每点一句"定了什么 + 为什么"，让用户一眼判断是否批准>

下一步：
  ✅ 满意 → 调 /spec:apply 进入实施
     apply 会自动在 proposal.md 末尾追加 <!-- APPROVED: ... --> 标记
  🔧 局部改某段 → /spec:revise [why | what | how | risk]
  💭 方向想再聊 → /spec:chat
  🔄 调研要重做 → /spec:research "<新方向>"
</HARD-GATE>
```

`/spec:revise` 的 HARD GATE 同结构，标题改为 `=== 提案修订（<section>）===` + 写明"旧 APPROVED 标记已移除"。

`<!-- APPROVED: YYYY-MM-DD HH:mm -->` 标记由 **`/spec:apply` 执行前自动追加**（视用户主动调用为批准动作）——propose / revise **不追加**（详见 proposal-spec.md）。

hook `check-gate.ps1` 在 `/spec:apply` 执行前检查此标记。**无标记 → 拒绝执行**。

### 拷问规则（继承 grill-me 精神）

- **提示自包含**（最重要，适用于一切"向用户提问 / 给出建议"之处——ask 的选项、HARD GATE 变化点、status 下一步）：所给内容 = ① 决策 / 动作一句 + ② 理由（影响什么 / 不做的后果）+ ③ 每个选项"选择它将导致什么（具体场景 / 后果）"。**判据：用户无需反问即可据以决策**。空泛内容（仅罗列"A / B / C"、或仅给命令名而无后果 / 理由）是首要失败模式。
- **主张自审（四问过滤）**（提示自包含的姊妹：前者约束"向用户提的问题"，本条约束"产出的内容"）：每项主张落笔前先过四问——① **为什么**（缺它无法解决什么问题）② **何时有利**（锚定具体场景，而非抽象的"更优雅"）③ **隐患**（任何方案皆有代价，说不出代价即未想透）④ **能否删减**（删除后无影响者**不写**）。**严谨在于精准，不在篇幅**：四问是**思考**动作、每项主张皆须经过；但**落成文字的仅为第④问的结论**（删减后的保留项）——②③的深度论证默认**内化**，仅 1-2 个**确有争议 / 高风险**的决策展开记述（展开内容置于 design `## Key Decisions`，不并入 research / proposal）。判据：用户以四问反诘已问不出新内容，**且文档无一句可删而无损**。
- 偏好型决策点**必须**用 AskUserQuestion 问用户
- 2-4 个选项 / 推荐项放第一并标"(推荐)" + 一句为什么推荐
- 选项 >4 → 拆"多级窄化"
- 拿不准是事实型还是偏好型 → 当偏好型问
- 一次最多 4 问

### 卡死保护

任一命令执行中**连续 3 次**修复同方向失败 → 立即停下汇报。

一次尝试 = 新假设 + 改码 + 验证；重跑同样代码 / 修 typo / 调日志**不算**。

```
=== 卡死自检 ===
现象：<一句话>
已试三个假设：
  1. <假设> → <结果>
  2. <假设> → <结果>
  3. <假设> → <结果>
推断真因：<能推断写真因，否则"未知">
建议换方向：<有则写，否则"等用户指示">
```

等用户决策，禁止无限 patch。

### 反作弊（继承 explore skill 精神）

1. **不伪造结果**：未实际跑通的命令 / PoC / 输出**不许汇报为"成功"**
2. **不把绕过当解决**：mock 假响应 / 改 assert / patch 检查函数返回 true，必须明说"绕过，真因未解"
3. **硬编码必标注**：偏移量 / 固定 hash / 一次性参数，在代码注释 + tasks.md 标"仅适用本场景"

### 任务不可行时叫停

发现前提就错了（题目矛盾 / 资产在范围外 / 工具不兼容到无法继续 / 漏洞被修了）→ 立刻停下汇报：

```
=== 任务不可行 ===
发现：<前提哪里错 / 哪里矛盾>
证据：<具体观察 / 报错 / 引用>
建议：<改范围 / 换工具 / 联系出题方 / 放弃>
```

## hook 机制（硬约束加固）

| Hook 脚本 | 触发命令 | 作用 |
|---|---|---|
| `hooks/check-tbd.ps1` | `/spec:propose` 前 | research.md 含 `[TBD]` 则拒绝执行，提示走 `/spec:ask` |
| `hooks/check-gate.ps1` | `/spec:apply` 前 | proposal.md 缺 `APPROVED` 标记则拒绝执行 |

两个 hook 还会在 `spec/changes/` 下存在 **>1 个活跃 change** 时 `exit 2`（本工作流假设单活跃 change，先归档其余再继续）。

**软约束 vs 硬约束**：
- 软约束（prompt）：模型可能违反，违反率取决于模型水平
- 硬约束（hook）：shell 脚本拦截，违反率 0

`hooks/` 下的 PowerShell 脚本由 `hooks/hooks.json` 注册到 `UserPromptSubmit` 事件。

## references 加载策略

按需读，**不强制**：
- `skills/core/references/alibaba-java.md` + `java-conventions.md` — Java + Spring
- `skills/core/references/vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md` — Vue（uni-app 加 `uniapp-miniprogram.md`）
- `skills/core/references/bulletproof-react.md` + `react-patterns.md` — React
- `skills/core/references/google-ts-style.md` + `ts-conventions.md` — TS（叠加于 Vue/React/Node 之上）
- `skills/core/references/python-conventions.md` — Python
- `skills/core/references/php-conventions.md` — PHP
- `skills/core/references/flutter-conventions.md` — Flutter / Dart

只在写到具体技术决策时按需 Read，避免污染 token。

## 与全局协议交互

- **中文**：proposal / research 内容用中文，段标题英文（按 CLAUDE.md「人读字段中文」折衷——段标题英文便于工具识别、参数化）
- **子代理委派**：WebSearch 派 `@researcher`、跨文件搜索派 `@code-explorer`
- **并发**：多个独立操作同时发起
