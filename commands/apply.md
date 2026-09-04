---
description: Implement the code, advancing by proposal/tasks. A pre-command hook checks that proposal.md carries the APPROVED marker. Verification model: cheap self-run working checks per node while implementing; ONE independent spec-verifier pass at the end (never dispatch verification subagents mid-implementation)
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---
<!-- GENERATED from core/commands/apply.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:apply

## Pre-check + auto-approval

1. **Check proposal.md exists**:
   - Doesn't exist → error, tell the user to run `/spec:propose` first
   - Exists but missing a section (any of Why / What / How / Risk) → error, tell the user to run `/spec:revise` to complete it first

2. **Auto-append the APPROVED marker** (treating the user's deliberate `/spec:apply` invocation as the act of approval):
   - proposal.md has **no** `<!-- APPROVED: ... -->` marker at the end → append immediately:
     ```markdown
     <!-- APPROVED: YYYY-MM-DD HH:mm -->
     ```
     Timestamp uses the current ISO local time
   - Already has an APPROVED marker (from the `/spec:workflow` flow or a previous apply) → don't append again

3. **Hook check**: `check-gate.sh` fires at the `UserPromptSubmit` moment — BEFORE this command runs — so it deliberately checks **prerequisites only** (proposal.md exists with all four sections, single active change) and never the APPROVED marker: this command appends the marker afterwards, so requiring it in the hook would deadlock the happy path. The marker is enforced later — `check-archive.sh` audits it at archive time.

   If the hook blocks (no/incomplete proposal, multiple active changes) → handle per its error message, don't force a bypass.

4. **Escalated echo**: if research.md `## Decided` contains `escalated`-marked entries, the **first line of this command's output** restates them — `Implementing with <N> escalated decisions: <one line each>` — before any implementation work. This is the second informed-consent point (the gate pinned them on top; apply echoes them once more) at zero interaction cost: the flow never pauses, but an irreversible call can no longer slip through unread. No escalated entries → no echo line.

## Scoping

Read proposal.md's `## What`:
- **No tasks.md** → advance fully by the proposal
- **tasks.md, single executor** → advance in tasks order
- **tasks.md, multi-executor** → do only this owner's tasks (checkout `feat/<name>-<owner>` first)

## Dispatch the dev agent

Dispatch by the type of code the proposal `## What` involves:

| What involves | Dispatch |
|---|---|
| UI / routing / components / styling / client-side interaction | `spec-dev` (scope: frontend) |
| server-side logic / API / data models / DB migration / middleware | `spec-dev` (scope: backend) |
| **Cross-stack (including interface-contract changes)** | **Pin the contract first → dispatch two `spec-dev` concurrently (one frontend, one backend)** (see below) |
| config / scripts / CI / docs | main conversation handles it |


**Dispatching `spec-dev` MUST state the scope in the dispatch prompt** (`scope: frontend` / `scope: backend` / `scope: fullstack`) — this is what the agent uses to decide which stack references to read and which design sections to read. Omitting it = the agent can only infer the scope from the file types being changed, which is a suboptimal path.

**The dispatch prompt MUST also carry proposal What's `Not in this change` list verbatim** (the do-not-touch scope), **and state whether `spec/changes/<name>/index.md` exists** (legacy change without one → tell the agent to proceed per proposal and declare the absence in its summary). An agent whose task seems to require touching excluded scope stops and reports — widening scope is a user decision (`/spec:revise what`), never the agent's.

### Cross-stack: contract first + parallel implementation

**The serial approach is forbidden** (backend then frontend = 50% of the time wasted). The correct flow:

1. **Pre-check**: design.md's `## Interfaces` section must already spell out:
   - endpoint / method / path
   - input schema
   - output schema
   - error codes + error response structure

   If missing, **refuse to dispatch** and go through `/spec:design` to pin the contract first.

2. **Concurrent dispatch** (issue two Agent calls in one message):
   - `spec-dev` (scope: backend): implement the server side, returning contract-compliant mock data first, then wiring the real data source
   - `spec-dev` (scope: frontend): implement the client skeleton, wiring the contract with mock data / TypeScript types

   The two agents **do not wait on each other**, each advancing by design.md `## Interfaces`.

3. **Integration phase** (after both agents report "implementation done"):
   - backend switches to real data
   - frontend switches to the real interface
   - end-to-end test

**The contract = a high-fan-out node**: tasks.md should make it explicit:

```
- [ ] 1. Interface contract (landed in design.md ## Interfaces)
- [ ] 2. Backend implementation   owner: backend   deps: 1
- [ ] 3. Frontend skeleton (mock) owner: frontend  deps: 1
- [ ] 4. Wire up the real interface                deps: 2, 3
```

Steps 2 and 3 **don't depend on each other** (both depend only on step 1), so they run in parallel.

### What the dev agent gives you

The agent automatically loads the corresponding tech-stack references by scope (vue-style / java-conventions, etc.) + inherits the sdd plugin's Shared Principles (Anti-Cheating / Stuck Protection / halt on infeasible task).

### Optional flags: principles reinforcement

`/spec:apply` supports two flags, space-separated, combinable, omittable.

| flag | Turns on | Effect |
|---|---|---|
| `design` | anti-AI-slop | `spec-dev` (frontend scope) reads `skills/core/references/frontend-aesthetics.md` |
| `strict` | anti-laziness + anti-hallucination | the agent reads `skills/core/references/agent-principles.md` § 1 + § 2 |

**$ARGUMENTS parsing**: split on spaces, and for each token check whether it's in the `{design, strict}` set. Matched ones turn into "turn on anti-X" instructions in the dispatch prompt; unmatched tokens are flagged to the user as possible typos.

**Usage examples**:

| Command | Behavior |
|---|---|
| `/spec:apply` | default, lean implementation |
| `/spec:apply design` | the frontend agent loads anti-AI-slop |
| `/spec:apply strict` | anti-laziness + anti-hallucination |
| `/spec:apply design strict` | both on |

**No flag by default** — to avoid over-caution on routine tool-type UIs / internal pages / backend services.

The main conversation only steps in when dispatch fails / cross-executor coordination is needed / an agent reports it's stuck.

## Concern adjudication (consumes the summaries' Concerns fields)

Dev agents implement permissively and reroute every tightening impulse into their summary's `Concerns` field (spec-dev § Concerns discipline). After the last agent returns, adjudicate by invocation mode:

- **Standalone `/spec:apply`**: batch ALL concerns into ONE interrogation round (multi-select, asked per SKILL Interrogation rules; each option self-contained — proposed tightening + trigger + cost of adopting). Adopted → append each as a **new R-N** to `spec/changes/<name>/index.md` and implement it in-session, **before** the closing verification, so the closing verifier round audits base change + adopted tightenings uniformly (concerns never seed V-N rows before a round exists). Rejected → one ledger note each (`concern rejected: <one line>`) so the same worry isn't re-litigated later.
- **Inside `/spec:workflow`** (two-touchpoint doctrine — no mid-flight pause): carry the Concerns list verbatim into the acceptance report (touchpoint 2); adopted ones enter the ledger via the acceptance-stage user-sourced-findings path and drive the scoped fix round.
- No concerns returned → skip entirely, zero ceremony.
- A **blocking** concern (the agent stopped: no permissive fallback exists) is not batch material — it already halted implementation; resolve it immediately (an immediate interrogation per SKILL rules when standalone; in workflow mode it surfaces as the reason apply stopped).

## Implementation + verification model

**Independent verification is a terminal event, not a rhythm.** While implementing, the only checks are your OWN working checks (seconds-cheap, self-run); the ONE subagent-backed independent verification happens after the last item lands. Never dispatch a verifier / fresh-context subagent mid-implementation — a verify-edit-verify-edit cadence spends the budget on re-reading context instead of building (measured in real runs: it dominates the bill).

- Advance by deps, touching only tasks whose deps are done
- Multiple deps satisfied and independent → **prefer dispatching two dedicated agents concurrently** (if frontend and backend are independent)
- After finishing each node (or a group of parallel ones) → run that node's own checks close by (compile / tests for the node), **don't save them for the end**. These are working checks — self-run, seconds-cheap, they do NOT write ledger rounds and they NEVER involve a subagent
- **Closing verification is part of apply, not optional**: after the last What item / task lands, **dispatch the `spec-verifier` agent** (the same fresh-context, evidence-or-drop protocol `/spec:verify` uses — the conversation that just implemented MUST NOT write the closing round from its own self-review, that is exactly the bias the verifier exists to remove) and write its results as a ledger round to `spec/changes/<name>/verify.md` **before reporting implementation complete** — "done" without an independent ledger round covering the final state is not done. The Stop-event reminder hook (`check-verify-reminder.sh`) backstops this: ending a turn with an approved proposal and no ledger gets nudged back.
- Mark finished tasks `[x]` in tasks.md — **whoever finishes it marks it**: the dev agent marks the subtasks it owns; the main conversation marks the items it handles itself (config / scripts / cross-module coordination)

## Failure triage

A verify failure → diagnose first, then fix, handling by category:

| Symptom | Category | Handling |
|---|---|---|
| Didn't implement to the proposal's requirement | Implementation incomplete | keep applying |
| Syntax / type / boundary error | Single-point bug | fix it directly |
| Did something the proposal didn't ask for | Drift | go back to the proposal and re-align |
| Followed the proposal exactly and it's still wrong | Proposal is wrong | stop and go through `/spec:revise` (ask probably missed this point) |

**NEVER silently edit the proposal to fit the code already written** — the proposal is the truth of "what should be done".

## Stuck Protection

Same error / case, **3 consecutive** fix attempts still failing → stop immediately and report.

One attempt = new hypothesis + code change + verification; re-running the same code / fixing a typo / tweaking logging **doesn't count**. From the second attempt on, the hypothesis must also state **why the previous attempt failed** — a retry without a root-cause reading of the last failure is a blind retry, and doesn't count.

**Type the blocker before burning attempts**: if what actually blocks is a **decision** (preference / scope / authorization) rather than missing knowledge, stop right there — neither research nor a retry can answer a preference question.

**The third shot must be evidence-backed.** Two failures mean the working mental model is suspect; the third attempt MUST be grounded in retrieved evidence — framework source, official docs, community reports of the same failure — never a third guess. Research is read-only and cannot break anything, while a third blind patch can (and its damage is often silent). No research channel reachable from the current context → skip the third attempt and go straight to the self-check.

```
=== Stuck Self-Check ===
Symptom: <one line>
Blocker type: knowledge (how does X actually work) | decision (preference / scope / authorization)
Three hypotheses tried:
  1. <hypothesis> → <result>
  2. <hypothesis, why #1 failed> → <result>
  3. <evidence-backed hypothesis + source> → <result>   (or "skipped: no research channel")
Research findings: <what source / docs / community say about this failure, or "none retrievable">
Inferred root cause: <write it if you can infer one, otherwise "unknown">
Default next direction: <ONE direction stated as the decision to run with next round; "awaiting user guidance" only when genuinely none exists>
```

Close the report in **statement mode**: the default direction plus one "overridable" line — never a multiple-choice menu (an option that is already a fait accompli, or one that was never authorized, must not be posed as a question). Then wait for the user's decision; **no endless patching**.

## Anti-Cheating

- A command / test that hasn't actually run **MUST NOT be reported as "success"** — success claims carry evidence (command + exit code / key output), same contract as /spec:verify's Evidence block
- A workaround that makes it "look like it passes" (mocking a fake response, changing an assert, patching a check function to return true) **MUST be stated plainly** as "bypass, root cause unresolved"
- Hardcoding (offsets, fixed hashes) if necessary MUST be flagged in a code comment + a "applies to this case only" note in tasks.md

## Coding Charter (binding on everyone who writes code in this phase)

The dev agent reads `code-charter.md` on startup; **the main conversation, when it writes code itself (config / scripts / CI), is equally bound** — before the first keystroke, Read `${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md`. The core: failure must be loud (throw when you should, **NEVER silently re-route a query to scrape a result**), **changing logic is replacement, not accumulation** (NEVER keep the old logic as a fallback — the number-one source of dirty data + instability), fail-fast for core logic, degrade only at a trust boundary and always loudly, and **comments state function, not process** (process markers carry the `DEVLOG:` tag and are swept to zero before wrap-up). **Applies to the coding phase only** — it does not constrain the solution-space exploration of research/design/propose. A fallback / degrade / compat path is a **gate-level decision**: if proposal How/Risk doesn't authorize it, don't write it — `/spec:verify`'s charter audit treats unauthorized ones as findings (critical on data-write paths).

## What it does not do

- Doesn't run `git commit` / `git push` (only on user request)
- Doesn't archive (only when the user says "archive", via `/spec:archive`)
- Doesn't edit the proposal to fit the code (it should be the reverse: change the code to match the proposal, or `/spec:revise` the proposal)
