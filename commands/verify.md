---
description: Verifies the current change. Default is Claude self-review across three dimensions (completeness / correctness / coherence); --codex adds a heterogeneous Codex peer review (read-only); --codex --fix lets Codex apply fixes directly. Can be re-run independently.
allowed-tools: Read, Bash, Edit, Grep, Glob
---

# /spec:verify

## Three modes (flags)

| Command | Behavior | Modifies code |
|---|---|---|
| `/spec:verify` | Claude self-review, three dimensions | ❌ |
| `/spec:verify --codex` | + Codex heterogeneous peer review, produces findings | ❌ report only |
| `/spec:verify --codex --fix` | Codex review + applies fixes + Claude second-pass sign-off | ✅ |

`--fix` MUST be paired with `--codex` (standalone `--fix` produces an error prompt). Default (no flags) performs only the Claude self-review, maintaining a read-only reporter stance.

## Three-dimension verification framework (Claude self-review; runs in all modes)

### 1. Completeness
- Is every item in proposal `## What` implemented?
- Do inputs / outputs align with the interface contract (design.md, if present)?
- Do tests cover the critical paths?

### 2. Correctness
- Does the code compile / pass type checks?
- Do unit / integration tests pass?
- Are edge cases (empty / extreme / invalid input) handled correctly?

### 3. Coherence
- Is the change consistent with the decisions in proposal `## How`?
- **Nothing was done that the proposal did not ask for** (no scope creep)?
- Does it conform to the coding conventions in `skills/core/references/<stack>.md`?

## --codex: heterogeneous Codex peer review

When `--codex` is specified, after the self-review, invoke **Codex (a heterogeneous model)** to review the same set of changes — filling in the systematic blind spots of a single Claude pass (real-world result: Codex found 4 high-severity issues vs. Claude's 8, with only 1 overlap).

**All invocation mechanics are encapsulated in `${CLAUDE_PLUGIN_ROOT}/scripts/codex-exec.ps1`** — Windows workarounds (#336 bypass sandbox / #337 avoid node spawn), `effort=low` for cost control, timeout to prevent hangs, residual-process cleanup, session parsing. The "why this exact invocation is required" constraints are in the script header comments (single source of truth).

**Session reuse**: if `spec/changes/<name>/.codex-session` exists (left by `/spec:propose --codex`), pass `-ResumeSession <id>` to resume — Codex remembers the proposal it reviewed and can judge "**does the code faithfully implement the proposal?**". Omit the parameter if no session file exists.

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
[self-review] Completeness: <pass/fail/partial> - <explanation>
               Correctness:  <pass/fail/partial> - <explanation>
               Coherence:    <pass/fail/partial> - <explanation>

[--codex] Codex peer review findings: <N items>
[--fix]   Codex changed <M> locations → kept X / reverted Y / supplemented Z; tokens ≈ <from output>

Overall: <pass / fail>
```

Without flags, only the `[self-review]` section is output.

## Failure triage (locate the problem; do not prescribe a fix)

When self-review fails, **report the specific failure point**:

| Failing dimension | Report content |
|---|---|
| Completeness | List unimplemented items from proposal `## What`; list interfaces in design.md that are not aligned |
| Correctness | Paste the exact error + file / line number; failing test case + expected vs. actual |
| Coherence | Where the change diverges from `## How`; scope creep; violations of `references/<stack>` conventions |

**Guiding principle**: describe the problem; do not prescribe the fix — the remediation path is for the user / main conversation to decide.

## Anti-Cheating

- **NEVER mark a test pass if it was not actually run** — reading the code with your eyes does not count as a Correctness pass
- If Codex fails to run (auth / timeout / ENOENT), **NEVER treat it as "reviewed"** — explicitly report the failure
- "Codex reported no issues" ≠ "the code has no issues" — Codex has its own blind spots; that is precisely why there are two layers
- partial MUST specify what is partial — a vague "basically passed" is NEVER acceptable

## Stuck Protection

- Codex invocations come with a built-in timeout (300s in the template); on timeout, stop and clean up residual processes
- If `--fix` causes the same change to cycle through review and re-fix without converging → stop and report; NEVER loop endlessly through `codex → fix → codex`

## What this command does NOT do

- Does not proactively recommend "which command to run next" — that is `/spec:status`'s job; verify only reports
- Does not modify code when `--fix` is absent (modification is `/spec:apply`'s job)
- Does not modify proposal (`/spec:revise`'s job)
- Does not archive (`/spec:archive`'s job)
