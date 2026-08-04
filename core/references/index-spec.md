# index.md spec

`spec/changes/<change-name>/index.md` is the **requirement & asset index** of the sdd workflow — the external anchor every downstream stage cites instead of re-interpreting the requirement source. Mandatory for every change created under this format; changes that predate it are **legacy**: every consumer (spec-dev, spec-verifier, the gate) declares the absence explicitly and falls back to What-anchored auditing — never blocks.

## When it exists

Built by `/spec:research` at **first contact** with the requirement source (user words / prototype / defect) — one extraction, verbatim quotes, never paraphrases. Frozen at the HARD GATE; **append-only** afterwards: adjudicated concerns and newly discovered requirements append new IDs; existing IDs are never renumbered or rewritten (downstream citations would become dead pointers).

Afterward proposal `## What` items cite it (`| refs: R-N`), spec-dev reads it at startup, spec-verifier audits the diff against it, and `/spec:archive` sediments its Assets/Exemplars into `spec/knowledge.md`.

## Format

```markdown
# Index: <change-name>

Requirement source: <where the quotes come from + date>

## Requirements
- R-1: <verbatim quote of a behavioral clause> | source: <prototype page / user message / defect id>
- R-2: ...

## Assets
- A-1: <existing service / util / pattern this change's domain touches> | use: reuse | extend | pattern | rejected: <reason>
- A-2: ...

## Exemplars
- E-1: <new page/module> → <existing page/module designated as its master template>
```

## Field rules

### R-N (Requirements)

- **Quote, don't paraphrase** — the entry is the original sentence; interpretation happens downstream *against* the quote, so a fresh-context auditor can re-read the source meaning independently
- **Behavioral clauses only**: validation, required fields, value ranges, permissions, display mappings, state rules. Descriptive UI narrative is not indexed — it has no audit value
- When no prototype/document exists, the user's task statement itself is the source: quote its sentences (a few lines — mandatory does not mean heavy)

### A-N (Assets)

- Only assets the change's domain will touch — a short list, not a codebase catalog
- `use:` marks the relationship: `reuse` (call it) / `extend` (add to it) / `pattern` (imitate it) / `rejected: <reason>` (searched, found unfit — the reason is the record that the search happened)

### E-N (Exemplars)

- For each **new** page/module, designate 1–2 existing ones as the master template. The exemplar sets the design level in both directions: abstractions it lacks are not added (over-design), conventions it has are not dropped (under-design). Deviating from the exemplar's patterns requires a stated reason in the implementation summary

## Static-only discipline

The index stores only what does not change: quotes, asset names, exemplar designations. **No status, no progress, no code locations, no coverage** — every volatile mapping (diff↔R-N coverage) is computed per verify round and never persisted. Every field must have a consumer (R-N: What refs + Coherence audit; A-N: new-creation citations + Reuse check; E-N: exemplar conformance); a field nobody reads is decoration.

## Lifecycle

| Stage | Command | Action |
|---|---|---|
| Build | `/spec:research` | extract at first source contact |
| Freeze | `/spec:propose` (HARD GATE) | What items cite entries; the gate lists unsourced additions |
| Append | `/spec:apply` concern adjudication | adopted concerns → new R-N |
| Audit | `/spec:verify` | Coherence anchors to R-N; Reuse anchors to A-N / E-N |
| Sediment | `/spec:archive` | durable A-N / E-N facts → spec/knowledge.md |

## Anti-patterns

- ❌ Paraphrasing instead of quoting (re-interpretation is the drift mechanism the index exists to kill)
- ❌ Indexing descriptive narrative (bloat; only behavioral clauses carry audit value)
- ❌ Renumbering or rewriting existing entries (downstream citations become dead pointers)
- ❌ Storing volatile state (coverage, progress, file:line) — a hand-maintained mapping rots exactly like a stale task list
- ❌ Building the index at propose time (a second reading is a second interpretation; build at research's first contact)
- ❌ A-N as an exhaustive codebase inventory (only the change's domain)
- ❌ Citing an R-N whose quote does not entail the item (a mismatched ref is audited as unsourced — same finding as no ref)
