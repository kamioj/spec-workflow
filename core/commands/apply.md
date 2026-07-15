---
<!-- host:claude -->
description: Implement the code, advancing by proposal/tasks. A pre-command hook checks that proposal.md carries the APPROVED marker. Incremental verification: call /spec:verify close to each node as it lands, don't save it all for the end
<!-- /host -->
<!-- host:codex -->
description: Implement the code, advancing by proposal/tasks. A pre-command hook checks that proposal.md carries the required prerequisites. Incremental verification: call /spec:verify close to each node as it lands, don't save it all for the end.
<!-- /host -->
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

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

<!-- host:claude -->
3. **Hook check**: `check-gate.sh` fires at the `UserPromptSubmit` moment — BEFORE this command runs — so it deliberately checks **prerequisites only** (proposal.md exists with all four sections, single active change) and never the APPROVED marker: this command appends the marker afterwards, so requiring it in the hook would deadlock the happy path. The marker is enforced later — `check-archive.sh` audits it at archive time.

   If the hook blocks (no/incomplete proposal, multiple active changes) → handle per its error message, don't force a bypass.
<!-- /host -->
<!-- host:codex -->
3. **Hook check**: `codex/hooks/check-gate` fires at the prompt-submission moment — BEFORE this command runs — so it deliberately checks **prerequisites only** (proposal.md exists with all four sections, single active change) and never the APPROVED marker: this command appends the marker afterwards, so requiring it in the hook would deadlock the happy path. The marker is enforced later — `codex/hooks/check-archive` audits it at archive time.

   If the hook blocks (outputs `{"decision":"block"}` to stdout — no/incomplete proposal, multiple active changes) → handle per its error message, don't force a bypass.
<!-- /host -->

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
<!-- host:claude -->
| UI / routing / components / styling / client-side interaction | `spec-dev` (scope: frontend) |
| server-side logic / API / data models / DB migration / middleware | `spec-dev` (scope: backend) |
| **Cross-stack (including interface-contract changes)** | **Pin the contract first → dispatch two `spec-dev` concurrently (one frontend, one backend)** (see below) |
<!-- /host -->
<!-- host:codex -->
| UI / routing / components / styling / client-side interaction | spawn the spec-dev agent (defined in ~/.codex/agents/spec-dev.toml) (scope: frontend) |
| server-side logic / API / data models / DB migration / middleware | spawn the spec-dev agent (defined in ~/.codex/agents/spec-dev.toml) (scope: backend) |
| **Cross-stack (including interface-contract changes)** | **Pin the contract first → spawn two spec-dev agents concurrently (one frontend, one backend)** (see below) |
<!-- /host -->
| config / scripts / CI / docs | main conversation handles it |

<!-- host:codex -->
`spawn_agent` parameter contract: pass EITHER `message` (plain-text task only) OR `items` (use this when attaching a skill reference — put the task text inside `items` as a `{type:"text"}` entry alongside the `{type:"skill"}` entry). Passing both is rejected by the tool.
<!-- /host -->

<!-- host:claude -->
**Dispatching `spec-dev` MUST state the scope in the dispatch prompt** (`scope: frontend` / `scope: backend` / `scope: fullstack`) — this is what the agent uses to decide which stack references to read and which design sections to read. Omitting it = the agent can only infer the scope from the file types being changed, which is a suboptimal path.
<!-- /host -->
<!-- host:codex -->
**Dispatching spec-dev MUST state the scope in the dispatch prompt** (`scope: frontend` / `scope: backend` / `scope: fullstack`) — this is what the agent uses to decide which stack references to read and which design sections to read. Omitting it = the agent can only infer the scope from the file types being changed, which is a suboptimal path.
<!-- /host -->

**The dispatch prompt MUST also carry proposal What's `Not in this change` list verbatim** (the do-not-touch scope). An agent whose task seems to require touching excluded scope stops and reports — widening scope is a user decision (`/spec:revise what`), never the agent's.

### Cross-stack: contract first + parallel implementation

**The serial approach is forbidden** (backend then frontend = 50% of the time wasted). The correct flow:

1. **Pre-check**: design.md's `## Interfaces` section must already spell out:
   - endpoint / method / path
   - input schema
   - output schema
   - error codes + error response structure

   If missing, **refuse to dispatch** and go through `/spec:design` to pin the contract first.

<!-- host:claude -->
2. **Concurrent dispatch** (issue two Agent calls in one message):
   - `spec-dev` (scope: backend): implement the server side, returning contract-compliant mock data first, then wiring the real data source
   - `spec-dev` (scope: frontend): implement the client skeleton, wiring the contract with mock data / TypeScript types
<!-- /host -->
<!-- host:codex -->
2. **Concurrent dispatch** (spawn two agents in one message):
   - spec-dev (scope: backend): implement the server side, returning contract-compliant mock data first, then wiring the real data source
   - spec-dev (scope: frontend): implement the client skeleton, wiring the contract with mock data / TypeScript types
<!-- /host -->

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

`/spec:apply` supports three flags, space-separated, combinable, omittable.

| flag | Turns on | Effect |
|---|---|---|
<!-- host:claude -->
| `design` | anti-AI-slop | `spec-dev` (frontend scope) reads `skills/core/references/frontend-aesthetics.md` |
| `solid` | anti-laziness | the agent reads `skills/core/references/agent-principles.md` § 1 |
| `verify` | anti-hallucination | the agent reads `skills/core/references/agent-principles.md` § 2 |
<!-- /host -->
<!-- host:codex -->
| `design` | anti-AI-slop | spec-dev (frontend scope) reads `frontend-aesthetics.md` from the sdd spec-core skill's references directory |
| `solid` | anti-laziness | the agent reads `agent-principles.md` § 1 from the sdd spec-core skill's references directory |
| `verify` | anti-hallucination | the agent reads `agent-principles.md` § 2 from the sdd spec-core skill's references directory |
<!-- /host -->

