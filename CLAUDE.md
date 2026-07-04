# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is a **Claude Code plugin marketplace** housing the `sdd` (spec-driven development) plugin. **There is no application code, no compile/build/test runner** — the "source" is markdown commands, JSON manifests, PowerShell hook scripts, and ast-grep rule packs (`rules/`, consumed by the spec-verifier's charter audit). Edits take effect immediately; "testing" means loading the plugin and actually running the commands.

Manifest layout: `.claude-plugin/` holds both `marketplace.json` (`source: "./"`, pointing back at the repo root) and `plugin.json` (the plugin itself) — this is the source-self-referencing single-plugin layout, where the repo root is the plugin root. When changing plugin metadata, **keep both manifests in sync** (name / version / description).

## Dev loop (no build/test — load and run for real)

```pwsh
# Local development: load the source copy directly, which wins over the marketplace cache, so edits are testable immediately
claude --plugin-dir .

# Release loop: sync the cache after pushing
git add . ; git commit -m "..." ; git push
claude plugin marketplace update spec-workflow
```

**Key: changing anything under `hooks/` (hooks.json or .ps1) requires restarting Claude to take effect** — commands / skills / agents hot-reload, hooks don't. This is the easiest trap: edit a hook without restarting and you're testing the old behavior.

Validate all JSON manifests (no CI — run it by hand):
```pwsh
Get-ChildItem -Recurse -Filter *.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null; "OK: $($_.Name)" }
```

Test a single hook in isolation (a hook reads JSON from stdin, exit 2 = block, exit 0 = allow):
```pwsh
'{"user_prompt":"/spec:apply","cwd":"D:\\path\\to\\test-project"}' | pwsh -NoProfile -File hooks/check-gate.ps1 ; "exit=$LASTEXITCODE"
```

## Platform constraints

**Windows-only**: hooks are written in pwsh (PowerShell 7). **Always use `pwsh`, never `powershell`** — PS 5.1 defaults to GBK encoding, which corrupts Chinese in pipelines. The hook scripts explicitly set UTF-8 stdin/stdout in their headers; cross-platform support needs an equivalent bash/sh rewrite (the README "Limitations" notes this as a known gap).

## Big picture: soft vs hard constraints

The whole design of sdd centers on "**stopping for real where you have to stop**", via two layers:

1. **Soft constraints** (the command / agent markdown prompts saying "you must do X") — the model can violate them.
2. **Hard constraints** (`hooks/*.ps1` shell scripts that intercept) — a 0% violation rate.

The three gate hooks are attached to the `UserPromptSubmit` event (see `hooks/hooks.json`) and decide whether to intervene by **regex-matching the command name in the user input**; a fourth, `check-verify-reminder.ps1`, is attached to the **Stop** event (a reminder, not a gate):

| Hook | Matches | Blocks | When unsatisfied |
|---|---|---|---|
| `check-tbd.ps1` | `/spec:propose` | research.md's `## Open [TBD]` section still has `[TBD-N]` | `exit 2`, points to `/spec:ask` |
| `check-gate.ps1` | `/spec:apply` | proposal.md lacks the `<!-- APPROVED: ... -->` marker | `exit 2`, points to passing the HARD GATE first |
| `check-archive.ps1` | `/spec:archive` | the change bypassed the flow: proposal without APPROVED / tasks.md with unchecked items / no proposal.md | `exit 2`, lists the findings; deliberate override = the prompt contains `force` or `abandon(ed)` (the archive command then records the reason in retrospect.md) |
| `check-verify-reminder.ps1` | Stop event (end of a Claude turn) | the single active change has an APPROVED proposal but no verify.md ledger — implementation ended without a closing verification | `exit 2`, nudges Claude to run the closing verification or state explicitly why it's pausing; `stop_hook_active` in stdin guards against loops (one nudge per stop cycle) |

