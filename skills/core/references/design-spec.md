<!-- GENERATED from core/references/design-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# design.md spec

`spec/changes/<change-name>/design.md` is the **optional technical-design artifact** of the sdd workflow. It is produced on demand by `/spec:design`, only for complex tasks / cross-stack collaboration.

## When to produce it

Triggered when any one holds (see [`commands/design.md`](../../../commands/design.md)):

- **Cross-stack project** (mandatory — pin down the interface contract so frontend and backend can build in parallel)
- More than 3 interfaces
- An architecture / data-flow / sequence diagram is needed (mermaid / ASCII)
- A decision needs >300 words of deep argument (benchmark / constraint comparison / performance model)

**Simple single-stack tasks don't get one** — a few sentences in `proposal.md ## How` cover it.

## Altitude (who it's written for)

design.md is this change's **single source of design truth** — architecture, contracts, and decisions all live in **one** file, **not split across multiple files** (design can change at any time, and every extra file is one more place that can fall out of sync; when writing the proposal, reference design directly rather than making a formal cross-file citation).

Within that one file, **two registers that must not be mixed**:
- **Narrative parts** (`## Architecture` notes / `## Key Decisions`): explain **what / why / what it solves**, in natural language, problem-driven, and **list no function names / SQL in the narrative** — concrete code belongs to propose `## How` and tasks.
- **Contract parts** (`## Interfaces` / `## Data Model`): must be fully precise — they are the **contract source for parallel frontend/backend implementation**, so signatures / schemas / fields must all be spelled out.

Test: **a non-technical reader can decide from the narrative; an implementer can code directly from the contract.**

## Format

```markdown
# Design: <change-name>

## Architecture
(structure diagram: domain layering, box = name + one-line responsibility, no fields in the diagram. See "Drawing the Architecture (iron rules)" below.)

## Interfaces (contract source; frontend/backend build against it in parallel; precise schemas go right here)
- <capability / endpoint method path>
  - Input: <schema>
  - Output: <schema>
  - Error codes: <list>
  - Invariants: <e.g. "output contains no source IDs">

## Data Model
- tables / entities / fields + relations (references / 1:N …)
- indexes / constraints; key ownership / invariants (e.g. "the source of truth for price is X")

## Key Decisions (problem-driven · narrative · **expand contested ones only**)
**Not every decision goes in this section** — the source of truth for decision conclusions is research `## Decided` (DEC-N). Here you **expand only the 1–2 genuinely contested / high-risk** decisions into deep argument (benchmark / performance model / multi-option trade-off); non-contested decisions stay as a one-liner in DEC-N and are **not repeated here**. Each expansion ≤12 lines, stating the **scenario that could go wrong** first, then the solution (no code):
- Problem: <what operation → what goes wrong → what consequence>
- Solution: <how it's solved, conceptual level, no functions / SQL>
- Cost: <what this solution sacrifices — every option has a price; if you can't name it, you haven't thought it through>
- Why not the alternatives: <alternative + one-line reason for rejection; **"do nothing" is itself a rejected alternative**>

## Migration / Compatibility
- how old data migrates
- how old interfaces stay compatible / when they retire
```

## Drawing the Architecture (iron rules)

`## Architecture` is not "draw everything you know" — it presents **structure + the key loops**, not fields. The primary failure of an architecture diagram is **detail overload** (nobody can read it). Hard constraints:

