---
<!-- host:claude -->
description: Interrogates preference-driven decision points. Derives questions from the candidate sets research minted into each [TBD] (options are citations, not inventions), asks via AskUserQuestion (multiSelect for pick-several), and moves answered items to ## Decided. Inside /spec:workflow it switches to auto triage (decide + mark, no questions). Can be triggered multiple times; new [TBD]s may surface during the process.
<!-- /host -->
<!-- host:codex -->
description: Interrogates preference-driven decision points. Derives questions from the candidate sets research minted into each [TBD] (options are citations, not inventions), asks via Codex's request_user_input tool when the session has it (plain-text batch fallback otherwise), and moves answered items to ## Decided. Inside /spec:workflow it switches to auto triage (decide + mark, no questions). Can be triggered multiple times; new [TBD]s may surface during the process.
<!-- /host -->
allowed-tools: Read, Edit, AskUserQuestion
---

# /spec:ask

## Process

1. Read `spec/changes/<name>/research.md` and list every entry in `## Open [TBD]`
2. **Classify — shared step 0 for BOTH modes** (interactive and workflow auto-triage run the same classification; only the delivery differs):
   - **Factual** (determinable by reading code / docs / spec/knowledge.md) → decide from evidence, mark "decided from status quo: X", move to Decided
   - **Preference-driven** → tag it **reversible** or **irreversible** (irreversible = any of: data migration / schema change / public API surface / new dependency / destructive operation / user-visible product semantics; **when unsure, it is irreversible**)
   - Unsure whether factual or preference → **treat as preference-driven** (never skip)
   - After classification the modes fork at delivery only: interactive asks (§ How to ask); workflow auto-triage marks (§ Auto triage)
3. Work the preference-driven set through the four-stage pipeline below
4. Before the first question, one-line declaration:
   ```
   Found N open decisions — working through them. This may not be exhaustive; flag anything I miss.
   ```
   Legacy TBDs minted without candidate sets exist → add: `M legacy TBDs without candidate sets — asking those in legacy mode`
5. **New [TBD]s surfacing during the process** → append them to `## Open` (with candidate sets), announce "found M new TBDs", continue

## How to ask (four-stage pipeline)

### 1 · Derive the question set (from research, never from imagination)

- **Options are citations, not inventions**: each question's options come from the TBD's minted candidate set, each candidate anchored to a research.md line (Practice / Constraint / status-quo evidence). A candidate you want to offer but can't point back to a research line → **add it to research first**, then ask. The skip/minimal candidate is the one exemption (its evidence is the status quo itself). Invented-on-the-spot options are natural wording-variants of each other — the mechanism behind duplicated, nutrition-free choices.
- **Legacy fallback**: a TBD minted without a candidate set (older change, other tiers) → craft options the best you can and say so via the declaration line in Process step 4 — never silently mix modes.
- **Select type** comes from the TBD's mark (or classify now): pick-ONE (mutually exclusive paths) vs pick-SEVERAL (independent inclusions; "which of these…" phrasing is the signal).
- **Sibling aggregation**: N sibling TBDs that are each an include/skip decision over the same theme are ONE pick-several question (each sibling one option) — never a serial run of single-selects. Decomposition back into per-candidate calls happens ONLY in the Codex delivery stage; it never leaks back into how the question is constructed.
- **Question-level culling**: after the consequence-merge test (stage 2), a question left with fewer than 2 genuinely different options is not a question — decide it on the spot, record it in Decided, and surface it on the gate's `Decided without asking` line (one line to overturn). Evidence has made it factual.
- **Ordering & batching**: irreversible-tagged questions enter the queue first (the round budget must not be spent on trivia while irreversible calls wait). Mutually independent questions batch (≤4 per round); a mutually dependent chain goes one at a time, next question shaped by the answer.

### 2 · Craft each question

- **Self-contained (top priority)**: ① the decision in one sentence + ② why it must be settled now (what it affects / what breaks if left open) + ③ per option, what choosing it leads to — concrete scenario / consequence. **Test: the user can answer without asking a follow-up.**
- **Options differ in consequence, not wording**: for every pair of options you must be able to state different outcomes — can't → same option, merge. Option count follows the real decision space (2–4), never padded: a dominated option nobody would pick, or a restatement of the question stem, is noise. Two honest options beat four manufactured ones.
- **The skip/minimal candidate is mandatory** (Claim Self-Review question ④ applied at the ask stage): "don't do it yet (cost = X)" or "minimal viable (cost = Y)" — unless the decision genuinely has no skip path. It is never trimmed to fit any host limit.
- **Recommended option first**, labeled "(recommended)" with a one-line reason. More than 4 genuine candidates → progressive narrowing (category first, then specifics).

**Anti-example → Correct example** (same [TBD]: cache library selection):
- ❌ Empty question (invites follow-ups): `Which cache? Redis(recommended) / Caffeine / Neither`
- ✅ Self-contained, candidates cited from research:
  > Cache library selection — affects whether multiple instances read stale data:
  > • Redis (recommended, Practices L12): shared across instances, strongly consistent; cost = extra dependency + network round-trip per read
  > • Caffeine (Practices L14): fastest in-process, zero dependencies; cost = per-instance copies, **data inconsistent across machines**
  > • Skip for now: simplest; cost = high-frequency reads hit the DB directly, revisit when load demands it

### 3 · Deliver per host

