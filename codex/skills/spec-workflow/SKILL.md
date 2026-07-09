---
name: spec-workflow
description: Full SDD workflow, end to end. Runs everything from research through archive automatically; MUST stop at interrogation points and MUST stop at HARD GATE. Also accepts the legacy $sdd entry point. Trigger words: spec first / proposal / design first / draft a plan.
---
<!-- GENERATED from core/commands/workflow.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-workflow

Task: $ARGUMENTS

## When to use

Large changes (>150 lines / touching 3+ files / introducing new dependencies / architectural decisions). Trivial / small / medium tasks should be handled directly — **NEVER activate this workflow for those**.

## Execution order

Invoke each phase command in the order below. **If any phase encounters user rejection or a placeholder scan / HARD GATE failure → stop and report; do not push through**.

1. **`$spec-research <direction>`** — survey industry practices + key constraints + flag `[TBD]` pending decisions
2. **`$spec-ask`** — work through each `[TBD]` one by one by presenting numbered options to the user; move answered items to `## Decided`
   - New [TBD]s may surface during this process; add them to the list and keep asking
3. **Decide whether `$spec-design` is needed** — trigger if any one applies:
   - **Cross-cutting frontend + backend** (touching both UI and server side, including interface contracts) ← design is **MANDATORY** here, not optional
   - More than 3 interfaces
   - Architecture diagram / data-flow diagram / sequence diagram needed
   - Deep decision argumentation exceeding 300 words
4. **`$spec-propose`** — write the four-section proposal.md
   - Before writing, the hook scans research.md for any remaining `[TBD]` placeholders
5. **HARD GATE** — output the fixed closing block "=== Proposal Ready ==="; wait for user confirmation
   - **Write zero code before confirmation**; if satisfied → go directly to `$spec-apply` (apply auto-appends APPROVED; no "reply go" step needed)
   - Rejected → use `$spec-revise [section]` (minor adjustments) or `$spec-chat` (rethink the direction)
6. **`$spec-apply`** — implement the code, advancing through proposal / tasks
   - The pre-command hook verifies the prerequisites (proposal.md with all four sections, single active change); apply itself then appends the APPROVED marker
7. **`$spec-verify`** — spawns the independent spec-verifier agent (three dimensions + charter audit, ledger round)
8. **Wait for the user to say "archive"** → `$spec-archive`

## Commands allowed to jump the queue mid-workflow

- `$spec-chat` — enter discussion mode; no documents are touched
- `$spec-ask` — run another interrogation round (for newly surfaced [TBD]s)
- `$spec-research <new direction>` — re-survey; existing artifacts are snapshotted, not deleted
- `$spec-status` — check which phase you are currently in

## Anti-Cheating principles

- Commands that have not actually been run / outputs that have not been verified MUST NOT be presented as successful
- A workaround that makes something "look like it passed" MUST be explicitly flagged as "bypassed; root cause unresolved"
- Hardcoded values (offsets / fixed hashes / one-off parameters) MUST be flagged in a code comment + a "applies to this case only" note in tasks.md
- Self-reported success from another agent or an earlier round is not verification — it gets independently re-run
- If the task's premise is wrong (contradictory requirements / out of scope / incompatible tooling) → stop immediately and report "task is not feasible"
