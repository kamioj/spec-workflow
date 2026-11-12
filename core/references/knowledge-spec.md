# knowledge-spec — the project knowledge base (index + subdocs)

Authority for `spec/knowledge.md` (the index) and `spec/knowledge/` (the subdocs). The knowledge base is the project's **cache of verified facts**: commands consult it before paying scan cost, and a recorded fact is trusted until contradicted — except that a fact carrying `| suspect:` is re-checked before you rely on it — its evidence anchor is gone.

## Format

```
spec/knowledge.md                  pure INDEX — one line per subdoc, nothing else
spec/knowledge/
├── archive/                       retired long-form docs (moved here only on a user pick in the tidy
│                                  round; no index line, file kept as written)
├── <domain>.md                    one-line facts grouped by domain (backend-db.md, hooks.md,
│                                  process-rulings.md, … — created on demand, never pre-seeded)
└── <experience-title>.md          long-form experience doc (business walkthroughs, post-mortems)
```

**Index line form** (the only content lines knowledge.md may hold):

```
- [<kind>/<domain>] <filename> — <hook sentence: what a reader gains by opening it>
```

**Domain-file fact line form** (inside subdocs; unchanged from the classic form — a line merged from several changes keeps every distinct change tag, comma-separated, because recurrence across changes is what qualifies a fact for promotion):

```
- <fact> | evidence: <source> | <date> (<change>[, <change>…])
```

**Long-form doc frontmatter**: `status: current` or `status: superseded by <filename>`.

**Suspect suffix** (written by the tidy audit, inside the fact line — the line form itself is unchanged):

```
- <fact> | evidence: <source> | <date> (<change>) | suspect: <date> anchor gone
```

**Promotion pointer** (replaces a fact promoted into a skill, in the same subdoc):

```
- → skill <name>: <hook> | <date>
```

## Field rules

- **kind** is `fact` (project reality: ownership, call chains, commands, traps) or `ruling` (flow judgments: false-positive lessons, wontfix precedents, panel refutations). Readers route by kind: fact → research / spec-dev / fix; ruling → verifier / panel.
- **Hook sentence** decides selective reading — write it as the answer to "when would I open this file?".
- **Two-step read (all consumers)**: scan the index (cheap, tens of lines) → open ONLY the subdocs whose tag+hook match the task at hand. Reading every subdoc defeats the design.
- **Legacy predicate**: a knowledge.md is legacy (flat pre-index format) ⟺ it contains a **flat fact line** — a line matching `^- ` that also contains `| evidence:`. Headings, blank lines, and index lines (which never contain `| evidence:`) do not trigger it. Self-test: `- [fact/hooks] hooks.md — pwsh PATH trap` → not legacy; `- gawk parses o=o(expr) as a call | evidence: smoke | 2026-07-17` → legacy. A reader hitting legacy reads the whole file once and declares `legacy knowledge format` in its output.
- Facts stay one line; a fact that needs paragraphs is a long-form doc.

## Lifecycle

- **Writers** (archive step 4 primary — sediment, taking the lesson-mining step's `knowledge` candidates too, then the tidy pass; ship step 5; verify rule 4; `/spec:knowledge`): write the fact into the matching subdoc (create the domain file if new) AND maintain its index line. **Never write a flat fact line into the index** — one flat line re-flags the whole file as legacy and downgrades every reader to full reads.
- **Lazy migration**: at sediment time, a legacy flat knowledge.md is restructured in the same pass — facts sorted into domain subdocs, index written, nothing dropped.
- **Change tag**: `(<change>)` is the change name; a diff-mode verify writes its record dir name `(<date>-verify-<slug>)` — it counts as a distinct change tag for promotion
- **Consolidation pass** (self-maintenance at ship / verify sedimentation; archive and `/spec:knowledge` run the full tidy pass below instead): triggers = index > 40 lines, OR a domain file > 60 lines, OR writing next to an existing same-topic entry. Actions = merge duplicates, compress wording, **newer evidence+date on the same topic overrides the stale fact** (the correct-not-contradict rule executed automatically), long-form docs get `status: superseded by <new>` — superseded docs are kept, never deleted.
- **Corrections outside consolidation**: single-line facts are corrected in place; long docs are superseded, not rewritten.

## Tidy pass (`/spec:knowledge` any time; `/spec:archive` step 3 after sedimenting)

Three stages, in order — reversible edits run automatically, anything destructive or written outside spec/ waits for the user's pick:

1. **Audit** (its only write is the suspect mark): for every fact whose `evidence:` names a checkable anchor — a file path or a symbol — confirm it still exists (Glob / Grep); gone → append `| suspect: <date> anchor gone` — once: a line already carrying `| suspect:` is left as is, and one whose anchor is back loses the suffix (prose evidence such as "live probe" is not mechanically checkable and is left alone). Also list exact or near-duplicate facts, contradicting pairs on one topic, index lines pointing at missing files — and collect the promote candidates now, before stage 2 merges anything.
2. **Auto-apply** (no threshold): the consolidation actions — merge duplicates into one line (the merged line keeps every distinct change tag), compress wording, newer evidence + date on the same topic overrides the stale fact (correction noted), fix broken index lines. These rewrite lines; they never retire a document or drop a fact that has no newer replacement.
3. **Ask** — delivered per /spec:ask's rules (scenario stem, every option with its consequence; ≤4 options per question including the skip option, ≤4 questions per round), in two rounds:
   - **Round 1 — one pick-several question per action class that has candidates**; its options are up to 3 candidates plus `skip all`; candidates beyond 3 are reported as `N more next tidy`:
     - **delete** — suspect or obsolete facts the audit could not confirm
     - **retire** — `status: superseded` long-form docs → move to `spec/knowledge/archive/`, remove the index line
     - **promote** — procedural facts / rulings (a how-to or a trap), not suspect, that recur: ≥2 distinct change tags on the topic, or a ruling cited across domains
   - **Round 2 — one question per candidate picked under promote**: new skill `<proposed-name>` / merge into existing project skill `<name>` (offered only when `.claude/skills/` or `.agents/skills/` holds one; the closest by topic) / drop the fact (the lesson is obsolete) / keep in knowledge (recommended when unsure). A new or merge pick writes the current host's skill (Claude `.claude/skills/<name>/SKILL.md`, Codex `.agents/skills/<name>/SKILL.md`; frontmatter `name` + `description` written as "when to open this", description ≤1536 chars, body <500 lines), then ONE follow-up asks whether to write the other host's copy; a merge shows the paragraph to append before writing and reports the path after; the promoted line becomes a promotion pointer.
   No candidates in any class → no question; output one line: `knowledge tidy: nothing to decide`.

Report: `Tidy: <S> suspect · <M> merged · <D> deleted · <R> retired · <P> promoted (<paths>)`.

## Anti-patterns

- ❌ A flat fact line in the index (self-corrupts the file to legacy — the #1 way to break the architecture)
- ❌ Reading all subdocs when the index is present (Cline-style full reads; the index exists to prevent exactly this)
- ❌ Overriding a fact without newer evidence+date on the same topic (consolidation merges; it does not guess)
- ❌ Deleting or retiring anything automatically (the tidy pass only proposes those; a superseded doc moves to `knowledge/archive/` on a user pick and is never deleted — the reasoning trail answers "why did we do it that way")
- ❌ Writing a skill the user did not pick, or editing an existing skill without first showing the paragraph (skills live outside spec/ in user-owned dirs)
- ❌ Change-specific content in the knowledge base (R-N quotes, per-change decisions — those live and die with the change's own artifacts)
