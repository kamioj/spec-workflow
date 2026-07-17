---
name: spec-loop
description: Goal-driven autonomous round loop. Give it a goal + acceptance checklist + round budget (touchpoint 1), then it researches, implements, verifies, and retrospects round after round — driven by a Stop-event hook, not by prompt discipline — until every acceptance item is verifier-checked (touchpoint 2: final acceptance) or a fuse blows (round cap / no-progress / refusal-to-retrospect). Use when the goal is known but the path is not; a known plan one-pass change belongs to $spec-workflow instead.
---
<!-- GENERATED from core/commands/loop.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-loop

Goal-driven autonomous iteration: `research → implement → verify → retrospect` per round, with a **file ledger as cross-round memory** and a **Stop-event hook as the round driver**. The HARD GATE moves up to the goal level — the user approves the goal/acceptance/budget once, then the loop runs unattended until final acceptance or a fuse.

**Positioning**: `$spec-workflow` = plan known, one pass, two touchpoints. `$spec-loop` = goal known, path unknown, N rounds, same two touchpoints. A bare self-feeding loop (ralph-style) = no acceptance checklist, no independent verification, no ledger — this command exists precisely to add those. **Never run two loops at once** (nor alongside another Stop-driven looper such as ralph-loop).

**Ledger format authority**: [`../spec-core/references/loop-spec.md`](../spec-core/references/loop-spec.md) — loop.md structure, write ownership (loop.md model-only / .loop-state driver-only), field rules.

## Invocation forms

| Form | Behavior |
|---|---|
| `$spec-loop <goal>` | cold start (below) |
| `$spec-loop` | resume: a `paused`/fuse-stopped ledger exists → set `status: running`, **re-bind the session** (below — skipping this leaves the session guard silently ignoring every Stop from this session), continue from the latest Retrospect's plan |
| `$spec-loop stop` | soft brake: set `status: paused` — the driver releases the next stop |
| `$spec-loop abandon` | drop the direction: set `status: aborted`; archive later with `$spec-archive abandoned` |

