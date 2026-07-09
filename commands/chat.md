---
description: Discussion mode. Everything said during this mode is treated as thinking material only — no documents are touched. Use for brainstorming directions, or to talk through concerns about a proposal before deciding how to change it.
allowed-tools: Read
---
<!-- GENERATED from core/commands/chat.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# /spec:chat

Topic: $ARGUMENTS

## Entering discussion mode

Everything the user says during this mode **is treated as thinking material — no documents are touched**.
- Does not write research.md
- Does not write proposal.md
- Does not call /spec:revise
- Does not write project source code

May Read existing artifacts for discussion context.

## Value

Makes "discussion mode" an explicit state. Prevents Claude from automatically editing documents when you share feedback — this is the SDD workflow's "safe pause zone".

## Exit conditions

The user issues a clear command to switch to another mode:

| User says | Transition to |
|---|---|
| "update the proposal based on what we just discussed" / "revise section X" | `/spec:revise [section]` |
| "research X again" / "look into Y" | `/spec:research <direction>` |
| "we just surfaced N TBDs — ask me about them" | `/spec:ask` |
| "let's draw the architecture" | `/spec:design` |
| "let's pick this up tomorrow" / "leave it for now" | stay in chat mode |

**No explicit switch command → stay in chat mode and keep talking**.

## Anti-patterns

- ❌ User shares a view → immediately editing the proposal (that is not chat, it is overstepping)
- ❌ Presenting options A / B / C → picking one without asking the user's preference (that is `/spec:ask`'s job)
- ❌ Drifting into writing code during a chat session (Write/Edit on project source is NEVER allowed in chat mode)
- ❌ Wrapping up with a "meeting notes" md file (no touching documents means no touching documents)

## Boundaries with other commands

| Command | Touches proposal | Touches research | Signal to Claude |
|---|---|---|---|
| `/spec:chat` | ❌ | ❌ | "just talk, don't act yet" |
| `/spec:ask` | ❌ | ✅ (TBD→Decided) | "structurally ask me about preference-driven decisions" |
| `/spec:revise [seg]` | ✅ (partial) | ❌ | "I know what I want to change in section X" |
| `/spec:propose` | ✅ (full) | ❌ | "write or rewrite from scratch" |
