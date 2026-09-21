---
description: Streaming light tier for bug fixes and small changes (user-explicit only, never model-initiated). Appends F-N entries to today's daily batch under spec/changes/fixes/<date>/ — locate & confirm before touching code, fix directly when confident or research candidates when not, self-check evidence per entry; the ONE independent audit happens at /spec:ship.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---
<!-- GENERATED from core/commands/fix.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:fix

Task: $ARGUMENTS

The streaming light tier: bug fixes and small changes delivered across conversations, one
F-N entry at a time, into small daily batches. Tier invariants: a verbatim quote anchor
per entry, honest self-check evidence per entry, and ONE independent verification per
**batch** — at `/spec:ship`, never per entry.

## Daily batch dirs

- Fixes accumulate in **daily batches**: today's entries go to `spec/changes/fixes/<YYYY-MM-DD>/fix.md`
  (format → [`skills/core/references/fix-spec.md`](../skills/core/references/fix-spec.md));
  the first fix of a day creates that day's dir with `status: open` and starts at F-1.
  Each batch ships and archives independently (`/spec:ship`), so debt stays in small
  digestible slices instead of one ever-growing pile. There is deliberately **no nudge line
  about old batches** — batch lifetime is entirely the user's call. **spec/ roots at
  the directory the session was launched from — never inside a subproject, never in another
  worktree's or the main repository's tree** (the ship/archive gates resolve it at that root
  only; see the root rule in SKILL).
- A **legacy flat batch** (`fixes/fix.md` directly, no date dir) stays recognized: read and
  shippable as its own batch; new entries always go to today's dated batch, never appended
  to the legacy file.
- **Collision guard**: `spec/changes/fixes/` exists holding a proposal.md, or holding neither
  fix.md nor dated batch dirs — that is someone's normal change dir which happens to be named
  "fixes" — REFUSE to write into it, report the collision, and ask how to proceed (rename
  their change dir, or archive it first). Writing a fix ledger into a foreign change would
  corrupt both records.
- The `fixes/` tree never counts toward the gates' active-change count (gates exempt the
  parent when it carries fix.md directly or in dated subdirs, with no proposal.md) — a full
  change and the fix stream run in parallel, neither blocking the other. fix is ungated by
  design; its protection is the per-batch audit.

## Size advisory (never a refusal)

Estimate the change first. If it looks full-flow sized (>150 lines / 3+ files / new
dependency / architecture choice), say ONE advisory line — "this looks full-flow sized; a
full proposal is available if you'd rather" — then **proceed anyway**. The size estimate is
reference information for the user, never a gate: routing to the full flow is the user's
call, not the model's.

## Per-entry flow

1. **Locate & confirm before touching anything**: consult the knowledge base first — scan
   `spec/knowledge.md` (the index) and open relevant `[fact]` subdocs before hunting the
   codebase (a recorded trap or call-chain fact beats a fresh scan; legacy flat file → read
   whole, declare); then find the exact code lines, state the problem point and your
   root-cause reading. The user's ask is quoted **verbatim** into the entry (the mini
   anchor — interpretation happens against the quote, never a paraphrase).
2. **Fork on confidence**:
   - Confident and small → implement directly. The Coding Charter binds (Read
     `${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md` before the first
     keystroke — same rule as /spec:apply); the Concerns discipline binds (requirement
     silent → most permissive behavior; tightening impulses go to the entry's Concerns,
     never into code).
   - Uncertain about the right fix → **inline research first**: read the framework source /
     official docs / community reports of the same failure, present 2–3 candidates with a
     recommendation, implement the chosen one; the chosen rationale lands in the entry's
     Root cause. No research.md ceremony at this tier.
3. **Self-check**: run the working checks (compile / focused tests) yourself — commands +
   exit codes go into the entry. Anti-Cheating binds: nothing unrun is "success". Do NOT
   dispatch a verifier here (terminal-audit doctrine; the user can still demand an immediate
   spot-verify on any entry conversationally).
4. **Append the F-N entry** to fix.md (append-only — never renumber or rewrite earlier
   entries): verbatim ask, root cause, files touched (+ commit hash when one exists),
   self-check evidence, concerns.
5. **Close with the batch count**: end the report with `今日批次现有 N 条待审` (N = this
   day-batch's un-audited entries). This line is mandatory information — and it is the ONLY
   batch bookkeeping in the report: older batches are never nagged about (batch lifetime is
   the user's call; /spec:ship names them when the user runs it).

## Known limitation

One session at a time: two sessions appending fix.md concurrently can lose an entry (the
same exposure every sdd artifact has — single-session operation is the artifact model's
global assumption).

## Anti-patterns

- ❌ Model-initiated fix — user-explicit only; size signals warrant at most a one-line
  suggestion (same activation doctrine as the full flow)
- ❌ Editing code before locate-and-confirm (the diagnosis comes first)
- ❌ Paraphrasing the ask in the entry (quote, never paraphrase)
- ❌ Refusing by size (advisory only — routing is the user's decision)
- ❌ Dispatching a verifier per entry (the ONE independent audit is /spec:ship's)
- ❌ Renumbering, rewriting, or deleting existing F-N entries (append-only ledger)
- ❌ Skipping the batch-count closing line
