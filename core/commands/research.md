---
<!-- host:claude -->
description: Dispatches a @researcher sub-agent to survey industry practices and key constraints, writing findings into research.md (single file; Open[TBD]/Decided maintained as before). Changing direction = snapshot the current research.md into the research/ discarded-draft pile first, then overwrite with the new direction; old drafts can be resurrected at any time.
<!-- /host -->
<!-- host:codex -->
description: Dispatches a researcher agent to survey industry practices and key constraints, writing findings into research.md (single file; Open[TBD]/Decided maintained as before). Changing direction = snapshot the current research.md into the research/ discarded-draft pile first, then overwrite with the new direction; old drafts can be resurrected at any time.
<!-- /host -->
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(mkdir:*, date:*)
---

# /spec:research

Research direction: $ARGUMENTS

## Artifact structure

```
spec/changes/<name>/
├── research.md                   ← current research (single file: Practices + Constraints + Open[TBD] + Decided)
└── research/                     ← discarded-draft pile for this proposal (optional; only created on direction change)
    └── <title>-research.md       ← full snapshot of an abandoned research.md; no labels, no links, resurrectable
```

- **research.md** is the **current** research — single file, all content inline. `## Open [TBD]` / `## Decided` are maintained the same way as before.
- **research/** holds **discarded drafts only** — when you change direction, the old research.md is moved here in its entirety. **No cross-linking**: research.md does not link to them, and drafts carry no status markers.
- Want to go back to an old direction? **Resurrect** the relevant draft by pulling it back into research.md. Drafts belong to this change and travel with it at archive time.

## research.md format

```markdown
# Research: <change-name>

## Practices
- Option A: implementation highlights / performance / integration cost / known issues | why it's a candidate (under what constraints it's worth considering)
- Option B: ...
Key references: <URL>

## Constraints
- <constraint>: compatibility / performance target / dependency version / security requirement | consequence of violating it (a constraint you can't name consequences for is probably redundant)

## Open [TBD]
- [TBD-1] <preference-driven decision point> (candidates A / B / C; leaning toward X; needs user confirmation)

## Decided
(Moved here from Open after interrogation. Format: [DEC-N] <decision> | source [TBD-N] | rationale)
```

**Write external information only** (see SKILL "Stage Responsibility Matrix"): architecture / interfaces / schema belong in design; the list of changed files belongs in proposal `## What` — do not write these into research. Raw search process notes do not belong in the body (move them to the `research/` discarded-draft pile when changing direction). `## Decided` DEC-N entries are **decision records** (conclusion + one-line rationale) — they are **not** the single source of truth for deep argumentation (deep argumentation covers only 1–2 contested decisions, in design `## Key Decisions`). proposal `## How` MUST forward-pass the conclusion + one-line rationale to apply (apply does not read research), so the implementer is never left with an empty pointer like "see DEC-N".

## Process

1. **Confirm the change directory**: no active change → create `spec/changes/<kebab-name>/`, deriving the name from the user's description; active change with a matching direction → append to research.md.
<!-- host:claude -->
2. **Dispatch the `@researcher` sub-agent** to research and write into research.md:
<!-- /host -->
<!-- host:codex -->
2. **Spawn a researcher subagent** to research and write into research.md. No dedicated researcher TOML ships with sdd — describe the role inline in the spawn task ("web-research specialist: survey practices, cite URLs, no fabrication").
   `spawn_agent` parameter contract: pass EITHER `message` (plain-text task only) OR `items` (use this when attaching a skill reference — put the task text inside `items` as a `{type:"text"}` entry alongside the `{type:"skill"}` entry). Passing both is rejected by the tool.
<!-- /host -->
   - WebSearch option A/B/C comparisons, known issues, benchmarks → `## Practices`
   - Hard constraints (compatibility / performance / security / dependency versions) → `## Constraints`
   - References MUST include URLs
   - **Apply the four-question self-check before writing anything** (SKILL "Claim Self-Review"): do not dump everything found — for each practice / constraint ask "what breaks if this is removed?"; omit anything whose removal has no impact; a constraint MUST identify where it causes a failure if violated. Zero encyclopedia-style padding.
3. Main conversation maps the status quo — **read `spec/knowledge.md` first** (if it exists: project-level durable facts from previous changes — table ownership / call chains / verified gotchas; don't re-derive or re-Grep what's already recorded there), then Grep / Glob relevant modules to **map existing call chains / constraints** (write into `## Constraints` — this is "understanding the status quo", not "designing new architecture"; new architecture belongs in design). A knowledge.md fact contradicted by what you find → note the correction in research (`订正/corrected: ...`); the fix to knowledge.md itself lands at archive time.
4. **Flag [TBD]s**: preference-driven decision points go into `## Open`:
   - Factual (determinable by reading code / docs) → decide yourself, note "decided from status quo: X"
   - Preference-driven (multiple valid options, depends on user trade-offs) → MUST mark `[TBD]` for `/spec:ask`
   - When in doubt, treat it as preference-driven — **NEVER skip a preference-driven point by pretending it's factual**

## Changing direction (user provides a new direction)

**Hard steps — order MUST NOT be reversed** — research.md will be overwritten; skipping the snapshot loses the old direction permanently:

1. **Snapshot first**: save the entire current research.md as `research/<old-direction-title>-research.md` (create `research/` if it doesn't exist)
2. **Overwrite second**: rewrite research.md as a fresh survey for the new direction (Practices / Constraints)
3. Update `## Open` / `## Decided` to reflect current thinking on the new direction
4. **Do not touch design.md / proposal.md / tasks.md** — they are independently generated artifacts; apply/verify reads proposal + design, not research, so they will not be polluted by the new survey

## Resurrecting an old direction (user wants to go back to a previous approach)

1. (If you still want to keep the current direction) → first snapshot the current research.md as a draft following Step 1 of "Changing direction"
2. Pull the target draft `research/<title>-research.md` **back into research.md**
3. Update `## Open` / `## Decided` as needed

## Loading references (on demand)

Load the corresponding reference only when writing Practices that involve a specific tech stack (all files below live under `${CLAUDE_PLUGIN_ROOT}/skills/core/references/`):
- Java + Spring → `${CLAUDE_PLUGIN_ROOT}/skills/core/references/alibaba-java.md` + `java-conventions.md`
- Vue / uni-app → `vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md` (add `uniapp-miniprogram.md` for uni-app)
- React → `bulletproof-react.md` + `react-patterns.md`
- Any TS → also load `google-ts-style.md` + `ts-conventions.md`
- Python → `python-conventions.md`; PHP → `php-conventions.md`; Flutter → `flutter-conventions.md`

`/spec:research` does **not** force-load references (saves tokens); load them on demand only when writing a specific decision.

## Anti-Cheating

- **NEVER fabricate** links or benchmark numbers you did not actually find
- If research coverage is incomplete, proactively say "could not find X — recommend the user supplement"; do not fill gaps from memory
- If the in-project call chain was not fully scanned, proactively say "did not scan module Y"; do not speculate
- ❌ Encyclopedia-style padding: listing every option / constraint found without applying the fourth self-check question (can it be cut?) — only what survives the cut gets written (SKILL "Claim Self-Review")
