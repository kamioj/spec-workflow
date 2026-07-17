#!/bin/sh
# Claude Code gate for /spec:archive (POSIX sh — one implementation for macOS/Linux sh and
# Windows Git Bash, invoked by hooks.json shell form).
# Claude contract: stdin field `prompt`; blocking = reason on stderr + exit 2; allow = exit 0.
# NEVER print to stdout (see check-tbd.sh header; fixture canary enforces this).
# cwd from $CLAUDE_PROJECT_DIR only — never parsed from stdin JSON (\uXXXX trap, V-2).
# Audits the single active change (no APPROVED marker / unchecked tasks / no proposal);
# override with "force" or "abandon(ed)" in the prompt VALUE only (a cwd containing "force"
# must not bypass — original finding V-1). Does NOT block on multiple active changes --
# archiving is exactly how you get back down to one.
# fail-open: any parsing doubt -> exit 0.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    printf '%s\n' "$1" >&2
    exit 2
}

printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*/spec:archive|\\n[[:space:]]*/spec:archive' || exit 0

# Deliberate override — scoped to the prompt VALUE only, never the whole raw JSON
PROMPT_VAL=$(printf '%s' "$STDIN" | sed -n 's/.*"prompt":"\([^"]*\)".*/\1/p')
printf '%s' "$PROMPT_VAL" | grep -Eiq '\bforce\b|\babandon(ed)?\b' && exit 0

CWD=${CLAUDE_PROJECT_DIR:-}
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
if [ ! -d "$CHANGES_DIR" ]; then
    block 'SDD: no spec/changes/ directory -- nothing to archive'
fi

set --
for d in "$CHANGES_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "archive" ] && continue
    set -- "$@" "$d"
done

if [ $# -eq 0 ]; then
    block 'SDD: no active change -- nothing to archive'
fi

# Multiple active changes: let it through; /spec:archive asks which one to archive
[ $# -gt 1 ] && exit 0

change=$1
name=$(basename "$change")

# /spec:loop change: no proposal.md by design — the ledger is the flow record. Trust
# model (0.5.1): status: done is written by the final-acceptance turn, the same class of
# flow-moment anchor as the APPROVED marker (both are model-written text; this gate
# guards against a bypassed flow, not against forgery).
if [ -f "$change/loop.md" ]; then
    lstatus=$(sed -n 's/^status:[[:space:]]*//p' "$change/loop.md" | head -1 | sed 's/#.*//' | tr -d '[:space:]')
    lacc=$(awk '/^## Acceptance[[:space:]]*$/ && !seen {f=1; seen=1; next} /^## /{f=0} f' "$change/loop.md")
    lunchecked=$(printf '%s\n' "$lacc" | grep -c '^- \[ \]')
    lchecked=$(printf '%s\n' "$lacc" | grep -c '^- \[[xX]\]')
    if [ "$lstatus" = "done" ] && [ "$lunchecked" -eq 0 ] && [ "$lchecked" -ge 1 ]; then
        exit 0
    fi
    block "SDD: archive blocked for '$name' -- the loop is not finished:
  - loop.md must have status: done AND a fully checked ## Acceptance list (run the final acceptance via /spec:loop)
Or archive deliberately:
  \"/spec:archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"/spec:archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
fi

findings=''

proposal="$change/proposal.md"
if [ -f "$proposal" ]; then
    # Only the <!-- APPROVED: --> comment form counts (bare text mentioning the word must not)
    if ! grep -Eiq '<!--[[:space:]]*APPROVED[[:space:]]*[:>]' "$proposal"; then
        findings="$findings  - proposal.md has no APPROVED marker -- the HARD GATE was bypassed (code written without /spec:apply?)
"
    fi
else
    findings="$findings  - no proposal.md -- research-only change (pausing or dropping a direction?)
"
fi

tasks="$change/tasks.md"
if [ -f "$tasks" ]; then
    unchecked=$(grep -Ec '^[[:space:]]*- \[ \]' "$tasks") || unchecked=0
    if [ "$unchecked" -gt 0 ]; then
        findings="$findings  - tasks.md has $unchecked unchecked item(s) -- archiving unfinished work
"
    fi
fi

[ -z "$findings" ] && exit 0

block "SDD: archive blocked for '$name' -- this change bypassed the flow:
${findings}Fix first (/spec:apply to finish, /spec:verify to verify), or archive deliberately:
  \"/spec:archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"/spec:archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
