---
description: Switches the current change (writes the spec/changes/.current pointer) and, when the target is paused, deletes its .paused marker — then reports where the work left off so re-entry is instant. The switcher for parallel changes; no argument lists what there is to switch to.
allowed-tools: Read, Glob, Write, Bash(rm:*)
---

# /spec:resume

Target change name (optional): $ARGUMENTS

## Process

1. **No argument** → list the switchable changes: active dirs (with the current one marked) and paused dirs (with their paused-line), then ask which — per SKILL Interrogation rules, each option carrying its state (stage / open findings / archive candidate).
2. **Named target**:
   - Paused → delete `spec/changes/<name>/.paused`
   - Active → nothing to unfreeze; this is a pure switch
   - Nonexistent → report, list what exists (never guess a near-match silently)
3. **Write the pointer**: `spec/changes/.current` ← the target name (one line). This is the switch — gates and the Stop reminder now target this change; other active changes coexist untouched (no stash ritual required).
4. **Report re-entry context** (read, don't recompute): proposal state (APPROVED or not), verify.md's latest round + open findings, unchecked tasks.md items, the paused line if it was parked — then the natural next command (`/spec:apply` to continue, `/spec:verify` to re-audit, `/spec:archive` to close out).

## What it does NOT do

- Does not run any stage itself — it only switches and orients; the user picks the next command
- Does not resurrect archived changes (archive is a different state; parking is what `.paused` exists for)
- Does not touch the other changes' artifacts or markers
