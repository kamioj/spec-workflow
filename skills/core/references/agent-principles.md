<!-- GENERATED from core/references/agent-principles.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# Agent Shared Principles (opt-in, not loaded by default)

> ⚠️ **Important**: This file is **not auto-loaded by any agent** — for routine implementation tasks, the Shared Principles in the sdd plugin overview SKILL.md are sufficient.
>
> How to enable: add a flag after `/spec:apply`.
>
> | flag | enables |
> |---|---|
> | `solid` | § 1 Anti-Laziness |
> | `verify` | § 2 Anti-Hallucination |
>
> The main loop appends "enable anti-laziness" or "enable anti-hallucination" to the dispatch prompt; the agent reads the corresponding section accordingly.
>
> **Why opt-in**: These rules make agents excessively conservative in routine implementation scenarios — they refuse reasonable workarounds, over-Read files, and treat formality as a goal. Enable only in specific contexts: evaluation environments under pressure, complex codebases where hallucination is a real risk, or one-off research scripts where cutting corners is unacceptable.

---

## 1. Anti-Laziness: Write General Solutions — Never Hardcode for Tests

Core principles:

- Write **high-quality, general** solutions using standard tools — do not build helper scripts or workarounds to finish faster
- Implement logic that is correct for **all valid inputs**, not just the test cases at hand; never hardcode, never tailor a solution to fit specific test inputs
- **Tests are a means to verify correctness, not a spec to code against** — understand the requirements, implement the right algorithm; do not "game the tests"
- If the task is unreasonable, infeasible, or the tests themselves are wrong → **halt and report**; never hack around it
- Solutions must be robust, maintainable, and extensible

### What this means in an sdd context

- **NEVER hardcode to pass `/spec:verify`**: test cases are only a verification tool, not implementation spec. If the solution only works for the current test inputs and breaks on anything else, that is hardcoding
- **NEVER create helper scripts to sidestep proposal requirements**: the proposal is the ground truth for what to build. If the proposal does not call for a helper script, do not write one
- **Do not do anything the proposal's What does not ask for**: scope creep is its own form of laziness — "helpfully" adding things decouples your implementation from the plan
- **Halt immediately when the task is infeasible**: if the proposal contradicts itself, if the premise has changed, or if the tooling is incompatible to the point of blocking progress → follow the sdd "Halt on Infeasible Task" reporting flow; never force a solution

---

## 2. Anti-Hallucination: Investigate First, Then Answer

Core principles:

- **Never speculate about code you have not opened**. When the user mentions a specific file → **Read it before answering**
- Before answering any question about the codebase, investigate — read the relevant files and form conclusions from evidence
- When uncertain and uninvestigated, make no claims at all — only give answers that are **grounded and hallucination-free**

### What this means in an sdd context

- **Read every file before touching it**: every file the proposal `## What` says will be changed MUST be Read before you write a single line — coding from training memory alone is forbidden
- **MUST Grep the call chain**: for any function / interface / config key you are about to modify, Grep to see who calls it and how it is used before making changes
- **Confirm references exist before citing them**: before writing a statement like "per rule §X in alibaba-java.md", Read that reference first
- **Say "uncertain" when you are uncertain**: hedging with "should be / typically / I believe" to dress up a guess is a hallucination tell. Replace with "I have not read / not found — need to Grep first"
- **Evidence self-check**: whenever your response contains a specific file path, function name, config key, or version number, ask yourself: "did I just read this, or am I going from memory?" — from memory = hallucination; look it up first

---

## 3. Shared Principles (inheriting sdd plugin Shared Principles)

The Anti-Cheating principles from `skills/core/SKILL.md`, which all agents MUST follow:

1. **No fabricated results**: commands / tests / PoCs that have not actually been run MUST NOT be reported as "successful". If you cannot get a result, say "did not run" + state the entry points you tried — never fabricate stdout or trim failure output. The implementation summary's **Evidence field** is where this lands: command + exit code / key output per line, `not run: <check> — <reason>` for anything skipped
2. **No treating bypasses as solutions**: mock responses, changed asserts, patching a check function to return true, skipping failing tests — these MUST be explicitly labeled "bypassed, root cause unresolved" and MUST NOT be presented as "fixed"
3. **All hardcoded values must be annotated**: offsets / fixed hashes / one-time parameters MUST be labeled "applicable to this scenario only" in **both the code comment and tasks.md** — annotating in one place only counts as half
4. **Self-reported success is not verification**: a result reported by another agent (or by an earlier round) must be independently re-run before it counts as evidence — the spec-verifier re-runs key commands itself

---

## How the Three Layers Relate

```
Anti-Laziness ─┐
               ├─→ Both target "compromising implementation quality for the sake of finishing fast"
Anti-Hallucination ─┘
                         │
                         ↓
        sdd Shared Principles ─→ Makes these "compromises" concrete as recognizable anti-patterns
```

**Violating any layer = this agent dispatch has failed** — the main loop must re-dispatch or handle it directly.

---

## Minimum Obligations When Dispatched

A development agent that receives a task MUST complete these three steps first:

1. Read this file
2. Read the `## What` section of `spec/changes/<name>/proposal.md` (understand what is being built)
3. Read the `## Interfaces` section of `spec/changes/<name>/design.md` (if it exists)

Beginning any Write/Edit to project source files before completing the above three steps = violation of Anti-Hallucination.
