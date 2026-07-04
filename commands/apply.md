---
description: Implement the code, advancing by proposal/tasks. A pre-command hook checks that proposal.md carries the APPROVED marker. Incremental verification: call /spec:verify close to each node as it lands, don't save it all for the end
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
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

3. **Hook check**: `check-gate.ps1` still checks at the `UserPromptSubmit` moment — after apply auto-appends, the hook lets it through smoothly (serving as an audit layer and backstop).

   In the rare case the hook blocks (e.g. proposal.md missing / wrong name) → handle per the hook's error message, don't force a bypass.

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

**The dispatch prompt MUST also carry proposal What's `Not in this change` list verbatim** (the do-not-touch scope). An agent whose task seems to require touching excluded scope stops and reports — widening scope is a user decision (`/spec:revise what`), never the agent's.

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

`/spec:apply` supports three flags, space-separated, combinable, omittable.

| flag | Turns on | Effect |
|---|---|---|
| `design` | anti-AI-slop | `spec-dev` (frontend scope) reads `skills/core/references/frontend-aesthetics.md` |
| `solid` | anti-laziness | the agent reads `skills/core/references/agent-principles.md` § 1 |
| `verify` | anti-hallucination | the agent reads `skills/core/references/agent-principles.md` § 2 |

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
- Multiple deps satisfied and independent → **prefer dispatching two dedicated agents concurrently** (if frontend and backend are independent)
- After finishing each node (or a group of parallel ones) → run that node's own checks close by (compile / tests for the node), **don't save them for the end**. These are working checks — they do NOT write ledger rounds
- **Closing verification is part of apply, not optional**: after the last What item / task lands, **dispatch the `spec-verifier` agent** (the same fresh-context, evidence-or-drop protocol `/spec:verify` uses — the conversation that just implemented MUST NOT write the closing round from its own self-review, that is exactly the bias the verifier exists to remove) and write its results as a ledger round to `spec/changes/<name>/verify.md` **before reporting implementation complete** — "done" without an independent ledger round covering the final state is not done. The Stop-event reminder hook (`check-verify-reminder.ps1`) backstops this: ending a turn with an approved proposal and no ledger gets nudged back.
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

The dev agent reads `code-charter.md` on startup; **the main conversation, when it writes code itself (config / scripts / CI), is equally bound** — before the first keystroke, Read `${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md`. The core: failure must be loud (throw when you should, **NEVER silently re-route a query to scrape a result**), **changing logic is replacement, not accumulation** (NEVER keep the old logic as a fallback — the number-one source of dirty data + instability), fail-fast for core logic, degrade only at a trust boundary and always loudly. **Applies to the coding phase only** — it does not constrain the solution-space exploration of research/design/propose. A fallback / degrade / compat path is a **gate-level decision**: if proposal How/Risk doesn't authorize it, don't write it — `/spec:verify`'s charter audit treats unauthorized ones as findings (critical on data-write paths).

## What it does not do

- Doesn't run `git commit` / `git push` (only on user request)
- Doesn't archive (only when the user says "archive", via `/spec:archive`)
- Doesn't edit the proposal to fit the code (it should be the reverse: change the code to match the proposal, or `/spec:revise` the proposal)
