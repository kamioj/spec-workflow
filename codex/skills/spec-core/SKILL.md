---
name: spec-core
description: Spec-driven development workflow overview. Load this skill ONLY when the user explicitly asks for the spec flow — says "spec this first / draft a proposal / design first / write a proposal", or invokes a $spec-x command. NEVER self-activate on task size or complexity: size is at most grounds for a one-line suggestion, and silence means proceed without spec. Teaches the sdd plugin's 16 commands, artifact map, and Shared Principles (HARD GATE / interrogation / Stuck Protection / Anti-Cheating).
---
<!-- GENERATED from core/skill.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# SDD Plugin Overview

Spec-driven development workflow: research → interrogate → propose → HARD GATE → implement → verify → archive. A multi-command plugin where every stage fires independently.

## When to use

**Activation is user-explicit ONLY** — the flow starts when the user invokes a `$spec-x` command or says "spec this first | proposal | design first | draft a solution". **The model NEVER self-activates this workflow**, no matter how large the task looks.

Size signals (>150 lines / 3+ files / new dependency / architecture choice) are grounds for **at most a one-line suggestion** ("this is large — want the spec flow?"). No answer = no spec: just do the work. Auto-drifting a task into spec ceremony uninvited is this plugin's single biggest failure mode — worse than skipping spec on a large change, because the user can always invoke spec later, but time burned on unwanted process is gone.

**Never even suggest the full flow for**: trivial (typo / log / styling) · small (<30 lines, single file) · medium (30–150 lines / 2–3 files / no cross-module impact). When the user wants a record for a small change anyway, `$spec-fix` is the tier to name — same doctrine: one-line suggestion at most, user-explicit activation only.

## Command index

| Category | Command | Responsibility |
|---|---|---|
| Entry | `$spec-workflow <task>` | run the whole flow end-to-end; back-compatible with the old /sdd |
|  | `$spec-loop <goal>` | goal-driven autonomous round loop (goal known, path unknown): two touchpoints — goal confirmation + final acceptance — with Stop-hook-driven rounds and a cross-round ledger in between |
|  | `$spec-fix <task>` | streaming light tier for bug fixes and small changes: locate & confirm → fix (or research candidates when uncertain) → append an F-N entry to the standing `spec/changes/fixes/` batch; size is advisory, never a refusal |
|  | `$spec-ship` | close the fix batch: ONE verifier audit over the accumulated diff, then archive the whole batch dir; findings stay in place on fail |
|  | `$spec-status` | report the current stage |
|  | `$spec-stash` | suspend the active change (`.paused` marker) — frees the single-active slot; every artifact stays warm |
|  | `$spec-resume` | bring a paused change back, with re-entry context (where it left off) |
| Gather | `$spec-research <direction>` | survey industry practice + key constraints |
|  | `$spec-ask` | interrogate and resolve `[TBD]` items |
|  | `$spec-chat` | discussion mode, touches no file |
| Design & propose | `$spec-design` | technical design pass (on demand) |
|  | `$spec-propose` | write proposal.md |
|  | `$spec-revise [section]` | edit a single proposal section (why/what/how/risk) |
| Execute & verify | `$spec-apply` | implement the code |
|  | `$spec-verify [--fix] [native]` | dispatches the independent spec-verifier agent (four dimensions + charter audit); `--fix` lets the agent edit, `native` adds the opt-in project-idiom conformance pass |
| Wrap up | `$spec-archive` | archive the change |

> Heterogeneous peer review (`--codex`) is not available in this port — Codex cannot be its own heterogeneous reviewer.

## Artifact map