1. **No fields in the diagram** (the top iron rule): a box holds only **name + one-line responsibility (+ tech choice)**. Fields, enums, states, rules, prices, thresholds **all go to `## Data Model` or a table below the diagram**; interfaces likewise — the diagram only references names from `## Interfaces`, it does not redraw schemas.
2. **One abstraction level per diagram**: a single diagram stands at one level (system level "who talks to whom" / component level "which blocks are inside"), never mixed. Use C4 (Context / Container) for granularity.
3. **Domains set the skeleton, modules fill the layers**: domains = layers (horizontal / vertical bands — **as many layers as there are real domains = N, not fixed**); modules / tables = boxes within a layer. Note that "layer (a band, can be N)" ≠ rule 2's "abstraction level (C4's system/container, one level per diagram)" — a single container-level diagram can have N domain bands. **A module must NEVER cross layers to act as the tree root** — don't let one field (e.g. some `type` column) become the whole diagram's branching axis.
4. **Symmetric decomposition**: each party is broken down at the same granularity — don't decompose one side into 4 layers and flatten the other into a single box (the "external / customer" side must be decomposed properly too).
5. **Invariants proven by layout**: when there's a business invariant (e.g. "the internal source is invisible externally"), make the relevant token **appear only in the layer where it belongs and get desensitized layer by layer**, reaching zero at the external layer — **the diagram itself is the proof**, not a side note.
6. **Structure diagrams still draw the key loop**: don't draw process detail, but the core loop of "who drives whom" (**initiate → process → deliver → back to initiator**) must show direction, otherwise it ends up a "one-way push" that omits the initiator.
7. **One-directional, labeled lines** (label "what it does", not `uses`; the label's direction matches the arrow); the diagram must **stand on its own without the prose** — any visual distinction used (color / border / symbol) gets a legend, and a title when it's complex.
8. **Complexity gate**: a single diagram over ~15–20 nodes → **split it** (zoom to a finer level, or split by domain into several diagrams); **never cram it in by shrinking fonts / squeezing spacing**.
9. **External systems get only a boundary**: services / third parties / SaaS not under this system's control are drawn only as an **interaction boundary**, not expanded internally; mark them clearly as `[external]` (or a distinct style). A shared library counts as a Component, not a separate system.

**Recommended layout**: along the chosen vertical axis (e.g. "external transparency"), **split top-to-bottom into N layers** — **the number of layers follows the system's real domains / stages, not a fixed count**. Draw as many layers as exist; don't force-fit 2, and don't cram N domains into 2. If there's a visibility boundary like "internal ↔ external", mark it as **one of the horizontal cut-lines** (both sides can still have multiple layers each). Take this system's point of view.

Skeleton sketch (N layers, arbitrary; different domains, same effect):

```
═══ Layer 1 (innermost / deepest detail) ═══
  [ Domain A ] ──relation label──▶ [ Domain B ]
              │
═══ Layer 2 ═══
  [ Domain C ]
              │
              ⋮   ← number of layers = the system's real domains / stages (N, not fixed)
              │
══════════════╪══ visibility boundary (if any: internal ↔ external) ══
              ▼
═══ Layer N (external / contract layer) ═══
  [ Browse ] ─①initiate─▶ [ Process ] ─②deliver─▶ [ Receive ]   ← draw the closed loop back to the initiator
```

(Fields go to `## Data Model`: DomainA.xxx, DomainB.yyy …)

## Section constraints

Every section is **optional** — a simple task may contain only the architecture diagram. But **at least one section**, otherwise design.md shouldn't be created at all.

**Soft budget** (the principle is in SKILL § Phase Responsibility Matrix; the line-count numbers are authoritative here): **narrative/argument ≤150 lines** (architecture diagram + Key Decisions + migration notes) — `## Interfaces` / `## Data Model` contracts are **excluded and must be as precise as needed** (schemas / fields / primary keys / error codes listed in full, never elided with "…", so an implementer can code without guessing); `## Key Decisions` **expands at most 1–2** contested decisions, ≤12 lines each; an architecture diagram >20 nodes must be split. If the narrative won't fit in 150 lines, cut it down (if you genuinely must exceed, explain why first); conversely, if the contract alone runs to hundreds of lines, that signals too many interfaces and you should **split the change**, not trim the schema.

## Boundary: what does not belong in design.md

| Content | Where it belongs |
|---|---|
| Business motivation / time window | proposal.md `## Why` |
| Which files / modules change | proposal.md `## What` |
| Risk / rollback | proposal.md `## Risk` |
| Task breakdown / deps | tasks.md |
| Code implementation: function bodies / full migration SQL / concrete algorithms | written in the apply phase (design stops at contract schema) |

design.md focuses on **technical structure**: architecture / interfaces / data / deep argument.

## Special responsibility for cross-stack work

design's `## Interfaces` section is the **contract source for parallel frontend/backend implementation** (the precise schema lives in this one file, not a separate one):

- **Must land before `/spec:apply`**
- the frontend agent runs a skeleton on mock data first (based on the `## Interfaces` schema)
- the backend agent implements the server side (also based on `## Interfaces`)
- the two align on the real interface during integration

No `## Interfaces` → frontend / backend agents can't work in parallel (it degrades to serial implementation).

## Relationship to proposal.md / research.md

| File | Relationship |
|---|---|
| research.md | upstream (external information) |
| design.md | **midstream** (internal technical structure, deep expansion) |
| proposal.md | downstream (distilled decision record, references design's key conclusions) |

proposal.md `## How` references the conclusions of design.md `## Key Decisions`; it does not copy the deep argument.

## Anti-patterns

- ❌ Complexity for its own sake: forcing into design.md what a few sentences in the proposal would cover
- ❌ Moving the whole of proposal `## How` into design `## Key Decisions` (design carries the "why" deep argument, not a copy of the conclusions)
- ❌ Drawing the architecture out of thin air: drawing without reading research.md / scanning the project code
- ❌ Architecture-diagram smells: fields piled into boxes / mixed abstraction levels / a module acting as the tree root / unbalanced decomposition / invariants relying on side notes / external systems expanded internally / over 20 nodes not split but crammed in (see "Drawing the Architecture (iron rules)")
- ❌ Writing code in the narrative: piling function names / SQL into `## Architecture` notes / `## Key Decisions` (narrative uses natural language; precise signatures / schemas go in `## Interfaces` / `## Data Model`)
- ❌ Key Decisions listing decisions abstractly without anchoring "the scenario that could go wrong" (the reader can't tell what it solves)
- ❌ Key Decisions expanding **every** decision (expand only 1–2 contested ones, point the rest at research `## Decided` DEC-N; turning 6 decisions into 6 long essays is the primary source of bloat)
- ❌ design writing a separate Context business narrative / a standalone Risks section (the source of truth for motivation is proposal `## Why`, for risk proposal `## Risk`; crossing the line puts the same content in two places — see SKILL § Phase Responsibility Matrix)
- ❌ Writing full migration DDL / function bodies into design (→ the apply phase; design stops at contract schema + migration **shape**, no executable SQL)
- ❌ A solution that states only "how it's solved" without the cost (SKILL Claim Self-Review question ③: every option has a price; if you can't name it, you haven't thought it through)
- ❌ "Why not the alternatives" comparing only alternatives while omitting the "do nothing" option (failing to answer "must this problem be solved at all" — question ④)
- ❌ A cross-stack project skipping design.md (resulting in no contract, so frontend/backend can't parallelize)
