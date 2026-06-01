# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这个仓库是什么

这是一个 **Claude Code plugin marketplace**，里面装着 `sdd`（spec-driven development）插件。**没有应用代码、没有编译/构建/测试运行器**——"源码"就是 markdown 命令、JSON 清单、PowerShell hook 脚本。修改即生效，"测试"靠加载插件并实跑命令。

清单结构：`.claude-plugin/` 下同时放 `marketplace.json`（`source: "./"` 自指仓库根）和 `plugin.json`（plugin 自身）——这是 source 自指的单插件布局，仓库根即 plugin 根。改插件元数据时**两个 manifest 都要同步**（name / version / description）。

## 开发循环（无 build/test，靠加载实跑）

```pwsh
# 本地开发：直接加载源码副本，优先级高于 marketplace cache，改了立刻能测
claude --plugin-dir .

# 发布循环：push 后同步 cache
git add . ; git commit -m "..." ; git push
claude plugin marketplace update spec-workflow
```

**关键：改了 `hooks/` 下任何东西（hooks.json 或 .ps1）必须重启 Claude 才生效**——commands / skills / agents 是热加载，hook 不是。这是最容易踩的坑：改完 hook 不重启，测出来的是旧行为。

校验所有 JSON 清单（CI 没有，手动跑）：
```pwsh
Get-ChildItem -Recurse -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null; "OK: $($_.Name)" }
```

单独测一个 hook（hook 从 stdin 读 JSON，exit 2 = 阻断，exit 0 = 放行）：
```pwsh
'{"user_prompt":"/spec:apply","cwd":"D:\\path\\to\\test-project"}' | pwsh -NoProfile -File hooks/check-gate.ps1 ; "exit=$LASTEXITCODE"
```

## 平台约束

**Windows-only**：hook 用 pwsh（PowerShell 7）写。**永远用 `pwsh` 不用 `powershell`**——PS 5.1 默认 GBK 编码会把中文管道弄乱码。hook 脚本头部已显式设 UTF-8 stdin/stdout，跨平台需要等价的 bash/sh 重写（README "Limitations" 标了这是已知局限）。

## 架构大图：软约束 vs 硬约束

整个 sdd 的设计核心是「**该停的地方真停下来**」，靠两层：

1. **软约束**（命令 / agent 的 markdown prompt 里写"必须做 X"）——模型可能违反。
2. **硬约束**（`hooks/*.ps1` shell 脚本拦截）——违反率 0。

两个 hook 都挂在 `UserPromptSubmit` 事件（见 `hooks/hooks.json`），靠 **正则匹配用户输入里的命令名** 决定是否介入：

| Hook | 匹配 | 拦什么 | 不满足时 |
|---|---|---|---|
| `check-tbd.ps1` | `/spec:propose` | research.md 的 `## Open [TBD]` 段还有 `[TBD-N]` | `exit 2`，提示走 `/spec:ask` |
| `check-gate.ps1` | `/spec:apply` | proposal.md 缺 `<!-- APPROVED: ... -->` 标记 | `exit 2`，提示先过 HARD GATE |

hook 约定（改 hook 时必须守）：
- stdin JSON 的字段名是 **`user_prompt`**（不是 `prompt`）+ `cwd`。这点踩过坑，README 里专门记了证据。
- **fail-open**：hook 自身报错走 catch → `exit 0` 放行。hook 的 bug 绝不能阻断用户正常流程。
- `check-gate.ps1` 的 APPROVED 正则接受多种格式（`<!-- APPROVED:` / `## HARD GATE...APPROVED` / `APPROVED: YYYY-MM-DD`），改标记格式时正则要一起改。

## 架构大图：命令 + agent + 产物

**11 个独立 slash 命令**（`commands/*.md`），每个可单独触发、可重入、可单点重做——这是相对 OpenSpec（4 命令一把梭）/ superpowers（9 步硬流程）的定位差异。典型流：
`research → ask → (design) → propose → [HARD GATE] → apply → verify → archive`。`/spec:workflow` 是全流程一把梭，`/spec:status` 报告当前在哪一步。

