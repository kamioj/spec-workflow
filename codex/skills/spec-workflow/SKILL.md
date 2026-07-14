---
name: spec-workflow
description: Full SDD workflow, end to end, requirement fully delegated. Open decisions are digested internally (auto triage — no mid-flight questions); MUST stop at exactly two points — the HARD GATE and acceptance/archive. The user participates as an evaluator; evaluation rounds are unlimited. Also accepts the legacy $sdd entry point. Trigger words: spec first / proposal / design first / draft a plan.
---
<!-- GENERATED from core/commands/workflow.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-workflow

Task: $ARGUMENTS

## When to use

Large changes (>150 lines / touching 3+ files / introducing new dependencies / architectural decisions). Trivial / small / medium tasks should be handled directly — **NEVER activate this workflow for those**.

## Execution order

Invoke each phase command in the order below. **If any phase encounters user rejection or a placeholder scan / HARD GATE failure → stop and report; do not push through**.

1. **`$spec-research <direction>`** — survey industry practices + key constraints + flag `[TBD]` pending decisions
2. **`$spec-ask` in auto-triage mode** — do NOT interrogate the user; triage every `[TBD]` into `## Decided` per ask.md § Auto triage: factual → evidence; reversible preference → decide + `auto` mark; irreversible / product-semantics → decide + `escalated` mark (surfaced at the gate, standing unless overturned). Every self-decision passes the four-question filter; "don't do it / minimal" is always a candidate
   - New [TBD]s surfacing later in the flow are triaged the same way, never asked mid-flight
3. **Decide whether `$spec-design` is needed** — trigger if any one applies:
   - **Cross-cutting frontend + backend** (touching both UI and server side, including interface contracts) ← design is **MANDATORY** here, not optional
   - More than 3 interfaces
   - Architecture diagram / data-flow diagram / sequence diagram needed
   - Deep decision argumentation exceeding 300 words
4. **`$spec-propose`** — write the four-section proposal.md, then **run the critique panel** (propose.md § Critique panel: necessity chief lens + regression-compat + testability, +security/+performance by content; one refutation round; findings → ledger round 0)
   - Before writing, the hook scans research.md for any remaining `[TBD]` placeholders
5. **HARD GATE — touchpoint 1 of 2** — output the fixed closing block; escalated decisions pinned on top; wait
   - **Write zero code before the user's next command**; satisfied (or silent on the flagged decisions) → `$spec-apply` (apply auto-appends APPROVED; no "reply go" step)
   - The user's reply is an **evaluation**: respond per item adopt / refute (with reason) / partial — one response round, user has final say — then `$spec-revise` → re-emit the gate. **This evaluation loop has no round limit**; it converges on the user's satisfaction, not on a counter
6. **`$spec-apply`** — implement the code, advancing through proposal / tasks
   - The pre-command hook verifies the prerequisites (proposal.md with all four sections, single active change); apply itself then appends the APPROVED marker and **echoes the escalated decisions in its first line**
7. **`$spec-verify`** — spawns the independent spec-verifier agent (three dimensions + charter audit, ledger round)
   - Findings → fix → re-verify runs automatically, **at most 2 auto-fix rounds** (aligned with the ledger's "open 2+ rounds forces fail" escalation); still-open items are NOT ground down further — they lead the acceptance report
8. **Acceptance — touchpoint 2 of 2** — report the result (open ledger items first, escalated decisions restated), then wait
   - The user's acceptance feedback is an evaluation: respond per item adopt / refute / partial, then record accepted items as **user-sourced findings** in the ledger (stable V-N) and run a fix round → re-verify. **No round limit** — the loop ends when the user says "archive" → `$spec-archive`

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
