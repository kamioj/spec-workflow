# quick.md spec

`spec/changes/<change-name>/quick.md` is the **light-tier flow record** — the only required artifact of a `/spec:quick` change. It keeps the three tier-invariants (verbatim quote anchor, independent verification, honest evidence) while dropping the ceremony artifacts (research.md / index.md / proposal.md / the gate).

## When it exists

Created by `/spec:quick` at the start of a light-tier change. **Precedence rule: proposal.md presence wins** — if the change later grows and `/spec:research` → `/spec:propose` run in the same dir, the dir flips to full-change semantics everywhere (gates, archive audit, status); quick.md stays as inert history and is **never deleted**.

## Format

```markdown
# Quick: <change-name>

status: in-flight | done
date: YYYY-MM-DD

## Ask
<one-line restatement>
> <verbatim quote of the user's request — the mini anchor; quote, never paraphrase>

## Done
- <file / behavior changed, one line each>

## Concerns
<[Concern] entries per spec-dev's Concerns discipline; "none" — mandatory>

## Evidence
<the closing verifier round: commands + exit codes / key output; findings + how each was resolved>
```

## Field rules

- `status: done` is legal **only after** the closing spec-verifier dispatch — the same trust-model class as the APPROVED marker and loop.md's `status: done` (a model-written flow-moment anchor; the archive gate audits it)
- `## Ask` quotes the user verbatim — interpretation happens against the quote, exactly like index.md R-N entries
- `## Evidence` is **independently sourced** (the dispatched verifier's output), never the implementing conversation's self-report

## Lifecycle

| Stage | Action |
|---|---|
| Start | `/spec:quick` creates the dir + quick.md (`status: in-flight`) |
| Implement | direct edits; concerns rerouted to `## Concerns`, never into code |
| Close | ONE diff-scoped spec-verifier dispatch → Evidence written → `status: done` |
| Archive | normal `/spec:archive`; the check-archive quick branch audits `status: done` + non-empty Evidence |
| Upgrade | `/spec:research` in the same dir; proposal.md presence flips semantics — quick.md stays |

## Anti-patterns

- ❌ Paraphrasing the ask instead of quoting it (kills the anchor)
- ❌ Self-certified Evidence (no verifier dispatch = the change is not done)
- ❌ Deleting quick.md on upgrade (history loss; the precedence rule already makes it inert)
- ❌ Routing full-flow-sized work through quick (the command refuses upfront; the verifier flags it as a finding if it slips through)
- ❌ Model-initiated quick — the tier is user-explicit only, same activation doctrine as the full flow
