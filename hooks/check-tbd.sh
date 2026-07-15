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
    set -- "$@" "$d"
done

if [ $# -eq 0 ]; then
    block 'SDD: no active change. Start with /spec:research <direction>'
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected ($names). This workflow assumes a single active change -- /spec:archive the rest (or clean them up) before /spec:propose"
fi

change=$1
name=$(basename "$change")
research="$change/research.md"

if [ ! -f "$research" ]; then
    block "SDD: $name is missing research.md. Run /spec:research <direction> first"
fi

# Strip the ## Decided section (resolved citations, not open items), then scan for [TBD-N].
if awk '/^## *Decided/{skip=1; next} /^## /{skip=0} !skip' "$research" | grep -Eq '\[TBD-[0-9]+\]'; then
    block "SDD: research.md ($name) has unresolved [TBD] decision points. Run /spec:ask to resolve them first"
fi

exit 0
