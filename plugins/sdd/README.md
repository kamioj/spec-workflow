# SDD Plugin

> Spec-driven development 工作流：调研 → 拷问 → 提案 → HARD GATE → 实施 → 验证 → 归档。

11 个独立 slash 命令 + 2 个硬约束 hook + 2 个开发 agent。每阶段可独立触发、可重入。

## 安装

放在 `~/.claude/plugins/sdd/`。重启 Claude Code 后 `/help` 应能看到 `/sdd:*` 命令列表。

```
~/.claude/plugins/sdd/
├── .claude-plugin/plugin.json
├── commands/        11 个 slash 命令
├── hooks/           硬约束（sh + python3 实现，保留 pwsh 版本）
├── agents/          前后端开发 agent
└── skills/sdd/      plugin 总览 skill + 知识库
    ├── SKILL.md
    └── references/  14 个语言栈 + 2 个 agent 精神 + 4 个产物 spec
```

## 何时使用

**激活**（满足任一）：
- 改动 >150 行
- 跨 3+ 文件
- 引入新依赖
- 架构选择（多方案权衡）
- 用户主动说 "先 spec | 提案 | 先设计"

**不激活**：trivial / small / medium（<150 行 / 单文件 / 不跨模块）→ 直接改，**绝不走 sdd**。

## 命令一览

| 类别 | 命令 | 职责 |
|---|---|---|
| 入口 | `/sdd:auto <任务>` | 全流程一把梭 |
|  | `/sdd:status` | 报告当前阶段 |
| 信息收集 | `/sdd:research <方向>` | 调研，产出 research.md + 标 [TBD] |
|  | `/sdd:ask` | 拷问消化 [TBD] |
|  | `/sdd:chat` | 讨论模式，不动文档 |
| 设计 & 方案 | `/sdd:design` | 技术设计梳理（按需） |
|  | `/sdd:propose` | 写 proposal + HARD GATE |
|  | `/sdd:revise [why/what/how/risk]` | 局部改 proposal |
| 执行 & 验证 | `/sdd:apply` | 派遣 dev agent 实施 |
|  | `/sdd:verify` | 三维验证（completeness/correctness/coherence） |
| 收尾 | `/sdd:archive` | 归档 |

## 产物地图

```
spec/
├── changes/<change-name>/          活跃工作区
│   ├── research.md   必有          调研 + 待决点工作台
│   ├── design.md     可选          技术设计（架构 / 接口 / 数据模型）
│   ├── proposal.md   必有          方案终态（含 APPROVED 标记）
│   ├── tasks.md      可选          多执行体协作清单
│   └── archive/                    重做时旧产物备份
└── archive/<YYYY-MM-DD-name>/      归档目录
```

## 典型工作流

```
/sdd:research "Caffeine vs Redis 缓存方案"
    ↓ 产出 research.md（含 [TBD-1, TBD-2, ...]）
/sdd:ask
    ↓ 消化 [TBD] → ## Decided
/sdd:design        ← 可选，复杂任务才用
    ↓ 产出 design.md
/sdd:propose
    ↓ 产出 proposal.md
    ↓ hook 拦：research.md 还有 [TBD] 则拒绝
[HARD GATE 等"开始/go/实施"]
    ↓ /sdd:apply 自动追加 <!-- APPROVED: ... -->
/sdd:apply
    ↓ hook 拦：缺活跃 change / proposal.md 则拒绝
    ↓ 派遣 sdd-frontend-dev / sdd-backend-dev
/sdd:verify
    ↓ 三维验证 OK
/sdd:archive
```

简单任务可 `/sdd:auto` 一键跑完。

## Hook 机制（硬约束）

| Hook 脚本 | 触发命令 | 作用 |
|---|---|---|
| `hooks/check-tbd.sh` | `/sdd:propose` 前 | research.md 含 `[TBD-N]` 则 `exit 2` 拒绝执行 |
| `hooks/check-gate.sh` | `/sdd:apply` 前 | 缺活跃 change / proposal.md 则 `exit 2` 拒绝执行 |

事件：`UserPromptSubmit`（hookify 同款，plugin wrapper 格式）。
脚本：macOS/Linux 默认走 `sh` Exec form，内部调用 `python3` 做 JSON 解析；未找到 `python3` 时会阻断并提示安装方式，也可主动运行 `sh hooks/install-python3.sh`。`.ps1` 版本仍保留给 Windows。

**软约束 vs 硬约束**：
- 软约束（prompt 里写"必须做 X"）：模型可能违反
- 硬约束（hook）：shell 脚本拦截，违反率 0

