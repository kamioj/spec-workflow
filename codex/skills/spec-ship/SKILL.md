---
name: spec-ship
description: Closes one fix batch — ONE independent audit over the batch's accumulated diff (F-N entries are the claim anchors; the shipping conversation audits directly when it wrote none of the entries, a subagent only when it did), writes the audit into fix.md, and archives that batch dir on pass; on fail the batch stays in place with findings recorded. Gated by check-archive (no batch with entries blocks; archiving a fix dir without shipping blocks).
---
<!-- GENERATED from core/commands/ship.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-ship

Closes the current fix batch: one independent audit over everything accumulated since the
last ship, then archive. This is the fix tier's ONLY independent verification point — the
counterpart of the full flow's $spec-verify + $spec-archive, collapsed into one command.

## Pre-checks

- At least one open batch with an F-N entry must exist — a dated batch
  `spec/changes/fixes/<YYYY-MM-DD>/fix.md`, or the legacy flat `fixes/fix.md` (the
  check-archive hook blocks the invocation otherwise — there is nothing to audit).
- **Target selection**: the user named a batch date → that batch; otherwise the OLDEST open
  batch (oldest debt first); say which batch this ship run closes in the first line.
- fix.md already `status: shipped` but the dir still present (a previous ship's archive
  move failed) → report it and point to `$spec-archive`, which passes a shipped+Audit
  batch through its fix branch; ship itself audits open batches only.

## Flow

1. **Collect the batch**: read the target batch's fix.md; every F-N entry is in scope — the
   batch is the unit.
2. **ONE independent audit** — executor choice and the no-proposal audit contract per SKILL
   § Independent audit (batches are usually written across earlier sessions, so this
   conversation is usually the fresh reader). For a fix batch the claim list is the F-N
   entries — root cause plausible against the code, the described fix actually present,
   self-check evidence real — and the scope is the accumulated diff across the files the
   entries list; oversized entries are an observation to report, never a blocker (size is
   advisory at this tier).
3. **Findings** → triage and fix them in-session (same failure-triage table as $spec-apply),
   then write the audit results — commands + exit codes, findings + resolutions —
   into the batch's fix.md `## Audit`. Unresolvable now → leave the batch in place
   (`status: open`), report the findings, stop; ship again after fixing.
4. **Pass** → set `status: shipped`, then archive: move the batch dir to
   `spec/archive/<batch-date>-fixes/` (legacy flat batch → today's date). Target already
   exists → append a counter: `<batch-date>-fixes-2`, `-3`, … — overwriting an earlier
   batch would destroy its audit record. Other open batches stay in place untouched.
5. **Sediment knowledge**: a root-cause pattern that recurred across entries (or matches a
   prior batch) is worth one fact line — into its domain subdoc under `spec/knowledge/` with
   the index line maintained (format → references/knowledge-spec.md; never a flat fact line
   into the index), same correct-rather-than-contradict rule as $spec-archive.
6. **Report**: which batch, entries audited, findings fixed, archive path, and how many
   other open batches remain (information only — no urging). The next `$spec-fix` opens
   today's batch automatically.

## Deliberate override

`$spec-ship force` (or `abandoned`) passes the hook and archives as-is — say plainly in the
report that the batch was shipped WITHOUT a completed audit and why.

## What it does NOT do

- Does not run `git commit` / `git push` (only on user request)
- Does not promise per-entry diff attribution (whole-batch audit scope)
- Does not touch a fixes dir that has grown a proposal.md (precedence: proposal.md wins —
  that dir is a full change now; use $spec-verify + $spec-archive)
