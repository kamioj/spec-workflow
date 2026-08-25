---
description: Streaming light tier for bug fixes and small changes (user-explicit only, never model-initiated). Appends F-N entries to the standing spec/changes/fixes/ batch — locate & confirm before touching code, fix directly when confident or research candidates when not, self-check evidence per entry; the ONE independent audit happens at /spec:ship.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

# /spec:fix

Task: $ARGUMENTS

The streaming light tier: bug fixes and small changes delivered across conversations, one
F-N entry at a time, into a single standing batch. Tier invariants: a verbatim quote anchor
per entry, honest self-check evidence per entry, and ONE independent verification per
**batch** — at `/spec:ship`, never per entry.

## The standing batch dir

- The batch always lives at `spec/changes/fixes/` with the ledger `fixes/fix.md`
  (format → [`skills/core/references/fix-spec.md`](../skills/core/references/fix-spec.md)).
  No naming, no per-batch setup: batch = the dir's lifetime between ships. **spec/ roots at
  the directory the session was launched from — never inside a subproject** (the ship/archive
  gates resolve it at that root only; see the root rule in SKILL).
- No `fixes/` dir → create it with `status: open` and start at F-1.
- **Collision guard**: `spec/changes/fixes/` exists WITHOUT fix.md → that is someone's
  normal change dir which happens to be named "fixes" — REFUSE to write into it, report the
  collision, and ask how to proceed (rename their change dir, or archive it first). Never
  mix a fix ledger into a foreign change.
- `fixes/` never counts toward the single-active-change slot (gates exempt dirs with fix.md
  present and proposal.md absent) — a full change and the fix stream run in parallel,
  neither blocking the other. fix is ungated by design; its protection is the batch audit.

## Size advisory (never a refusal)

Estimate the change first. If it looks full-flow sized (>150 lines / 3+ files / new
dependency / architecture choice), say ONE advisory line — "this looks full-flow sized; a
full proposal is available if you'd rather" — then **proceed anyway**. The size estimate is
reference information for the user, never a gate: routing to the full flow is the user's
call, not the model's.

## Per-entry flow

1. **Locate & confirm before touching anything**: find the exact code lines, state the
   problem point and your root-cause reading. The user's ask is quoted **verbatim** into the
   entry (the mini anchor — interpretation happens against the quote, never a paraphrase).
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
5. **Close with the pending count**: end the report with `批次现有 N 条待审` (N = entries
   not yet audited by ship). This line is mandatory — it keeps the un-audited backlog
   visible every single round.

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
- ❌ Skipping the pending-count closing line
