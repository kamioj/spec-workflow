---
name: spec-verify
description: Verifies the current change by dispatching the independent spec-verifier agent (fresh context — the implementing conversation never audits itself) across three dimensions + charter audit. Every run updates the verification ledger spec/changes/<name>/verify.md (stable finding IDs + round diffing + unfixed-escalation). Can be re-run independently.
---
<!-- GENERATED from core/commands/verify.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-verify

> Heterogeneous peer review (`--codex`) is not available in this port — Codex cannot be its own heterogeneous reviewer.

## Independent verifier (why verify dispatches an agent instead of reviewing inline)

The conversation that just ran `$spec-apply` cannot audit its own output — same context, same blind spots, and "be objective" instructions have near-zero measured effect on self-preference. `$spec-verify` therefore **spawns the spec-verifier agent (defined in ~/.codex/agents/spec-verifier.toml)** (fresh context: it reads only proposal + design + charter + the diff) and keeps the bookkeeping for itself. The same rule binds `$spec-apply`'s closing verification: the review is ALWAYS performed by a spawned spec-verifier, whoever initiates it — the implementing conversation only ever does bookkeeping:

1. Spawn spec-verifier with the change name and nothing else — its ignorance of the implementation process is the mechanism, don't "helpfully" brief it
   (`spawn_agent` parameter contract: EITHER `message` — plain text only — OR `items` when attaching skill references, with the task text as a `{type:"text"}` item; both together is rejected)
