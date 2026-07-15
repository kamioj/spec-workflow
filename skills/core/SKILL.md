---
name: core
description: Spec-driven development workflow overview. Load this skill when the user says "spec this first / draft a proposal / design first / write a proposal", or when a task is >150 lines / spans 3+ files / introduces a new dependency / involves an architecture choice — to learn the sdd plugin's 11 commands, artifact map, and Shared Principles (HARD GATE / interrogation / Stuck Protection / Anti-Cheating).
---
<!-- GENERATED from core/skill.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# SDD Plugin Overview

Spec-driven development workflow: research → interrogate → propose → HARD GATE → implement → verify → archive. A multi-command plugin where every stage fires independently.

## When to use

**Activate** (any one is enough):
- The change is expected to exceed 150 lines
- It spans 3+ files
- It introduces a new dependency
- It involves an architecture choice (weighing multiple options)
- The user explicitly says "spec this first | proposal | design first | draft a solution"

**Do NOT activate**:
- trivial (typo / log / styling)
- small (<30 lines, single file)
- medium (30–150 lines / 2–3 files / no cross-module impact)

→ Just make the change; **NEVER activate this workflow**. Spinning up the heavy process by mistake is this plugin's single biggest failure mode.

## Command index

| Category | Command | Responsibility |
|---|---|---|
| Entry | `/spec:workflow <task>` | run the whole flow end-to-end; back-compatible with the old /sdd |
|  | `/spec:status` | report the current stage |
| Gather | `/spec:research <direction>` | survey industry practice + key constraints |
|  | `/spec:ask` | interrogate and resolve `[TBD]` items |
|  | `/spec:chat` | discussion mode, touches no file |
| Design & propose | `/spec:design` | technical design pass (on demand) |
|  | `/spec:propose [--codex]` | write proposal.md; `--codex` lets codex poke holes in the solution |
|  | `/spec:revise [section]` | edit a single proposal section (why/what/how/risk) |
| Execute & verify | `/spec:apply` | implement the code |
|  | `/spec:verify [--codex] [--fix]` | dispatches the independent spec-verifier agent (three dimensions + charter audit); `--codex` adds codex as a heterogeneous second reviewer, `--fix` lets codex edit |
| Wrap up | `/spec:archive` | archive the change |

## Artifact map

```
spec/
├── knowledge.md                      project-level durable facts, cross-change (maintained by /spec:archive, read first by /spec:research)
├── changes/                          active change workspace
│   └── <change-name>/
│       ├── research.md   required    current research (Practices + Constraints + Open[TBD] + Decided, single file)
│       ├── research/     optional    discarded-draft pile of research directions (research.md snapshots of abandoned directions, no markers/links, revivable)
│       ├── design.md     optional    technical design (architecture / interfaces / data model)
│       ├── proposal.md   required    the final solution (carries the HARD GATE approval marker)
│       ├── tasks.md      optional    task list for multi-executor collaboration
│       ├── verify.md     at-propose+ verification ledger (stable V-N finding IDs + round history + Evidence; round 0 by propose's critique panel, rounds 1+ by /spec:verify)
│       └── retrospect.md at-archive  written by /spec:archive right before the move (divergence review + evidence + leftovers)
│
└── archive/                          archive directory
    └── YYYY-MM-DD-<name>/            the whole change directory after archiving
```

**The artifact set is fixed at these four + the discarded-draft pile + the verification ledger + the archive-stage retrospect + the project-level knowledge.md.** The model inventing unplanned extra files (app-current / decisions / migration-inventory, etc.) is a direct source of document bloat — any fifth file type requires **explicit user approval**, otherwise fold the content into one of the four.

## Phase Responsibility Matrix (each artifact has its own job; crossing the line is the source of bloat)

The main cause of bloated docs on large changes is **phase boundary violations**: research content leaking into design, code and DDL misplaced in design, the same decision narrated in both research and design. **Principle: each piece of content is written in full only at its single source of truth; everywhere else references it, never restates it.**

