---
<!-- host:claude -->
description: Edit a single proposal.md section (why / what / how / risk). A full rewrite goes through /spec:propose. After editing, the HARD GATE must run again
<!-- /host -->
<!-- host:codex -->
description: Edit a single proposal.md section (why / what / how / risk). A full rewrite goes through /spec:propose. After editing, the HARD GATE must run again.
<!-- /host -->
allowed-tools: Read, Edit
---

# /spec:revise

Target section: $ARGUMENTS

## Flow

1. Parse the parameter:

| Parameter | Section edited |
|---|---|
| `why` | `## Why` |
| `what` | `## What` |
| `how` | `## How` |
| `risk` | `## Risk` |
<!-- host:claude -->
| none | ask the user which section to edit (via AskUserQuestion) |
<!-- /host -->
<!-- host:codex -->
| none | ask the user which section to edit by presenting numbered options: "Which section to edit? 1) why  2) what  3) how  4) risk" |
<!-- /host -->

2. Read `spec/changes/<name>/proposal.md`, locate the target section
3. **Remove the old `<!-- APPROVED: ... -->` approval marker** (any revision invalidates the old approval)
4. Edit the target section, **leaving the other sections untouched**
5. **Re-emit the HARD GATE**

## HARD GATE re-emission

Any revision must pass through the HARD GATE again:

```
<HARD-GATE>
=== Proposal revised (<section>) ===
Path: spec/changes/<name>/proposal.md
Changes — same explanation layer as propose's gate, scoped to the edit:
  <the revised decision in one plain sentence>
  Scenario: <what concretely goes wrong without it> / Avoided by: <plain words> / Cost: <the price>
  (never paste the proposal line verbatim; define domain terms at first use)
(the old APPROVED marker has been removed)

Next:
  ✅ Looks good → run /spec:apply to start implementing
     apply will automatically append the new <!-- APPROVED: ... --> marker
  🔧 Edit another section → /spec:revise [why | what | how | risk]
  💭 Want to discuss more → /spec:chat
  🔄 Direction changed, redo research → /spec:research "<new direction>"
</HARD-GATE>
```

**NEVER carry over the old approval state.**

## When to use

- During the HARD GATE wait the user says "in How, change Caffeine to Redis" → `/spec:revise how`
- Mid-implementation you find Risk missed an item → `/spec:revise risk` to add it
- After brainstorming in `/spec:chat` you decide to change Why → `/spec:revise why`

## Boundary with other commands

| Scenario | Use |
|---|---|
| Goal changed, needs fresh research | `/spec:research <new direction>` |
| Just want to talk, touch no file | `/spec:chat` |
| Full rewrite of the proposal | `/spec:propose` (revise edits a single section only; propose has hooks guarding TBD / single-change, revise has no hook) |
| Local edit of one proposal section | `/spec:revise [section]` |

## Anti-patterns

- ❌ Editing a section without re-running the HARD GATE before continuing
- ❌ Not removing the old APPROVED marker (letting the `/spec:apply` hook think it's approved)
- ❌ "Tidying up" other sections while editing one (don't touch what the user didn't ask for)