Hook conventions (must hold when editing hooks):
- The stdin JSON field is named **`user_prompt`** (not `prompt`) + `cwd`. This was a trap we hit; the README records the evidence specifically.
- **fail-open**: a hook erroring out goes to catch → `exit 0` (allow). A bug in a hook must never block the user's normal flow.
- `check-gate.ps1`'s APPROVED regex recognizes only the `<!-- APPROVED:` comment form (which is exactly what apply writes; bare text / headings are not recognized, to avoid the body text mentioning the word being misread as approval). When changing the marker format, change the regex together with it.
- **Multiple active changes**: check-tbd and check-gate `exit 2` when there is >1 non-archive directory under `spec/changes/`, requiring you to archive down to a single change first (this workflow assumes a single active change, otherwise a draft change cross-blocks an approved one). check-archive deliberately does **not** block on multiple changes — archiving is exactly how you get back down to one.

## Big picture: commands + agent + artifacts

**11 independent slash commands** (`commands/*.md`), each independently triggerable, re-entrant, and re-runnable on its own — this is the positioning difference from OpenSpec (4 commands all-in-one) / superpowers (a rigid 9-step flow). The typical flow:
`research → ask → (design) → propose → [HARD GATE] → apply → verify → archive`. `/spec:workflow` runs the whole flow end-to-end, `/spec:status` reports which step you're on.

**The HARD GATE mechanism** (runs through propose/revise/apply):
- propose/revise, after writing the proposal, **must emit the fixed `<HARD-GATE>` closing block**, then stop and wait for the user. The gate's Changes block is the **explanation layer**: scenario-based plain language for the decision-maker (Scenario / Avoided by / Cost per decision, plus "Decided without asking" and "Not in this change" lines) — proposal.md stays compressed for the executor; never paste its lines verbatim into the gate.
- The `<!-- APPROVED: YYYY-MM-DD HH:mm -->` marker is **appended by `/spec:apply` before it runs** (treating "the user deliberately invoking apply" as the act of approval) — **not** appended by propose, and **no** "reply go" from the user is needed. This is a redundancy recently refactored out (see git log `fix: simplify HARD GATE`); when changing this logic, take care not to add "reply go" back.
- After emitting the HARD GATE, **NEVER write project source**; wait for the next command.

**1 development agent** (`agents/spec-dev.md`), dispatched by scope in the `/spec:apply` stage (cross-stack = dispatch two concurrently in one message: frontend + backend scope):
- Dispatched by the type of code the proposal `## What` involves (frontend UI/routing/components vs backend API/data-model/migration).
- **Cross-stack = contract first + parallel**: the interface contract is pinned down in `design.md ## Interfaces` first, then **two agents are dispatched concurrently in one message** (not serial — serial wastes 50% of the time). The agent frontmatter uses `model: inherit`.

