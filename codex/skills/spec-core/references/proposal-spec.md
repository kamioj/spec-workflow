<!-- GENERATED from core/references/proposal-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# proposal.md spec

`spec/changes/<change-name>/proposal.md` is the **final-solution artifact** of the sdd workflow. Produced by `$spec-propose`, it carries the HARD GATE approval marker.

## Format

```markdown
# Proposal: <change-name>

## Why
Why this change is being made (business motivation / technical pain / time window). 1–3 paragraphs.

## What
What concretely changes (files / modules / interfaces / additions / deletions / renames). A list is fine.
- <item> | verify: <observable behavior or executable check that proves this item landed>
- ...

**Not in this change**: <1–3 lines of adjacent scope explicitly excluded — the boundary of what approval covers>

## How
Key technical decisions (distilled from research.md `## Decided`, **not copied verbatim**):
- Choice: X (not Y)
- Reason: one distilled sentence — **the conclusion and reason must be self-contained here**; the deep argument lives in design `## Key Decisions` (apply doesn't read research, so a pointer can't stand in for the conclusion)
- Failure strategy / key algorithm / key parameters ... — any fallback / degrade / compat behavior the implementation may introduce **MUST be decided here or in `## Risk`**; `$spec-verify`'s charter audit treats untraceable fallbacks as defects (critical on data-write paths)

## Risk
- Blast radius: which modules / interfaces / user scenarios are affected
- Risk: **the concrete hazard of each key decision + its trigger scenario** (not a vague "there may be risk"; it must explain "under what operation it fails in what way") + mitigation
- Rollback plan: how to back it out
```

## Section constraints

- Each section **≤ 5 lines** (What: ≤5 items; the `| verify:` clause on an item and the closing **Not in this change** block don't count toward the limit)
- Content over the limit → move it to `design.md`, **don't stuff it into the proposal**
- `## How` distills `research.md ## Decided`, doesn't copy it verbatim
- **What / How must pass question ④ (cut it)**: before committing a non-trivial What item / How decision, ask "what happens if I remove it" and don't write what makes no difference removed (SKILL § Claim Self-Review) — this is the precondition for the HARD GATE change points to let the user judge "approve or not" at a glance

## HARD GATE block sections (order is contract)

The gate block emitted by `$spec-propose` / `$spec-revise` (full template in propose.md, mirrored in SKILL § HARD GATE flow — keep the two verbatim-identical) presents, in this order:

1. `Escalated decisions` — **always first when present** (irreversible-class provisional calls; they stand by default, silence + `$spec-apply` = consent, one reply line overturns; `$spec-apply` echoes them again at its first line)
2. `Changes` — 3–6 key decisions, each a **same-scenario before/after mirror**: Problem / After / Cost, Problem and After ≤2 lines each; register test: a non-developer can tell what problem each point solves
3. `Decided without asking` — factual + `auto` triage decisions, one line each + reversibility (mandatory line, "none" allowed)
4. `Unresolved critique` — critique-panel findings still open after the one refutation round (they live as round-0 ledger findings)
5. `Not in this change` — the approval boundary

The user's reply is an evaluation: per-item adopt / refute (with reason) / partial, one response round, user final; insisted items are applied and ledger-marked `user-override`.

## HARD GATE approval marker

The `<!-- APPROVED: YYYY-MM-DD HH:mm -->` marker is **appended automatically by `$spec-apply` before it runs** (treating the user's deliberate invocation as the act of approval).

The timestamp uses the current ISO local time.

This marker is simultaneously:
- the contract `codex/hooks/check-archive` enforces at archive time (a change without it = flow bypassed) and `codex/hooks/check-verify-reminder` uses to detect the implementation window
- an **audit record**: git log shows when it was approved

(`codex/hooks/check-gate` deliberately does **not** require it — that hook fires before apply runs, and apply is what appends the marker; requiring it there would deadlock the flow. Hooks signal blocking via stdout `{"decision":"block"}`.)

**propose does not append APPROVED directly** — the HARD GATE is the user's decision point, and APPROVED is apply's contract action. Separating them spares the flow a redundant "reply go" step.

## $spec-revise revisions

Any revision MUST:

1. Actively **remove the old `<!-- APPROVED: ... -->` marker** (any revision invalidates the old approval)
2. Re-emit the HARD GATE after editing and wait for the user's decision
3. When the user runs `$spec-apply`, apply appends the new APPROVED marker automatically (no "go" reply needed)

If the old APPROVED isn't removed after a revise → apply sees a marker and won't append a fresh one, and status / check-archive treat the pre-revision approval as still valid — the approval audit trail lies about what was actually approved.

## $spec-revise's editable sections

| Parameter | Section edited |
|---|---|
| `why` | `## Why` |
| `what` | `## What` |
| `how` | `## How` |
| `risk` | `## Risk` |

On revise, **leave the other sections untouched** — edit only the named section (a full rewrite goes through `$spec-propose`).

## Anti-patterns

- ❌ Adding the APPROVED marker yourself during the HARD GATE wait, before any approval word
- ❌ Keeping the old APPROVED when the user rejects / revises
- ❌ `## How` copying `research.md ## Decided` verbatim (it should distill)
- ❌ Stuffing content past the section limit (it should move to design.md)
- ❌ Risk written as vague filler ("there may be a performance risk") without anchoring the trigger scenario / concrete hazard (SKILL Claim Self-Review question ③)
- ❌ What listing "everything I can think of changing" without passing question ④'s cut (leaving the HARD GATE change points unjudgeable for approval)
- ❌ A What item without a `verify:` clause (Completeness verification has nothing falsifiable to check)
- ❌ Scope limits bolted on after APPROVED as extra HTML comments (they belong in **Not in this change**, re-gated via `$spec-revise what`)
- ❌ Translated section headers (`## 为什么（Why）`) — headers are always the English canonical forms; prose follows the working language