**$ARGUMENTS parsing**: split on spaces, and for each token check whether it's in the `{design, solid, verify}` set. Matched ones turn into "turn on anti-X" instructions in the dispatch prompt; unmatched tokens are flagged to the user as possible typos.

**Usage examples**:

| Command | Behavior |
|---|---|
| `/spec:apply` | default, lean implementation |
| `/spec:apply design` | the frontend agent loads anti-AI-slop |
| `/spec:apply solid verify` | anti-laziness + anti-hallucination |
| `/spec:apply design solid verify` | all three on |

**No flag by default** — to avoid over-caution on routine tool-type UIs / internal pages / backend services.

The main conversation only steps in when dispatch fails / cross-executor coordination is needed / an agent reports it's stuck.

## Implementation + incremental verification

- Advance by deps, touching only tasks whose deps are done
<!-- host:claude -->
- Multiple deps satisfied and independent → **prefer dispatching two dedicated agents concurrently** (if frontend and backend are independent)
<!-- /host -->
<!-- host:codex -->
- Multiple deps satisfied and independent → **prefer spawning two dedicated agents concurrently** (if frontend and backend are independent)
<!-- /host -->
- After finishing each node (or a group of parallel ones) → run that node's own checks close by (compile / tests for the node), **don't save them for the end**. These are working checks — they do NOT write ledger rounds
<!-- host:claude -->
- **Closing verification is part of apply, not optional**: after the last What item / task lands, **dispatch the `spec-verifier` agent** (the same fresh-context, evidence-or-drop protocol `/spec:verify` uses — the conversation that just implemented MUST NOT write the closing round from its own self-review, that is exactly the bias the verifier exists to remove) and write its results as a ledger round to `spec/changes/<name>/verify.md` **before reporting implementation complete** — "done" without an independent ledger round covering the final state is not done. The Stop-event reminder hook (`check-verify-reminder.sh`) backstops this: ending a turn with an approved proposal and no ledger gets nudged back.
<!-- /host -->
<!-- host:codex -->
- **Closing verification is part of apply, not optional**: after the last What item / task lands, **spawn the spec-verifier agent (defined in ~/.codex/agents/spec-verifier.toml)** (the same fresh-context, evidence-or-drop protocol `/spec:verify` uses — the conversation that just implemented MUST NOT write the closing round from its own self-review, that is exactly the bias the verifier exists to remove) and write its results as a ledger round to `spec/changes/<name>/verify.md` **before reporting implementation complete** — "done" without an independent ledger round covering the final state is not done. The Stop-event reminder hook (`codex/hooks/check-verify-reminder`) backstops this: ending a turn with an approved proposal and no ledger gets nudged back.
<!-- /host -->
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

```
=== Stuck Self-Check ===
Symptom: <one line>
Three hypotheses tried:
  1. <hypothesis> → <result>
  2. <hypothesis> → <result>
  3. <hypothesis> → <result>
Inferred root cause: <write it if you can infer one, otherwise "unknown">
Suggested new direction: <write it if you have one, otherwise "awaiting user guidance">
```

Wait for the user's decision; **no endless patching**.

## Anti-Cheating

- A command / test that hasn't actually run **MUST NOT be reported as "success"** — success claims carry evidence (command + exit code / key output), same contract as /spec:verify's Evidence block
- A workaround that makes it "look like it passes" (mocking a fake response, changing an assert, patching a check function to return true) **MUST be stated plainly** as "bypass, root cause unresolved"
- Hardcoding (offsets, fixed hashes) if necessary MUST be flagged in a code comment + a "applies to this case only" note in tasks.md

## Coding Charter (binding on everyone who writes code in this phase)

<!-- host:claude -->
The dev agent reads `code-charter.md` on startup; **the main conversation, when it writes code itself (config / scripts / CI), is equally bound** — before the first keystroke, Read `${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md`. The core: failure must be loud (throw when you should, **NEVER silently re-route a query to scrape a result**), **changing logic is replacement, not accumulation** (NEVER keep the old logic as a fallback — the number-one source of dirty data + instability), fail-fast for core logic, degrade only at a trust boundary and always loudly. **Applies to the coding phase only** — it does not constrain the solution-space exploration of research/design/propose. A fallback / degrade / compat path is a **gate-level decision**: if proposal How/Risk doesn't authorize it, don't write it — `/spec:verify`'s charter audit treats unauthorized ones as findings (critical on data-write paths).
<!-- /host -->
<!-- host:codex -->
The dev agent reads `code-charter.md` on startup; **the main conversation, when it writes code itself (config / scripts / CI), is equally bound** — before the first keystroke, read `code-charter.md` under the sdd spec-core skill's references directory. The core: failure must be loud (throw when you should, **NEVER silently re-route a query to scrape a result**), **changing logic is replacement, not accumulation** (NEVER keep the old logic as a fallback — the number-one source of dirty data + instability), fail-fast for core logic, degrade only at a trust boundary and always loudly. **Applies to the coding phase only** — it does not constrain the solution-space exploration of research/design/propose. A fallback / degrade / compat path is a **gate-level decision**: if proposal How/Risk doesn't authorize it, don't write it — `/spec:verify`'s charter audit treats unauthorized ones as findings (critical on data-write paths).
<!-- /host -->

## What it does not do

- Doesn't run `git commit` / `git push` (only on user request)
- Doesn't archive (only when the user says "archive", via `/spec:archive`)
- Doesn't edit the proposal to fit the code (it should be the reverse: change the code to match the proposal, or `/spec:revise` the proposal)