**1 verification agent** (`agents/spec-verifier.md`), dispatched by `/spec:verify` with a **deliberately fresh context** — the implementing conversation never audits itself (anti self-review-bias; "be objective" instructions have near-zero measured effect, structural isolation works). Its protocol: Iron Law (no pass without fresh evidence; a dev agent's self-reported Evidence is a claim to re-run, not proof), evidence-or-drop finding format (no quotable code = not a finding, ≤3 findings per dimension), refutation phase (a defense must cite a gate decision — "looks intentional" doesn't count), and an ast-grep machine pass over `rules/sgconfig.yml` (graceful "not run" declaration when ast-grep isn't installed). The main loop copies its findings into the ledger verbatim; user-overruled false positives are distilled into `spec/knowledge.md`.

**opt-in enhancement flags** (`/spec:apply design solid verify`, space-separated, combinable): by default **no** extra reference is loaded, to stay lean and avoid over-caution on tool-type UIs / internal pages / backend business. A flag has to hit before the agent reads the corresponding reference: `design`→frontend-aesthetics (anti-AI-slop), `solid`→agent-principles §1 (anti-laziness), `verify`→agent-principles §2 (anti-hallucination).

## Artifact model (generated in the user's project, not in this repo)

Running sdd produces, in the **target project**:
```
<target-project>/spec/
├── knowledge.md               project-level durable facts, cross-change (maintained by /spec:archive, read first by /spec:research; facts proven wrong are replaced, not appended-contradicted)
├── changes/<change-name>/     active workspace
│   ├── research.md  required  current research (Practices + Constraints + Open[TBD] + Decided, single file)
│   ├── research/    optional  discarded-draft pile of research directions (research.md snapshots of abandoned directions, no markers/links, revivable)
│   ├── design.md    optional  architecture / interface contract / data model
│   ├── proposal.md  required  the final solution (four sections + APPROVED marker; What items carry `verify:` clauses + a closing **Not in this change** list)
│   ├── tasks.md     optional  multi-executor collaboration list (owner + deps)
│   ├── verify.md    at-verify verification ledger (stable V-N finding IDs + round diffing + unfixed-escalation; YAML frontmatter carries round/conclusion state)
│   └── retrospect.md at-archive  written by /spec:archive right before the move (divergence review + verify Evidence + leftovers; YAML frontmatter carries the audit stats)
└── archive/<YYYY-MM-DD-name>/  archived change
```
The hooks judge state from this: they scan the non-`archive` directories under `spec/changes/` as "active changes" (the archive target is the sibling `spec/archive/` directory; the `-ne 'archive'` in the hooks is only defending against the old "once archived into `spec/changes/archive/`" layout, which the current layout doesn't trigger).

**The artifact set is fixed at these four + the discarded-draft pile + the verification ledger + the archive-stage retrospect + the project-level knowledge.md**; what each artifact "writes / doesn't write" and its soft budget live in SKILL § Phase Responsibility Matrix (the source of truth for cross-artifact de-duplication) — the model inventing unplanned extra files (app-current / decisions / migration-inventory, etc.) requires explicit user approval and is a common source of document bloat.

## Writing conventions (follow when editing command/agent/reference)

- **Language**: all plugin content — command docs, the prose in references, agents, SKILL — is written in **native, idiomatic English**. This plugin is built to be shared broadly, so English is the product language. Section headers stay English (`## Why / ## What / ## How / ## Risk`) so hooks can regex-detect them and `/spec:revise <section>` can target them by name. The one maintained Chinese artifact is `README_cn.md`, a courtesy mirror of `README.md` kept in sync.
- **proposal.md needs all four sections**: Why / What / How / Risk.
- **command frontmatter**: `description` + `allowed-tools`. **agent frontmatter**: `name` / `description` / `model: inherit` / `color` / `tools`.
- **Path variables**: hooks and agents reference in-plugin files via `${CLAUDE_PLUGIN_ROOT}/...`, never a hardcoded absolute path.
- **references/ read on demand**: the agent detects the project stack (reading `package.json` / `pubspec.yaml` / `manifest.json`) and reads only the relevant stack's reference, not all of them — to avoid polluting the token budget.
- **One rule scattered across multiple places must stay in sync**: the HARD GATE wording, the stuck-self-check template, and the anti-cheating clauses appear simultaneously in `SKILL.md`, the corresponding `commands/*.md`, and `references/*-spec.md`. When changing one, sweep the rest, otherwise the three fall out of sync. `references/*-spec.md` (proposal/design/tasks-spec) is the **single source of truth** for artifact format; command files point there with relative links. The research format is simple and lives directly in `commands/research.md`, with no separate spec file.

## Shared Principles (agents follow them by default, no opt-in needed — see SKILL.md § Shared Principles)

- **Anti-Cheating**: a command/PoC that hasn't actually run must not be reported as "success"; mocking a fake response / changing an assert / patching a return of true must be stated plainly as "bypass, root cause unresolved"; hardcoding (offsets/hashes) must be flagged in a comment + a "applies to this case only" note in tasks.md; self-reported success from another agent or an earlier round is not verification — it gets independently re-run.
- **Stuck Protection**: 3 consecutive failed fixes in the same direction → stop and emit the "Stuck Self-Check" block, wait for the user's decision, no endless patching. From the 2nd attempt on, each retry must state why the previous one failed (blind retries don't count as attempts).
- **Halt on infeasible task**: finding the premise itself is wrong (contradiction / out of scope / tool incompatible) → stop and report immediately.
