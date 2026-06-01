---
description: 验证当前改动。默认 Claude 自审三维（completeness / correctness / coherence）；--codex 加 codex 异构他审（只读），--codex --fix 让 codex 直接改。可独立重跑
allowed-tools: Read, Bash, Edit, Grep, Glob
---

# /spec:verify

## 三种模式（flag）

| 命令 | 行为 | 改代码 |
|---|---|---|
| `/spec:verify` | Claude 自审三维 | ❌ |
| `/spec:verify --codex` | + codex 异构他审，出 findings | ❌ 只报告 |
| `/spec:verify --codex --fix` | codex 审 + 直接改 + Claude 二次验收 | ✅ |

`--fix` 必须配 `--codex`（单独 `--fix` 报错提示）。默认（无 flag）只做 Claude 自审，保持只读 reporter 定位。

## 三维验证框架（Claude 自审，所有模式都先跑）

### 1. Completeness（完整性）
- **`test-checklist.md` 的每个 `T-N` 验收点**都满足吗？（无 test-checklist 时退回按 proposal `## What` 逐项核）
- 接口契约（design.md 若有）的输入 / 输出都对齐？
- 测试覆盖关键路径？

### 2. Correctness（正确性）
- 编译 / 类型检查通过？
- 单元 / 集成测试通过？
- 边界 case（空 / 极值 / 异常输入）处理正确？

### 3. Coherence（一致性）
- 改动跟 proposal `## How` 的决策一致？
- **没做 proposal 没要求的事**（scope creep）？
- 符合 `skills/core/references/<栈>.md` 的代码规范？

## --codex：codex 异构他审

带 `--codex` 时，自审之后再调 **codex（异构模型）** 审同一批改动——补 Claude 单模型的系统性盲区（实测：codex 找 4 个高危 vs Claude 找 8 个，重叠仅 1）。

**调用机制全部封装在 `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1`**——Windows 绕坑（#336 bypass sandbox / #337 不走 node spawn）、`effort=low` 控成本、超时防卡死、残留进程清理、session 解析；"为什么必须这么调"的实测约束见脚本头注释（单一真相源）。

**会话复用**：若 `spec/changes/<name>/.codex-session` 存在（`/spec:propose --codex` 留下的），传 `-ResumeSession <id>` 续会话——codex 记得它审过的方案，能判断「**代码忠实实现方案了吗**」。无则省略该参数开新会话。

```powershell
$prompt = @"
审查以下代码改动。审查重点：<本次改动重点 + proposal ## Risk>
范围：<git diff 涉及文件>
"@
pwsh -File ${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1 -Prompt $prompt -TimeoutSec 300 -ProjectDir "<项目目录>" -ResumeSession "<id；无则省略此参数>"
```

**默认（无 `--fix`）codex 只出 findings、不改代码**——报问题，由你看了走 `/spec:apply` 改，或加 `--fix`。

## --fix：codex 直接改 + Claude 二次验收

仅 `--codex --fix` 时启用。**同样走 `codex-exec.ps1`**，只把 prompt 换成「审查**并修复**」——bypass sandbox 允许 codex 直接改工作区文件。然后 **Claude 二次验收**（不盲信）：

1. **前置**：工作区最好已 commit（codex 改动能从 diff 隔离回滚）
2. `git diff` 看 codex 改了什么，逐处判：

| codex 改动 | 判定 | 处理 |
|---|---|---|
| 真问题、修对 | ✅ | 保留 |
| 改了不该改 / 引入新问题 | ❌ noise | 回退（`Edit` / `git checkout -p`） |
| 重写无关代码 | ❌ scope creep | 回退 |
| codex 漏的真问题 | ➕ | Claude 补 |

**社区实测警告固化**：codex 改动含噪音，必须 Claude 逐处过滤，禁止盲信「改了即对」。

## 输出格式

