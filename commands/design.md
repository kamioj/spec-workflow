---
description: Technical design elaboration. Trigger on demand — use when the architecture is complex, there are more than 3 interfaces, sequence/data-flow diagrams are needed, or a decision requires more than 300 words of deep argumentation. Produces design.md.
allowed-tools: Read, Write, Edit, Glob
---

# /spec:design

Focus: $ARGUMENTS

## When to use

Trigger if any one of the following applies:
- **Cross-cutting frontend + backend** (touching both UI and server side, including interface contracts) ← **in this scenario design is MANDATORY, not optional**
- More than 3 interfaces
- Architecture diagram / data-flow diagram / sequence diagram needed (mermaid / ASCII)
- Deep decision argumentation exceeding 300 words (benchmarks / limit comparisons / performance models)
- Cross-service / cross-process protocol design

**Pure frontend or pure backend simple tasks**: go directly research → propose; do not open a design for the sake of opening one.

**Why cross-cutting frontend + backend tasks MUST have a design**:
- The interface contract is the **only coordination medium that lets frontend and backend implement in parallel**
- No contract → frontend and backend must serialize (backend finishes first, frontend integrates after), wasting 50% of the time
- The contract lives in design.md `## Interfaces`; only once it is finalized can `/spec:apply` dispatch two agents concurrently

## Process

1. Read `spec/changes/<name>/research.md` to get research findings
2. Read `spec/changes/<name>/design.md` (if it already exists, revise in place)
3. Write / update `spec/changes/<name>/design.md`

**Detailed format + section constraints + boundary rules + anti-patterns** → [`skills/core/references/design-spec.md`](../skills/core/references/design-spec.md)

## Anti-patterns (summary)

- ❌ Complexity for its own sake: writing into design what a few sentences in proposal would cover fine
- ❌ Copy-pasting the proposal's How section verbatim (design holds the deep "why" argumentation, not a copy of conclusions)
- ❌ Drawing architecture diagrams from thin air: doing so without reading research.md or scanning the project code
- ❌ Expanding every decision regardless of how contested it is (only 1–2 genuinely contested decisions get full treatment; the rest point to research DEC-N entries; see SKILL "Stage Responsibility Matrix" + design-spec)

Full anti-pattern list: [`design-spec.md`](../skills/core/references/design-spec.md).
