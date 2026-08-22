---
description: Light-tier flow for small changes (user-explicit only, never model-initiated). Keeps the quote anchor + one diff-scoped independent verification + an archivable record; drops research/proposal/gate ceremony. Refuses full-flow-sized work upfront.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---
<!-- GENERATED from core/commands/quick.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:quick

Task: $ARGUMENTS

The middle tier between full ceremony and bare work. Three invariants survive at every tier — a verbatim quote anchor, ONE independent verification, honest evidence; everything else is dropped.

## Size self-check (before ANY work — hard stop)

Estimate the change first. Any of: **>150 lines / 3+ files / new dependency / architecture choice / preference forks that need user decisions** → REFUSE: report "this is full-flow sized" and point to `/spec:research` (if another change holds the active slot, suggest `/spec:pause` first). Never grind big work through the light tier — the closing verifier flags an oversized quick diff as a "should have been a full change" finding, so it gets flagged either way; refusing upfront is cheaper.

## Flow

1. Create `spec/changes/<kebab-name>/quick.md` (format → [`skills/core/references/quick-spec.md`](../skills/core/references/quick-spec.md)): `status: in-flight`, `## Ask` = one-line restatement + the user's words **quoted verbatim** (the mini anchor — interpretation happens against the quote)
2. Implement directly. The Coding Charter binds (Read `${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md` before the first keystroke — same rule as /spec:apply); the Concerns discipline binds (requirement silent → most permissive behavior; tightening impulses go to `## Concerns`, never into code; a blocking structural decision → stop and ask immediately)
3. **Closing verification — mandatory, never self-certified**: dispatch ONE `spec-verifier` scoped to this diff. Tell it: this is a quick change — audit the diff against quick.md's `## Ask` quote (unsourced behavioral additions = findings), run the charter machine pass, and **size-audit**: a diff exceeding small-change bounds is itself a finding
4. Fix findings, write the verifier's output into `## Evidence` (commands + exit codes; findings + resolution), set `status: done`
5. Archive on the user's word, via normal `/spec:archive` (the check-archive quick branch audits `status: done` + non-empty Evidence)

## Growing into a full change (upgrade path)

Mid-quick you discover it's bigger than estimated → stop, report, and run `/spec:research` **in the same dir**. proposal.md's presence flips the dir to full-change semantics everywhere (gates, archive audit, status — the precedence rule); quick.md stays as inert history. **Never delete quick.md.**

## Coexistence

A quick change may run alongside an active or paused full change — gates exclude quick dirs (quick.md present, proposal.md absent) from the active-change count. The reminder and TBD/gate hooks keep protecting the full change; quick itself is ungated by design (its protection is the mandatory closing verification).

## Anti-patterns

- ❌ Model-initiated quick — user-explicit only; size signals warrant at most a one-line suggestion (same activation doctrine as the full flow)
- ❌ Skipping the verifier dispatch or writing Evidence from self-review (a quick with self-certified Evidence is not done)
- ❌ Routing full-flow-sized work through quick (refuse upfront)
- ❌ Paraphrasing the ask in `## Ask` (quote, never paraphrase)
- ❌ Deleting quick.md when upgrading to the full flow