```
=== Verify ===
[自审] Completeness: <pass/fail/partial> - <说明>
       Correctness:  <pass/fail/partial> - <说明>
       Coherence:    <pass/fail/partial> - <说明>

[--codex] codex 他审 findings：<N 条>
[--fix]   codex 改 <M> 处 → 确认 X / 回退 Y / 补 Z；tokens ≈ <从输出读>

整体：<pass / fail>
```

无 flag 时只输出 `[自审]` 部分。

## 裁决产物：verdict.md + VERIFIED 标记

自审（+ 可选 codex）跑完，**写 `spec/changes/<name>/verdict.md`**（这一版的质量报告）：

```markdown
# Verdict: <change-name>

裁决：<pass | fail>  ·  isolation:<shared|subagent>  ·  model:<claude | codex | ...>

## 逐点（对照 test-checklist.md 的 T-N）
- [x] T-1: <验收条件> — pass
- [ ] T-2: <验收条件> — fail
      复现：<最小步骤>
      问题点：<现象 / 报错 + 文件:行>
      分诊：<bug | requirement> — <一句理由>

## 三维
- Completeness / Correctness / Coherence：<各 pass/fail/partial + 说明>
```

然后**确定性盖裁决锚点**（算当前契约指纹写进 VERIFIED 标记，归档门认它）：

```powershell
pwsh -File ${CLAUDE_PLUGIN_ROOT}/scripts/stamp-verdict.ps1 -ChangeDir spec/changes/<name> -Verdict <pass|fail>
```

- 整体 **pass** → 盖 `verdict:pass`，`/spec:archive` 才放行。
- 整体 **fail** → 盖 `verdict:fail`，归档被拦；按下方分诊回流。
- **isolation/model 字段如实写**——共享档自审**不许**标成独立验证（v3 会把隔离做成可选，这里先记真实值）。

## 两条回流（分诊，verify 只分类不替你跑下一步）

每个失败点在 verdict.md 标 `分诊：bug | requirement`：

| 分诊 | 含义 | 去向 | 指纹 |
|---|---|---|---|
| **bug** | 契约没错、代码错 | 回**实施域**改代码（快道） | **不变**，改完直接重 `/spec:verify` |
| **requirement** | 契约本身错 / 缺 | 回**决策域** `/spec:revise` 改契约 | **重铸**：改完重跑 `/spec:apply` 重铸指纹再实施 |

**分诊作弊不了**：标 bug 却要改 proposal/design → 写源码时 PreToolUse 门会拦（契约漂移），逼你按 requirement 走重铸。

## 失败处理（定位，不规定方案）

自审失败时**报告具体失败点**：

| 维度 fail | 报告内容 |
|---|---|
| Completeness | 列 proposal `## What` 未实现项；design.md 未对齐接口 |
| Correctness | 贴报错原文 + 文件 / 行号；测试 fail 的 case + 期望 vs 实际 |
| Coherence | 与 `## How` 不一致处；scope creep；违反 `references/<栈>` 规范 |

**判定原则**：描述问题，不规定方案——修复路径由用户 / 主对话决定。

## 反作弊

- **未实际跑通的测试不许标 pass**——肉眼通读不算 Correctness pass
- codex 跑失败（认证 / 超时 / ENOENT）**不许当成「审过了」**——明确报失败
- 「codex 没报问题」不等于「代码没问题」——codex 也有盲区，双层正为此
- partial 必须说清哪里 partial，不许笼统「基本通过」

## 卡死保护

- codex 调用自带超时（模板 300s），超时即停 + 清理残留进程
- `--fix` 同一改动反复审改仍不收敛 → 停下汇报，禁止无限 `codex → 改 → 再 codex`

## 不做的事

- 不主动推荐「下一步用哪个命令」——verify 只报告 + 分类（bug/requirement），路由由用户决定
- 无 `--fix` 时不改代码（改是 `/spec:apply` 的事）
- 不改 proposal **内容**（`/spec:revise` 的事）——只在末尾盖 VERIFIED 标记（不计入契约指纹）
- 不归档（`/spec:archive` 的事）；verify 只产 verdict + 盖标记，归档门据此放行 / 拦截
