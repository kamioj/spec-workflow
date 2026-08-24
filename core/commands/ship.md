---
description: Closes the fix batch — dispatches ONE spec-verifier over the batch's accumulated diff (F-N entries are the claim anchors), writes the audit into fix.md, and archives spec/changes/fixes/ on pass; on fail the batch stays in place with findings recorded. Gated by check-archive (empty batch blocks; archiving a fix dir without shipping blocks).
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

# /spec:ship

Closes the current fix batch: one independent audit over everything accumulated since the
last ship, then archive. This is the fix tier's ONLY independent verification point — the
counterpart of the full flow's /spec:verify + /spec:archive, collapsed into one command.

## Pre-checks

- `spec/changes/fixes/fix.md` must exist with at least one F-N entry (the check-archive
  hook blocks the invocation otherwise — there is nothing to audit).
- fix.md already `status: shipped` but the dir still present (a previous ship's archive
  move failed) → skip the audit, redo the archive move only.

## Flow

1. **Collect the batch**: read fix.md; every F-N entry is in scope — the batch is the unit.
2. **Dispatch ONE `spec-verifier`** (fresh context — the conversations that implemented the
   entries never audit themselves). Tell it:
   - this is a fix batch: audit the **accumulated diff as a whole** across the files the
     entries list (per-entry diff attribution is NOT expected — successive uncommitted
     edits to one file are indistinguishable);
   - the F-N entries are the claims to check: root cause plausible against the code, the
     described fix actually present, self-check evidence real (**re-run the key commands** —
     self-reported success is a claim, Iron Law applies);
   - run the charter machine pass (ast-grep rule pack; declare `not run` gracefully when
     absent);
   - unsourced behavioral additions beyond the entries' asks = findings; oversized entries
     are an observation to report, never a blocker (size is advisory at this tier).
3. **Findings** → triage and fix them in-session (same failure-triage table as /spec:apply),
   then have the verifier's results — commands + exit codes, findings + resolutions —
   written into fix.md `## Audit`. Unresolvable now → leave the batch in place
   (`status: open`), report the findings, stop; ship again after fixing.
4. **Pass** → set `status: shipped`, then archive: move `spec/changes/fixes/` to
   `spec/archive/<YYYY-MM-DD>-fixes/`. Target already exists (second ship the same day) →
   append a counter: `<YYYY-MM-DD>-fixes-2`, `-3`, … — never overwrite an earlier batch.
5. **Sediment knowledge**: a root-cause pattern that recurred across entries (or matches a
   prior batch) is worth one line in `spec/knowledge.md` — same rule as /spec:archive,
   correct rather than contradict.
6. **Report**: entries audited, findings fixed, archive path. The next `/spec:fix`
   recreates a fresh batch automatically.

## Deliberate override

`/spec:ship force` (or `abandoned`) passes the hook and archives as-is — say plainly in the
report that the batch was shipped WITHOUT a completed audit and why.

## What it does NOT do

- Does not run `git commit` / `git push` (only on user request)
- Does not promise per-entry diff attribution (whole-batch audit scope)
- Does not touch a fixes dir that has grown a proposal.md (precedence: proposal.md wins —
  that dir is a full change now; use /spec:verify + /spec:archive)
