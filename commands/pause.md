---
description: Suspends the active change — writes a .paused marker so the gates release the single-active-change slot while every artifact (ledger, index, proposal) stays warm for /spec:resume. Refuses on a running /spec:loop change.
allowed-tools: Read, Write, Glob, Bash(date:*)
---
<!-- GENERATED from core/commands/pause.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:pause

Reason (optional): $ARGUMENTS

Frees the single-active-change slot **without** archiving: the change directory stays in place with every artifact intact; the three prompt gates and the Stop reminder simply skip dirs carrying a `.paused` marker. Resume anytime with `/spec:resume` — the ledger's V-N history, the index, and the proposal come back exactly as left.

## Process

1. **Identify the target**: scan `spec/changes/*/` (minus `archive`, minus already-`.paused` dirs). Exactly one active change → that's the target. Multiple → ask which. None → report "nothing to pause".
2. **Refuse on a running loop**: if the target has `loop.md` with `status: running`, refuse — the Stop-driver is bounded by ledger state and ignores markers; pausing under it would desync the two. Finish or let the loop's fuses end it first.
3. **Write the marker** `spec/changes/<name>/.paused`, one line:
   ```
   paused: <YYYY-MM-DD> | reason: <the user's stated reason, or "user request">
   ```
4. **Report**: the slot is free (new changes / quick changes can start); `/spec:status` will show this change as paused with the date + reason; `/spec:resume` brings it back; archiving a paused change directly (without resuming) stays legal.

## What it does NOT do

- Does not archive, commit, or touch any artifact other than creating `.paused`
- Does not pause /spec:loop changes (step 2)
- Does not stack: pausing an already-paused change is a no-op (report it)
