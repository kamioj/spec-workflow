# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **dual-host plugin marketplace** shipping the same sdd (spec-driven development) workflow to two hosts: a **Claude Code plugin** (repo root, `/spec:x` commands) and an **OpenAI Codex CLI plugin** (`codex/`, `$spec-x` skills). **There is no application code, no compile/build/test runner** — the deliverables are markdown prompts, JSON/TOML manifests, hook scripts, and ast-grep rule packs. "Testing" means regenerating, loading the plugin in the real host, and watching a gate actually block.

**This repo dogfoods sdd on itself**: large changes go through the full research → propose → HARD GATE → apply → verify → archive flow. The resulting `spec/` artifacts are **gitignored** (local iteration records, never shipped or committed).

## Single source of truth: core/ (edit core/, never the generated trees)

All shipped markdown in BOTH plugins is generated from **`core/`** by `node tools/generate.mjs`:

| core/ source | Claude tree (near-identity) | Codex tree (6-rule transform) |
|---|---|---|
| core/commands/*.md | commands/*.md | codex/skills/spec-*/SKILL.md |
| core/skill.md | skills/core/SKILL.md | codex/skills/spec-core/SKILL.md |
| core/references/* | skills/core/references/* | codex/skills/spec-core/references/* |
| core/rules/* | rules/* | codex/skills/spec-core/rules/* |
| core/agents/*.md | agents/*.md | codex/agents/*.toml |

- The six mechanical Codex rules: sigil `/spec:x`→`$spec-x` · frontmatter mapping (drop `allowed-tools`/`model`/`color`/`tools`, add `name`) · reference-path rewrite · `--codex` section drop · host-marker selection · agent md→TOML (`developer_instructions = '''body'''`).
- Host-divergent passages use paired `<!-- host:claude -->` / `<!-- host:codex -->` … `<!-- /host -->` blocks (no nesting; unclosed marker or a `'''` in an agent body = generator **hard error**, never a silent skip — same for a missing core source file).
- Generated files carry a first-line/post-frontmatter `GENERATED from core/...` marker. The marker sits **after** YAML frontmatter in .md files (before it would break frontmatter parsing on both hosts) and as a `#` comment on line 1 of .toml/.yml.
- **NOT generator-owned** (hand-maintained): all hooks (`hooks/`, `codex/hooks/`), all manifests, READMEs, install scripts, `codex/skills/spec-setup`, `scripts/`.

## Dev loop (no build/test — regenerate, load, run for real)

```pwsh
# 1. Edit core/ (or a hand-maintained file), regenerate both trees
node tools/generate.mjs
# 2. Local Claude testing: the source copy wins over the marketplace cache
claude --plugin-dir .
# 3. Release: drift check → bump versions in THREE manifests → push
node tools/generate.mjs --check   # nonzero = hand-edit in a generated file or core changed without regenerating
#    .claude-plugin/plugin.json + .claude-plugin/marketplace.json + codex/.codex-plugin/plugin.json
#    (version drives cache refresh on BOTH hosts — Codex caches under <name>/<version>/)
git add . ; git commit -m "..." ; git push
# 4. Update local installs
claude plugin marketplace update spec-workflow
codex plugin marketplace upgrade spec-workflow    # Git-marketplace installs; local-path installs need remove+add instead
```

- **Claude hooks reload via `/reload-plugins`** (verified for the UserPromptSubmit gates + Stop reminder; monitors are the documented exception needing a restart). Commands / skills / agents hot-reload on their own. The old "hooks need a full restart" doctrine is obsolete for current Claude Code — but sessions started BEFORE a plugin update still run the old hook config until `/reload-plugins` or restart, which is the easiest trap in the repo.
- **Codex hooks require re-trusting in the TUI whenever hooks.json changes** (trust is recorded per hook-definition hash). Untrusted hooks are **silently skipped** — no error, no log. After any hook-affecting update, verify the gate bites: in a project with no `spec/changes/`, send `$spec-apply` — it must come back blocked.
- Codex agents aren't plugin-bundled (no such mechanism); `$spec-setup` copies the shipped TOMLs to `~/.codex/agents/` — re-run it after agent changes.

Validate all JSON manifests (no CI — run by hand):
```pwsh
Get-ChildItem -Recurse -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null; "OK: $($_.Name)" }
```

## Manifests (four, roles differ)

- `.claude-plugin/marketplace.json` (`source: "./"` — repo root IS the Claude plugin root) + `.claude-plugin/plugin.json` — the Claude pair, keep name/version/description in sync.
- `.agents/plugins/marketplace.json` — the Codex marketplace (plugin `spec` → `./codex`).
- `codex/.codex-plugin/plugin.json` — the Codex plugin (bundles `skills` + `hooks` keys; Codex also falls back to reading `.claude-plugin/plugin.json`, but we ship both explicitly).

## Big picture: soft vs hard constraints

The whole design centers on "**stopping for real where you have to stop**":

1. **Soft constraints** (prompt text saying "you must do X") — the model can violate them.
2. **Hard constraints** (hook scripts that intercept) — a 0% violation rate.

Four hooks, same semantics on both hosts: three UserPromptSubmit gates match the command **invocation at line start** (never a mention — "what does /spec:apply do?" passes) + one Stop-event reminder:

| Gate | Matches | Blocks when |
|---|---|---|
| check-tbd | propose | research.md still has `[TBD-N]` outside `## Decided` |
| check-gate | apply | proposal.md absent / missing any of the four sections / ≠1 active change. **Deliberately does NOT require the APPROVED marker** — apply appends it after this hook fires (requiring it here = happy-path deadlock, the pre-0.2.3 bug); check-archive enforces it at archive time |
| check-archive | archive | flow was bypassed (no APPROVED / unchecked tasks / no proposal); override = prompt contains `force` or `abandon(ed)` — **matched against the prompt value only**, never the whole stdin JSON (a cwd containing "force" must not bypass; that was finding V-1) |
| check-verify-reminder | Stop event | single active change has an APPROVED proposal but no verify.md ledger; `stop_hook_active` loop-guards (one nudge per stop) |

**The two hook implementations share the sh language but not the contract** — each host's contract was probe-verified and they disagree with each other AND with the docs:

| | Claude Code (`hooks/*.sh`) | Codex CLI (`codex/hooks/*` — see `codex/hooks/SCHEMA.md`, the evidence file) |
|---|---|---|
| stdin user-input field | `prompt` (**probe-verified against real stdin 2026-07-15** — the older `user_prompt` lore was wrong for current Claude Code, which means the pre-0.4.2 ps1 gates had been silently dead on this axis) | `prompt` |
| blocking mechanism | `exit 2` + stderr (**stdout must stay empty** — codex-style stdout JSON does NOT block on Claude; the fixture canary enforces this) | stdout `{"decision":"block","reason":...}` + exit 0 (**exit 2 does NOT block on Codex**) |
| invocation anchor | `^\s*/spec:x` | `^\s*\$spec-x` |
| project dir | `$CLAUDE_PROJECT_DIR` env only — **never parsed from stdin JSON** (sed can't decode `\uXXXX`; a non-ASCII project path would silently kill the gate) | stdin JSON `cwd` (sed parse + un-escape) |
| entry point | hooks.json **shell form**: `sh "$CLAUDE_PLUGIN_ROOT/hooks/check-x.sh"` — runs under sh (macOS/Linux) or Git Bash (Windows); `$CLAUDE_PLUGIN_ROOT` expanded by the shell from the exported env | `command` (sh) + `commandWindows` (pwsh) |
| languages | single POSIX sh implementation, all platforms | pwsh + POSIX sh **twin pairs** — the pair is the unit of change |
| config trap | — | an unknown top-level key in hooks.json (e.g. `description`) makes the whole file **silently ignored** |

Shared conventions across both: **fail-open** (hook internal error / missing `$CLAUDE_PROJECT_DIR` → allow; a hook bug must never block normal flow); the APPROVED regex recognizes only the `<!-- APPROVED:` comment form (what apply writes — bare text mentioning the word must not read as approval); check-tbd/check-gate block on >1 active change, check-archive deliberately doesn't (archiving is how you get back to one).

**After ANY gate edit, run the matching fixture suite** — Claude side: `sh hooks/run-fixtures.sh` (43 cases: 20 scenarios name-synced against the codex set + unicode-path + env-missing fail-open + wrong-contract canary; run it on Git Bash AND `wsl sh hooks/run-fixtures.sh` for a real-POSIX pass). Codex side: `sh codex/hooks/run-fixtures.sh` (40 cases, both twins). Test a Claude hook in isolation:
```sh
printf '%s' '{"prompt":"/spec:apply","hook_event_name":"UserPromptSubmit"}' | CLAUDE_PROJECT_DIR="D:/path/to/test-project" sh hooks/check-gate.sh ; echo "exit=$?"
```

## Platform constraints

**Always `pwsh` (PowerShell 7), never `powershell`, for interactive/dev commands** — PS 5.1 defaults to GBK and corrupts Chinese in pipelines. **Both hook stacks are cross-platform sh since 0.4.2**: Claude-side gates are single POSIX sh implementations run via hooks.json shell form (sh on macOS/Linux, Git Bash on Windows — Git for Windows is a prerequisite Claude Code's own Bash tool already imposes; a Windows box without it gets fail-open gates plus non-blocking hook errors, see README Troubleshooting); Codex-side gates ship pwsh + sh twins (`commandWindows` in hooks.json overrides `command` on Windows — binary-verified field, not in the official docs).

## Big picture: commands + agents + artifacts

**11 independent commands** (`core/commands/*.md` → both hosts), each re-entrant and re-runnable — the positioning difference from OpenSpec (4 commands all-in-one) / superpowers (rigid 9 steps). Typical flow: `research → ask → (design) → propose → [HARD GATE] → apply → verify → archive`; `workflow` runs end-to-end, `status` reports position.

**The HARD GATE mechanism**:
- propose/revise end by emitting the fixed `<HARD-GATE>` block, then stop. The gate's Changes block is the **explanation layer** (Scenario / Avoided by / Cost per decision, plus "Decided without asking" and "Not in this change") — decision-maker register, never proposal lines pasted verbatim.
- The `<!-- APPROVED: -->` marker is appended **by apply before it runs** (deliberate invocation = the act of approval) — not by propose, and no "reply go" is needed. Don't reintroduce a "reply go" step.
- After emitting the HARD GATE, **never write project source**; wait for the next command.

**spec-dev** (dev agent, `core/agents/spec-dev.md`): dispatched by scope at apply time; cross-stack = contract pinned in `design.md ## Interfaces` first, then **two instances dispatched concurrently in one message** (never serial).

**spec-verifier** (verification agent): dispatched by verify with a **deliberately fresh context** — the implementing conversation never audits itself. Protocol: Iron Law (no pass without fresh evidence; self-reported success is a claim to re-run), evidence-or-drop (≤3 findings per dimension), refutation phase (a defense must cite a gate decision), ast-grep machine pass over the shipped rule pack (graceful `not run` declaration when absent).

**opt-in flags** (`apply design solid verify`): no extra reference loads by default; `design`→frontend-aesthetics, `solid`→agent-principles §1, `verify`→agent-principles §2.

## Artifact model (generated in the user's project)

```
<target-project>/spec/
├── knowledge.md               project-level durable facts (archive maintains, research reads first; wrong facts get replaced, not contradicted)
├── changes/<name>/            active workspace
│   ├── research.md  required  Practices + Constraints + Open[TBD] + Decided
│   ├── research/    optional  discarded-draft pile (snapshots of abandoned directions, revivable)
│   ├── design.md    optional  architecture / interface contract / key decisions
│   ├── proposal.md  required  four sections + APPROVED marker; What items carry verify: clauses + Not in this change
│   ├── tasks.md     optional  multi-executor list (owner + deps)
│   ├── verify.md    at-verify verification ledger (stable V-N IDs, round diffing, unfixed-escalation)
│   └── retrospect.md at-archive divergence review + Evidence + leftovers
└── archive/<YYYY-MM-DD-name>/
```

Hooks judge state by scanning non-`archive` directories under `spec/changes/` as active changes. The artifact set is **fixed**; inventing extra files (app-current / decisions / migration-inventory…) requires explicit user approval — a known source of document bloat. Per-artifact write/don't-write boundaries live in SKILL § Phase Responsibility Matrix.

## Writing conventions (when editing core/ or hand-maintained files)

- **Language**: all plugin content is native, idiomatic English (the product language; broad sharing). Section headers stay English (`## Why / ## What / ## How / ## Risk`) so hooks regex them and `revise` targets them by name. `README_cn.md` is the one maintained Chinese artifact, a courtesy mirror kept in sync with `README.md`.
- **core is Claude-canonical**: write `/spec:x`, `AskUserQuestion`, `${CLAUDE_PLUGIN_ROOT}` paths in core; the Codex emitter transforms them. Reach for a host marker only when the hosts genuinely diverge beyond the six rules.
- **Cross-host sync is automated; in-core sync is not**: the HARD GATE wording, stuck-self-check template, and anti-cheating clauses still appear in `core/skill.md`, the corresponding `core/commands/*.md`, and `core/references/*-spec.md` — changing one still means sweeping the others (the generator faithfully propagates inconsistencies to both hosts). `core/references/*-spec.md` remains the single source of truth for artifact formats.
- **Command frontmatter** (core): `description` + `allowed-tools`. **Agent frontmatter** (core): `name` / `description` / `model: inherit` / `color` / `tools`. The Codex emitter maps/drops these automatically.
- **references/ read on demand**: agents detect the project stack and read only the relevant reference — never all of them.
- Public docs (READMEs) carry no iteration narrative and no private project details; process records live in the gitignored `spec/` and in commit messages.

## Shared Principles (agents follow by default — see core/skill.md § Shared Principles)

- **Anti-Cheating**: nothing unrun is "success"; a bypass (mocked response / weakened assert / return-true patch) must be declared as a bypass; necessary hardcoding gets a code comment + "applies to this case only" note; self-reported success from another agent or an earlier round gets independently re-run.
- **Stuck Protection**: 3 consecutive failed fixes in one direction → emit the Stuck Self-Check block and wait; from the 2nd attempt on, each retry must state why the previous failed (blind retries don't count).
- **Halt on infeasible task**: a wrong premise (contradiction / out of scope / tool incompatible) → stop and report immediately.