```
spec/
├── knowledge.md                      project-level durable facts, cross-change (maintained by $spec-archive, read first by $spec-research)
├── changes/                          active change workspace
│   └── <change-name>/
│       ├── research.md   required    current research (Practices + Constraints + Open[TBD] + Decided, single file)
│       ├── research/     optional    discarded-draft pile of research directions (research.md snapshots of abandoned directions, no markers/links, revivable)
│       ├── index.md      required    requirement & asset index (R-N verbatim quotes + A-N assets + E-N exemplars; built by research, frozen at gate, append-only — see references/index-spec.md; changes predating the format are legacy: consumers declare the absence and fall back, never block)
│       ├── design.md     optional    technical design (architecture / interfaces / data model)
│       ├── proposal.md   required    the final solution (carries the HARD GATE approval marker)
│       ├── tasks.md      optional    task list for multi-executor collaboration
│       ├── verify.md     at-propose+ verification ledger (stable V-N finding IDs + round history + Evidence; round 0 by propose's critique panel, rounds 1+ by $spec-verify)
│       ├── loop.md       at-loop     round ledger of a $spec-loop run (goal + acceptance checklist + rounds + lessons; model-written, driver-read — see references/loop-spec.md)
│       ├── .loop-state   at-loop     the loop driver's own state (driver-written ONLY — never edit)
│       ├── fix.md        at-fix      streaming light-tier batch ledger, lives ONLY in the standing dir changes/fixes/ (F-N entries + ship-time Audit — see references/fix-spec.md); fix.md WITHOUT proposal.md = light-tier dir, excluded from the active count; WITH proposal.md = upgraded, normal full change. Legacy quick.md dirs keep the same exemption + archive audit
│       ├── .paused       at-stash    suspension marker (one line: date + reason) — gates and the reminder skip the dir; $spec-resume deletes it
│       └── retrospect.md at-archive  written by $spec-archive right before the move (divergence review + evidence + leftovers)
│
└── archive/                          archive directory
    └── YYYY-MM-DD-<name>/            the whole change directory after archiving
```

**spec/ roots at the directory the session was launched from** (`$CLAUDE_PROJECT_DIR` on Claude Code; the session cwd on Codex) — the gate hooks resolve it there and ONLY there, with no subdirectory search. Working on a subproject of a monorepo does NOT move spec/ into the subproject: keep spec/ at the launch root (change names can carry a subproject prefix), or launch the session inside the subproject so the root follows. **A git worktree is its own root**: the session's worktree carries its own spec/ tree — never follow `.git`/gitdir back to the main repository or a sibling worktree (their spec/ trees belong to their sessions). A spec/ tree created anywhere else is invisible to every gate — apply/ship/archive block with "no spec/changes/ directory", and a gate that DOES find the local tree can block naming an unrelated change from it (maximally misleading). **After creating a change directory, self-check the path**: confirm its absolute path sits under `<launch root>/spec/changes/` before writing artifacts into it.

**The artifact set is fixed at these four + the requirement & asset index + the discarded-draft pile + the verification ledger + the $spec-loop round ledger (with its driver state file) + the $spec-fix batch ledger + the .paused marker + the archive-stage retrospect + the project-level knowledge.md.** The model inventing unplanned extra files (app-current / decisions / migration-inventory, etc.) is a direct source of document bloat — any fifth file type requires **explicit user approval**, otherwise fold the content into one of the four.

## Phase Responsibility Matrix (each artifact has its own job; crossing the line is the source of bloat)

The main cause of bloated docs on large changes is **phase boundary violations**: research content leaking into design, code and DDL misplaced in design, the same decision narrated in both research and design. **Principle: each piece of content is written in full only at its single source of truth; everywhere else references it, never restates it.**

