# SDD workflow (Codex CLI)

This project uses the sdd spec-driven development workflow. Large changes (>150 lines /
3+ files / new dependency / architecture choice) go through the gated flow instead of
being implemented directly:

```
$spec-research → $spec-ask → ($spec-design) → $spec-propose → [HARD GATE] → $spec-apply → $spec-verify → $spec-archive
```

Rules that bind you, the agent:

- **Never write project source before the HARD GATE is approved.** After emitting the
  `<HARD-GATE>` block at the end of `$spec-propose`, stop and wait for the user. The
  `<!-- APPROVED: ... -->` marker is appended by `$spec-apply` itself — do not add it,
  and never add it on the user's behalf.
- **Artifacts are fixed**: `spec/changes/<name>/` holds research.md, design.md (optional),
  proposal.md, tasks.md (optional), verify.md; project-durable facts go to
  `spec/knowledge.md`. Inventing extra artifact files requires explicit user approval.
- **Verification is independent**: `$spec-verify` spawns the spec-verifier agent
  (`~/.codex/agents/spec-verifier.toml`) with a fresh context. The conversation that
  implemented a change never audits itself.
- **Anti-Cheating**: nothing is "success" without having actually run; bypasses are
  declared as bypasses; another agent's self-reported success gets independently re-run.
- **Stuck Protection**: 3 consecutive failed fixes in one direction → emit the Stuck
  Self-Check block and wait; from the 2nd attempt on, state why the previous one failed.

The gates are enforced by hooks (`~/.codex/sdd-hooks/`), not by this file — attempting to
skip a step gets blocked with the reason. Details: the spec-core skill
(`~/.agents/skills/spec-core/`).