| Artifact | **Writes only** (single source of truth) | **Does not write** (moves to) | Soft budget |
|---|---|---|---|
| research.md | External information: Practices / Constraints / Open[TBD] / Decided (DEC-N conclusion + one-line reason) | architecture·interfaces·schema→design ｜ changed files→proposal What ｜ raw search process→discarded-draft pile | one line each |
| design.md | Internal technical structure: architecture diagram (structure, no fields) / interface contract (precise schema) / data model / **deep argument for contested decisions only** | business motivation→proposal Why ｜ risk·rollback→proposal Risk ｜ full code·DDL→apply ｜ copying DEC-N conclusions (reference, don't transcribe) ｜ expanding non-contested decisions | **narrative/argument ≤150 lines** (contracts excluded, as precise as needed); split diagrams >20 nodes; expand 1–2 decisions, ≤12 lines each |
| proposal.md | Decision record: Why / What (each item + `verify:` acceptance check, closing **Not in this change** list) / How (conclusion + pointer) / Risk | deep argument→design ｜ schema→design ｜ restating design decisions | ≤5 lines per section (`verify:` clauses + the Not-in-this-change block don't count) |
| tasks.md | Collaboration list: owner / deps / acceptance | restating the solution → point back to proposal/design | one line per task |
| verify.md | Verification ledger — two writers, same table: round 0 (stage: propose) by /spec:propose's critique panel, rounds 1+ by /spec:verify; findings with stable V-N IDs + severity + status (open/fixed/wontfix) + per-round Evidence; acceptance-stage user evaluations enter as user-sourced findings | restating the fix → it lives in code ｜ restating the solution → proposal/design | one line per finding |
| retrospect.md | Archive-stage audit (written by /spec:archive only): divergences found ("docs say A, code does B"), verify Evidence lines, unfinished/deferred items, force/abandon reason | restating the solution → point back to proposal/design | ≤40 lines |
| knowledge.md (project-level, outside the change dir) | Durable cross-change facts: topology/ownership, verified mechanisms, gotchas — `<fact> \| evidence \| date (change)` | anything change-specific → stays in that change's artifacts ｜ a fact proven wrong is **replaced** (correction noted), never left contradicting | one line per fact |

**The soft budget governs "narrative/argument" only, not "contracts":** `## Interfaces` / `## Data Model` contracts are as precise as they need to be and **do not count toward the budget** — an imprecise contract is the real failure to specify. The exact line counts for design and rules like "split the change if the contract is too large" live in `references/design-spec.md` § Section Constraints (those numbers are authoritative) — **this matrix sets the principle only and does not restate them**.

**De-duplication removes the "deep argument" (kept in one place only), not the "conclusion."** Conclusions MUST be **forwarded** to the documents the executor actually reads — `/spec:apply` **reads only proposal + design, not research**, so those two combined must specify the task on their own. The three items most prone to duplication, with their fixed sources of truth:
- **Decisions**: research `## Decided` (DEC-N) is the **decision registry** (conclusion + one-line reason), **not the source of truth for deep argument**; the **conclusion + reason are forwarded to proposal `## How`** (e.g. "chose X, one-line reason"), and MUST NOT be referenced merely as "see DEC-N", which would leave apply with nothing to act on. The **deep argument** (benchmarks / multi-option trade-offs) lives at design `## Key Decisions`, expanded for the 1–2 **contested** decisions only.
- **Motivation** = proposal `## Why`. design writes no business-Context narrative.
- **Risk** = proposal `## Risk`. design has no separate Risks section (a decision's "cost" goes in one line under that decision, not in a separate list).

## Shared Principles

### HARD GATE flow

`/spec:propose` / `/spec:revise` MUST emit this fixed closing block once the proposal is written:

```
<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/<name>/proposal.md
(if tasks.md was generated too → declare the decision, not just the fact:
 + tasks.md — trigger: <cross-stack / >5 subtasks / multi-executor>; split: <N> groups — <one-line group list>
   disagree with the need or the split → say so now, before /spec:apply)

Escalated decisions — pinned FIRST, never buried. Irreversible-class calls the agent made
provisionally (data migration / schema / public API / new dependency / destructive op /
user-visible product semantics). They stand by default: silence + /spec:apply = consent;
overturn any with one line of reply. Omit the whole section when there are none.
  E1. <decision> | basis: <evidence or default used> | if wrong: <blast radius + undo path>

Changes — the explanation layer for the decision-maker. proposal.md stays compressed for
the executor; this block is where it gets explained. NEVER paste proposal lines verbatim.
One block per key decision (3–6), each a before/after mirror of the SAME concrete scenario;
Problem and After are ≤2 lines each (longer = you are explaining mechanism — that belongs
in proposal/design, not here):

  1. <the decision, one plain sentence>
     Problem: when <who does what concretely>, because <what is missing/wrong today>,
              <the concrete bad outcome>.
     After:   when <the same action>, because <what this change adds>, it <mechanism used>,
              so <that bad outcome no longer happens>.
     Cost:    <the price paid — dependency / latency / limitation / rework>

Register test: a reader who is NOT a developer can tell what problem every point solves
and how. Define each domain term at first use; a line only an insider can parse must be
rewritten around its scenario.

Decided without asking: <[TBD]s resolved autonomously (factual + auto), one line each — the
evidence or default used + reversibility; "none" if none — mandatory line, it lets the user
catch a misclassified preference>
Unresolved critique: <critique-panel findings that survived the refutation round unresolved,
one line each with the panel's evidence (they sit as open round-0 findings in the ledger);
"none" if none>
Not in this change: <mirror What's "Not in this change" list — what approval does NOT cover>

Next:
  ✅ Looks good → run /spec:apply to start implementing
     apply will automatically append the <!-- APPROVED: ... --> marker to the end of proposal.md
  🔧 Tweak one section → /spec:revise [why | what | how | risk]
  💭 Want to talk the direction over → /spec:chat
  🔄 Research needs redoing → /spec:research "<new direction>"
</HARD-GATE>
```

The user's reply to a gate is an **evaluation, not a command sheet**: respond to every item
explicitly — adopt / refute (with evidence or a Decided entry) / partial — one round, user
has the final say; an insisted-on item after refutation is applied and recorded as a
user-override in the ledger. Absorbing every point unexamined is sycophancy toward the user.

`/spec:revise` uses the same structure, with the title changed to `=== Proposal revised (<section>) ===` and a note that "the old APPROVED marker has been removed".

The `<!-- APPROVED: YYYY-MM-DD HH:mm -->` marker is **appended automatically by `/spec:apply` before it runs** (treating the user's deliberate invocation as the act of approval) — propose / revise **do not append it** (see proposal-spec.md).

The `check-gate.sh` hook checks the prerequisites before `/spec:apply` runs (proposal.md exists with all four sections + a single active change). It deliberately does **not** require the marker — apply appends the marker after the hook fires (requiring it there would deadlock the flow); the marker is enforced at archive time by `check-archive.sh`.

### Interrogation rules (in the spirit of grill-me)

- **Self-contained prompts** (most important; applies everywhere you "ask the user / give a recommendation" — ask's options, HARD GATE change points, status's next steps): what you present = ① the decision / action in one line + ② the reason (what it affects / the cost of not doing it) + ③ for each option, "what choosing it leads to (concrete scenario / consequence)". **Test: the user can decide on it without asking a follow-up.** Vague content (just listing "A / B / C", or just naming a command with no consequence / reason) is the primary failure mode.
- **Claim Self-Review (four-question filter)** (the sibling of self-contained prompts: that one governs "questions put to the user", this one governs "content produced"): before committing any claim, run it through four questions — ① **Why** (what problem can't be solved without it) ② **When is it favorable** (anchor a concrete scenario, not an abstract "more elegant") ③ **Cost** (every option has a price; if you can't name the cost, you haven't thought it through) ④ **Can it be cut** (if removing it changes nothing, **don't write it**). **Rigor is precision, not length**: the four questions are a **thinking** act, applied to every claim; but **only the conclusion of question ④ becomes text** (what survives the cut) — the deep argument of ② and ③ is **internalized** by default, expanded in writing only for the 1–2 decisions that are **genuinely contested / high-risk** (the expansion goes in design `## Key Decisions`, not folded into research / proposal). Test: the user can't extract anything new by pressing with the four questions, **and not a single sentence can be cut without loss**.
- Preference-type decisions **MUST** be put to the user via AskUserQuestion
- 2–4 options / put the recommended one first, mark it "(recommended)" + one line on why
- More than 4 options → split into "multi-level narrowing"
- Unsure whether it's fact-type or preference-type → treat it as preference-type
- At most 4 questions at a time
- **Exception — inside the `/spec:workflow` orchestration**: the flow is two-touchpoint by
  design (HARD GATE + acceptance), so preference points are NOT asked mid-flight — they are
  triaged (see /spec:ask § Auto triage): decided with an `auto` or `escalated` mark and
  surfaced at the HARD GATE (escalated ones pinned on top, standing unless overturned).
  The user participates as an **evaluator**, and every evaluation gets a per-item
  adopt / refute / partial response. Standalone `/spec:ask` keeps the interactive rules above.

### Stuck Protection

**3 consecutive** failed fixes in the same direction during any command → stop immediately and report.

One attempt = new hypothesis + code change + verification; re-running the same code / fixing a typo / tweaking logging **does not count**. From the second attempt on, the hypothesis must also state **why the previous attempt failed** — a retry without a root-cause reading of the last failure is a blind retry, and does not count.

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

Wait for the user's decision; no endless patching.

### Anti-Cheating (in the spirit of the explore skill)

1. **No faking results**: a command / PoC / output that hasn't actually run **MUST NOT be reported as "success"** — a success claim must carry its evidence (the command + exit code / key output line; see /spec:verify's Evidence block)
2. **No passing off a bypass as a fix**: mocking a fake response / changing an assert / patching a check function to return true MUST be stated plainly as "bypass, root cause unresolved"
3. **Hardcoding must be flagged**: offsets / fixed hashes / one-off parameters get a code comment + a "applies to this case only" note in tasks.md
4. **Self-reported success is not verification**: a result reported by another agent (or by an earlier round) must be independently re-run before it counts as evidence — /spec:verify's spec-verifier re-runs the key commands itself (Iron Law)

### Halt on infeasible task

When you find the premise itself is wrong (a contradictory task / an asset out of scope / a tool too incompatible to continue / a vulnerability already patched) → stop immediately and report:

```
=== Task infeasible ===
Finding: <where the premise is wrong / contradictory>
Evidence: <concrete observation / error / citation>
Suggestion: <change scope / switch tools / contact the task owner / abandon>
```

## Hook mechanism (hard-constraint reinforcement)

| Hook script | Trigger command | Effect |
|---|---|---|
| `hooks/check-tbd.sh` | before `/spec:propose` | refuses to run if research.md still contains `[TBD]`, points to `/spec:ask` |
| `hooks/check-gate.sh` | before `/spec:apply` | refuses to run if prerequisites are missing: no/incomplete proposal.md (four sections) or ≠1 active change. Deliberately does NOT require the APPROVED marker — apply appends it after the hook fires; `check-archive.sh` enforces it |
| `hooks/check-archive.sh` | before `/spec:archive` | refuses to run if the change bypassed the flow (proposal without APPROVED / unchecked tasks / no proposal); deliberate override: say `force` (archive as-is, reason recorded in retrospect.md) or `abandoned` (drop the direction) |
| `hooks/check-verify-reminder.sh` | Stop event (Claude ends its turn) | **reminder, not gate**: active change has an APPROVED proposal but no verify.md ledger → exit 2 nudges Claude to run the closing verification (or state explicitly why it's pausing, then stop); `stop_hook_active` guards loops — at most one nudge per stop |

check-tbd / check-gate also `exit 2` when **more than one active change** exists under `spec/changes/` (this workflow assumes a single active change — archive the rest before continuing). check-archive deliberately does **not** block on multiple changes: archiving is exactly how you get back down to one.

**Soft vs hard constraints:**
- Soft constraint (prompt): the model may violate it; the violation rate depends on the model's quality
- Hard constraint (hook): a shell script blocks it; a 0% violation rate

The POSIX sh scripts under `hooks/` are registered by `hooks/hooks.json` (shell form — sh on macOS/Linux, Git Bash on Windows): the three gates to the `UserPromptSubmit` event, the verify reminder to the `Stop` event.

## references loading strategy

Read on demand, **not mandatory**:
- `skills/core/references/alibaba-java.md` + `java-conventions.md` — Java + Spring
- `skills/core/references/vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md` — Vue (uni-app adds `uniapp-miniprogram.md`)
- `skills/core/references/bulletproof-react.md` + `react-patterns.md` — React
- `skills/core/references/google-ts-style.md` + `ts-conventions.md` — TS (layered on top of Vue/React/Node)
- `skills/core/references/python-conventions.md` — Python
- `skills/core/references/php-conventions.md` — PHP
- `skills/core/references/flutter-conventions.md` — Flutter / Dart

Read on demand only when writing a concrete technical decision, to avoid polluting the token budget.

## Interaction with the global protocol

- **Language**: proposal / research prose follows your working language; **section headers are ALWAYS the English canonical forms** (`## Why / ## What / ## How / ## Risk` — never translated, e.g. ❌ `## 为什么（Why）`). A global "write in Chinese" protocol applies to prose only — hooks and `/spec:revise` target headers by their English names, and translated headers break that targeting
- **Subagent delegation**: WebSearch goes to `@researcher`, cross-file search to `@code-explorer`
- **Concurrency**: independent operations are dispatched at once
