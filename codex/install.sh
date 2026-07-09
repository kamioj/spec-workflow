#!/bin/sh
# SDD-for-Codex installer (macOS / Linux / Git Bash). POSIX twin of install.ps1 -- keep in sync.
# Copies: skills -> ~/.agents/skills/, agents -> ~/.codex/agents/, hooks -> ~/.codex/sdd-hooks/,
# and generates ~/.codex/hooks.json from hooks/hooks.json.template.
# Refuses to overwrite an existing ~/.codex/hooks.json (merge by hand instead).
# After installing, Codex must still TRUST the hooks once: open the codex TUI and approve
# them in the hooks browser (untrusted hooks are silently skipped -- see hooks/SCHEMA.md).

set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILLS_DST="$HOME/.agents/skills"
AGENTS_DST="$HOME/.codex/agents"
HOOKS_DST="$HOME/.codex/sdd-hooks"
HOOKS_JSON="$HOME/.codex/hooks.json"

# 1. Skills
mkdir -p "$SKILLS_DST"
for d in "$SRC"/skills/*/; do
    [ -d "$d" ] || continue
    cp -R "$d" "$SKILLS_DST/"
    echo "skill:  $(basename "$d") -> $SKILLS_DST"
done

# 2. Agents
mkdir -p "$AGENTS_DST"
for f in "$SRC"/agents/*.toml; do
    [ -f "$f" ] || continue
    cp "$f" "$AGENTS_DST/"
    echo "agent:  $(basename "$f") -> $AGENTS_DST"
done

# 3. Hook scripts
mkdir -p "$HOOKS_DST"
for f in "$SRC"/hooks/*.ps1 "$SRC"/hooks/*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$HOOKS_DST/"
done
chmod +x "$HOOKS_DST"/*.sh
echo "hooks:  8 gate scripts -> $HOOKS_DST"

# 4. hooks.json (generated with the absolute install path)
if [ -e "$HOOKS_JSON" ]; then
    echo "ERROR: $HOOKS_JSON already exists. Refusing to overwrite -- merge the entries from" >&2
    echo "       $SRC/hooks/hooks.json.template by hand (replace __SDD_HOOKS_DIR__ with $HOOKS_DST)" >&2
    exit 1
fi
sed "s|__SDD_HOOKS_DIR__|$HOOKS_DST|g" "$SRC/hooks/hooks.json.template" > "$HOOKS_JSON"
echo "config: $HOOKS_JSON generated"

echo ''
echo 'Done. One manual step remains: hooks will NOT run until trusted.'
echo 'Open the codex TUI once and approve the SDD hooks in the hooks browser,'
echo 'then verify the gate actually bites: in a project without spec/changes/,'
echo 'send "$spec-apply" -- it must be blocked with an SDD message.'
