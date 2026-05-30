---
name: sdd
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
| 入口 | `/sdd:auto <任务>` | 全流程一把梭，兼容旧 /sdd |
|  | `/sdd:status` | 报告当前阶段 |
| 信息收集 | `/sdd:research <方向>` | 调研业界做法 + 关键约束 |
|  | `/sdd:ask` | 拷问消化 [TBD] |
|  | `/sdd:chat` | 讨论模式，不动文档 |
| 设计 & 方案 | `/sdd:design` | 技术设计梳理（按需） |
|  | `/sdd:propose` | 写 proposal.md |
|  | `/sdd:revise [section]` | 局部改 proposal（why/what/how/risk） |
| 执行 & 验证 | `/sdd:apply` | 实施代码 |
|  | `/sdd:verify` | 三维验证 |
| 收尾 | `/sdd:archive` | 归档 |

## 产物地图

```
spec/
├── changes/                          活跃 change 工作区
│   └── <change-name>/
│       ├── research.md   必有        调研 + 待决点工作台
│       ├── design.md     可选        技术设计（架构 / 接口 / 数据模型）
│       ├── proposal.md   必有        方案终态（含 HARD GATE 批准标记）
│       ├── tasks.md      可选        多执行体协作的任务清单
│       └── archive/                  重做时旧产物备份
│
└── archive/                          归档目录
    └── YYYY-MM-DD-<name>/            归档后的整个 change 目录
```

## 共享精神

### HARD GATE 流程

`/sdd:propose` / `/sdd:revise` 写完 proposal 必须输出固定收尾：

```
<HARD-GATE>
=== 提案就绪 ===
路径：spec/changes/<name>/proposal.md
（若同步生成 tasks.md → 加一行：+ tasks.md（<N> 阶段任务分解 + deps + owner））

变化点：<首版含什么 / 关键决策点摘要>

下一步：
  ✅ 满意 → 调 /sdd:apply 进入实施
     apply 会自动在 proposal.md 末尾追加 <!-- APPROVED: ... --> 标记
  🔧 局部改某段 → /sdd:revise [why | what | how | risk]
  💭 方向想再聊 → /sdd:chat
  🔄 调研要重做 → /sdd:research "<新方向>"
</HARD-GATE>
```

`/sdd:revise` 的 HARD GATE 同结构，标题改为 `=== 提案修订（<section>）===` + 写明"旧 APPROVED 标记已移除"。

收到批准 → 在 proposal 末尾追加：
```markdown
<!-- APPROVED: YYYY-MM-DD HH:mm -->
```

`/sdd:apply` 会在进入实施时追加此标记；hook `check-gate.sh` 在 `/sdd:apply` 执行前检查 change / proposal 是否存在。

### 拷问规则（继承 grill-me 精神）

- 偏好型决策点**必须**用 AskUserQuestion 问用户
- 2-4 个选项 / 推荐项放第一并标"(推荐)"
- 选项 >4 → 拆"多级窄化"
- 拿不准是事实型还是偏好型 → 当偏好型问
- 一次最多 4 问

### 卡死保护

任一命令执行中**连续 3 次**修复同方向失败 → 立即停下汇报：

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
| `hooks/check-tbd.sh` | `/sdd:propose` 前 | research.md 含 `[TBD]` 则拒绝执行，提示走 `/sdd:ask` |
| `hooks/check-gate.sh` | `/sdd:apply` 前 | 缺活跃 change / proposal.md 则拒绝执行 |

**软约束 vs 硬约束**：
- 软约束（prompt）：模型可能违反，违反率取决于模型水平
- 硬约束（hook）：shell 脚本拦截，违反率 0

`hooks/` 下的 macOS/Linux shell 入口由 `hooks/hooks.json` 注册到 `UserPromptSubmit` 事件；缺少 `python3` 会阻断并提示安装，也可主动运行 `sh hooks/install-python3.sh`。Windows `.ps1` 版本保留备用。

## references 加载策略

按需读，**不强制**：
- `skills/sdd/references/alibaba-java.md` + `java-conventions.md` — Java + Spring
- `skills/sdd/references/vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md` — Vue（uni-app 加 `uniapp-miniprogram.md`）
- `skills/sdd/references/bulletproof-react.md` + `react-patterns.md` — React
- `skills/sdd/references/google-ts-style.md` + `ts-conventions.md` — TS（叠加于 Vue/React/Node 之上）
- `skills/sdd/references/python-conventions.md` — Python
- `skills/sdd/references/php-conventions.md` — PHP
- `skills/sdd/references/flutter-conventions.md` — Flutter / Dart

只在写到具体技术决策时按需 Read，避免污染 token。

## 与全局协议交互

- **中文**：proposal / research 内容用中文，段标题英文（按 CLAUDE.md「人读字段中文」折衷——段标题英文便于工具识别、参数化）
- **子代理委派**：WebSearch 派 `@researcher`、跨文件搜索派 `@code-explorer`
- **并发**：多个独立操作同时发起