| Artifact | **Writes only** (single source of truth) | **Does not write** (moves to) | Soft budget |
|---|---|---|---|
| research.md | External information: Practices / Constraints / Open[TBD] / Decided (DEC-N conclusion + one-line reason) | architecture·interfaces·schema→design ｜ changed files→proposal What ｜ raw search process→discarded-draft pile | one line each |
| index.md | Static external anchor: R-N verbatim requirement quotes / A-N assets / E-N exemplar designations (append-only; quotes, never paraphrases) | status·progress·code locations·coverage → computed per verify round, never stored ｜ interpretation → downstream artifacts cite entries, never restate them | one line per entry |
| design.md | Internal technical structure: architecture diagram (structure, no fields) / interface contract (precise schema) / data model / **deep argument for contested decisions only** | business motivation→proposal Why ｜ risk·rollback→proposal Risk ｜ full code·DDL→apply ｜ copying DEC-N conclusions (reference, don't transcribe) ｜ expanding non-contested decisions | **narrative/argument ≤150 lines** (contracts excluded, as precise as needed); split diagrams >20 nodes; expand 1–2 decisions, ≤12 lines each |
| proposal.md | Decision record: Why / What (each item + `verify:` acceptance check, closing **Not in this change** list) / How (conclusion + pointer) / Risk | deep argument→design ｜ schema→design ｜ restating design decisions | ≤5 lines per section (`verify:` clauses + the Not-in-this-change block don't count) |
| tasks.md | Collaboration list: owner / deps / acceptance | restating the solution → point back to proposal/design | one line per task |
| verify.md | Verification ledger — two writers, same table: round 0 (stage: propose) by $spec-propose's critique panel, rounds 1+ by $spec-verify; findings with stable V-N IDs + severity + status (open/fixed/wontfix) + per-round Evidence; acceptance-stage user evaluations enter as user-sourced findings | restating the fix → it lives in code ｜ restating the solution → proposal/design | one line per finding |
| loop.md | $spec-loop round ledger: goal + Acceptance checklist (checkboxes ONLY here; mid-loop checks self-claimed with working-check evidence, independently audited at final acceptance) / round records (Plan·Act·Verify·Retrospect) / Lessons — **model-written only**; the driver reads mechanical counts and owns `.loop-state` | proposal-grade solution records → the loop's own artifacts stay in loop.md; durable lessons → knowledge.md at archive | one round section per round; Lessons one line each |
| fix.md | Streaming light-tier batch ledger: per-entry verbatim Ask quote / root cause / files / self-check evidence; ship-time verifier Audit (status: shipped only after $spec-ship's dispatch) | research·proposal-grade content → if it needs those, it needed the full flow (upgrade in place) | 1–2 lines per entry field |
| retrospect.md | Archive-stage audit (written by $spec-archive only): divergences found ("docs say A, code does B"), verify Evidence lines, unfinished/deferred items, force/abandon reason | restating the solution → point back to proposal/design | ≤40 lines |
| knowledge.md (project-level, outside the change dir) | Durable cross-change facts: topology/ownership, verified mechanisms, gotchas — `<fact> \| evidence \| date (change)` | anything change-specific → stays in that change's artifacts ｜ a fact proven wrong is **replaced** (correction noted), never left contradicting | one line per fact |

**The soft budget governs "narrative/argument" only, not "contracts":** `## Interfaces` / `## Data Model` contracts are as precise as they need to be and **do not count toward the budget** — an imprecise contract is the real failure to specify. The exact line counts for design and rules like "split the change if the contract is too large" live in `../spec-core/references/design-spec.md` § Section Constraints (those numbers are authoritative) — **this matrix sets the principle only and does not restate them**.

**De-duplication removes the "deep argument" (kept in one place only), not the "conclusion."** Conclusions MUST be **forwarded** to the documents the executor actually reads — `$spec-apply` **reads only proposal + design, not research**, so those two combined must specify the task on their own. The three items most prone to duplication, with their fixed sources of truth:
- **Decisions**: research `## Decided` (DEC-N) is the **decision registry** (conclusion + one-line reason), **not the source of truth for deep argument**; the **conclusion + reason are forwarded to proposal `## How`** (e.g. "chose X, one-line reason"), and MUST NOT be referenced merely as "see DEC-N", which would leave apply with nothing to act on. The **deep argument** (benchmarks / multi-option trade-offs) lives at design `## Key Decisions`, expanded for the 1–2 **contested** decisions only.
- **Motivation** = proposal `## Why`. design writes no business-Context narrative.
- **Risk** = proposal `## Risk`. design has no separate Risks section (a decision's "cost" goes in one line under that decision, not in a separate list).

## Shared Principles

### HARD GATE flow

`$spec-propose` / `$spec-revise` MUST emit this fixed closing block once the proposal is written:

```
<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/<name>/proposal.md
(if tasks.md was generated too → declare the decision, not just the fact:
 + tasks.md — trigger: <cross-stack / >5 subtasks / multi-executor>; split: <N> groups — <one-line group list>
   disagree with the need or the split → say so now, before $spec-apply)

Escalated decisions — pinned FIRST, never buried. Irreversible-class calls the agent made
provisionally (data migration / schema / public API / new dependency / destructive op /
user-visible product semantics). They stand by default: silence + $spec-apply = consent;
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
Unsourced additions: <behavioral items (validation / required fields / permissions / endpoints /
schema) carrying no valid R-N citation against the change's index.md, AND new carriers
(fields / params / methods / endpoints / validations / defaults) with no C-N backing — one
line each; declared C-N minting rows surface here for approval too. They ride this gate as
additions to approve, never slip through as "obviously good"; "none" if every behavioral
What item cites the index and every carrier reconciles; "legacy change (no index)" when the
change predates the index format — mandatory line>
Unresolved critique: <critique-panel findings that survived the refutation round unresolved,
one line each with the panel's evidence (they sit as open round-0 findings in the ledger);
"none" if none>
Not in this change: <mirror What's "Not in this change" list — what approval does NOT cover>

Next:
  ✅ Looks good → run $spec-apply to start implementing
     apply will automatically append the <!-- APPROVED: ... --> marker to the end of proposal.md
  🔧 Tweak one section → $spec-revise [why | what | how | risk]
  💭 Want to talk the direction over → $spec-chat
  🔄 Research needs redoing → $spec-research "<new direction>"
</HARD-GATE>
```

The user's reply to a gate is an **evaluation, not a command sheet**: respond to every item
explicitly — adopt / refute (with evidence or a Decided entry) / partial — one round, user
has the final say; an insisted-on item after refutation is applied and recorded as a
user-override in the ledger. Absorbing every point unexamined is sycophancy toward the user.

`$spec-revise` uses the same structure, with the title changed to `=== Proposal revised (<section>) ===` and a note that "the old APPROVED marker has been removed".

The `<!-- APPROVED: YYYY-MM-DD HH:mm -->` marker is **appended automatically by `$spec-apply` before it runs** (treating the user's deliberate invocation as the act of approval) — propose / revise **do not append it** (see proposal-spec.md).

The `codex/hooks/check-gate` hook checks the prerequisites before `$spec-apply` runs (proposal.md exists with all four sections + a single active change). It deliberately does **not** require the marker — apply appends the marker after the hook fires (requiring it there would deadlock the flow); the marker is enforced at archive time by `codex/hooks/check-archive`. These hooks signal blocking by emitting `{"decision":"block"}` to stdout (not exit 2).

### Interrogation rules (in the spirit of grill-me)

- **Self-contained prompts** (most important; applies everywhere you "ask the user / give a recommendation" — ask's options, HARD GATE change points, status's next steps): what you present = ① the decision / action in one line + ② the reason (what it affects / the cost of not doing it) + ③ for each option, "what choosing it leads to (concrete scenario / consequence)". **Test: the user can decide on it without asking a follow-up.** Vague content (just listing "A / B / C", or just naming a command with no consequence / reason) is the primary failure mode.
- **Classify the select type, then police the options** (the two structural failures of low-value questions): pick-ONE (mutually exclusive paths — architecture A/B/C) → single-select; pick-SEVERAL (independent inclusions — which edge cases are in scope, which pages to touch, which concerns to adopt) → **multi-select, never forced into pick-one** (forcing drops legitimate picks or shreds one decision into serial questions; "which of these…" phrasing is the signal). And options must differ in **consequence, not wording**: a pair of options whose outcome lines read the same is ONE option — merge them; option count follows the real decision space, never padded toward 4 (a dominated option nobody would rationally pick, or a restatement of the question stem, is noise that costs reading time and trust). Two honest options beat four manufactured ones.
- **Claim Self-Review (four-question filter)** (the sibling of self-contained prompts: that one governs "questions put to the user", this one governs "content produced"): before committing any claim, run it through four questions — ① **Why** (what problem can't be solved without it) ② **When is it favorable** (anchor a concrete scenario, not an abstract "more elegant") ③ **Cost** (every option has a price; if you can't name the cost, you haven't thought it through) ④ **Can it be cut** (if removing it changes nothing, **don't write it**). **Rigor is precision, not length**: the four questions are a **thinking** act, applied to every claim; but **only the conclusion of question ④ becomes text** (what survives the cut) — the deep argument of ② and ③ is **internalized** by default, expanded in writing only for the 1–2 decisions that are **genuinely contested / high-risk** (the expansion goes in design `## Key Decisions`, not folded into research / proposal). Test: the user can't extract anything new by pressing with the four questions, **and not a single sentence can be cut without loss**.
- Preference-type decisions **MUST** be put to the user — via the `request_user_input` tool whenever the session has it (Codex's structured question tool, experimental flag `default_mode_request_user_input`; single-select, max 3 options per call). Fit questions to the tool rather than falling back to text while it exists: >3 candidates → the 3 slots are recommended + strongest alternative + skip/minimal (never trimmed), the rest named in the question text as text-reply picks (genuinely wide spaces narrow across two calls: category, then specifics); multi-select → per-candidate include/skip single-select calls, combined outcome echoed once. Plain text is ONLY the no-tool fallback, after a one-line tip naming the flag. Plain-text form: **batch independent questions into one message** (≤4): number questions `Q1 / Q2 / …`, letter options `A. / B. / C.` (never numbered — they would visually continue the question sequence), recommended option first marked "(Recommended)" with a one-line reason; close with one combined reply line (`"1A 3C"`; omitted questions resolve to the recommended option) and echo the full resolution — defaults marked — before writing anything to Decided. Only a mutually dependent chain goes one question at a time.
- 2–4 options / put the recommended one first, mark it "(Recommended)" + one line on why
- More than 4 options → split into "multi-level narrowing"
- Unsure whether it's fact-type or preference-type → treat it as preference-type
- At most 4 questions per round — and round caps are not run caps: rounds repeat until every pending point is resolved or the user says stop; a point left silently unasked doesn't disappear, it comes back as a gate block
- **Exception — inside the `$spec-workflow` orchestration**: the flow is two-touchpoint by
  design (HARD GATE + acceptance), so preference points are NOT asked mid-flight — they are
  triaged (see $spec-ask § Auto triage): decided with an `auto` or `escalated` mark and
  surfaced at the HARD GATE (escalated ones pinned on top, standing unless overturned).
  The user participates as an **evaluator**, and every evaluation gets a per-item
  adopt / refute / partial response. Standalone `$spec-ask` keeps the interactive rules above.

### Stuck Protection

**3 consecutive** failed fixes in the same direction during any command → stop immediately and report.

One attempt = new hypothesis + code change + verification; re-running the same code / fixing a typo / tweaking logging **does not count**. From the second attempt on, the hypothesis must also state **why the previous attempt failed** — a retry without a root-cause reading of the last failure is a blind retry, and does not count.

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

Close the report in **statement mode**: the default direction plus one "overridable" line — never a multiple-choice menu (an option that is already a fait accompli, or one that was never authorized, must not be posed as a question). Then wait for the user's decision; no endless patching.

### Anti-Cheating (in the spirit of the explore skill)

1. **No faking results**: a command / PoC / output that hasn't actually run **MUST NOT be reported as "success"** — a success claim must carry its evidence (the command + exit code / key output line; see $spec-verify's Evidence block)
2. **No passing off a bypass as a fix**: mocking a fake response / changing an assert / patching a check function to return true MUST be stated plainly as "bypass, root cause unresolved"
3. **Hardcoding must be flagged**: offsets / fixed hashes / one-off parameters get a code comment + a "applies to this case only" note in tasks.md
4. **Self-reported success is not verification**: a result reported by another agent (or by an earlier round) must be independently re-run before it counts as evidence — $spec-verify's spec-verifier re-runs the key commands itself (Iron Law)

### Requirement fidelity (anti-gold-plating)

**What the requirement source did not ask for is forbidden by default.** The requirement source is the user's words / the prototype / the defect being fixed — "engineering best practice" is NOT a requirement source. The classic inflations — finer-grained permissions than the system uses, extra config switches, extension points, defensive features, "while we're here" capabilities — are the top real-world failure mode of autonomous flows: every checker downstream anchors to the proposal, so an inflated proposal (or an implementation-time invention that never entered one) gets certified all the way to production.

- Every proposal `## What` item traces to the requirement source; an item with **no source is an ADDITION** and must ride the gate as an escalated decision — never slip in as "obviously good"
- **Fidelity extends to the CARRIER level**: a requirement noun is not entitled to its own code entity — derive from the existing truth source first (field / method / endpoint mapped in the index's `## Carriers`); minting a new carrier requires the empty-handed responsibility search on record. Behavioral fidelity asks "was this behavior asked for"; carrier fidelity asks "does this concept already have a home"
- At implementation time, a capability not in `## What` is **drift**: stop and report, never build it because it seems professional
- When the existing system has a simpler convention (e.g. menu-level permissions), matching that convention IS the requirement; exceeding it is an addition
- **Mechanical layer — the index** (references/index-spec.md): `$spec-research` extracts the requirement source ONCE into the change's `index.md` (R-N verbatim quotes, behavioral clauses only); every behavioral What item carries `| refs: R-N`; the gate's `Unsourced additions` line lists what has no valid citation; `$spec-verify` audits the diff against the quotes — a **mismatched** citation (behavior not entailed by the quoted text) is the same finding as a missing one. Detection never relies on the agent knowing it made an assumption — only on the assumption existing in the diff

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
| `codex/hooks/check-tbd` | before `$spec-propose` | refuses to run if research.md still contains `[TBD]`, points to `$spec-ask`; signals block via stdout `{"decision":"block"}` |
| `codex/hooks/check-gate` | before `$spec-apply` | refuses to run if prerequisites are missing: no/incomplete proposal.md (four sections) or ≠1 active change. Deliberately does NOT require the APPROVED marker — apply appends it after the hook fires; `check-archive` enforces it; signals block via stdout `{"decision":"block"}` |
| `codex/hooks/check-archive` | before `$spec-archive` | refuses to run if the change bypassed the flow (proposal without APPROVED / unchecked tasks / no proposal); deliberate override: say `force` (archive as-is, reason recorded in retrospect.md) or `abandoned` (drop the direction); signals block via stdout `{"decision":"block"}` |
| `codex/hooks/check-verify-reminder` | Stop event (turn ends) | **reminder, not gate**: active change has an APPROVED proposal but no verify.md ledger → nudges the model to run the closing verification (or state explicitly why it's pausing); `stop_hook_active` guards loops — at most one nudge per stop |
| `codex/hooks/loop-driver` | Stop event, when exactly one `running` loop.md exists | **driver, not gate**: re-injects the next $spec-loop round via stdout `{"decision":"block","reason":...}` until acceptance is met or a fuse blows (round cap / no-progress / refusal-to-retrospect / corrupt ledger — four distinct notices); deliberately ignores `stop_hook_active`, bounded by ledger state instead |

check-tbd / check-gate also block when **more than one active change** exists under `spec/changes/` (this workflow assumes a single active change — archive or `$spec-stash` the rest before continuing). **Dirs carrying `.paused`, or `quick.md`/`fix.md` without proposal.md, don't count as active** (precedence: proposal.md wins — an upgraded light-tier dir is a normal full change); the same filter keeps check-verify-reminder's single-active window detectable. check-archive deliberately does **not** block on multiple changes (archiving is exactly how you get back down to one) and audits light-tier dirs by their own record (fix.md `status: shipped` + non-empty Audit; legacy quick.md `status: done` + non-empty Evidence). `$spec-ship` invocations are gated on preconditions only (a batch with entries exists) — never on the shipped status ship itself writes.

**Soft vs hard constraints:**
- Soft constraint (prompt): the model may violate it; the violation rate depends on the model's quality
- Hard constraint (hook): blocks execution; a 0% violation rate

## references loading strategy

Read on demand, **not mandatory**:
- `../spec-core/references/alibaba-java.md` + `java-conventions.md` — Java + Spring
- `../spec-core/references/vue-style.md` + `vue-patterns.md` + `js-style.md` + `css-style.md` — Vue (uni-app adds `uniapp-miniprogram.md`)
- `../spec-core/references/bulletproof-react.md` + `react-patterns.md` — React
- `../spec-core/references/google-ts-style.md` + `ts-conventions.md` — TS (layered on top of Vue/React/Node)
- `../spec-core/references/python-conventions.md` — Python
- `../spec-core/references/php-conventions.md` — PHP
- `../spec-core/references/flutter-conventions.md` — Flutter / Dart

Read on demand only when writing a concrete technical decision, to avoid polluting the token budget.

## Interaction with the global protocol

- **Language**: proposal / research prose follows your working language; **section headers are ALWAYS the English canonical forms** (`## Why / ## What / ## How / ## Risk` — never translated, e.g. ❌ `## 为什么（Why）`). A global "write in Chinese" protocol applies to prose only — hooks and `$spec-revise` target headers by their English names, and translated headers break that targeting
- **Subagent delegation**: WebSearch goes to spawn the researcher agent (defined in ~/.codex/agents/researcher.toml); cross-file search to spawn the code-explorer agent
- **Concurrency**: independent operations are dispatched at once
