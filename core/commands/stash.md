---
description: Parks a change deliberately — writes a .paused marker (date + reason) so it stops counting as active and status shows it as set aside, with every artifact (ledger, index, proposal) staying warm for /spec:resume. Optional bookkeeping, not a switching ritual — switching lives in /spec:resume <name>. Refuses on a running /spec:loop change.
allowed-tools: Read, Write, Glob, Bash(date:*)
---

# /spec:stash

Reason (optional): $ARGUMENTS

Parks a change **deliberately, with a recorded reason** — the directory stays in place with every artifact intact; gates and the Stop reminder skip `.paused` dirs, and `/spec:status` lists it as set aside instead of active. Parking is bookkeeping, not a prerequisite for working on something else: active changes coexist freely, and switching between them is `/spec:resume <name>` (the current pointer). Park what you want visibly shelved; resume anytime — the ledger's V-N history, the index, and the proposal come back exactly as left.

Unlike `git stash`, this touches **no source code and no git state** — it only marks the spec change directory as set aside. Uncommitted code changes stay exactly where they are.

## Process

1. **Identify the target**: the current change (`spec/changes/.current`) when set; else the single active change; multiple without a pointer → ask which. None → report "nothing to stash".
2. **Refuse on a running loop**: if the target has `loop.md` with `status: running`, refuse — the Stop-driver is bounded by ledger state and ignores markers; stashing under it would desync the two. Finish or let the loop's fuses end it first.
3. **Write the marker** `spec/changes/<name>/.paused` (the marker filename is a hook contract — it stays `.paused`), one line:
   ```
   paused: <YYYY-MM-DD> | reason: <the user's stated reason, or "user request">
   ```
4. **Pointer upkeep**: the stashed change was the current pointer's target → delete `spec/changes/.current` (other actives remain → recommend the next `/spec:resume <name>` target per SKILL § Gate-aware next steps).
5. **Report**: `/spec:status` will show this change as parked with the date + reason; `/spec:resume <name>` brings it back; archiving a parked change directly (without resuming) stays legal.

## What it does NOT do

- Does not archive, commit, or touch any artifact other than creating `.paused`
- Does not stash /spec:loop changes (step 2)
- Does not stack: stashing an already-stashed change is a no-op (report it)
