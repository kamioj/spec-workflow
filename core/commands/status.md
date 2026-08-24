---
description: Reports where the current SDD change stands, what artifacts exist, and which commands can be run next. Use when returning after an interruption and unsure where things left off.
allowed-tools: Read, Glob, Bash(ls:*)
---

# /spec:status

## Task

Read the `spec/changes/` directory (excluding `archive/`) and output the current change status.

## Inspection process

1. **Glob `spec/changes/*/`** to list all un-archived changes; classify each dir first:
   - `.paused` present → **paused** (report its date + reason line; excluded from stage detection and next-step recommendations)
   - `fix.md` present AND `proposal.md` absent → **fix batch** (streaming light tier; stage from fix.md's `status:` field + pending F-N entry count)
   - `quick.md` present AND `proposal.md` absent → **legacy quick change** (pre-0.6.0 light tier; stage from quick.md's `status:` field)
   - otherwise → normal full change (an upgraded light-tier dir with proposal.md lands here — precedence: proposal.md wins)
2. For each change, check artifact presence:
   - `research.md` (current research) + discarded drafts under `research/` (if any), `index.md`, `design.md`, `proposal.md`, `tasks.md`
3. Read `research.md` to count `[TBD-N]` entries under `## Open [TBD]` and the number of `## Decided` entries — splitting Decided by mark: plain / `auto` / `escalated`; count discarded drafts under `research/` (if any)
4. Read `proposal.md` to check whether the HARD GATE approval marker is present (`<!-- APPROVED: YYYY-MM-DD HH:mm -->`)
5. Read `verify.md` (the verification ledger, if present): frontmatter `round` / `conclusion` + count of Status=open findings, split by origin (round 0 = critique panel / verifier rounds / `source: user`)

## Output format

No active change:

```
No active SDD change.
Start a new task: /spec:research "<direction>"
```

Active change present:

```
Active change: <kebab-name>
Artifacts:
  research.md ✓ (current research)
    Drafts:      <K> (under research/, if any)
    Open [TBD]:  <N>
    Decided:     <M> (<A> auto, <E> escalated — escalated stand unless overturned at the gate)
  design.md   <✓/✗> (note whether one is needed if absent)
  proposal.md ✓ (HARD GATE: <pending approval / approved / rejected>)
  tasks.md    <✓/✗>
  verify.md   <✓/✗> (round <N>, <pass/fail>, <M> open — critique r0: <C> · verifier: <V> · user-sourced: <U>)

Milestone:
  Rounds so far: <e.g. "critique r0 (2 findings, 1 fixed) → verify r1 (pass) → user eval r2 (1 open)">
  Touchpoint position: <before HARD GATE / between gate and acceptance / at acceptance (loop ends when you say "archive")>

Current stage: <determined by the state machine below>
Recommended next step: <mapped from the state machine below — do not generate from memory>
```

Paused changes are listed separately, never counted as active:

```
Paused changes:
  <name> — paused <date>, reason: <reason>   (resume: /spec:resume)
```

A fix batch reports its own two-line form: `Fix batch: <N> entries pending audit — <open/shipped> (streaming light tier; /spec:fix appends, /spec:ship audits + archives)`. A legacy quick change reports: `Quick change: <name> — <in-flight/done> (pre-0.6.0 light tier; archive when done)`.

Multiple un-archived ACTIVE changes → list all, and add a note: this workflow is designed for **a single active change**; there is no switch command. When multiple exist, `/spec:archive` the completed one(s) or `/spec:stash` the not-current one(s) first.

## State machine mapping (authoritative definition of "Current stage" + "Recommended next step" output)

**Generate output strictly from the table below** — do not fill in from training-data memory, or you will output stale flow steps (e.g., "reply go to proceed").

**Recommended next step must be self-contained** (SKILL "Self-Contained Prompts"): do not just throw a command name — include "why this step" (the specific reason the current state leads here). The recommendation texts in the table already include a brief rationale; copy them as-is, do not trim them down to a bare command.

| Detection condition | Current stage | Recommended next step (output this text verbatim) |
|---|---|---|
| `spec/changes/` is empty (or holds only paused dirs) | No active change | `/spec:research "<direction>"` to start a new survey (paused changes present → or `/spec:resume` to pick one back up) |
| dir has `.paused` | Paused | Report only ("paused <date>: <reason>"); no next step is recommended for a paused change — `/spec:resume` when the user wants it back |
| `fix.md` present, `proposal.md` absent, `status: open` | Fix batch open (N entries pending) | Keep streaming with `/spec:fix`, or close the batch with `/spec:ship` (ONE audit over the accumulated diff, then archive) — a fixes dir doesn't block anything |
| `fix.md` present, `proposal.md` absent, `status: shipped` | Fix batch shipped, archive pending | The archive move didn't complete — re-run `/spec:ship` (it skips the audit and redoes the move) |
| `quick.md` present, `proposal.md` absent | Legacy quick change (pre-0.6.0) | `status: done` → archive when ready (`/spec:archive`); otherwise finish per its quick.md record — new light-tier work uses `/spec:fix` |
| `research.md` exists + `## Open [TBD]` is non-empty | Research has open TBDs | `/spec:ask` to work through the pending decisions |
| `research.md` exists + Open [TBD] empty + no `proposal.md` | Interrogation done, awaiting propose | For complex tasks, `/spec:design` first (architecture / >3 interfaces / data-flow diagram); otherwise `/spec:propose` |
| `proposal.md` exists + **no** `<!-- APPROVED: ... -->` marker | Awaiting HARD GATE approval | ✅ Satisfied → `/spec:apply` (apply auto-appends APPROVED then implements)<br>🔧 Partial changes → `/spec:revise [why \| what \| how \| risk]`<br>💭 Want to discuss → `/spec:chat`<br>🔄 Direction changed → `/spec:research "<new direction>"` |
| `proposal.md` has APPROVED + tasks.md (if present) has unchecked tasks, or code changes have not been through verify | In progress | `/spec:apply` to continue; when the last item lands, `/spec:verify` runs the ONE closing independent pass |
| Main implementation done but no `verify.md` ledger yet (or code changed since its last round) | Awaiting verification | `/spec:verify` to run the four-dimension + charter check |
| `verify.md` latest round `conclusion: fail` (incl. escalated still-open findings) | Verification failed | Review the ledger's open findings: `/spec:apply` to continue fixing / `/spec:revise` to fix the proposal (if the proposal itself is wrong) |
<!-- host:claude -->
| `verify.md` latest round `conclusion: pass` | Verification passed (independent review) | Optional: heterogeneous Codex peer review → `/spec:verify --codex` (fills blind spots; `--fix` lets Codex apply fixes). **Do not proactively recommend archive** — call `/spec:archive` when you want to archive |
<!-- /host -->
<!-- host:codex -->
| `verify.md` latest round `conclusion: pass` | Verification passed (independent review) | **Do not proactively recommend archive** — call `/spec:archive` when you want to archive |
<!-- /host -->
| The user explicitly said "archive" in conversation (not file-detectable — never inferred from artifacts alone) | Ready to archive | `/spec:archive` |

<!-- host:codex -->
> Heterogeneous peer review (`--codex`) is not available in this port — Codex cannot be its own heterogeneous reviewer.

<!-- /host -->
**Key anti-patterns**:

- ❌ Outputting "approve → reply go" during the awaiting-approval stage (**deprecated** — `/spec:apply` now auto-appends APPROVED; there is no "reply go" intermediate step)
- ❌ Proactively pushing "you can run /spec:archive now" at the verification-passed stage (user decides; do not push)
- ❌ Generating "Recommended next step" from memory — MUST cross-reference the table above for the current stage

## What this command does NOT do

- Does not create or modify any files
- Read-only
