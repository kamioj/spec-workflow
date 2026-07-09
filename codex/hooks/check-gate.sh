#!/bin/sh
# Codex port of the /spec:apply gate (POSIX sh twin of check-gate.ps1 -- keep both in sync;
# the shared fixtures under fixtures/ are the sync contract).
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex contract (SCHEMA.md): stdin field `prompt`; blocking = stdout
# {"decision":"block","reason":...} + exit 0; invocation form `$spec-apply`.
# Deliberately NOT checked here: the <!-- APPROVED --> marker ($spec-apply appends it
# AFTER this hook fires; requiring it here = happy-path deadlock). check-archive enforces it.
# fail-open: any parsing doubt -> exit 0 with no stdout.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    printf '{"decision":"block","reason":"%s"}\n' "$reason"
    exit 0
}

printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*\$spec-apply|\\n[[:space:]]*\$spec-apply' || exit 0

CWD=$(printf '%s' "$STDIN" | sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
if [ ! -d "$CHANGES_DIR" ]; then
    block 'SDD: no spec/changes/ directory. Start with $spec-research -> $spec-propose'
fi

set --
for d in "$CHANGES_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "archive" ] && continue
    set -- "$@" "$d"
done

if [ $# -eq 0 ]; then
    block 'SDD: no active change. Start with $spec-research -> $spec-propose'
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected ($names). This workflow assumes a single active change -- \$spec-archive the rest (or clean them up) before \$spec-apply (otherwise a draft change blocks the approved one)"
fi

change=$1
name=$(basename "$change")
proposal="$change/proposal.md"

if [ ! -f "$proposal" ]; then
    block "SDD: $name is missing proposal.md. Run \$spec-propose first"
fi

missing=''
for section in '## Why' '## What' '## How' '## Risk'; do
    grep -Eq "^$section" "$proposal" || missing="$missing$section, "
done
if [ -n "$missing" ]; then
    missing=${missing%, }
    block "SDD: proposal.md ($name) is missing section(s): $missing. Run \$spec-revise to complete it, or \$spec-propose to rewrite"
fi

exit 0