## Agents（专属开发执行体）

| Agent | 触发场景 | 默认加载 references |
|---|---|---|
| `sdd-frontend-dev` | UI / 路由 / 组件 / 样式 | vue / react / ts / css 等技术栈 references |
| `sdd-backend-dev` | 服务端逻辑 / API / 数据模型 / DB 迁移 | java / python / php / ts 等技术栈 references |

### opt-in 加载（默认不读，flag 启用）

两份 reference 默认**不**被 agent 加载。通过 `/sdd:apply` 后跟 flag 启用：

| flag | 启用 reference | 适用场景 |
|---|---|---|
| `solid` | `agent-principles.md` § 一 反偷懒 | 一次性研究脚本怕走捷径 / 评测压力 |
| `verify` | `agent-principles.md` § 二 反幻觉 | 复杂代码库怕乱猜 |
| `design` | `frontend-aesthetics.md` 反 AI slop | 营销页 / 作品集 / 视觉重要的前端 |

**用法**：

```
/sdd:apply                       # 默认轻量
/sdd:apply design                # 启用反 AI slop
/sdd:apply solid verify        # 反偷懒 + 反幻觉
/sdd:apply design solid verify # 三件套全启用
```

flag 顺序任意，空格分隔，可组合。

**为什么 opt-in**：
- 日常实施大头是工具型 UI / 内部仪表盘 / 调试页 / 后端业务——反 AI slop / 严格反幻觉 在这些场景会让 agent **过度保守**（拒合理 workaround / 过度 Read / 美学折腾不该折腾的地方）
- 三层叠加（反偷懒 + 反幻觉 + 反 AI slop）容易让 agent 陷入"什么都不敢做"的瘫痪态
- 仅在你**明确说出**该场景关键词时才启用——保留这些规则的火力，用在该用的地方

### 默认精神

agent 派遣时自觉遵守 `skills/sdd/SKILL.md` 的"共享精神"——反作弊、卡死保护、任务不可行叫停。**无需** opt-in，是默认行为。

## 与全局协议交互

- **中文**：proposal / research 内容中文；段标题英文（## Why / ## What / ## How / ## Risk）便于工具识别和 revise 参数化
- **子代理委派**：sdd plugin 在 research 阶段派全局 `@researcher`、在 apply 阶段派 plugin 内 `sdd-frontend-dev` / `sdd-backend-dev`
- **并发**：互不依赖的任务一次性并发派单

## 设计哲学

| 维度 | sdd | OpenSpec | superpowers |
|---|---|---|---|
| 阶段 GATE | 显式 HARD GATE | fluid 软警告 | 9 步硬流程 |
| [TBD] 路线 | 允许，但 hook 强制清空 | Open Questions 可滞留 | 严禁 TBD 当场消解 |
| 命令粒度 | 11 个独立命令 | 4 命令一把梭 | skill-based |
| 拷问机制 | AskUserQuestion 显式 | 无 | 9 步对话 |
| 反作弊 | 命令 + agent 双层精神 | 无 | 隐含 |

**sdd 定位**：单人 + 大改动 + 反呆机制——比 OpenSpec 严，比 superpowers 灵活。

## 已知局限

1. **macOS/Linux 优先**：hook 依赖 `sh` + `python3`；缺少 `python3` 会阻断并提示安装，也可主动运行 `sh hooks/install-python3.sh`。Windows 用户可把 `hooks.json` 切回 `.ps1` 脚本
2. **未做的扩展**：
   - 没专门的 sdd-researcher agent（用全局 @researcher 替代）
   - 没 MCP server 集成
   - 没 Stop / SessionEnd hook（任务遗忘提醒）——后续按需

## 已确认的设计决策（曾担心、调研后确认无问题）

| 项 | 结论 | 证据 |
|---|---|---|
| `user_prompt` 字段名 | ✅ 正确 | hookify/core/rule_engine.py 第 226-228 行实际访问 `input_data.get('user_prompt', '')` |
| plugin agent 调用方式 | ✅ 直接用 agent name（`sdd-frontend-dev`），无需 plugin 前缀 | plugin-dev/skills/agent-development/SKILL.md § Namespacing |
| agent frontmatter 必填字段 | ✅ name / description / model / color 全部就位 | plugin-dev/skills/agent-development/SKILL.md § Frontmatter Fields |
| agent model 策略 | ✅ `inherit`（继承父对话模型，官方推荐） | plugin-dev/skills/agent-development/SKILL.md § model |

## 版本历史

- **0.1.0** — 首版：11 命令 + 2 hook + 2 agent，从 skill 形态迁移而来
