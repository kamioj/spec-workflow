---
description: Archives the current change to spec/archive/YYYY-MM-DD-<name>/. Only invoked when the user explicitly says "archive". Checks for uncommitted code before archiving.
allowed-tools: Read, Glob, Bash(mv:*, mkdir:*, git:*)
---

# /spec:archive

## Pre-flight checks

1. **git status check**:
   - Uncommitted changes present → warn the user and ask "commit first or archive first?"
   - User chooses "archive first" → proceed; "commit first" → exit and prompt the user to run `git commit`
2. **Verification status**:
   - Recommended: `/spec:verify` should be fully passing before archiving
   - Not passing → warn but do not block (the user may intentionally want to archive a failed proposal)

## Process

1. Read the current change name from `spec/changes/<name>/`
2. Compute the archive path: `spec/archive/<YYYY-MM-DD>-<name>/` (use today's date — it is already in context; no shell call needed)
3. `mv` the entire directory there
4. Output a summary:
   ```
   Archived: spec/archive/YYYY-MM-DD-<name>/
   Artifacts included: research.md, design.md, proposal.md, tasks.md
   ```

## Multi-owner scenario

- Only archive after all owner tasks are complete and all branches have been merged to the main trunk
- Any owner with incomplete tasks → refuse to archive; prompt "waiting for owner X to finish"

## Failed / abandoned archive

If the change is being abandoned (user says "this direction is wrong, drop it"):
- Archive path: `spec/archive/YYYY-MM-DD-<name>-abandoned/`
- Add `ABANDONED.md` inside with the reason for abandonment

## Anti-patterns

- ❌ Archiving without the user explicitly saying "archive"
- ❌ Defaulting to archive when git has uncommitted changes (risk of losing code)
- ❌ Archiving a failed proposal without a label (the archive directory must make it clear "this is a failed case")
