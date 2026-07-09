# sdd for Codex CLI

A port of the [sdd spec-driven development plugin](../README.md) to OpenAI Codex CLI.
Same workflow, same hard-gate guarantees, different host. The Claude Code plugin at the
repo root is untouched by this port; everything Codex-specific lives under `codex/`.

Probe-verified against **codex-cli 0.142.1** (2026-07). Codex hook internals are not yet
a stable public contract — after a major Codex update, re-run the probe in
[hooks/SCHEMA.md](hooks/SCHEMA.md) before trusting the gates.

## Install

### Preferred: Codex plugin

Install from a repo URL or local checkout:

```sh
codex plugin marketplace add <repo-url-or-local-path>
codex plugin add spec@spec-workflow
# (verified on codex-cli 0.142.1: the subcommand is `add`, and the plugin must be
#  qualified as <plugin>@<marketplace> unless you pass --marketplace)
```

Then run the setup skill once:

```text
$spec-setup
```

`$spec-setup` installs the bundled `agents/*.toml` files into `~/.codex/agents/` without
overwriting existing different files.

**Then one manual step: trust the hooks.** Plugin-bundled hooks are still non-managed
hooks, so Codex requires one TUI approval. Open the `codex` TUI once and approve the SDD
hooks in the hooks browser. Verify the gate actually bites before relying on it: in a
project with no `spec/changes/`, send `$spec-apply` — it must come back blocked with an
SDD message. An installed-but-silent gate is the worst failure mode this port has.

### Fallback: script installer

Use this path only when plugin install is unavailable or you intentionally want a
user-layer script install:

```sh
# macOS / Linux / Git Bash
sh codex/install.sh

# Windows
pwsh -File codex/install.ps1
```

This copies skills to `~/.agents/skills/`, agents to `~/.codex/agents/`, hook scripts to
`~/.codex/sdd-hooks/`, and generates `~/.codex/hooks.json` (it refuses to overwrite an
existing one — merge by hand from `hooks/hooks.json.template`).

The same hook trust and gate verification step above still applies.

## Usage

Commands are Codex **skills**, invoked with `$` (Codex does not support user-defined
slash commands):

| Claude Code | Codex CLI |
|---|---|
| `/spec:research <direction>` | `$spec-research <direction>` |
| `/spec:ask` | `$spec-ask` |
| `/spec:design` | `$spec-design` |
| `/spec:propose` | `$spec-propose` |
| `/spec:apply` | `$spec-apply` |
| `/spec:verify` | `$spec-verify` |
| `/spec:archive` | `$spec-archive` |
| `/spec:status` / `chat` / `revise` / `workflow` | `$spec-status` / `$spec-chat` / `$spec-revise` / `$spec-workflow` |

The flow, the artifact model (`spec/changes/<name>/research.md` → `proposal.md` →
`verify.md` → archive), the HARD GATE, and the APPROVED-marker contract are identical to
the Claude Code plugin — see the [root README](../README.md).

## What's different on Codex (known degradations)

- **`$spec-ask` is prose-only**: Codex has no structured multiple-choice UI
  (AskUserQuestion), so interrogation happens as numbered options in plain text, one
  question at a time.
- **No heterogeneous peer review**: the Claude-side `--codex` flag (Codex as an
  adversarial second opinion) has no equivalent here — Codex cannot be its own
  heterogeneous reviewer.
- **Hook trust is manual**: one-time TUI approval per hooks.json change (see Install).
  `codex exec --dangerously-bypass-hook-trust` exists for CI/probe use only.
- **Agents are not bundled by Codex plugins**: Codex has no official agent TOML bundle
  mechanism yet. Run `$spec-setup` to copy the plugin's `agents/*.toml` files into
  `~/.codex/agents/` after plugin install.
- **Blocking mechanism differs**: gates block by printing
  `{"decision":"block","reason":"..."}` on stdout, not by `exit 2` (which Codex shows as
  "Failed" but does not block — probe-verified; the docs say otherwise, the probe wins).

## Editing skills / agents / references — edit core/, not these trees

Everything under `codex/skills/` and `codex/agents/` is **generated** from the repo-root
`core/` source tree by `node tools/generate.mjs` (first line of each file says so). Edit
the core file, regenerate, and run `node tools/generate.mjs --check` before releasing —
hand edits here are overwritten by the next generate. Hooks, both manifests, this README,
the install scripts, and `spec-setup` are hand-maintained (not generator-owned).

Local-path marketplaces don't support `codex plugin marketplace upgrade` (Git-only); to
refresh a local install after regenerating: `codex plugin remove spec@spec-workflow`
then `codex plugin add spec@spec-workflow`.

## Editing the gates

Each gate is a pwsh + POSIX sh **twin pair** (`check-*.ps1` / `check-*.sh`) — the pair is
the unit of change. After ANY gate edit, run the shared fixtures against both twins:

```sh
sh codex/hooks/run-fixtures.sh   # must end with fail=0, pwsh + sh both exercised
```

Field-name and blocking-semantics evidence lives in [hooks/SCHEMA.md](hooks/SCHEMA.md).
