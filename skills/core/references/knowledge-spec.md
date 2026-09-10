<!-- GENERATED from core/references/knowledge-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# knowledge-spec — the project knowledge base (index + subdocs)

Authority for `spec/knowledge.md` (the index) and `spec/knowledge/` (the subdocs). The knowledge base is the project's **cache of verified facts**: commands consult it before paying scan cost, and a recorded fact is trusted until contradicted.

## Format

```
spec/knowledge.md                  pure INDEX — one line per subdoc, nothing else
spec/knowledge/
├── <domain>.md                    one-line facts grouped by domain (backend-db.md, hooks.md,
│                                  process-rulings.md, … — created on demand, never pre-seeded)
└── <experience-title>.md          long-form experience doc (business walkthroughs, post-mortems)
```

**Index line form** (the only content lines knowledge.md may hold):

```
- [<kind>/<domain>] <filename> — <hook sentence: what a reader gains by opening it>
```

**Domain-file fact line form** (inside subdocs; unchanged from the classic form):

```
- <fact> | evidence: <source> | <date> (<change>)
```

**Long-form doc frontmatter**: `status: current` or `status: superseded by <filename>`.

## Field rules

- **kind** is `fact` (project reality: ownership, call chains, commands, traps) or `ruling` (flow judgments: false-positive lessons, wontfix precedents, panel refutations). Readers route by kind: fact → research / spec-dev / fix; ruling → verifier / panel.
- **Hook sentence** decides selective reading — write it as the answer to "when would I open this file?".
- **Two-step read (all consumers)**: scan the index (cheap, tens of lines) → open ONLY the subdocs whose tag+hook match the task at hand. Reading every subdoc defeats the design.
- **Legacy predicate**: a knowledge.md is legacy (flat pre-index format) ⟺ it contains a **flat fact line** — a line matching `^- ` that also contains `| evidence:`. Headings, blank lines, and index lines (which never contain `| evidence:`) do not trigger it. Self-test: `- [fact/hooks] hooks.md — pwsh PATH trap` → not legacy; `- gawk parses o=o(expr) as a call | evidence: smoke | 2026-07-17` → legacy. A reader hitting legacy reads the whole file once and declares `legacy knowledge format` in its output.
- Facts stay one line; a fact that needs paragraphs is a long-form doc.

## Lifecycle

- **Writers** (archive step 3 primary; ship step 5; verify rule 4): write the fact into the matching subdoc (create the domain file if new) AND maintain its index line. **Never write a flat fact line into the index** — one flat line re-flags the whole file as legacy and downgrades every reader to full reads.
- **Lazy migration**: at sediment time, a legacy flat knowledge.md is restructured in the same pass — facts sorted into domain subdocs, index written, nothing dropped.
- **Consolidation pass** (self-maintenance; runs during sedimentation when triggered): triggers = index > 40 lines, OR a domain file > 60 lines, OR writing next to an existing same-topic entry. Actions = merge duplicates, compress wording, **newer evidence+date on the same topic overrides the stale fact** (the correct-not-contradict rule executed automatically), long-form docs get `status: superseded by <new>` — superseded docs are kept, never deleted.
- **Corrections outside consolidation**: single-line facts are corrected in place; long docs are superseded, not rewritten.

## Anti-patterns

- ❌ A flat fact line in the index (self-corrupts the file to legacy — the #1 way to break the architecture)
- ❌ Reading all subdocs when the index is present (Cline-style full reads; the index exists to prevent exactly this)
- ❌ Overriding a fact without newer evidence+date on the same topic (consolidation merges; it does not guess)
- ❌ Deleting a superseded long-form doc (mark it; the reasoning trail answers "why did we do it that way")
- ❌ Change-specific content in the knowledge base (R-N quotes, per-change decisions — those live and die with the change's own artifacts)