<!-- host:claude -->
- Ask via **AskUserQuestion**: pick-several questions set `multiSelect: true`; ≤4 questions per call; recommended option first.
<!-- /host -->
<!-- host:codex -->
- **Tool always, when available**: with the experimental `default_mode_request_user_input` flag enabled, sessions carry a `request_user_input` tool — EVERY question goes through it; plain text is the no-tool fallback ONLY, never an escape from the tool's shape limits (single-select, max 3 options per call). Fit questions into the shape:
  - **Single-select with >3 candidates**: the 3 slots are the (recommended) option + the strongest genuine alternative + the skip/minimal candidate (never trimmed). Remaining candidates are named in the question text, one line each, closed with "prefer one of these → reply with its name in text". More than 4 genuine candidates → progressive narrowing across two tool calls.
  - **Pick-several**: decompose into per-candidate include/skip single-select calls — **a delivery-layer adaptation only** (the question was constructed as ONE pick-several in stage 1); each call self-contained with both sides' consequences; echo the combined outcome once at the end.
- **Tool unavailable** → say ONCE before the first question, then use the plain-text form:
  `Tip: 'codex features enable default_mode_request_user_input' turns on structured questions (experimental; takes effect on a new task). Asking in plain text this run.`
- **Plain-text form**: batch all independent questions into ONE message; questions numbered `Q1 / Q2 / …`; **options ALWAYS lettered `A. / B. / C.` — never numbered** (numbered options visually continue the question sequence). The message closes with ONE reply-protocol line (verbatim):
  `Reply in one line — e.g. "1A 3C". Multi-select: "2: A C". None fits: "3: <your answer>". "all recommended" takes every recommendation; questions you omit resolve to their (recommended) option.`
<!-- /host -->
- **Round caps are not run caps** (both hosts): rounds repeat until `## Open` is empty or the user says stop — the per-round limits never justify dropping a decision point.

### 4 · Book-keep

- **Echo before write-back whenever any outcome was not an explicit pick** (omitted questions resolved to recommended, culled questions self-decided): list `Q1 → A · Q2 → B (default) · Q3 → self-decided (culled)` — a wrong default must be one line to overturn, never silently absorbed.
- **Write back to research.md**: remove the entry from `## Open`, append to `## Decided`:
  ```
  [DEC-N] <decision> | source [TBD-N] | rationale: <distilled from user's answer>
  ```
- **Every round ends with the tail line**: `Open: N asked / M answered / K pending` — the pending set stays visible on the books, never in memory.
- **Ending the run with pending items** is legal ONLY with the explicit declaration: `K decisions remain open — /spec:propose stays blocked until they're resolved.`

## Auto triage (workflow-invoked delivery fork)

When `/spec:workflow` orchestrates this stage, the flow is two-touchpoint by design (HARD GATE + acceptance): classification (step 0) has already run — instead of asking, **every preference-driven TBD is decided and marked** (the pre-propose hook still requires `## Open` to be empty):

1. **Reversible** → decide the recommended option yourself: `[DEC-N] <decision> | source [TBD-N] | auto | <one-line rationale> | reversibility: <how to undo>`
2. **Irreversible** → still decide the recommended option, but mark it: `[DEC-N] <decision> | source [TBD-N] | escalated | <rationale> | if wrong: <blast radius>`

Every `auto` / `escalated` decision runs the four-question filter first (SKILL "Claim Self-Review") — and "don't do it / minimal" is ALWAYS among the candidates; a measure surviving only because "it might help" does not survive.

**Surfacing contract** (what makes self-deciding safe — decisions are never silent):
- `auto` decisions → the HARD GATE's `Decided without asking` line (one line each + reversibility)
- `escalated` decisions → the HARD GATE's `Escalated decisions` section, **pinned on top**; they stand by default — silence + `/spec:apply` = consent; overturn with one line (applied via `/spec:revise`); `/spec:apply` echoes them once more at its first line
- Standalone user-invoked `/spec:ask` keeps the interactive pipeline above — this section changes nothing about it

## Stopping conditions

| Situation | Action |
|---|---|
| Open [TBD] cleared | Stop; prompt "ready for /spec:propose" |
| User says "stop asking" / "that's enough" | Stop; leave remaining items Open with the pending declaration (the pre-/spec:propose hook will block execution) |
| Interrogation diverges and can't be resolved | Stop; report "collected N decisions, K items remain — suggest revisiting later" |

## Anti-patterns (each violates a named pipeline rule)

- ❌ Unmarked self-decision (interactive: must ask; triage: legal only WITH the `auto`/`escalated` mark — "silent" means unmarked)
- ❌ Preference-driven point skipped as "factual" (Classify)
- ❌ Options invented on the spot with no research anchor (Derive: options are citations)
- ❌ A run of include/skip siblings asked as serial single-selects (Derive: sibling aggregation)
- ❌ Duplicate / filler / stem-restating options (Craft: consequence-differ, no padding)
- ❌ Empty questions — bare "A / B / C" without stakes and consequences (Craft: self-contained)
- ❌ No skip/minimal candidate, or trimming it to fit a host limit (Craft)
- ❌ >4 questions in one round (Derive: batching)
- ❌ Ending the run with silently unasked items (Book-keep: pending declaration)
- ❌ Producing a "decision tree" artifact (false sense of completeness)

## What this command does NOT do

- Does not write proposal.md (that is `/spec:propose`'s job)
- Does not touch drafts under `research/`; only works research.md, moving Open items into Decided