**HARD GATE 机制**（贯穿 propose/revise/apply）：
- propose/revise 写完 proposal **必须输出固定的 `<HARD-GATE>` 收尾块**，然后停手等用户。
- `<!-- APPROVED: YYYY-MM-DD HH:mm -->` 标记由 **`/spec:apply` 在执行前自动追加**（视"用户主动调 apply"为批准动作）——**不是** propose 追加，**不需要**用户回"go"。这是近期重构掉的冗余（见 git log `fix: 简化 HARD GATE`），改这块逻辑时注意别把"回复 go"加回来。
- HARD GATE 输出后**绝不写项目源码**，等下一条命令。

**2 个开发 agent**（`agents/sdd-{frontend,backend}-dev.md`），在 `/spec:apply` 阶段派遣：
- 按 proposal `## What` 涉及的代码类型分派（前端 UI/路由/组件 vs 后端 API/数据模型/迁移）。
- **跨前后端 = 契约先行 + 并行**：接口契约先固化在 `design.md ## Interfaces`，然后**同一条消息并发派两个 agent**（不串行——串行浪费 50% 时间）。agent frontmatter 用 `model: inherit`。

**opt-in 增强 flag**（`/spec:apply design solid verify`，空格分隔可组合）：默认**不**加载额外 reference 保持轻量，避免在工具型 UI/内部页/后端业务里过度保守。flag 命中才让 agent 读对应 reference：`design`→frontend-aesthetics（反 AI slop）、`solid`→agent-principles §一（反偷懒）、`verify`→agent-principles §二（反幻觉）。

## 产物模型（在使用者项目里生成，不在本仓库）

跑 sdd 时在**目标项目**产生：
```
<target-project>/spec/
├── changes/<change-name>/     活跃工作区
│   ├── research.md  必有       调研索引（Directions + Open[TBD] + Decided）
│   ├── research/    必有       各方向调研正文 <title>-research.md
│   ├── design.md    可选       架构 / 接口契约 / 数据模型
│   ├── proposal.md  必有       方案终态（四段 + APPROVED 标记）
│   └── tasks.md     可选       多执行体协作清单（owner + deps）
└── archive/<YYYY-MM-DD-name>/  已归档 change
```
hook 据此判断状态：扫 `spec/changes/` 下非 `archive` 的目录当作"活跃 change"。

## 写作约定（改 command/agent/reference 时守）

- **语言分工**：人读内容（命令说明、proposal/research 正文、commit）用**中文**；**段标题用英文**（`## Why / ## What / ## How / ## Risk`）——便于 hook 正则识别和 `/spec:revise <section>` 参数化。这是对全局"人读字段中文"协议的刻意折衷。
- **proposal.md 四段缺一不可**：Why / What / How / Risk。
- **command frontmatter**：`description` + `allowed-tools`。**agent frontmatter**：`name` / `description` / `model: inherit` / `color` / `capabilities`。
- **路径变量**：hook 与 agent 里引用插件内文件用 `${CLAUDE_PLUGIN_ROOT}/...`，别写死绝对路径。
- **references/ 按需读**：agent 检测项目栈（读 `package.json` / `pubspec.yaml` / `manifest.json`）后只读相关栈的 reference，不全读——避免污染 token。
- **同一套规则散落多处要同步**：HARD GATE 文案、卡死自检模板、反作弊条款同时出现在 `SKILL.md`、对应 `commands/*.md`、`references/*-spec.md`。改其一要扫齐其余，否则三处不一致。`references/*-spec.md`（proposal/research/design/tasks-spec）是产物格式的**单一真相源**，命令文件用相对链接指过去。

## 共享精神（agent 默认遵守，无需 opt-in，见 SKILL.md「共享精神」）

- **反作弊**：未实跑通的命令/PoC 不许报"成功"；mock 假响应/改 assert/patch 返回 true 必须明说"绕过，真因未解"；硬编码（偏移/hash）必在注释 + tasks.md 标"仅适用本场景"。
- **卡死保护**：同方向连续 3 次修复失败 → 停下输出"卡死自检"块，等用户决策，禁止无限 patch。
- **任务不可行叫停**：发现前提就错（矛盾/范围外/工具不兼容）→ 立即停下汇报。
