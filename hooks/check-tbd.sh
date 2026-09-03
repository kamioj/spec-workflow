#!/bin/sh
# Claude Code gate for /spec:propose (POSIX sh — one implementation for macOS/Linux sh and
# Windows Git Bash, invoked by hooks.json shell form).
# Claude contract: stdin field `prompt`; blocking = reason on stderr + exit 2; allow = exit 0.
# NEVER print to stdout — the codex twins' stdout-JSON contract does NOT block on Claude Code
# (the fixture runner's wrong-contract canary enforces this at test time).
# cwd comes from $CLAUDE_PROJECT_DIR (exported by Claude Code to hook processes), never parsed
# from stdin JSON: sed cannot decode \uXXXX escapes, so a non-ASCII project path would silently
# disable the gate (critique-panel finding V-2).
# fail-open: any parsing doubt -> exit 0.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    printf '%s\n' "$1" >&2
    exit 2
}

# Invocation (not mention): /spec:propose at the start of the prompt value or of a line
# inside it (inner newlines are literal \n in raw JSON).
printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*/spec:propose|\\n[[:space:]]*/spec:propose' || exit 0

CWD=${CLAUDE_PROJECT_DIR:-}
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
[ -d "$CHANGES_DIR" ] || exit 0

set --
for d in "$CHANGES_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "archive" ] && continue
    # Skip suspended changes and self-auditing tier dirs -- quick/fix/loop without proposal.md
    # (precedence: proposal.md wins -- an upgraded tier dir counts as a normal full change).
    [ -f "$d/.paused" ] && continue
    [ -f "$d/quick.md" ] && [ ! -f "$d/proposal.md" ] && continue
    [ -f "$d/fix.md" ] && [ ! -f "$d/proposal.md" ] && continue
    [ -f "$d/loop.md" ] && [ ! -f "$d/proposal.md" ] && continue
    set -- "$@" "$d"
done

if [ $# -eq 0 ]; then
    block "SDD: no active change under $CHANGES_DIR (.paused / quick / fix / loop dirs do not count). Start with /spec:research <direction>. Already researched one? It may sit in a DIFFERENT spec tree (another worktree / the main repo / a subproject) -- hooks only see the root this session was launched from: move it here, or relaunch there"
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected under $CHANGES_DIR ($names). This workflow assumes a single active change -- /spec:archive the rest (or clean them up) before /spec:propose"
fi

change=$1
name=$(basename "$change")
research="$change/research.md"

if [ ! -f "$research" ]; then
    # Self-diagnosis: name what the gate actually saw, so a change created in a different
    # spec tree (worktree / main repo / subproject) is recognizable at a glance instead of
    # blocking with a misleading unrelated change name (field finding, 0.6.4).
    found=$(ls -A "$change" 2>/dev/null | tr '\n' ' ')
    found=${found% }
    [ -n "$found" ] || found='(empty)'
    block "SDD: change '$name' is missing research.md -- run /spec:research <direction> first.
(gate inspected $CHANGES_DIR; '$name' holds: $found. Not the change you just researched? Yours likely sits in a DIFFERENT spec tree -- another worktree / the main repo / a subproject: hooks only see this root; move it here, or relaunch the session where it lives)"
fi

# Scan ONLY the ## Open [TBD] section: [TBD-N] tokens elsewhere (Practices/Constraints/Decided)
# are provenance citations of a decision point, not open items. List the concrete IDs so the
# user can jump straight into /spec:ask on them.
open_tbds=$(awk '/^## *Open/{grab=1; next} /^## /{grab=0} grab' "$research" | grep -Eo '\[TBD-[0-9]+\]' | sort -u | tr '\n' ' ')
open_tbds=${open_tbds% }
if [ -n "$open_tbds" ]; then
    block "SDD: research.md ($name) has unresolved decision points: $open_tbds. Run /spec:ask to resolve them first"
fi

exit 0