**Resume re-bind** (the only .loop-state touch besides cold start — it rewrites the session_id line and preserves every counter):
```
awk -v s="" 'BEGIN{FS=OFS="="} $1=="session_id"{$2=s} 1' spec/changes/<name>/.loop-state > spec/changes/<name>/.loop-state.tmp && mv spec/changes/<name>/.loop-state.tmp spec/changes/<name>/.loop-state
```
(Codex has no session-id environment variable — clearing the field lets the driver adopt this session's id on its first Stop.)

## Cold start (touchpoint 1 of 2: goal confirmation)

1. **Pre-check**: another `running` loop.md in this project → refuse (one loop at a time). Other active changes exist → warn: while a loop runs, its change dir counts toward the single-active-change rule (check-tbd/check-gate will block `$spec-propose`/`$spec-apply` in this project).
2. **Goal confirmation** — the one interrogation of the whole run, so it must be complete (AskUserQuestion; self-contained options per SKILL Interrogation rules):
   - the goal, restated in one sentence (no restatement → no loop)
   - the **acceptance checklist**: 2–8 items, each independently verifiable with a `verify:` clause (an executable check or observable behavior — "feels better" is not acceptance); confirm items AND their verify clauses with the user
   - **max_rounds** (default 10 — the primary safety mechanism; budget generously for exploratory goals) and anything explicitly out of scope
3. **Create the ledger**: `spec/changes/<kebab-name>/loop.md` per loop-spec — frontmatter (`status: running`, `max_rounds`, `no_progress_fuse: 3` — plain bare values, and the fuse must be >= 1), `## Acceptance` (checkboxes live ONLY here), empty `## Rounds` / `## Lessons`.
4. **Bind the session** (keeps other sessions in this project from being hijacked by the driver):
   ```
   printf 'session_id=\nrounds_injected=0\nretro_reinjects=0\nchecked_history=\ntree_fp_history=\n' > spec/changes/<name>/.loop-state
   ```
   (Codex has no session-id environment variable — the driver adopts this session's id on its first Stop.)
   Cold start and the resume re-bind above are the ONLY times anything other than the driver touches `.loop-state`.
5. **Round 1 starts now, in this same turn** — no waiting, no extra approval.

## Round protocol (every round, including Round 1)

<!-- KEPT IN SYNC with the loop-driver reinject templates (hooks/loop-driver.sh + codex/hooks/loop-driver.{sh,ps1}) — change one, sweep all four. -->


1. **Read the ledger first**: Acceptance state, the latest Retrospect's plan, ALL of `## Lessons`. Then **search the ledger and the codebase before assuming anything is unimplemented** — re-implementing existing work is the classic fresh-context failure.
2. **Plan**: pick exactly **ONE** item — from the previous Retrospect's plan, or the first unchecked Acceptance item. One item per round is the anti-degradation rule, not a suggestion. Write `#### Plan` (what + why this one).
3. **Act**: implement the one item. Coding Charter applies (read `../spec-core/references/code-charter.md` before the first keystroke of the run). Write `#### Act` (file-level).
4. **Verify**: dispatch the **spec-verifier agent** (fresh context) on what this round produced. Self-review does not count; an Acceptance checkbox may be checked **only** with the verifier's evidence anchored in `#### Verify`. Anti-Cheating applies in full (unrun ≠ success; a bypass must be declared a bypass).
5. **Retrospect** (the driver hard-checks this): `#### Retrospect` = the lesson learned (durable/operational ones also appended to `## Lessons` as `L-N`) + the next round's plan. Then **end the turn** — ending the turn is how the round ends.
6. **Stuck?** SKILL Stuck Protection applies within and across rounds: 3 consecutive failed fixes in one direction → write the Stuck Self-Check into the Retrospect, set `status: paused`, and report to the user instead of burning rounds.

## What drives the next round (hard mechanics — know them, don't fight them)

The `loop-driver` Stop hook fires every time the turn ends and decides mechanically (see its header for the probe-verified contract): ledger integers valid? → round budget left? → all Acceptance checked (→ it injects the **final acceptance** turn)? → Retrospect written (missing → re-inject, ≤2)? → progress made (checkbox count / worktree fingerprint, `no_progress_fuse` consecutive stale rounds → fuse)? → otherwise it **injects the next round**. Four distinct stop notices tell the user WHICH way it ended: round cap / no progress / refusal-to-retrospect / ledger corrupt.

Implications:
- You cannot "just stop" mid-loop by ending the turn — set `status: paused` (that IS the exit; say why in the Retrospect).
- You cannot skip the retrospect — the driver re-injects until it exists.
- Progress is what the driver can count, not what you claim.

## Final acceptance (touchpoint 2 of 2)

<!-- KEPT IN SYNC with the loop-driver final-acceptance reinject template (hooks/loop-driver.sh + codex twins). -->


When every Acceptance item is checked, the driver injects the final-acceptance turn: dispatch a **fresh spec-verifier** to independently re-verify EVERY Acceptance item against its `verify:` clause (mid-loop checkmarks are claims, this is the audit), write the result as a ledger round in `verify.md` if the project keeps one, **report per-item results to the user**, and only if verification holds set `status: done`. Then `$spec-archive` closes the change (loop.md travels with it, `.loop-state` is deleted, durable Lessons feed `spec/knowledge.md`).

A fuse stop instead of acceptance → report the driver's notice verbatim, plus: what the ledger shows, what you would change (plan / acceptance list / budget), and wait — resuming is the user's call (`$spec-loop`).

## Anti-patterns

- ❌ Starting a loop for a task with a known plan (that's `$spec-workflow`) or for pure understanding (that's exploration, no delivery)
- ❌ A vague acceptance list ("works well") — unverifiable acceptance = the loop cannot ever legitimately finish
- ❌ Checking Acceptance items without verifier evidence; checkboxes outside `## Acceptance`; editing `.loop-state` (full list in loop-spec.md)
- ❌ Advancing multiple items in one round because "they're small" — round-scope creep is how context saturates and lessons stop being written
- ❌ After a fuse, restarting with nothing changed — same inputs, same fuse