2. Transcribe its findings into ledger rows **without softening, dropping, or re-judging them** — format conversion only (one finding = one table row; severity / location / text preserved). Derive the per-dimension pass/fail lines from its findings; its `conclusion` is authoritative and may never be upgraded fail → pass. Disagreement is recorded as a note next to the row, never by deletion
3. Run the round rules below (diff vs previous round, escalation)
4. The user overrules a finding as a false positive → distill the generalized lesson (what pattern + why it's acceptable here) into `spec/knowledge.md`, so later rounds and later changes stop repeating it

## Three-dimension verification framework (executed by the spawned spec-verifier; runs in all modes)

### 1. Completeness
- Is every item in proposal `## What` implemented? **Check each item against its `verify:` clause** — that clause is the falsifiable acceptance check; a What item with no `verify:` clause → flag it explicitly, don't improvise a pass
- Do inputs / outputs align with the interface contract (design.md, if present)?
- Do tests cover the critical paths?

### 2. Correctness
- Does the code compile / pass type checks?
- Do unit / integration tests pass?
- Are edge cases (empty / extreme / invalid input) handled correctly?

### 3. Coherence
- Is the change consistent with the decisions in proposal `## How`?
- **Nothing was done that the proposal did not ask for** (no scope creep)?
- **`Not in this change` = exclusion zones**: code changes inside that scope → scope violation, flag it; conversely NEVER flag excluded scope as "missing work" — it is out of scope by decision
- Does it conform to the coding conventions in the sdd spec-core skill's stack references?
- **Charter audit** (see the dedicated section below): every fallback / degrade / compat path in the diff must trace to an explicit proposal `## How` / `## Risk` decision

## Charter audit (part of Coherence — hunts the dirty-data defect class)

Models rate defensive fallbacks as "robust"; the charter (`code-charter.md`) rates them as the number-one source of dirty data. This audit therefore never asks "is this fallback well-written?" — it asks "**which gate decision authorized it?**". Untraceable = finding, zero judgment calls.

**Machine pass first**: `ast-grep scan --config <sdd-rules>/sgconfig.yml <changed files>` — resolve `<sdd-rules>` first (the installed sdd `spec-core/rules` directory; location depends on install method): `find ~/.codex/plugins/cache ~/.agents/skills -path '*spec-core/rules/sgconfig.yml' 2>/dev/null | sort | tail -1` (pwsh: `Get-ChildItem ~/.codex/plugins/cache, ~/.agents/skills -Recurse -Filter sgconfig.yml -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName`) — the shipped rule pack (`rules/dirty-data/`, validated: catches "return default in catch" even when a log line disguises it; never flags a proper throw) produces AST-level Evidence with no regex false positives. ast-grep not installed (`scoop install main/ast-grep` / `npm i -g @ast-grep/cli`) → declare `not run: ast-grep not installed` in Evidence and fall back to the manual patterns below. Java projects with a JVM can additionally run PMD's built-in EmptyCatchBlock (`pmd check --file-list changed.txt -R category/java/errorprone.xml`) with zero project changes.

Manual patterns (fallback, Grep the changed files — patterns, not vibes):

- catch blocks that swallow an error and return a default / continue, on any path that writes
- "try new logic, fall back to old logic" branches; replaced code kept alive next to its replacement
- `|| defaultValue` / ternary fallback chains that mask a failed lookup as a normal result
- compat flags or branches defaulting to old behavior; "temporary" dual-write / dual-read
- silent re-route: query A fails → quietly run query B and return its shape as if A succeeded

Verdict rules:

| Situation | Verdict |
|---|---|
| Pattern hit traces to an explicit `## How` / `## Risk` decision (quote it in the finding check) | Not a finding — but confirm it degrades **loudly** (log/alert per charter); silent even when authorized → finding |
| Pattern hit with no decision behind it | Finding, severity **major** |
| Same, on a data-write path (INSERT / UPDATE / message produce / file write) | Severity **critical** — this is how dirty data is born |

The fix direction is **replacement or a gate decision** (`$spec-revise how` to authorize it deliberately) — never "keep the fallback but add a log line".

## Output format

```
=== Verify ===
[independent] Completeness: <pass/fail/partial> - <explanation>
               Correctness:  <pass/fail/partial> - <explanation>
               Coherence:    <pass/fail/partial> - <explanation>

Evidence (mandatory — one line per check actually executed):
  <command / action> → <exit code or the key output line>
  not run: <check> — <reason>        ← declaring a skip is legal; hiding it is not

Overall: <pass / fail>
```

**Correctness may be marked pass only when at least one Evidence line supports it**; nothing runnable in this environment → write `Correctness: not verifiable - <why>`, never pass.

## Verification ledger: `spec/changes/<name>/verify.md` (written every run)

A stateless verify can pass the same broken change twice. Every run therefore writes/updates a ledger in the change directory — findings carry stable IDs, and the next round must face every still-open one before it may conclude.

The ledger has **two writers, one table**: `$spec-propose`'s critique panel opens it with round 0 (stage: propose, pre-code findings), and `$spec-verify` owns every round after — so the round narrative runs unbroken from before the gate to acceptance, and `$spec-status` derives the milestone view from it without any extra file.

Format (YAML frontmatter + findings table):

```markdown
---
change: <name>
round: <N>                 # increments each run
date: YYYY-MM-DD
conclusion: pass | fail
issues: { critical: <N>, major: <N>, minor: <N>, open: <N> }
---

# Verify: <name>

## Findings
| ID | Severity | Location | Finding | Status | Rounds |
|----|----------|----------|---------|--------|--------|
| V-1 | critical | file:line | <one line> | open / fixed(rN) / wontfix: <reason> | r1→r2 |

## Evidence (round N)
<command> → <exit code / key output>
not run: <check> — <reason>
```

Round rules:
1. **Read the previous ledger first** (if present): this run's `round` = previous + 1. **Round 0 is legal**: `$spec-propose`'s critique panel writes its surviving findings as round 0 (stage: propose) before any code exists — the first verify run is then round 1, and it re-checks round 0's open findings like any others
2. **Re-check every Status=open finding one by one** — fixed → `fixed(rN)`; still open → stays open and **escalates**: a critical/major finding open for 2+ rounds forces `conclusion: fail` and leads the user-facing output
3. New findings take the next V-N ID; IDs are never reused or renumbered
4. `wontfix` requires a written reason (inside `Not in this change` / explicit user decision) — silence is not a status
5. Keep the latest round's Evidence in full; collapse earlier rounds' Evidence to one line each
6. **User-sourced findings**: acceptance-stage user evaluations enter the ledger too — after the per-item adopt/refute/partial response (one round; the user has the final say), each accepted or insisted-on item becomes a finding row with the next V-N ID and `source: user` noted in the Finding column; an item applied over your refutation is additionally marked `user-override`. They then drive the next fix round exactly like verifier findings. A user-overruled false positive still follows rule "distill the lesson into spec/knowledge.md"

The user-facing output ends with the round summary:

```
Ledger: verify.md round <N> — fixed <X> · still open <Y> (escalated: <IDs>) · new <Z>
```

## Failure triage (locate the problem; do not prescribe a fix)

When the review fails, **report the specific failure point**:

| Failing dimension | Report content |
|---|---|
| Completeness | List unimplemented items from proposal `## What`; list interfaces in design.md that are not aligned |
| Correctness | Paste the exact error + file / line number; failing test case + expected vs. actual |
| Coherence | Where the change diverges from `## How`; scope creep; violations of stack conventions |

**Guiding principle**: describe the problem; do not prescribe the fix — the remediation path is for the user / main conversation to decide.

## Anti-Cheating

- **NEVER mark a test pass if it was not actually run** — reading the code with your eyes does not count as a Correctness pass
- **The dev agent's self-reported Evidence is a claim, not proof** — spec-verifier re-runs the key commands itself (Iron Law: no pass without fresh verification evidence)
- partial MUST specify what is partial — a vague "basically passed" is NEVER acceptable

## Stuck Protection

- If verify cycles through review without converging → stop and report; NEVER loop endlessly

## What this command does NOT do

- Does not proactively recommend "which command to run next" — that is `$spec-status`'s job; verify only reports
- Does not modify project source (the one file it always writes is the verification ledger `spec/changes/<name>/verify.md`; source modification is `$spec-apply`'s job)
- Does not modify proposal (`$spec-revise`'s job)
- Does not archive (`$spec-archive`'s job)
