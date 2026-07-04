---
description: Archives the current change to spec/archive/YYYY-MM-DD-<name>/. Only invoked when the user explicitly says "archive". Writes an archive-stage retrospect, checks for uncommitted code, and is guarded by the check-archive hook.
allowed-tools: Read, Glob, Grep, Write, Bash(mv:*, mkdir:*, git:*)
---

# /spec:archive

## Pre-flight checks

0. **Hook layer**: `check-archive.ps1` has already screened this invocation — it blocks (`exit 2`) when the change bypassed the flow: proposal.md without the APPROVED marker / tasks.md with unchecked items / no proposal.md at all. Deliberate override: the user says `force` (archive as-is) or `abandoned` (drop the direction). When an override passed through, the reason **MUST be recorded in retrospect.md** (Process step 2).
1. **git status check**:
   - Uncommitted changes present → warn the user and ask "commit first or archive first?"
   - User chooses "archive first" → proceed; "commit first" → exit and prompt the user to run `git commit`
2. **Verification status**: read `spec/changes/<name>/verify.md` (the verification ledger) — latest round's `conclusion` + open findings
   - Recommended: `conclusion: pass` with zero open critical/major findings before archiving
   - Not passing / no ledger → warn but do not block (the user may intentionally want to archive a failed proposal)

## Process

1. Read the current change name from `spec/changes/<name>/`
2. **Write `spec/changes/<name>/retrospect.md`** — the archive-stage audit (≤40 lines, plain language; an audit record, never a second proposal):

   ```markdown
   ---
   change: <change-name>
   archived_at: <YYYY-MM-DD>
   divergences: <N>
   evidence: attached | not-verified
   deferred: <N>
   override: none | force | abandoned
   ---

   # Retrospect: <change-name>

   ## Divergence review
   Re-read proposal ## What / ## How + design key decisions, spot-check the implementation.
   Every "docs say A, code does B" found, one line each with file:line — or "none found".

   ## Evidence
   Copy the latest round's Evidence lines from verify.md, the verification ledger (commands + results).
   verify never ran → write "not verified" plainly. Never omit this section.

   ## Unfinished / deferred
   Unchecked tasks.md items, one line each on why deferred — or "all done".

   ## Force / abandon note
   Only when archived via force/abandoned: one line on why.
   ```

   Why the divergence review earns its cost: "docs say A, code does B" is precisely the defect class that implementation and verify most often both miss — the archive review is the last set of eyes on it.
3. **Maintain `spec/knowledge.md`** (project-level, lives OUTSIDE the change dir so it survives archiving; create on first use):
   - Extract from this change the durable facts future changes will need: topology / table ownership ("ICMP and mallcoo share one physical DB"), verified mechanisms, hard-won gotchas
   - One line per fact: `<fact> | evidence: <source> | <YYYY-MM-DD> (<change-name>)`
   - **Correct, don't contradict**: a recorded fact this change proved wrong is replaced (correction noted), never left standing next to its refutation
   - Change-specific details stay in the change's artifacts; nothing durable to record → skip, never pad
4. Compute the archive path: `spec/archive/<YYYY-MM-DD>-<name>/` (use today's date — it is already in context; no shell call needed)
5. `mv` the entire directory there
6. Output a summary:
   ```
   Archived: spec/archive/YYYY-MM-DD-<name>/
   Artifacts included: research.md, research/ (if present), design.md, proposal.md, tasks.md, verify.md, retrospect.md
   Retrospect: divergences <N / none> · evidence <attached / not verified> · deferred <M items / none>
   Knowledge: <K facts added/corrected in spec/knowledge.md / nothing durable>
   ```

## Multi-owner scenario

- Only archive after all owner tasks are complete and all branches have been merged to the main trunk
- Any owner with incomplete tasks → refuse to archive; prompt "waiting for owner X to finish"

## Failed / abandoned archive

If the change is being abandoned (user says "this direction is wrong, drop it" / `/spec:archive abandoned`):
- Archive path: `spec/archive/YYYY-MM-DD-<name>-abandoned/`
- Add `ABANDONED.md` inside with the reason for abandonment
- retrospect.md is still written (its Force / abandon note points at ABANDONED.md)

## Anti-patterns

- ❌ Archiving without the user explicitly saying "archive"
- ❌ Defaulting to archive when git has uncommitted changes (risk of losing code)
- ❌ Archiving a failed proposal without a label (the archive directory must make it clear "this is a failed case")
- ❌ Archiving an unapproved proposal / unchecked tasks silently — the hook blocks it; going through `force` requires retrospect.md to record why
- ❌ Writing the retrospect as a solution recap — it is an audit: divergences + evidence + leftovers only
