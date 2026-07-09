---
description: Verifies the current change by dispatching the independent spec-verifier agent (fresh context — the implementing conversation never audits itself) across three dimensions + charter audit; --codex adds a heterogeneous Codex peer review (read-only); --codex --fix lets Codex apply fixes directly. Every run updates the verification ledger spec/changes/<name>/verify.md (stable finding IDs + round diffing + unfixed-escalation). Can be re-run independently.
allowed-tools: Read, Write, Bash, Edit, Grep, Glob, Task
---
<!-- GENERATED from core/commands/verify.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:verify

## Three modes (flags)

| Command | Behavior | Modifies code |
|---|---|---|
| `/spec:verify` | independent spec-verifier review: three dimensions + charter audit | ❌ |
| `/spec:verify --codex` | + Codex heterogeneous peer review, produces findings | ❌ report only |
| `/spec:verify --codex --fix` | Codex review + applies fixes + Claude second-pass sign-off | ✅ |

`--fix` MUST be paired with `--codex` — standalone `--fix` outputs exactly `--fix requires --codex; run /spec:verify --codex --fix` and stops. Default (no flags) performs the independent review only, maintaining a read-only reporter stance.

## Independent verifier (why verify dispatches an agent instead of reviewing inline)

The conversation that just ran `/spec:apply` cannot audit its own output — same context, same blind spots, and "be objective" instructions have near-zero measured effect on self-preference. `/spec:verify` therefore **dispatches the `spec-verifier` agent** (fresh context: it reads only proposal + design + charter + the diff) and keeps the bookkeeping for itself. The same rule binds `/spec:apply`'s closing verification: the review is ALWAYS performed by a dispatched spec-verifier, whoever initiates it — the implementing conversation only ever does bookkeeping:

1. Dispatch `spec-verifier` with the change name and nothing else — its ignorance of the implementation process is the mechanism, don't "helpfully" brief it
2. Transcribe its findings into ledger rows **without softening, dropping, or re-judging them** — format conversion only (one finding = one table row; severity / location / text preserved). Derive the per-dimension pass/fail lines from its findings; its `conclusion` is authoritative and may never be upgraded fail → pass. Disagreement is recorded as a note next to the row, never by deletion
3. Run the round rules below (diff vs previous round, escalation)
4. The user overrules a finding as a false positive → distill the generalized lesson (what pattern + why it's acceptable here) into `spec/knowledge.md`, so later rounds and later changes stop repeating it

## Three-dimension verification framework (executed by the dispatched spec-verifier; runs in all modes)

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
- Does it conform to the coding conventions in `skills/core/references/<stack>.md`?
- **Charter audit** (see the dedicated section below): every fallback / degrade / compat path in the diff must trace to an explicit proposal `## How` / `## Risk` decision

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

## --codex: heterogeneous Codex peer review

When `--codex` is specified, after the independent review, invoke **Codex (a heterogeneous model)** to review the same set of changes — filling in the systematic blind spots of a single Claude pass (real-world result: Codex found 4 high-severity issues vs. Claude's 8, with only 1 overlap).

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

## Output format

```
=== Verify ===
[independent] Completeness: <pass/fail/partial> - <explanation>
               Correctness:  <pass/fail/partial> - <explanation>
               Coherence:    <pass/fail/partial> - <explanation>

Evidence (mandatory in all modes — one line per check actually executed):
  <command / action> → <exit code or the key output line>
  not run: <check> — <reason>        ← declaring a skip is legal; hiding it is not

[--codex] Codex peer review findings: <N items>
[--fix]   Codex changed <M> locations → kept X / reverted Y / supplemented Z; tokens ≈ <from output>

Overall: <pass / fail>
```

Without flags, only the `[independent]` section (plus Evidence) is output. **Correctness may be marked pass only when at least one Evidence line supports it**; nothing runnable in this environment → write `Correctness: not verifiable - <why>`, never pass.

## Verification ledger: `spec/changes/<name>/verify.md` (written every run)

A stateless verify can pass the same broken change twice. Every run therefore writes/updates a ledger in the change directory — findings carry stable IDs, and the next round must face every still-open one before it may conclude.

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
1. **Read the previous ledger first** (if present): this run's `round` = previous + 1
2. **Re-check every Status=open finding one by one** — fixed → `fixed(rN)`; still open → stays open and **escalates**: a critical/major finding open for 2+ rounds forces `conclusion: fail` and leads the user-facing output
3. New findings take the next V-N ID; IDs are never reused or renumbered
4. `wontfix` requires a written reason (inside `Not in this change` / explicit user decision) — silence is not a status
5. Keep the latest round's Evidence in full; collapse earlier rounds' Evidence to one line each

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
| Coherence | Where the change diverges from `## How`; scope creep; violations of `references/<stack>` conventions |

**Guiding principle**: describe the problem; do not prescribe the fix — the remediation path is for the user / main conversation to decide.

## Anti-Cheating

- **NEVER mark a test pass if it was not actually run** — reading the code with your eyes does not count as a Correctness pass
- **The dev agent's self-reported Evidence is a claim, not proof** — spec-verifier re-runs the key commands itself (Iron Law: no pass without fresh verification evidence)
- If Codex fails to run (auth / timeout / ENOENT), **NEVER treat it as "reviewed"** — explicitly report the failure
- "Codex reported no issues" ≠ "the code has no issues" — Codex has its own blind spots; that is precisely why there are two layers
- partial MUST specify what is partial — a vague "basically passed" is NEVER acceptable

## Stuck Protection

- Codex invocations come with a built-in timeout (300s in the template); on timeout, stop and clean up residual processes
- If `--fix` causes the same change to cycle through review and re-fix without converging → stop and report; NEVER loop endlessly through `codex → fix → codex`

## What this command does NOT do

- Does not proactively recommend "which command to run next" — that is `/spec:status`'s job; verify only reports
- Does not modify project source when `--fix` is absent (the one file it always writes is the verification ledger `spec/changes/<name>/verify.md`; source modification is `/spec:apply`'s job)
- Does not modify proposal (`/spec:revise`'s job)
- Does not archive (`/spec:archive`'s job)
