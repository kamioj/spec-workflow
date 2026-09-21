---
name: spec-archive
description: Archives the current change to spec/archive/YYYY-MM-DD-<name>/. Only invoked when the user explicitly says "archive". Writes an archive-stage retrospect, checks for uncommitted code, and is guarded by the check-archive hook.
---
<!-- GENERATED from core/commands/archive.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-archive

## Pre-flight checks

0. **Hook layer**: `codex/hooks/check-archive` has already screened this invocation — it blocks (outputs `{"decision":"block"}` to stdout) when the change bypassed the flow: proposal.md without the APPROVED marker / tasks.md with unchecked items / no proposal.md at all. Deliberate override: the user says `force` (archive as-is) or `abandoned` (drop the direction). When an override passed through, the reason **MUST be recorded in retrospect.md** (Process step 2).
1. **git status check**:
   - Uncommitted changes present → warn the user and ask "commit first or archive first?"
   - User chooses "archive first" → proceed; "commit first" → exit and prompt the user to run `git commit`
2. **Verification status**: read `spec/changes/<name>/verify.md` (the verification ledger) — latest round's `conclusion` + open findings
   - Recommended: `conclusion: pass` with zero open critical/major findings before archiving
   - Not passing / no ledger → warn but do not block (the user may intentionally want to archive a failed proposal)
   - **`pending live check` lines never count against archiving** — they are the live-acceptance handover (the machine-verifiable set is green; the live set is the user's own acceptance run, and failures there return through $spec-fix). List them in the archive summary so the user carries the list forward, and proceed

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

   ## Auto-decision calibration
   Only for changes that carried auto/escalated decisions (workflow auto triage): how many
   held up vs. were overturned (at the gate or later). Each misjudgment gets one line —
   the pattern, not the instance — and is synced into the knowledge base (step 3): that is
   the only channel through which the triage rules learn this project. All held → "all held".

   ## Force / abandon note
   Only when archived via force/abandoned: one line on why.
   ```

   Why the divergence review earns its cost: "docs say A, code does B" is precisely the defect class that implementation and verify most often both miss — the archive review is the last set of eyes on it.
3. **Sediment the knowledge base** (`spec/knowledge.md` index + `spec/knowledge/` subdocs — format authority: `references/knowledge-spec.md`; lives OUTSIDE the change dir so it survives archiving; create on first use):
   - Extract from this change the durable facts future changes will need: topology / table ownership, verified mechanisms, hard-won gotchas; durable A-N assets and E-N exemplar designations from `index.md` sediment too (the next change's research reads them instead of re-surveying); a `$spec-loop` change's `loop.md ## Lessons` is a primary input — read it before the move. Change-specific R-N quotes stay in the archived change
   - **Route by kind into subdocs, never into the index**: each fact lands as a `- <fact> | evidence: <source> | <date> (<change>)` line in its domain file under `spec/knowledge/` (create on demand), or as a long-form experience doc (frontmatter `status: current`); then maintain the file's index line in knowledge.md (`- [kind/domain] file — hook`). A flat fact line written into the index re-flags it legacy — the one way to break the architecture
   - **Lazy migration**: knowledge.md still in legacy flat format (contains `^- ` lines with `| evidence:`) → restructure it in this same pass (facts into domain subdocs, index written, nothing dropped)
   - **Consolidation pass** (when triggered: index > 40 lines / a domain file > 60 lines / writing next to a same-topic entry): merge duplicates, compress wording, newer evidence+date on the same topic overrides the stale fact, long-form docs get `status: superseded by <new>` (kept, never deleted)
   - **Correct, don't contradict**: a recorded fact this change proved wrong is replaced (correction noted), never left standing next to its refutation
   - Nothing durable to record → skip, never pad
4. Compute the archive path: `spec/archive/<YYYY-MM-DD>-<name>/` (use today's date — it is already in context; no shell call needed)
5. If the change was a `$spec-loop` run: delete `.loop-state` (the driver's machine state — dead weight once archived; loop.md itself travels with the directory; its Lessons were already consumed by step 3)
6. `mv` the entire directory there
7. **Pointer upkeep**: `spec/changes/.current` points at the archived change → delete the pointer; other active changes remain → list them per SKILL § Gate-aware next steps and recommend the next `$spec-resume <name>` target (a dangling pointer is harmless — gates fall back — but the recommendation saves the bounce)
8. Output a summary:
   ```
   Archived: spec/archive/YYYY-MM-DD-<name>/
   Artifacts included: research.md, research/ (if present), index.md, design.md, proposal.md, tasks.md, verify.md, loop.md (if present), retrospect.md
   Retrospect: divergences <N / none> · evidence <attached / not verified> · deferred <M items / none>
   Knowledge: <K facts sedimented/corrected (which subdocs) / nothing durable>
   ```

## Multi-owner scenario

- Only archive after all owner tasks are complete and all branches have been merged to the main trunk
- Any owner with incomplete tasks → refuse to archive; prompt "waiting for owner X to finish"

## Failed / abandoned archive

If the change is being abandoned (user says "this direction is wrong, drop it" / `$spec-archive abandoned`):
- Archive path: `spec/archive/YYYY-MM-DD-<name>-abandoned/`
- Add `ABANDONED.md` inside with the reason for abandonment
- retrospect.md is still written (its Force / abandon note points at ABANDONED.md)

## Anti-patterns

- ❌ Archiving without the user explicitly saying "archive"
- ❌ Defaulting to archive when git has uncommitted changes (risk of losing code)
- ❌ Archiving a failed proposal without a label (the archive directory must make it clear "this is a failed case")
- ❌ Archiving an unapproved proposal / unchecked tasks silently — the hook blocks it; going through `force` requires retrospect.md to record why
- ❌ Writing the retrospect as a solution recap — it is an audit: divergences + evidence + leftovers only
