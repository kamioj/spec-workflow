---
description: Resumes a paused change — deletes its .paused marker (after checking the single-active-change slot is free) and reports where the work left off so re-entry is instant.
allowed-tools: Read, Glob, Bash(rm:*)
---
<!-- GENERATED from core/commands/resume.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:resume

Change name (optional, for disambiguation): $ARGUMENTS

## Process

1. **List paused changes**: dirs under `spec/changes/` carrying `.paused`. None → report "nothing paused". Multiple → ask which (or use $ARGUMENTS).
2. **Check the slot**: if another change is currently ACTIVE (not paused, not a light-tier fix/quick dir), refuse — resuming would create two active changes and the gates would block both. Suggest pausing or archiving the occupant first.
3. **Delete the marker** `spec/changes/<name>/.paused`.
4. **Report re-entry context** (read, don't recompute): the `.paused` line (when + why it was parked), proposal state (APPROVED or not), verify.md's latest round + open findings, unchecked tasks.md items if present — then the natural next command (`/spec:apply` to continue implementing, `/spec:verify` to re-audit, `/spec:archive` to close out).

## What it does NOT do

- Does not run any stage itself — it only unfreezes and orients; the user picks the next command
- Does not resurrect archived changes (archive is a different state; a returned-from-archive workflow is not supported — that is what pause exists to avoid)
