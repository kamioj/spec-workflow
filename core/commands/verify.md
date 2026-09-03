---
<!-- host:claude -->
description: Verifies the current change by dispatching the independent spec-verifier agent (fresh context — the implementing conversation never audits itself) across four dimensions + charter audit; --codex adds a heterogeneous Codex peer review (read-only); --codex --fix lets Codex apply fixes directly; native adds the opt-in project-idiom conformance pass. Every run updates the verification ledger spec/changes/<name>/verify.md (stable finding IDs + round diffing + unfixed-escalation). Can be re-run independently.
<!-- /host -->
<!-- host:codex -->
description: Verifies the current change by dispatching the independent spec-verifier agent (fresh context — the implementing conversation never audits itself) across four dimensions + charter audit; native adds the opt-in project-idiom conformance pass. Every run updates the verification ledger spec/changes/<name>/verify.md (stable finding IDs + round diffing + unfixed-escalation). Can be re-run independently.
<!-- /host -->
allowed-tools: Read, Write, Bash, Edit, Grep, Glob, Task
---

# /spec:verify

<!-- host:claude -->
## Three modes (flags)

| Command | Behavior | Modifies code |
|---|---|---|
| `/spec:verify` | independent spec-verifier review: four dimensions + charter audit | ❌ |
| `/spec:verify --codex` | + Codex heterogeneous peer review, produces findings | ❌ report only |
| `/spec:verify --codex --fix` | Codex review + applies fixes + Claude second-pass sign-off | ✅ |
| `/spec:verify native` | + the opt-in **Native pass**: project-idiom conformance over every touched file (E-N exemplar / nearest same-type neighbors as the reference set — verifier check 6) | ❌ |

`--fix` MUST be paired with `--codex` — standalone `--fix` outputs exactly `--fix requires --codex; run /spec:verify --codex --fix` and stops. Default (no flags) performs the independent review only, maintaining a read-only reporter stance. `native` is a dimension switch, not a mode — combinable with any row above (`/spec:verify native --codex`).
<!-- /host -->
<!-- host:codex -->
> Heterogeneous peer review (`--codex`) is not available in this port — Codex cannot be its own heterogeneous reviewer.

`/spec:verify native` adds the opt-in **Native pass** (project-idiom conformance over every touched file — E-N exemplar / nearest same-type neighbors as the reference set; verifier check 6) to the spawned verifier's checklist.
<!-- /host -->

## Independent verifier (why verify dispatches an agent instead of reviewing inline)

<!-- host:claude -->
The conversation that just ran `/spec:apply` cannot audit its own output — same context, same blind spots, and "be objective" instructions have near-zero measured effect on self-preference. `/spec:verify` therefore **dispatches the `spec-verifier` agent** (fresh context: it reads only proposal + design + charter + the diff) and keeps the bookkeeping for itself. The same rule binds `/spec:apply`'s closing verification: the review is ALWAYS performed by a dispatched spec-verifier, whoever initiates it — the implementing conversation only ever does bookkeeping:

1. Dispatch `spec-verifier` with the change name and nothing else (plus the `native` switch when the user passed it — the ONLY extra the dispatch may carry) — its ignorance of the implementation process is the mechanism, don't "helpfully" brief it
<!-- /host -->
<!-- host:codex -->
The conversation that just ran `/spec:apply` cannot audit its own output — same context, same blind spots, and "be objective" instructions have near-zero measured effect on self-preference. `/spec:verify` therefore **spawns the spec-verifier agent (defined in ~/.codex/agents/spec-verifier.toml)** (fresh context: it reads only proposal + design + charter + the diff) and keeps the bookkeeping for itself. The same rule binds `/spec:apply`'s closing verification: the review is ALWAYS performed by a spawned spec-verifier, whoever initiates it — the implementing conversation only ever does bookkeeping:

0. **Agent freshness pre-check** (once per session): compare the shipped `${PLUGIN_ROOT}/agents/spec-verifier.toml` with `~/.codex/agents/spec-verifier.toml` — missing → copy + one-line notice; differs → one-line notice + ask once (sync / keep — never clobber a customized agent silently); identical → proceed. Codex cannot bundle agents; without this check a plugin upgrade leaves the OLD verifier running with no error
1. Spawn spec-verifier with the change name and nothing else (plus the `native` switch when the user passed it — the ONLY extra the dispatch may carry) — its ignorance of the implementation process is the mechanism, don't "helpfully" brief it
   (`spawn_agent` parameter contract: EITHER `message` — plain text only — OR `items` when attaching skill references, with the task text as a `{type:"text"}` item; both together is rejected)
<!-- /host -->
2. Transcribe its findings into ledger rows **without softening, dropping, or re-judging them** — format conversion only (one finding = one table row; severity / location / text preserved). Derive the per-dimension pass/fail lines from its findings; its `conclusion` is authoritative and may never be upgraded fail → pass. Disagreement is recorded as a note next to the row, never by deletion
3. Run the round rules below (diff vs previous round, escalation)
4. The user overrules a finding as a false positive → distill the generalized lesson (what pattern + why it's acceptable here) into `spec/knowledge.md`, so later rounds and later changes stop repeating it

<!-- host:claude -->
## Four-dimension verification framework (executed by the dispatched spec-verifier; runs in all modes)
<!-- /host -->
<!-- host:codex -->
## Four-dimension verification framework (executed by the spawned spec-verifier; runs in all modes)
<!-- /host -->

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
- **Index anchor**: with `index.md` present, every behavioral addition in the diff (validation / required field / value range / permission / endpoint / schema element) must trace to a `refs:` R-N whose quoted text entails it — no citation or a mismatched one = unsourced addition; index absent (legacy change) → declare it and hunt additions against `## What` only
- **`Not in this change` = exclusion zones**: code changes inside that scope → scope violation, flag it; conversely NEVER flag excluded scope as "missing work" — it is out of scope by decision
<!-- host:claude -->
- Does it conform to the coding conventions in `skills/core/references/<stack>.md`?
<!-- /host -->
<!-- host:codex -->
- Does it conform to the coding conventions in the sdd spec-core skill's stack references?
<!-- /host -->
- **Charter audit** (see the dedicated section below): every fallback / degrade / compat path in the diff must trace to an explicit proposal `## How` / `## Risk` decision

### 4. Reuse
- Each new class / shared util / shared component / page in the diff: does the host codebase already have an equivalent (grep by **responsibility**, not just name)? Does the dev summary's `New creations` field carry the A-N gap citation? Does a new page conform to its designated E-N exemplar (abstractions the exemplar lacks = additions; conventions it has that the page drops = findings)?

### Native pass (opt-in — runs ONLY with the `native` flag)
- Project-idiom conformance over every touched file: compare against the E-N exemplar (or 1–2 nearest same-type files when the index has none) — naming / component shape / styling approach / state & error idioms / API-call pattern. Findings need **dual citation** (project convention at file:line with ≥2 occurrences vs the change's deviation at file:line); the project's own code is the sole authority — generic stack references are not citations here, and consistency outranks elegance. Full definition: spec-verifier check 6.
- Anchored to index.md `## Assets` / `## Exemplars`; index absent (legacy change) → declare it, flag blatant duplication only

## Charter audit (part of Coherence — hunts the dirty-data defect class)

Models rate defensive fallbacks as "robust"; the charter (`code-charter.md`) rates them as the number-one source of dirty data. This audit therefore never asks "is this fallback well-written?" — it asks "**which gate decision authorized it?**". Untraceable = finding, zero judgment calls.

**Machine pass first**: `ast-grep scan --config ${CLAUDE_PLUGIN_ROOT}/rules/sgconfig.yml <changed files>` — the shipped rule pack (`rules/dirty-data/`, validated: catches "return default in catch" even when a log line disguises it; never flags a proper throw) produces AST-level Evidence with no regex false positives. ast-grep not installed (`scoop install main/ast-grep` / `npm i -g @ast-grep/cli`) → declare `not run: ast-grep not installed` in Evidence and fall back to the manual patterns below. Java projects with a JVM can additionally run PMD's built-in EmptyCatchBlock (`pmd check --file-list changed.txt -R category/java/errorprone.xml`) with zero project changes.

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

The fix direction is **replacement or a gate decision** (`/spec:revise how` to authorize it deliberately) — never "keep the fallback but add a log line".
<!-- host:claude -->

## --codex: heterogeneous Codex peer review

When `--codex` is specified, after the independent review, invoke **Codex (a heterogeneous model)** to review the same set of changes — a heterogeneous reviewer fills in the systematic blind spots of a single Claude pass (in practice the two finding sets barely overlap).

**All invocation mechanics are encapsulated in `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1`** — Windows workarounds (#336 bypass sandbox / #337 avoid node spawn), `effort=low` for cost control, timeout to prevent hangs, residual-process cleanup, session parsing. The "why this exact invocation is required" constraints are in the script header comments (single source of truth).

**Session reuse**: if `spec/changes/<name>/.codex-session` exists (left by `/spec:propose --codex`), pass `-ResumeSession <id>` to resume — Codex remembers the proposal it reviewed and can judge "**does the code faithfully implement the proposal?**". Omit the parameter if no session file exists.

> Executed by Claude inside the session (`${CLAUDE_PLUGIN_ROOT}` resolves only there) — **not** a command for you to run in a terminal.

```powershell
$prompt = @"
Review the following code changes. Focus: <key focus of this change + proposal ## Risk>
Scope: <files touched in git diff>
"@
pwsh -File ${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1 -Prompt $prompt -TimeoutSec 300 -ProjectDir "<project directory>" -ResumeSession "<id; omit this parameter if none>"
```

**Default (no `--fix`): Codex produces findings only, does not modify code** — it reports issues; you decide whether to address them via `/spec:apply` or by adding `--fix`.

## --fix: Codex applies fixes + Claude second-pass sign-off

Enabled only with `--codex --fix`. **Uses the same `codex-exec.ps1`**, but the prompt is switched to "review **and fix**" — sandbox bypass allows Codex to modify working-tree files directly. **Claude then performs a second-pass sign-off** (do not blindly trust):

1. **Pre-condition**: the working tree should ideally be committed beforehand (so Codex changes can be isolated and rolled back via diff)
2. Run `git diff` to see what Codex changed, and judge each change:

| Codex change | Verdict | Action |
|---|---|---|
| Real problem, correctly fixed | ✅ | Keep |
| Changed something it shouldn't / introduced a new problem | ❌ noise | Revert (`Edit` / `git checkout -p`) |
| Rewrote unrelated code | ❌ scope creep | Revert |
| Real problem Codex missed | ➕ | Claude fixes it |

**Community-validated warning, hardcoded here**: Codex changes contain noise; Claude MUST filter every change individually. Blindly trusting "it changed it, so it's right" is NEVER acceptable.
<!-- /host -->

## Output format

```
=== Verify ===
[independent] Completeness: <pass/fail/partial> - <explanation>
               Correctness:  <pass/fail/partial> - <explanation>
               Coherence:    <pass/fail/partial> - <explanation>
               Reuse:        <pass/fail/partial> - <explanation>

<!-- host:claude -->
Evidence (mandatory in all modes — one line per check actually executed):
<!-- /host -->
<!-- host:codex -->
Evidence (mandatory — one line per check actually executed):
<!-- /host -->
  <command / action> → <exit code or the key output line>
  not run: <check> — <reason>        ← declaring a skip is legal; hiding it is not

<!-- host:claude -->
[--codex] Codex peer review findings: <N items>
[--fix]   Codex changed <M> locations → kept X / reverted Y / supplemented Z; tokens ≈ <from output>

<!-- /host -->
Overall: <pass / fail>
```

<!-- host:claude -->
Without flags, only the `[independent]` section (plus Evidence) is output. **Correctness may be marked pass only when at least one Evidence line supports it**; nothing runnable in this environment → write `Correctness: not verifiable - <why>`, never pass.
<!-- /host -->
<!-- host:codex -->
**Correctness may be marked pass only when at least one Evidence line supports it**; nothing runnable in this environment → write `Correctness: not verifiable - <why>`, never pass.
<!-- /host -->

## Verification ledger: `spec/changes/<name>/verify.md` (written every run)

A stateless verify can pass the same broken change twice. Every run therefore writes/updates a ledger in the change directory — findings carry stable IDs, and the next round must face every still-open one before it may conclude.

The ledger has **two writers, one table**: `/spec:propose`'s critique panel opens it with round 0 (stage: propose, pre-code findings), and `/spec:verify` owns every round after — so the round narrative runs unbroken from before the gate to acceptance, and `/spec:status` derives the milestone view from it without any extra file.

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
1. **Read the previous ledger first** (if present): this run's `round` = previous + 1. **Round 0 is legal**: `/spec:propose`'s critique panel writes its surviving findings as round 0 (stage: propose) before any code exists — the first verify run is then round 1, and it re-checks round 0's open findings like any others
   - **Fix-round scoping**: when a round exists only to re-check fixes (no new implementation since the last full pass), the verifier's scope is the still-open findings + the fix diff — NOT a fresh full four-dimension pass over the whole change (a full re-pass over unchanged code is a measured pure duplicate). A full pass is warranted only when new implementation landed since the last one
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
<!-- host:claude -->
| Coherence | Where the change diverges from `## How`; scope creep; violations of `references/<stack>` conventions |
<!-- /host -->
<!-- host:codex -->
| Coherence | Where the change diverges from `## How`; scope creep; violations of stack conventions |
<!-- /host -->
| Reuse | The new creation + the existing equivalent it duplicates (file:line), or the E-N exemplar convention dropped, or the missing A-N gap citation |

**Guiding principle**: describe the problem; do not prescribe the fix — the remediation path is for the user / main conversation to decide.

## Anti-Cheating

- **NEVER mark a test pass if it was not actually run** — reading the code with your eyes does not count as a Correctness pass
- **The dev agent's self-reported Evidence is a claim, not proof** — spec-verifier re-runs the key commands itself (Iron Law: no pass without fresh verification evidence)
<!-- host:claude -->
- If Codex fails to run (auth / timeout / ENOENT), **NEVER treat it as "reviewed"** — explicitly report the failure
- "Codex reported no issues" ≠ "the code has no issues" — Codex has its own blind spots; that is precisely why there are two layers
<!-- /host -->
- partial MUST specify what is partial — a vague "basically passed" is NEVER acceptable

## Stuck Protection

<!-- host:claude -->
- Codex invocations come with a built-in timeout (300s in the template); on timeout, stop and clean up residual processes
- If `--fix` causes the same change to cycle through review and re-fix without converging → stop and report; NEVER loop endlessly through `codex → fix → codex`
<!-- /host -->
<!-- host:codex -->
- If verify cycles through review without converging → stop and report; NEVER loop endlessly
<!-- /host -->

## What this command does NOT do

- Does not proactively recommend "which command to run next" — that is `/spec:status`'s job; verify only reports
<!-- host:claude -->
- Does not modify project source when `--fix` is absent (the one file it always writes is the verification ledger `spec/changes/<name>/verify.md`; source modification is `/spec:apply`'s job)
<!-- /host -->
<!-- host:codex -->
- Does not modify project source (the one file it always writes is the verification ledger `spec/changes/<name>/verify.md`; source modification is `/spec:apply`'s job)
<!-- /host -->
- Does not modify proposal (`/spec:revise`'s job)
- Does not archive (`/spec:archive`'s job)
