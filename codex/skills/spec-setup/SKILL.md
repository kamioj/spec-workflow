---
name: spec-setup
description: Installs the Codex-side SDD agent TOML files from the plugin bundle, reminds the user to trust hooks, and verifies that the SDD gates bite after plugin install.
---

# $spec-setup

## Purpose

Run this once after installing the `sdd` Codex plugin. Codex plugins can bundle skills
and hooks, but there is no official bundled mechanism for `agents/*.toml`, so this skill
guides the agent TOML copy step.

## Agent TOML install

Source files live in the installed plugin at:

```text
${PLUGIN_ROOT}/agents/*.toml
```

Destination:

```text
~/.codex/agents/
```

Process:

1. Resolve `${PLUGIN_ROOT}` to the installed `sdd` plugin root. If it is not available in
   the current execution environment, stop and report that exact observation instead of
   guessing a path.
2. Create `~/.codex/agents/` if it does not exist.
3. For each `${PLUGIN_ROOT}/agents/*.toml`:
   - If the destination file does not exist, copy it.
   - If the destination file exists and is byte-identical, leave it as-is and report it.
   - If the destination file exists and differs, do not overwrite it. Report the source
     and destination paths and ask the user whether to merge or replace.

Do not silently overwrite existing agent files.

## Hook trust

Plugin-bundled hooks are still non-managed hooks. After plugin install, open the Codex
TUI once and trust the SDD hooks in the hooks browser. `codex exec
--dangerously-bypass-hook-trust` is for smoke tests only; it is not a persisted trust
step.

## Gate verification

After trusting hooks, verify the gate bites before relying on the workflow. In a bare
temporary project with no `spec/changes/`, submit:

```text
$spec-apply implement x
```

Expected result: Codex blocks the prompt with an SDD gate message before implementation
starts.
