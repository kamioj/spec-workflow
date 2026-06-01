<div align="center">

# spec-workflow

**Spec-driven development plugin for Claude Code**

Large changes, kept controllable and reversible. The pipeline — research → clarify → propose → **HARD GATE** → implement → verify → archive — is re-entrant at every step, enforced by hooks, and runs its agents in parallel.

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/kamioj/spec-workflow)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20pwsh-lightgrey.svg)](https://github.com/kamioj/spec-workflow)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-v2.1+-purple.svg)](https://docs.claude.com/en/docs/claude-code)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**English** | [中文](README_cn.md)

</div>

---

## Why

Two paradigms already dominate AI-assisted spec-driven development:

- **Fast lane** — start coding right away and let hooks catch the mistakes (hookify, or a stripped-down superpowers brainstorm).
- **Heavy lane** — spec everything up front, but down a rigid track (OpenSpec's 4 commands, superpowers brainstorm's 9 steps).

**spec-workflow takes a third path.** It keeps the discipline of thinking before acting, but breaks the process into 11 independent slash commands — each stage re-entrant, interruptible, and re-runnable on its own. Two hard-constraint hooks make sure the workflow stops where it has to.

### Comparison

| Dimension | spec-workflow | OpenSpec | superpowers |
|---|---|---|---|
| Stage gating | explicit HARD GATE + hook enforcement | loose, advisory warnings | rigid 9-step track |
| Open questions `[TBD]` | allowed, but a hook forces them closed | Open Questions can linger | banned — resolve on the spot |
| Command granularity | 11 independent commands | 4 commands, all-in-one | one skill-based flow |
| Mid-flow re-entry | call any stage on its own | `/opsx:continue` to advance | start over |
| Anti-cheating | two layers (command + agent) + opt-in flags | none | implicit |

Built for one person making large changes, with guardrails — stricter than OpenSpec, looser than superpowers.

---

## Quick Start

### Install

```pwsh
# Configure a GitHub token (required for a private repo)
$env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxx"

# Register the marketplace and install the plugin
claude plugin marketplace add kamioj/spec-workflow
claude plugin install spec@spec-workflow
```

### Try it

Once claude is running:

```
/spec:status                          # should print "no active SDD change"
/spec:research "Caffeine vs Redis"    # kick off a research run
```

Within a few minutes, `research.md` lands in `spec/changes/caffeine-vs-redis/`.

---

## Features

### 11 independent slash commands

| Category | Command | What it does |
|---|---|---|
| **Entry** | `/spec:workflow <task>` | run the whole flow end-to-end |
|  | `/spec:status` | report where the current change stands |
| **Gather** | `/spec:research <direction>` | survey industry practice and flag open questions as `[TBD]` |
|  | `/spec:ask` | work through the `[TBD]` questions with you |
|  | `/spec:chat` | discussion mode — never touches a file |
| **Design & propose** | `/spec:design` | technical design, when you need it |
|  | `/spec:propose [--codex]` | write the proposal + HARD GATE; `--codex` lets codex poke holes in it |
|  | `/spec:revise [why\|what\|how\|risk]` | edit a single proposal section |
| **Execute & verify** | `/spec:apply [flags]` | dispatch agents to implement |
|  | `/spec:verify [--codex] [--fix]` | self-review on three axes; `--codex` adds a second opinion from codex, `--fix` lets codex edit directly |
| **Wrap up** | `/spec:archive` | archive the current change |

### 2 hard-constraint hooks

On the `UserPromptSubmit` event, **shell scripts block** any command that breaks the flow:

| Hook | Fires before | What it blocks |
|---|---|---|
| `check-tbd.ps1` | `/spec:propose` | blocks if research.md still has a `[TBD-N]` |
| `check-gate.ps1` | `/spec:apply` | blocks if proposal.md has no `<!-- APPROVED -->` |

**Soft vs hard constraints.** A prompt that says "you must do X" can be ignored by the model. A hook is a shell script — it can't be: a **0% violation rate**.

### 2 development agents

| Agent | When it's used |
|---|---|
| `spec-frontend-dev` | UI / routing / components / styling / client-side interaction |
| `spec-backend-dev` | server-side logic / API / data models / DB migrations / middleware |

In a cross-stack project, the interface contract is pinned down first in `design.md ## Interfaces`, then both agents **build in parallel** — never one after the other.

### opt-in enhancement flags

`/spec:apply` runs lean by default. Three flags pull in extra discipline on demand:

| flag | Turns on | Use it when |
|---|---|---|
| `design` | anti-AI-slop | marketing pages, portfolios — anywhere visuals matter |
| `solid` | anti-laziness (no workarounds) | one-off scripts where cutting corners is tempting |
| `verify` | anti-hallucination (read before you write) | large codebases where guessing is dangerous |

Stack them:

```
/spec:apply design solid verify    # all three on
```

---

## Workflow

```mermaid
graph LR
    A[research]:::cmd -->|has TBD| B[ask]:::cmd
    B --> A
    A -->|TBD cleared| D{design needed?}
    D -->|complex| E[design]:::cmd
    D -->|simple| F[propose]:::cmd
    E --> F
    F -->|HARD GATE| G{user approves?}:::gate
    G -->|yes| H[apply]:::cmd
    G -->|no| I[revise]:::cmd
    I --> G
    H --> J[verify]:::cmd
    J -->|pass| K[archive]:::cmd
    J -->|fail| H

    classDef cmd fill:#e1f5fe,stroke:#01579b,color:#000
    classDef gate fill:#fff9c4,stroke:#f57f17,color:#000
```

Every stage stands alone. Jump wherever you need — `/spec:chat` to talk it over, `/spec:revise why` to rework one section, `/spec:research <new direction>` to start the research over.

---

## Architecture

### Repo layout

```
.
├── .claude-plugin/
│   ├── marketplace.json           # marketplace manifest (source: "./" — points back at the repo root)
│   └── plugin.json                # plugin manifest
├── commands/                       # 11 slash commands
├── hooks/                          # hard constraints (pwsh)
│   ├── hooks.json
│   ├── check-tbd.ps1
│   └── check-gate.ps1
├── agents/                         # development agents
│   ├── spec-frontend-dev.md
│   └── spec-backend-dev.md
└── skills/core/
    ├── SKILL.md                    # plugin overview (shared principles)
    └── references/                 # knowledge base
        ├── proposal-spec.md        # artifact spec: full format + HARD GATE rules
        ├── research-spec.md
        ├── design-spec.md
        ├── tasks-spec.md
        ├── agent-principles.md     # opt-in: anti-laziness + anti-hallucination
        ├── frontend-aesthetics.md  # opt-in: anti-AI-slop
        ├── alibaba-java.md         # 14 language/framework guides
        ├── bulletproof-react.md
        ├── vue-style.md vue-patterns.md
        ├── react-patterns.md
        ├── ts-conventions.md google-ts-style.md
        ├── python-conventions.md php-conventions.md
        ├── flutter-conventions.md
        ├── js-style.md css-style.md
        └── uniapp-miniprogram.md
```

### Runtime artifacts

What the plugin writes into your project when you run it:

```
<your-project>/spec/
├── changes/<change-name>/          # active change workspace
│   ├── research.md   required      # research index (directions + open decisions)
│   ├── research/     required      # per-direction research docs (<title>-research.md)
│   ├── design.md     optional      # technical design (architecture / interfaces / data model)
│   ├── proposal.md   required      # the final solution (carries the APPROVED marker)
│   └── tasks.md      optional      # multi-executor task list
└── archive/<YYYY-MM-DD-name>/      # archived changes
```

---

## Development

After changing plugin content:

```pwsh
git add . && git commit -m "..."
git push

claude plugin marketplace update spec-workflow    # sync the cache
# restart claude — hooks only load on startup
```

Or skip the push loop while developing and load the source directly:

```pwsh
claude --plugin-dir .
```

A copy loaded with `--plugin-dir` **wins over** the marketplace cache, so your edits are testable right away.

---

## Documentation

- [skills/core/SKILL.md](skills/core/SKILL.md) — shared principles (HARD GATE / interrogation rules / stuck-detection / anti-cheating)
- [Official Claude Code plugin docs](https://code.claude.com/docs/en/plugins) — the upstream plugin mechanism

---

## Limitations

- **Windows-only.** Hooks are written in pwsh and run on Windows for now; going cross-platform needs a bash/sh equivalent.
- **Not built yet.** Dedicated sdd-researcher / sdd-reviewer agents, an MCP server, a Stop hook (a "you forgot a task" reminder).

---

## Integration

How this plugin cooperates with the global CLAUDE.md protocol:

- **Language** — proposal and research content is written in Chinese; section headers stay in English (## Why / ## What / ## How / ## Risk) so tools can spot them and `revise` can target them by name.
- **Subagent delegation** — the research stage hands off to the global `@researcher`; the apply stage hands off to the in-plugin `spec-frontend-dev` / `spec-backend-dev`.
- **Concurrency** — independent tasks are dispatched all at once.

---

## Verified Decisions

Design calls I worried about, then confirmed safe after digging in:

| Item | Verdict | Evidence |
|---|---|---|
| `user_prompt` field name | ✅ correct | hookify/core/rule_engine.py lines 226–228 read `input_data.get('user_prompt', '')` |
| how to invoke a plugin agent | ✅ use the agent name directly (`spec-frontend-dev`) — no plugin prefix | plugin-dev/skills/agent-development/SKILL.md § Namespacing |
| required agent frontmatter | ✅ name / description / model / color all present | plugin-dev/skills/agent-development/SKILL.md § Frontmatter Fields |
| agent model strategy | ✅ `inherit` (takes the parent conversation's model — the official recommendation) | plugin-dev/skills/agent-development/SKILL.md § model |

---

## Changelog

- **0.1.0** — first release: 11 commands, 2 hooks, 2 agents; migrated from an earlier skill-only form.

---

## License

Released under the [MIT License](LICENSE).

**About `references/`:**

- Everything here is sdd's **own content**. The tech-stack guides (`js-style`, `vue-style`, `google-ts-style`, `alibaba-java`, …) distill the key points of the corresponding official specs, with the source noted in each file's frontmatter `source` field — for the full spec, follow the official link; this project does not reproduce the original text.
- `bulletproof-react.md` is a key-points summary of [bulletproof-react](https://github.com/alan2207/bulletproof-react) (MIT).
- The principles in `agent-principles.md` and `frontend-aesthetics.md` are original write-ups, synthesized from common industry engineering and design consensus.

---

<div align="center">

Built with [Claude Code](https://claude.com/claude-code) · Maintained by [@kamioj](https://github.com/kamioj)

</div>
