# Codex hooks — observed schema (probe evidence)

Captured live on **codex-cli 0.142.1** (win32-x64, 2026-07-08) with a stdin-dumping probe
hook. This file is the source of truth for the Codex-side gate scripts; when Codex bumps
versions, re-run the probe before trusting any of this.

## How to re-run the probe

```
# probe.ps1: append FIRED + raw stdin to captured.jsonl, exit 0
# ~/.codex/hooks.json: wire probe to UserPromptSubmit + Stop
codex exec --skip-git-repo-check --dangerously-bypass-hook-trust "reply pong only" </dev/null
```

## UserPromptSubmit stdin (observed verbatim; paths redacted, ids anonymized)

```json
{
  "session_id": "01234567-89ab-7cde-8f01-23456789abcd",
  "turn_id": "01234567-89ab-7cde-8f01-3456789abcde",
  "transcript_path": "C:\\Users\\...\\.codex\\sessions\\2026\\07\\08\\rollout-....jsonl",
  "cwd": "C:\\Users\\...\\probe",
  "hook_event_name": "UserPromptSubmit",
  "model": "gpt-5.5",
  "permission_mode": "bypassPermissions",
  "prompt": "reply pong only"
}
```

**The user-input field is `prompt`** — same name as Claude Code, as it turned out: the old belief that Claude Code uses `user_prompt` was corrected 2026-07-15 by a live stdin capture (see the repo CLAUDE.md hook-contract table). Same trap
class as the Claude-side incident recorded in the root README; the name differs per host.

## Stop stdin (observed verbatim)

Same envelope, plus:

```json
{
  "hook_event_name": "Stop",
  "stop_hook_active": false,
  "last_assistant_message": "pong"
}
```

`stop_hook_active` loop-guard semantics match Claude Code.

## Blocking semantics (the finding that contradicts the docs)

| Mechanism | Docs say | Observed on 0.142.1 |
|---|---|---|
| `exit 2` + stderr | blocks, stderr shown | **does NOT block** — UI shows `hook: UserPromptSubmit Failed`, the prompt still executes |
| stdout `{"decision":"block","reason":"..."}` + exit 0 | (documented as JSON response) | **blocks** — UI shows `hook: UserPromptSubmit Blocked`, the prompt never reaches the model |

Therefore every Codex gate script **emits the JSON decision object on stdout and exits 0**,
for both the block and the allow path (allow = emit nothing, exit 0). Non-zero exits are
reserved for genuine script failures, which Codex treats as fail-open — consistent with
the sdd fail-open convention.

Verified for `UserPromptSubmit` and `Stop` on codex-cli 0.142.1. In the S4 smoke
test (approved proposal, missing `verify.md`), stdout `{"decision":"block","reason":"..."}`
with exit 0 from `Stop` produced `hook: Stop Blocked`. Codex then re-entered
assistant generation with the reminder context, and the next `Stop` completed after the
assistant explicitly paused instead of writing a fake verification ledger.

## Hook handler config (hooks.json)

Struct fields observed in the binary: `type`, `command`, `commandWindows`, `timeout`,
`async`, `statusMessage`. **No `args` array** (unlike Claude Code) — `command` is a single
string, parsed with arguments (`pwsh -NoProfile -File x.ps1` spawns correctly).
`commandWindows` overrides `command` on Windows: put the sh invocation in `command` and
the pwsh invocation in `commandWindows` and one hooks.json serves both platforms.

## Trust model

Hooks do not run until trusted. Observed behaviors:

- Untrusted hooks are **silently skipped** in `codex exec` (no log, no error) — exactly the
  silent-gate failure mode the proposal warns about. After installing, always verify with a
  live blocked invocation.
- `codex exec --dangerously-bypass-hook-trust` runs enabled hooks without persisted trust
  (probe/CI use only).
- Interactive trust: the TUI has a hooks browser; approving there persists a
  `trusted_hash` (config `[hooks]` state). Overriding `-c hooks.enabled=true -c
  hooks.trusted_hash=<sha256-of-file>` did **not** unlock execution in exec mode — the
  hash is over a normalized hook identity (binary: "normalized hook identity should
  serialize to TOML"), not the raw file. Do not ship hash-guessing; instruct users to
  approve via the TUI once.

## Plugin-bundled hooks

Smoke run on **codex-cli 0.142.1** (Windows, 2026-07-09 local / CLI log UTC
2026-07-08T17:40Z):

- Marketplace install from the repo root worked:
  `codex plugin marketplace add <repo-root>` reported
  `Added marketplace spec-workflow`; `codex plugin add spec@spec-workflow` reported
  `Installed plugin root: C:\Users\...\.codex\plugins\cache\spec-workflow\spec\0.1.0`.
- On this binary, `codex plugin install spec` was **not** accepted
  (`unrecognized subcommand 'install'`); the working command was `codex plugin add
  spec@spec-workflow` after the marketplace was added.
- `codex/hooks/hooks.json` bundled through `codex/.codex-plugin/plugin.json` was
  discovered after plugin install. With user-layer `~/.codex/hooks.json` temporarily
  renamed away, the non-JSON smoke output included:

```text
hook: UserPromptSubmit Completed
hook: Stop
hook: Stop Blocked
```

- `${PLUGIN_ROOT}` expanded correctly in `commandWindows`. Evidence: the Stop hook loaded
  plugin resources from the installed cache root:

```text
C:\Users\...\.codex\plugins\cache\spec-workflow\spec\0.1.0\skills\spec-verify\SKILL.md
```

- Windows PowerShell 7 rejects literal `</dev/null` (`The '<' operator is reserved for
  future use`). For Windows smoke, pass the prompt as a normal argument and rely on an
  external timeout.
- Direct `codex exec "$spec-apply implement x"` on this build produced an empty turn
  (`input_tokens:0`) before hook evidence could be observed. A Stop-hook smoke with an
  approved proposal and missing `verify.md` was used to verify plugin hook discovery and
  `${PLUGIN_ROOT}` expansion.

## Placement

`~/.codex/hooks.json` (user layer) is discovered; `.codex/hooks.json` (project layer)
exists in the layer list (system/user/project/mdm/plugin) but requires per-project trust.
The install scripts target the user layer.
