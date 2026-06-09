---
description: Write or fully rewrite proposal.md (## Why / ## What / ## How / ## Risk). A pre-command hook forces research.md's [TBD] list to be empty. On completion, emit the HARD GATE and wait for user approval
allowed-tools: Read, Write, Edit, Glob
---

# /spec:propose

## Pre-checks

The hook already scanned research.md before the command. If the hook blocks → switch to `/spec:ask` to resolve the [TBD] items.

Stay disciplined at the prompt level too:

- `spec/changes/<name>/research.md` must exist
- `## Open [TBD]` must be empty

## Flow

1. Read research.md: read `## Decided` + `## Practices` / `## Constraints` (the research conclusions for the current direction; `research/` drafts don't participate unless already revived into research.md)
2. Read design.md (if it exists)
3. Write `spec/changes/<name>/proposal.md`
4. **Emit the HARD GATE closing block**

**Full format + HARD GATE approval-marker rules + revision flow** → [`skills/core/references/proposal-spec.md`](../skills/core/references/proposal-spec.md)

## When to also generate tasks.md

When any one condition holds, **the propose stage generates** `spec/changes/<name>/tasks.md` as well:

- Cross-stack project (in the apply stage, two spec-dev instances — frontend + backend scope — are dispatched concurrently to build in parallel)
- The task splits into >5 independent subtasks (a large linear change)
- Multi-executor collaboration (needs the owner field — assigning to different agents / people)

**Simple single-threaded implementation gets none** — apply advances straight down the proposal `## What` list.

### tasks.md generation steps

1. **Source the information** (by priority):
   - Primary: proposal.md `## What` — each What item → one level-1 task node
   - Cross-stack: design.md `## Interfaces` lands the **contract task** (must precede all implementation tasks)
   - Decision detail: research.md `## Decided` is reflected in the concrete actions of the subtasks

2. **Splitting granularity**:
   - Level 1 = the module corresponding to a What item (e.g. "user authentication module", "frontend", "integration")
   - Level 2 = an independently completable sub-action (e.g. "DB schema design", "interface contract OpenAPI")
   - Granularity test: a single subtask **takes an estimated 10 minutes – 1 hour**. Too small, merge; too large, keep splitting

3. **owner assignment**:
   - Cross-stack: mark subtasks `owner: frontend` / `owner: backend`
   - Single executor: no owner
   - Interface contract / DB migration / integration tests often carry **no owner** (main conversation or shared)

4. **deps derivation**:
   - Omitted = sequential (don't write deps)
   - **High-fan-out node** (interface contract / DB migration) → every subtask that depends on it gets an explicit `deps: <node>`
   - **Cross-branch parallel** (frontend mock depends on the backend contract task) → explicit deps skipping the intervening tasks
   - **Terminal integration / e2e tests** → deps list all prerequisites

5. **Execution**: the **main conversation** (not a dispatched dev agent) writes `spec/changes/<name>/tasks.md`, produced in the same propose stage as proposal.md

**Full format + field rules + completion marking + lifecycle** → [`skills/core/references/tasks-spec.md`](../skills/core/references/tasks-spec.md)

## --codex: heterogeneous adversarial review (optional)

With `--codex`, after proposal.md is written, **explicitly** call codex to adversarially poke holes in the solution — before the HARD GATE decision, use a heterogeneous model to expose the solution's logical holes / overlooked failure modes / over-optimistic assumptions.

**codex only critiques, it doesn't edit the solution** (the solution is the product of the user's HARD GATE decision; edits go through `/spec:revise`, and codex can't bypass that decision authority to touch the proposal).

Invoke the unified wrapper script `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1` (Windows workarounds for #336/#337 + `effort=low` for cost control + timeout against hangs + leftover-process cleanup + session parsing all live in the script; "why it must be called this way" is in the script's header comment):

```powershell
$prompt = @"
Adversarially review the following technical solution; surface problems only, don't rewrite it:
logical holes, overlooked failure modes, over-optimistic assumptions, risk points (auth / data loss / concurrency / rollback).
Solution: <full text of proposal.md>
"@
pwsh -File ${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1 -Prompt $prompt -TimeoutSec 180
```

**Save the session id**: the script's last line outputs `OK:session=<id>`; write `<id>` into `spec/changes/<name>/.codex-session` — for a later `/spec:verify --codex` to resume the session so codex remembers the solution it reviewed.

**Attach the critique to the HARD GATE**: codex's findings go as a "⚠️ codex heterogeneous critique" block in the HARD GATE output below, for your decision (which to adopt → `/spec:revise`; explain why for any you don't). **The codex critique does not block the HARD GATE** — you are still the final decision-maker.

## HARD GATE output (fixed closing)

After writing proposal.md (+ possibly tasks.md), you **MUST emit**:

```
<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/<name>/proposal.md
(if tasks.md was generated too → add a line: + tasks.md (<N>-phase breakdown + deps + owner))

Changes: <list each key decision in substance, one line of "what was decided + why" per point — not the empty "made several changes", so the user can decide approval at a glance>

Next:
  ✅ Looks good → run /spec:apply to start implementing
     apply will automatically append the <!-- APPROVED: ... --> marker to the end of proposal.md
  🔧 Tweak one section → /spec:revise [why | what | how | risk]
  💭 Want to talk the direction over → /spec:chat
  🔄 Research needs redoing → /spec:research "<new direction>"
</HARD-GATE>
```

**After emitting the HARD GATE, NEVER write code** — wait for the user to run `/spec:apply` or another command.

The `<!-- APPROVED: ... -->` marker is **appended automatically by `/spec:apply` before it runs** (treating the user's deliberate invocation as the act of approval) — the propose command does not append it directly. This design removes a redundant "reply go" step from the UX.

User rejects → go through `/spec:revise [section]` (local) or `/spec:chat` (rethink the direction).

## Handling rejection

| User reaction | Handling |
|---|---|
| Same goal, minor tweak ("change X to Y") | `/spec:revise [section]`, re-run the HARD GATE |
| Goal / direction changed | `/spec:chat` to talk it through, then decide between `/spec:research <new direction>` and a `/spec:revise` tweak |
| Vague / unclear | Ask "a local tweak or a change of direction", don't guess |

## Anti-patterns

- ❌ Writing code (NEVER Write/Edit project source before the HARD GATE is approved)
- ❌ Starting the proposal while research.md still has [TBD]
- ❌ `## How` copying research.md `## Decided` verbatim (distill, don't transport)
- ❌ Bursting the proposal sections with content (it should move to design)
- ❌ **During the HARD GATE wait**, adding the APPROVED marker yourself without user confirmation (that is "approving on the user's behalf")
- ❌ Keeping the old APPROVED when the user rejects / revises (it should be actively removed by `/spec:revise`)

The full anti-pattern lists for proposal.md / tasks.md are in their respective spec files.
