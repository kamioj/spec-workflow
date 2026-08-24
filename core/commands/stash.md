---
description: Stashes (suspends) the active change — writes a .paused marker so the gates release the single-active-change slot while every artifact (ledger, index, proposal) stays warm for /spec:resume. Refuses on a running /spec:loop change.
allowed-tools: Read, Write, Glob, Bash(date:*)
---

# /spec:stash

Reason (optional): $ARGUMENTS

Frees the single-active-change slot **without** archiving: the change directory stays in place with every artifact intact; the three prompt gates and the Stop reminder simply skip dirs carrying a `.paused` marker. Resume anytime with `/spec:resume` — the ledger's V-N history, the index, and the proposal come back exactly as left.

Unlike `git stash`, this touches **no source code and no git state** — it only marks the spec change directory as set aside. Uncommitted code changes stay exactly where they are.

## Process

1. **Identify the target**: scan `spec/changes/*/` (minus `archive`, minus already-`.paused` dirs). Exactly one active change → that's the target. Multiple → ask which. None → report "nothing to stash".
2. **Refuse on a running loop**: if the target has `loop.md` with `status: running`, refuse — the Stop-driver is bounded by ledger state and ignores markers; stashing under it would desync the two. Finish or let the loop's fuses end it first.
3. **Write the marker** `spec/changes/<name>/.paused` (the marker filename is a hook contract — it stays `.paused`), one line:
   ```
   paused: <YYYY-MM-DD> | reason: <the user's stated reason, or "user request">
   ```
4. **Report**: the slot is free (new changes / fix entries can start); `/spec:status` will show this change as stashed with the date + reason; `/spec:resume` brings it back; archiving a stashed change directly (without resuming) stays legal.

## What it does NOT do

- Does not archive, commit, or touch any artifact other than creating `.paused`
- Does not stash /spec:loop changes (step 2)
- Does not stack: stashing an already-stashed change is a no-op (report it)
