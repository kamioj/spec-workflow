#!/bin/sh
# Claude Code gate for /spec:apply (POSIX sh — one implementation for macOS/Linux sh and
# Windows Git Bash, invoked by hooks.json shell form).
# Claude contract: stdin field `prompt`; blocking = reason on stderr + exit 2; allow = exit 0.
# NEVER print to stdout (see check-tbd.sh header; fixture canary enforces this).
# cwd from $CLAUDE_PROJECT_DIR only — never parsed from stdin JSON (\uXXXX trap, V-2).
# Deliberately NOT checked here: the <!-- APPROVED --> marker (/spec:apply appends it AFTER
# this hook fires; requiring it here = happy-path deadlock). check-archive enforces it.
# fail-open: any parsing doubt -> exit 0.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    printf '%s\n' "$1" >&2
    exit 2
}

printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*/spec:apply|\\n[[:space:]]*/spec:apply' || exit 0

CWD=${CLAUDE_PROJECT_DIR:-}
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
if [ ! -d "$CHANGES_DIR" ]; then
    block 'SDD: no spec/changes/ directory. Start with /spec:research -> /spec:propose
(note: hooks resolve spec/ at the project root Claude was launched from -- a spec/ tree anywhere else (a subdirectory, another worktree, the main repo) is invisible to every gate: move it to this root, or relaunch Claude where that tree lives)'
fi

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
    block "SDD: no active change under $CHANGES_DIR (.paused / quick / fix / loop dirs do not count). Start with /spec:research -> /spec:propose. Already have one? It may sit in a DIFFERENT spec tree (another worktree / the main repo / a subproject) -- hooks only see the root this session was launched from: move it here, or relaunch there"
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected under $CHANGES_DIR ($names). This workflow assumes a single active change -- /spec:archive the rest (or clean them up) before /spec:apply (otherwise a draft change blocks the approved one)"
fi

change=$1
name=$(basename "$change")
proposal="$change/proposal.md"

if [ ! -f "$proposal" ]; then
    # Self-diagnosis: name what the gate actually saw, so a change created in a different
    # spec tree (worktree / main repo / subproject) is recognizable at a glance (0.6.4).
    found=$(ls -A "$change" 2>/dev/null | tr '\n' ' ')
    found=${found% }
    [ -n "$found" ] || found='(empty)'
    block "SDD: change '$name' is missing proposal.md -- run /spec:propose first.
(gate inspected $CHANGES_DIR; '$name' holds: $found. Not the change you meant? Yours likely sits in a DIFFERENT spec tree -- another worktree / the main repo / a subproject: hooks only see this root; move it here, or relaunch the session where it lives)"
fi

missing=''
for section in '## Why' '## What' '## How' '## Risk'; do
    grep -Eq "^$section" "$proposal" || missing="$missing$section, "
done
if [ -n "$missing" ]; then
    missing=${missing%, }
    block "SDD: proposal.md ($name) is missing section(s): $missing. Run /spec:revise to complete it, or /spec:propose to rewrite"
fi

exit 0
