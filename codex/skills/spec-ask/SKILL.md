---
name: spec-ask
description: Interrogates preference-driven decision points. Works through the [TBD]s in research.md via Codex's request_user_input tool when the session has it, else as batched plain-text questions (lettered options, one-line combined reply) after a one-line enablement tip; answered items are moved to ## Decided. Inside $spec-workflow it switches to auto triage (decide + mark, no questions). Can be triggered multiple times; new [TBD]s may surface during the process.
---
<!-- GENERATED from core/commands/ask.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-ask

## Process

1. Read `spec/changes/<name>/research.md` and list every entry in `## Open [TBD]`
2. For each [TBD], determine its nature:
   - **Factual** (determinable by reading code / docs) → Claude decides, marks "decided from status quo: X", moves to Decided
   - **Preference-driven** (multiple valid options, depends on user trade-offs) → ask per the host protocol below (`request_user_input` tool when available, else plain text)
   - **Uncertain → treat as preference-driven** (never skip)
3. **How to ask preference-driven questions** (inherits global *Asking Style* + SKILL "Self-Contained Prompts"):
   - **Tool always, when available**: Codex gates its structured question tool behind an experimental feature flag — with `default_mode_request_user_input` enabled, sessions carry a `request_user_input` tool. When that tool is available in this session, EVERY preference-driven question goes through it — plain text is the no-tool fallback ONLY, never an escape from the tool's shape limits (single-select, max 3 options per call). Fit questions into the shape instead:
     - **Single-select with >3 candidates**: the 3 slots are the (Recommended) option + the strongest genuine alternative + the mandatory skip/minimal candidate (never trimmed). Remaining candidates are named in the question text, one line each, closed with "prefer one of these → reply with its name in text". A genuinely wide option space (>4 real candidates) → progressive narrowing across two tool calls (category first, then specifics within it).
     - **Multi-select**: decompose into per-candidate single-select calls through the tool — each candidate becomes its own self-contained include/skip question (`A. Include (Recommended when it is) / B. Skip`, each side stating its consequence). Echo the combined outcome once at the end, same contract as the plain-text echo rule.
   - When the tool is NOT available, say ONCE before the first question, then proceed in plain text:
     `Tip: 'codex features enable default_mode_request_user_input' turns on structured questions (experimental; takes effect on a new task). Asking in plain text this run.`
   - **Plain-text form** (used ONLY when the tool is unavailable): **batch all mutually independent questions into ONE message** (≤4, per the shared rules below); only a mutually dependent chain goes one question at a time. Fixed format, no deviation: questions are numbered `Q1 / Q2 / …`; **options are ALWAYS lettered `A. / B. / C.` — never numbered** (numbered options visually continue the question sequence, and the user reads five questions where there is one); recommended option first, marked "(Recommended)". The message closes with ONE reply-protocol line (verbatim):
     `Reply in one line — e.g. "1A 3C". Multi-select: "2: A C". None fits: "3: <your answer>". "all recommended" takes every recommendation; questions you omit resolve to their (Recommended) option.`
   - **Echo the resolution before writing back**: after the reply, list every question's outcome (`Q1 → A · Q2 → B (default) · …`) with defaulted ones explicitly marked — a mistaken default must be overturnable with one line, never silently absorbed into Decided.
   - **Every question must be self-contained (top priority)**: ① one-sentence decision statement + ② why it must be settled now (what it affects / what breaks if left open) + ③ for each option, "choosing this leads to what — specific scenario / consequence". **The user must be able to answer without asking a follow-up**.
   - **Classify the select type first**: pick-ONE (mutually exclusive paths — architecture A/B/C) → single-select; pick-SEVERAL (independent inclusions — which edge cases are in scope, which pages to touch, which concerns to adopt) → **multi-select, never forced into single-select** (forcing drops legitimate picks; on this host it runs as per-candidate include/skip tool calls, or the plain-text combined reply). 2–4 options; recommended option goes first, labeled "(Recommended)" with a one-line reason
   - **Options must differ in consequence, not wording** (anti-padding test): for every pair of options you must be able to state different outcomes — can't → they are the same option, merge them. Option count follows the real decision space, never padded toward 4: a dominated option nobody would rationally pick, or one restating the question stem ("yes, do it properly"), is noise. Two honest options beat four manufactured ones.
   - **Always include a "skip / minimal" option** (SKILL Claim Self-Review fourth question applied at the ask stage): preference-driven questions MUST include a "don't do it yet (cost = X)" or "minimal viable (cost = Y)" candidate, to force the question "is this even necessary?" — unless there is genuinely no "skip" path for this decision (the cache example below is the canonical model). Not every option should be a variant of "which way to do it".
   - More than 4 options → use progressive narrowing: ask the broad category first, then narrow
   - Mutually dependent decision points: one question at a time, expand the next question based on the answer (don't pre-enumerate); mutually independent points: batch up to 4 questions at once
   - **Round caps are not run caps**: the per-round limits (max 4 questions; host option caps) never justify dropping a decision point — run as many rounds as it takes, until `## Open` is empty or the user says stop. Ending the run with items still Open is legal ONLY with an explicit declaration (`N decisions remain open — $spec-propose stays blocked until they're resolved`); a silently unasked item is exactly the miss the check-tbd gate bounces later

   **Anti-example → Correct example** (same [TBD]: cache library selection):
   - ❌ Empty question (will get follow-ups like "what does it affect / why recommend"): `Which cache? Redis(recommended) / Caffeine / Neither`
   - ✅ Self-contained:
     > Cache library selection — affects whether multiple instances read stale data:
     >
     > A. Redis (Recommended): shared across instances, strongly consistent across machines; cost = extra dependency + network round-trip per read
     > B. Caffeine: fastest in-process, zero dependencies; cost = each instance holds its own copy, **data inconsistent across machines**
     > C. Skip for now: simplest; cost = high-frequency reads hit the DB directly, revisit when load demands it

     (the reply-protocol line closes the whole batched message once — never repeated per question)
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

When `$spec-workflow` orchestrates this stage, the flow is two-touchpoint by design (HARD GATE + acceptance): do **NOT** ask the user question by question. Triage every `[TBD]` instead — **all of them end up in `## Decided`** (the pre-propose hook still requires `## Open` to be empty; leaving escalated items Open would deadlock the flow):

1. **Factual** (determinable from code / docs / spec/knowledge.md) → decide from evidence, exactly as in the interactive flow: `[DEC-N] <decision> | source [TBD-N] | decided from status quo: <evidence>`
2. **Preference-driven, reversible and cheap** → decide the recommended option yourself: `[DEC-N] <decision> | source [TBD-N] | auto | <one-line rationale> | reversibility: <how to undo>`
3. **Preference-driven, irreversible or product-semantics** — any of: data migration / schema change / public API surface / new dependency / destructive operation / user-visible product semantics; **when unsure, it is in this class** → still decide the recommended option, but mark it: `[DEC-N] <decision> | source [TBD-N] | escalated | <rationale> | if wrong: <blast radius>`

Every `auto` / `escalated` decision runs the **four-question filter** first (SKILL "Claim Self-Review"): why needed / when favorable / cost / can it be cut — and **"don't do it / minimal" is ALWAYS among the candidates**. A measure that survives only because "it might help" does not survive.

**Surfacing contract** (what makes self-deciding safe — the decisions are never silent):
- `auto` decisions → listed at the HARD GATE under `Decided without asking` (one line each + reversibility)
- `escalated` decisions → the HARD GATE's `Escalated decisions` section, **pinned at the top of the gate block**; they stand by default — silence + `$spec-apply` = consent; the user overturns any with one line of evaluation (applied via `$spec-revise`), and `$spec-apply` echoes them once more at its first line
- Standalone user-invoked `$spec-ask` keeps the interactive flow above — this section changes nothing about it

## Stopping conditions

| Situation | Action |
|---|---|
| Open [TBD] cleared | Stop; prompt "ready for $spec-propose" |
| User says "stop asking" / "that's enough" | Stop; leave remaining items Open (the pre-$spec-propose hook will block execution) |
| Interrogation diverges and can't be resolved | Stop; report "collected N decisions, M items remain — suggest revisiting later" |

## Anti-patterns

- ❌ Silently deciding a [TBD] based on assumed knowledge (interactive mode: MUST ask the user; auto-triage mode: deciding is legal but MUST carry the `auto` / `escalated` mark — "silent" means unmarked, and an unmarked self-decision is a violation in both modes)
- ❌ Treating a preference-driven point as factual and skipping it
- ❌ Throwing 5+ questions at the user at once (violates the 2–4 options + max-4-questions-per-round rule)
- ❌ Producing a "decision tree" artifact (creates a false sense of completeness)
- ❌ Empty questions: listing "A / B / C" without saying why it matters and what each option leads to (forcing the user to ask back = the number-one failure mode)
- ❌ Duplicate / filler options: two options whose stated consequences read the same, or an option added only to fill the 2–4 range (dominated, or a restatement of the question stem)
- ❌ Forcing a pick-several decision into single-select ("which edge cases / which pages / which suggestions" is multi-select by nature — single-select there drops legitimate picks)
- ❌ Every option being a variant of "which way to do it" — never offering a "skip / remove" escape hatch (strips away the fourth self-check question; user cannot challenge "is this even necessary?")

## What this command does NOT do

- Does not write proposal.md (that is `$spec-propose`'s job)
- Does not touch drafts under `research/`; only works research.md, moving Open items into Decided
