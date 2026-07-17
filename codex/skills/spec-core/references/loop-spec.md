<!-- GENERATED from core/references/loop-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# loop.md spec

`spec/changes/<change-name>/loop.md` is the **round ledger** of a `$spec-loop` run — the loop's cross-round memory (goal + acceptance checklist + round records + lessons), and the only file the Stop-event driver reads its mechanical signals from. Alongside it lives `.loop-state`, the driver's own state file.

## Write ownership (the load-bearing rule)

| File | Written by | Read by |
|---|---|---|
| `loop.md` | **the model only** | the model (each round) + the driver (mechanical counts only) |
| `.loop-state` | **the driver only** | the driver |

Never edit `.loop-state` by hand or by model — the driver rewrites it wholesale on every decision. The driver never *writes* loop.md; it only counts checkboxes, round headings, and retrospect bodies in it. A model claim of progress that isn't visible in those mechanical signals does not exist for the driver.

## loop.md format

Frontmatter values are **plain scalars on their own line** — the template below is copy-safe as-is. (Since 0.5.1 the driver also tolerates a trailing `# comment` on a value line, but the canonical form is bare; the 0.5.0 driver silently ignored ledgers whose values carried inline comments, which is why the template no longer shows any.)

```markdown
---
goal: <one-line goal>
status: running
max_rounds: 10
no_progress_fuse: 3
started: YYYY-MM-DD
---
# Loop: <change-name>

## Acceptance
- [ ] A-1 <verifiable item> (verify: <executable check / observable behavior>)
- [ ] A-2 ...

## Rounds
### Round 1
#### Plan
<the ONE item this round advances + why it was picked (cite the previous Retrospect)>
#### Act
<what actually changed, file-level>
#### Verify
<spec-verifier dispatch conclusion + evidence anchor — self-review does not count>
#### Retrospect
<lesson learned (durable ones also appended to ## Lessons) + next-round plan>

## Lessons
### L-1 <operational lesson> (source: Round N)
```

## Field rules

- **`status`**: `running` is the driver's arming condition — exactly one running loop.md per project, or the driver stands down. `paused` (user brake / stuck) and `aborted` (direction dropped) both release the stop immediately; `done` is set only after the final acceptance report — and is also what `$spec-archive`'s gate checks (done + fully checked Acceptance = flow honored).
- **`max_rounds` / `no_progress_fuse`**: plain integers only, and `no_progress_fuse` must be **>= 1** (0 would make the stale-window check vacuously true and blow the fuse unconditionally on round 2). Any non-integer or 0 makes the driver halt loudly with a "ledger corrupt" notice — deliberately, because a silently unparseable cap would otherwise mean an uncapped loop. `status` meaning: `running` arms the driver; `paused`/`aborted` release it; `done` only after the final acceptance report. Fields are read by the driver with comment-stripping (`value # note` → `value`).
- **Checkboxes live ONLY under `## Acceptance`** — the driver counts `- [ ]` / `- [x]` in that section slice; a checkbox anywhere else corrupts the progress signal. Round records and Lessons use prose.
- **An Acceptance item is checked only with verifier evidence** — the checking round's `#### Verify` must carry the spec-verifier conclusion that covers it. The final acceptance re-verifies every item with a fresh verifier; a mid-loop dishonest check only wastes rounds, it cannot produce a false final pass.
- **`#### Retrospect` must be non-empty before the turn ends** — the driver re-injects (without counting a new round) until it is; after 2 refusals it halts with a distinct "refusal-to-retrospect" notice.
- **A-N / L-N ids are stable** — never renumber or reuse.
- **Lessons vs Rounds**: `## Lessons` holds operational knowledge that must survive rounds (correct build/verify commands, known traps); round records hold what happened. Splitting them keeps re-read cost per round flat.

## .loop-state format (driver-owned; key=value, one per line)

```
session_id=<bound host session>
rounds_injected=<int>      # the cap counter (counts driver injections, incl. final acceptance)
retro_reinjects=<int>      # consecutive retrospect re-injections (reset on every counted round)
checked_history=<csv>      # acceptance checked-count at each injection
tree_fp_history=<csv>      # worktree fingerprint at each injection (na = git unavailable)
```

## Lifecycle

| Stage | Actor | Action |
|---|---|---|
| Cold start | `$spec-loop <goal>` | goal confirmation (touchpoint 1) → write loop.md (status: running) → bind session → Round 1 in the same turn |
| Resume | `$spec-loop` | set status back to `running` + **re-bind the session_id line** in `.loop-state` (the documented awk one-liner in the loop command — without it the session guard silently ignores every Stop from the new session) → continue from the latest Retrospect's plan |
| Every turn end | `loop-driver` hook | decision table: corrupt? acceptance met (≤1 cap overrun)? cap? retrospect written? progress? → re-inject or release |
| Final acceptance | injected by the driver | fresh spec-verifier re-checks every Acceptance item → report (touchpoint 2) → status: done |
| Close out | `$spec-archive` | loop.md travels with the change directory; `.loop-state` is deleted; durable Lessons feed knowledge.md |

## Anti-patterns

- ❌ Editing `.loop-state` (model or human) — the driver owns it; fix problems in loop.md instead
- ❌ Checkboxes outside `## Acceptance` (corrupts the driver's progress counting)
- ❌ Checking an Acceptance item from self-review, without a verifier evidence anchor in that round's `#### Verify`
- ❌ Padding `#### Retrospect` with filler to satisfy the gate (the retrospect is the loop's steering input — garbage in, blind next round out)
- ❌ Re-running `$spec-loop` after a fuse stop without changing anything (same plan → same fuse; adjust the plan, the acceptance list, or max_rounds first)
- ❌ Two loops at once — in one project, or alongside another Stop-driven looper (e.g. ralph-loop): two drivers competing for the same Stop event have undefined merge semantics
