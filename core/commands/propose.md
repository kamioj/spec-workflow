---
<!-- host:claude -->
description: Write or fully rewrite proposal.md (## Why / ## What / ## How / ## Risk). A pre-command hook forces research.md's [TBD] list to be empty. On completion, emit the HARD GATE and wait for user approval
<!-- /host -->
<!-- host:codex -->
description: Write or fully rewrite proposal.md (## Why / ## What / ## How / ## Risk). A pre-command hook forces research.md's [TBD] list to be empty. On completion, emit the HARD GATE and wait for user approval.
<!-- /host -->
allowed-tools: Read, Write, Edit, Glob, Bash
---

# /spec:propose

## Pre-checks

<!-- host:claude -->
The hook already scanned research.md before the command. If the hook blocks → switch to `/spec:ask` to resolve the [TBD] items.
<!-- /host -->
<!-- host:codex -->
The hook already scanned research.md before the command. If the hook blocks (outputs `{"decision":"block"}` to stdout, codex/hooks/) → switch to `/spec:ask` to resolve the [TBD] items.
<!-- /host -->

Stay disciplined at the prompt level too:

- `spec/changes/<name>/research.md` must exist
- `## Open [TBD]` must be empty

## Flow

1. Read research.md: read `## Decided` + `## Practices` / `## Constraints` (the research conclusions for the current direction; `research/` drafts don't participate unless already revived into research.md)
2. Read design.md (if it exists)
3. Write `spec/changes/<name>/proposal.md` — every `## What` item carries a `| verify: <observable behavior / executable check>` clause, and the section closes with a **Not in this change** list (adjacent scope explicitly excluded). Two later stages consume these: `/spec:verify` checks Completeness against the `verify:` clauses; the HARD GATE shows Not-in-this-change as the approval boundary
4. **Run the critique panel** (section below) — surviving findings land in the verification ledger as round 0
5. **Emit the HARD GATE closing block**

**Full format + HARD GATE approval-marker rules + revision flow** → [`skills/core/references/proposal-spec.md`](../skills/core/references/proposal-spec.md)

## When to also generate tasks.md

**The generation decision is declared at the gate, never silently attached**: the user must see which trigger fired and how the work was split (the gate template's tasks line carries trigger + split), so they can veto the need or the granularity before /spec:apply.

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

## Critique panel (runs after proposal.md is written, before the HARD GATE)

The proposal's quality guard is structural adversarialism, not a smarter single author. Dispatch independent critics **in parallel (one message)**, each with a **fresh context** (it reads only proposal.md + design.md + research.md `## Decided` — never this conversation) and **one locked stance**. Describe the role inline in the dispatch prompt — no dedicated critic agent file ships with sdd.
<!-- host:codex -->
(`spawn_agent` parameter contract: EITHER `message` — plain text only — OR `items` when attaching skill references; both together is rejected.)
<!-- /host -->

| Lens | Locked stance | On |
|---|---|---|
| **necessity** (chief) | "Oppose every measure by default." Four-question refutation of every `## What` item and every fallback / degrade / compat path in `## How`: why is it needed / what breaks if removed / does the triggering scenario actually occur in this business / is this optimal. **Verdict split**: a **silent fallback** (swallows failure, falls back to old logic, degrades pretending to be normal) with no real triggering-scenario evidence → recommend deletion; a **loud guard** (boundary validation / idempotency / CAS / throws on failure) is judged by "what invariant does it protect + blast radius if broken", **never** by incident history — tail-risk defenses may survive without one | always |
| **regression-compat** | what existing behavior, consumer, or installed user does this change break | always |
| **testability** | is every What item's `verify:` clause actually falsifiable — could it pass while the feature is broken | always |
| **security** | auth / permissions / external input / data-write paths | only when What/How touches those |
| **performance** | hot paths / loops / batch queries / N+1 | only when What/How touches those |

**Discipline** (reuses the spec-verifier protocol — the anti-sycophancy measures are structural, not tonal):
- **evidence-or-drop**: a finding must cite the concrete proposal line + the concrete scenario where it bites; "this might be risky" is dropped unwritten
- **≤3 findings per lens** — forced ranking, no noise dumps
- **ONE refutation round**: the proposing conversation defends each finding citing evidence or a Decided entry; a finding neither refuted nor adopted stays open. No second debate round — multi-round agent-to-agent debate is measured net-negative (critics start conceding and flipping correct answers)
- **Non-blocking**: the panel never vetoes. Open majors ride the gate's `Unresolved critique` line; the user is the judge

**Ledger round 0**: write the panel's surviving findings to `spec/changes/<name>/verify.md` as **round 0 (stage: propose)** with stable V-N IDs, same table format as /spec:verify's rounds (create the file if absent). `/spec:verify`'s next round re-checks every still-open one. Adopted findings that changed the proposal are marked `fixed(r0)`.

<!-- host:claude -->
## --codex: heterogeneous adversarial review (optional)

With `--codex`, after proposal.md is written, **explicitly** call codex to adversarially poke holes in the solution — before the HARD GATE decision, use a heterogeneous model to expose the solution's logical holes / overlooked failure modes / over-optimistic assumptions.

**codex only critiques, it doesn't edit the solution** (the solution is the product of the user's HARD GATE decision; edits go through `/spec:revise`, and codex can't bypass that decision authority to touch the proposal).

Invoke the unified wrapper script `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1` (Windows workarounds for #336/#337 + `effort=low` for cost control + timeout against hangs + leftover-process cleanup + session parsing all live in the script; "why it must be called this way" is in the script's header comment):

> Executed by Claude inside the session (`${CLAUDE_PLUGIN_ROOT}` resolves only there) — **not** a command for you to run in a terminal.

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
<!-- /host -->
<!-- host:codex -->
> Heterogeneous peer review (`--codex`) is not available in this port — Codex cannot be its own heterogeneous reviewer.
<!-- /host -->

## HARD GATE output (fixed closing)

After writing proposal.md (+ possibly tasks.md), you **MUST emit**:

```
<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/<name>/proposal.md
(if tasks.md was generated too → declare the decision, not just the fact:
 + tasks.md — trigger: <cross-stack / >5 subtasks / multi-executor>; split: <N> groups — <one-line group list>
   disagree with the need or the split → say so now, before /spec:apply)

Escalated decisions — pinned FIRST, never buried. Irreversible-class calls the agent made
provisionally (data migration / schema / public API / new dependency / destructive op /
user-visible product semantics). They stand by default: silence + /spec:apply = consent;
overturn any with one line of reply. Omit the whole section when there are none.
  E1. <decision> | basis: <evidence or default used> | if wrong: <blast radius + undo path>

Changes — the explanation layer for the decision-maker. proposal.md stays compressed for
the executor; this block is where it gets explained. NEVER paste proposal lines verbatim.
One block per key decision (3–6), each a before/after mirror of the SAME concrete scenario;
Problem and After are ≤2 lines each (longer = you are explaining mechanism — that belongs
in proposal/design, not here):

  1. <the decision, one plain sentence>
     Problem: when <who does what concretely>, because <what is missing/wrong today>,
              <the concrete bad outcome>.
     After:   when <the same action>, because <what this change adds>, it <mechanism used>,
              so <that bad outcome no longer happens>.
     Cost:    <the price paid — dependency / latency / limitation / rework>

Register test: a reader who is NOT a developer can tell what problem every point solves
and how. Define each domain term at first use; a line only an insider can parse must be
rewritten around its scenario.

Decided without asking: <[TBD]s resolved autonomously (factual + auto), one line each — the
evidence or default used + reversibility; "none" if none — mandatory line, it lets the user
catch a misclassified preference>
Unresolved critique: <critique-panel findings that survived the refutation round unresolved,
one line each with the panel's evidence (they sit as open round-0 findings in the ledger);
"none" if none>
Not in this change: <mirror What's "Not in this change" list — what approval does NOT cover>

Next:
  ✅ Looks good → run /spec:apply to start implementing
     apply will automatically append the <!-- APPROVED: ... --> marker to the end of proposal.md
  🔧 Tweak one section → /spec:revise [why | what | how | risk]
  💭 Want to talk the direction over → /spec:chat
  🔄 Research needs redoing → /spec:research "<new direction>"
</HARD-GATE>
```

**Evaluation response protocol** (how to receive the user's reply to this gate): the user's
reply is an evaluation, not a command sheet. Respond to EVERY item in it explicitly —
**adopt** (apply via /spec:revise) / **refute** (state the reason: evidence or a Decided
entry) / **partial** (which half and why). One response round only; the user has the final
say — an item the user insists on after your refutation is applied AND recorded in the
ledger as a user-override (the lesson later lands in spec/knowledge.md at archive time).
Absorbing every point without examination is sycophancy toward the user — the flow's
quality depends on criticism running in both directions.

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
- ❌ A `## What` item without a `verify:` clause (leaves /spec:verify's Completeness check nothing falsifiable)
- ❌ Translating section headers (e.g. `## 为什么（Why）`) — headers are always `## Why / ## What / ## How / ## Risk`; `/spec:revise` targets sections by English name
- ❌ Gate Changes written in insider shorthand ("three-layer CAS idempotency guarantee (DEC-8/9/11)") — that is executor register; the gate is decision-maker register (Problem / After / Cost, same-scenario mirror)
- ❌ Skipping the critique panel, or running it and withholding open findings from the gate (the user judges with full information or the gate is theater)
- ❌ Absorbing every user evaluation without a per-item adopt/refute/partial response (sycophancy toward the user is still sycophancy)
- ❌ **During the HARD GATE wait**, adding the APPROVED marker yourself without user confirmation (that is "approving on the user's behalf")
- ❌ Keeping the old APPROVED when the user rejects / revises (it should be actively removed by `/spec:revise`)

The full anti-pattern lists for proposal.md / tasks.md are in their respective spec files.
