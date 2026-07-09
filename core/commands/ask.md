---
<!-- host:claude -->
description: Interrogates preference-driven decision points. Uses AskUserQuestion to work through each [TBD] in research.md one by one; answered items are moved to ## Decided. Can be triggered multiple times; new [TBD]s may surface during the process.
<!-- /host -->
<!-- host:codex -->
description: Interrogates preference-driven decision points. Works through each [TBD] in research.md one by one as numbered plain-text questions; answered items are moved to ## Decided. Can be triggered multiple times; new [TBD]s may surface during the process.
<!-- /host -->
allowed-tools: Read, Edit, AskUserQuestion
---

# /spec:ask

## Process

1. Read `spec/changes/<name>/research.md` and list every entry in `## Open [TBD]`
2. For each [TBD], determine its nature:
   - **Factual** (determinable by reading code / docs) → Claude decides, marks "decided from status quo: X", moves to Decided
<!-- host:claude -->
   - **Preference-driven** (multiple valid options, depends on user trade-offs) → ask via AskUserQuestion
<!-- /host -->
<!-- host:codex -->
   - **Preference-driven** (multiple valid options, depends on user trade-offs) → ask as a numbered plain-text question in the conversation
<!-- /host -->
   - **Uncertain → treat as preference-driven** (never skip)
3. **How to ask preference-driven questions** (inherits global *Asking Style* + SKILL "Self-Contained Prompts"):
<!-- host:codex -->
   - Ask each question as numbered plain-text in the conversation. Do **not** use a structured tool UI — list options as numbered items (1, 2, 3 …), mark the recommended option with "(Recommended)", and wait for the user's answer before moving to the next question.
<!-- /host -->
   - **Every question must be self-contained (top priority)**: ① one-sentence decision statement + ② why it must be settled now (what it affects / what breaks if left open) + ③ for each option, "choosing this leads to what — specific scenario / consequence". **The user must be able to answer without asking a follow-up**.
<!-- host:claude -->
   - Single-select (architecture A/B/C) or multi-select (which edge cases are in scope); 2–4 options; recommended option goes first, labeled "(recommended)" with a one-line reason
<!-- /host -->
<!-- host:codex -->
   - Single-select (architecture A/B/C) or multi-select (which edge cases are in scope); 2–4 options; recommended option goes first, labeled "(Recommended)" with a one-line reason
<!-- /host -->
   - **Always include a "skip / minimal" option** (SKILL Claim Self-Review fourth question applied at the ask stage): preference-driven questions MUST include a "don't do it yet (cost = X)" or "minimal viable (cost = Y)" candidate, to force the question "is this even necessary?" — unless there is genuinely no "skip" path for this decision (the cache example below is the canonical model). Not every option should be a variant of "which way to do it".
   - More than 4 options → use progressive narrowing: ask the broad category first, then narrow
   - Mutually dependent decision points: one question at a time, expand the next question based on the answer (don't pre-enumerate); mutually independent points: batch up to 4 questions at once

   **Anti-example → Correct example** (same [TBD]: cache library selection):
   - ❌ Empty question (will get follow-ups like "what does it affect / why recommend"): `Which cache? Redis(recommended) / Caffeine / Neither`
   - ✅ Self-contained:
     > Cache library selection — affects whether multiple instances read stale data:
<!-- host:claude -->
     > • Redis (recommended): shared across instances, strongly consistent across machines; cost = extra dependency + network round-trip per read
     > • Caffeine: fastest in-process, zero dependencies; cost = each instance holds its own copy, **data inconsistent across machines**
     > • Skip for now: simplest; cost = high-frequency reads hit the DB directly, revisit when load demands it
<!-- /host -->
<!-- host:codex -->
     >
     > 1. Redis (Recommended): shared across instances, strongly consistent across machines; cost = extra dependency + network round-trip per read
     > 2. Caffeine: fastest in-process, zero dependencies; cost = each instance holds its own copy, **data inconsistent across machines**
     > 3. Skip for now: simplest; cost = high-frequency reads hit the DB directly, revisit when load demands it
     >
     > Which do you prefer? (reply with the number)
<!-- /host -->
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

## Stopping conditions

| Situation | Action |
|---|---|
| Open [TBD] cleared | Stop; prompt "ready for /spec:propose" |
| User says "stop asking" / "that's enough" | Stop; leave remaining items Open (the pre-/spec:propose hook will block execution) |
| Interrogation diverges and can't be resolved | Stop; report "collected N decisions, M items remain — suggest revisiting later" |

## Anti-patterns

- ❌ Silently deciding a [TBD] based on assumed knowledge (MUST ask the user)
- ❌ Treating a preference-driven point as factual and skipping it
- ❌ Throwing 5+ questions at the user at once (violates the 2–4 options + max-4-questions-per-round rule)
- ❌ Producing a "decision tree" artifact (creates a false sense of completeness)
- ❌ Empty questions: listing "A / B / C" without saying why it matters and what each option leads to (forcing the user to ask back = the number-one failure mode)
- ❌ Every option being a variant of "which way to do it" — never offering a "skip / remove" escape hatch (strips away the fourth self-check question; user cannot challenge "is this even necessary?")

## What this command does NOT do

- Does not write proposal.md (that is `/spec:propose`'s job)
- Does not touch drafts under `research/`; only works research.md, moving Open items into Decided
