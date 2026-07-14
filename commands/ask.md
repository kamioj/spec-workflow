---
description: Interrogates preference-driven decision points. Uses AskUserQuestion to work through each [TBD] in research.md one by one; answered items are moved to ## Decided. Inside /spec:workflow it switches to auto triage (decide + mark, no questions). Can be triggered multiple times; new [TBD]s may surface during the process.
allowed-tools: Read, Edit, AskUserQuestion
---
<!-- GENERATED from core/commands/ask.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:ask

## Process

1. Read `spec/changes/<name>/research.md` and list every entry in `## Open [TBD]`
2. For each [TBD], determine its nature:
   - **Factual** (determinable by reading code / docs) → Claude decides, marks "decided from status quo: X", moves to Decided
   - **Preference-driven** (multiple valid options, depends on user trade-offs) → ask via AskUserQuestion
   - **Uncertain → treat as preference-driven** (never skip)
3. **How to ask preference-driven questions** (inherits global *Asking Style* + SKILL "Self-Contained Prompts"):
   - **Every question must be self-contained (top priority)**: ① one-sentence decision statement + ② why it must be settled now (what it affects / what breaks if left open) + ③ for each option, "choosing this leads to what — specific scenario / consequence". **The user must be able to answer without asking a follow-up**.
   - Single-select (architecture A/B/C) or multi-select (which edge cases are in scope); 2–4 options; recommended option goes first, labeled "(recommended)" with a one-line reason
   - **Always include a "skip / minimal" option** (SKILL Claim Self-Review fourth question applied at the ask stage): preference-driven questions MUST include a "don't do it yet (cost = X)" or "minimal viable (cost = Y)" candidate, to force the question "is this even necessary?" — unless there is genuinely no "skip" path for this decision (the cache example below is the canonical model). Not every option should be a variant of "which way to do it".
   - More than 4 options → use progressive narrowing: ask the broad category first, then narrow
   - Mutually dependent decision points: one question at a time, expand the next question based on the answer (don't pre-enumerate); mutually independent points: batch up to 4 questions at once

   **Anti-example → Correct example** (same [TBD]: cache library selection):
   - ❌ Empty question (will get follow-ups like "what does it affect / why recommend"): `Which cache? Redis(recommended) / Caffeine / Neither`
   - ✅ Self-contained:
     > Cache library selection — affects whether multiple instances read stale data:
     > • Redis (recommended): shared across instances, strongly consistent across machines; cost = extra dependency + network round-trip per read
     > • Caffeine: fastest in-process, zero dependencies; cost = each instance holds its own copy, **data inconsistent across machines**
     > • Skip for now: simplest; cost = high-frequency reads hit the DB directly, revisit when load demands it
4. Before the first question, one-line declaration:
   ```
   Found N open decisions — working through them one by one. This may not be exhaustive; flag anything I miss.
   ```
5. **After the user answers → write back to research.md**:
   - Remove the entry from `## Open [TBD]`
   - Append to `## Decided`:
     ```
     [DEC-N] <decision> | source [TBD-N] | rationale: <distilled from user's answer>
     ```
6. **New [TBD]s surface during the process** → proactively append them to `## Open`, announce "found M new TBDs", continue asking

## Auto triage (workflow-invoked mode)

When `/spec:workflow` orchestrates this stage, the flow is two-touchpoint by design (HARD GATE + acceptance): do **NOT** ask the user question by question. Triage every `[TBD]` instead — **all of them end up in `## Decided`** (the pre-propose hook still requires `## Open` to be empty; leaving escalated items Open would deadlock the flow):

1. **Factual** (determinable from code / docs / spec/knowledge.md) → decide from evidence, exactly as in the interactive flow: `[DEC-N] <decision> | source [TBD-N] | decided from status quo: <evidence>`
2. **Preference-driven, reversible and cheap** → decide the recommended option yourself: `[DEC-N] <decision> | source [TBD-N] | auto | <one-line rationale> | reversibility: <how to undo>`
3. **Preference-driven, irreversible or product-semantics** — any of: data migration / schema change / public API surface / new dependency / destructive operation / user-visible product semantics; **when unsure, it is in this class** → still decide the recommended option, but mark it: `[DEC-N] <decision> | source [TBD-N] | escalated | <rationale> | if wrong: <blast radius>`

Every `auto` / `escalated` decision runs the **four-question filter** first (SKILL "Claim Self-Review"): why needed / when favorable / cost / can it be cut — and **"don't do it / minimal" is ALWAYS among the candidates**. A measure that survives only because "it might help" does not survive.

**Surfacing contract** (what makes self-deciding safe — the decisions are never silent):
- `auto` decisions → listed at the HARD GATE under `Decided without asking` (one line each + reversibility)
- `escalated` decisions → the HARD GATE's `Escalated decisions` section, **pinned at the top of the gate block**; they stand by default — silence + `/spec:apply` = consent; the user overturns any with one line of evaluation (applied via `/spec:revise`), and `/spec:apply` echoes them once more at its first line
- Standalone user-invoked `/spec:ask` keeps the interactive flow above — this section changes nothing about it

## Stopping conditions

| Situation | Action |
|---|---|
| Open [TBD] cleared | Stop; prompt "ready for /spec:propose" |
| User says "stop asking" / "that's enough" | Stop; leave remaining items Open (the pre-/spec:propose hook will block execution) |
| Interrogation diverges and can't be resolved | Stop; report "collected N decisions, M items remain — suggest revisiting later" |

## Anti-patterns

- ❌ Silently deciding a [TBD] based on assumed knowledge (interactive mode: MUST ask the user; auto-triage mode: deciding is legal but MUST carry the `auto` / `escalated` mark — "silent" means unmarked, and an unmarked self-decision is a violation in both modes)
- ❌ Treating a preference-driven point as factual and skipping it
- ❌ Throwing 5+ questions at the user at once (violates the 2–4 options + max-4-questions-per-round rule)
- ❌ Producing a "decision tree" artifact (creates a false sense of completeness)
- ❌ Empty questions: listing "A / B / C" without saying why it matters and what each option leads to (forcing the user to ask back = the number-one failure mode)
- ❌ Every option being a variant of "which way to do it" — never offering a "skip / remove" escape hatch (strips away the fourth self-check question; user cannot challenge "is this even necessary?")

## What this command does NOT do

- Does not write proposal.md (that is `/spec:propose`'s job)
- Does not touch drafts under `research/`; only works research.md, moving Open items into Decided
