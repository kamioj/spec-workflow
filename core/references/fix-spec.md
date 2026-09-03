# fix.md spec

`spec/changes/fixes/fix.md` is the **streaming light-tier batch ledger** — the only required
artifact of the fix tier. One standing dir, one ledger; each `/spec:fix` invocation appends
one F-N entry, `/spec:ship` writes the closing audit and archives the whole dir. It keeps
the tier invariants (verbatim quote anchor per entry, honest self-check evidence per entry,
ONE independent verification per batch) while dropping every ceremony artifact.

## When it exists

Created by the first `/spec:fix` after the previous ship (the dir name is always `fixes` —
batch = the dir's lifetime between ships). **Precedence rule: proposal.md presence wins** —
if the dir ever grows a proposal.md, it flips to full-change semantics everywhere (gates,
archive audit, status); fix.md stays as inert history. **Collision rule**: a
`spec/changes/fixes/` dir WITHOUT fix.md belongs to someone's normal change — /spec:fix
refuses to write into it.

## Format

```markdown
# Fixes

status: open | shipped
opened: YYYY-MM-DD

## F-1: <one-line title>
date: YYYY-MM-DD
files: <path>, <path> (+ commit: <hash> — when one exists)

### Ask
<one-line restatement>
> <verbatim quote of the user's request — the mini anchor; quote, never paraphrase>

### Root cause
<what was actually wrong, 1–2 lines; for an uncertain fix: candidates considered + why the
chosen one won>

### Self-check
<commands + exit codes / key output — run by the implementing session>

### Concerns
<[Concern] entries per the Concerns discipline; "none" — mandatory>

## Audit
(absent until /spec:ship; then: the verifier round — commands + exit codes; findings + how
each was resolved)
```

## Field rules

- `status: shipped` is legal **only after** /spec:ship's verifier dispatch — the same
  trust-model class as the APPROVED marker, loop.md's `status: done`, and quick.md's
  `status: done` (a model-written flow-moment anchor; the archive gate audits it)
- Entries are **append-only**: never renumber, rewrite, or delete an earlier F-N
- `### Ask` quotes the user verbatim — interpretation happens against the quote
- `files:` lists every touched path; add the commit hash when one exists (aids the batch
  audit; per-entry diff attribution is not promised without commits)
- `## Audit` is **independently sourced** (the dispatched verifier's output), never the
  implementing conversations' self-reports

## Lifecycle

| Stage | Action |
|---|---|
| Start | first `/spec:fix` creates `fixes/` + fix.md (`status: open`, F-1) |
| Stream | each `/spec:fix` appends F-N; report ends with the pending count `批次现有 N 条待审` |
| Close | `/spec:ship`: ONE verifier over the accumulated diff → `## Audit` → `status: shipped` |
| Archive | ship moves the dir to `archive/<date>-fixes/` (`-2`, `-3` on same-day collision) |
| Upgrade | proposal.md appearing in the dir flips it to full-change semantics — fix.md stays |

## Known limitation

One session at a time: concurrent sessions appending fix.md can lose an entry — the same
exposure every sdd artifact has; single-session operation is the artifact model's global
assumption. No locking machinery is provided.

## Legacy: quick.md

`quick.md` is the legacy light-tier record format (one invocation = one dir = one archive).
All hooks still recognize it: a dir with quick.md and no proposal.md stays exempt from the
active-change count, and check-archive still audits it by `status: done` + non-empty
`## Evidence`. Existing quick dirs (active or archived) need no migration; new work uses
the fix tier.

## Anti-patterns

- ❌ Per-entry verifier dispatch (the ONE independent audit is /spec:ship's)
- ❌ Paraphrasing the ask instead of quoting it (kills the anchor)
- ❌ Hand-writing `## Audit` or `status: shipped` without the verifier round (Anti-Cheating:
  self-certified audits are void)
- ❌ Renumbering / rewriting / deleting earlier entries
- ❌ Writing fix.md into a dir that lacks prior fix-tier ownership (collision rule)
- ❌ Model-initiated fix — the tier is user-explicit only
