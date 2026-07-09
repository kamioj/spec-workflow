#!/bin/sh
# Codex port of the /spec:archive gate (POSIX sh twin of check-archive.ps1 -- keep both in
# sync; the shared fixtures under fixtures/ are the sync contract).
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex contract (SCHEMA.md): stdin field `prompt`; blocking = stdout
# {"decision":"block","reason":...} + exit 0; invocation form `$spec-archive`.
# Audits the single active change (no APPROVED marker / unchecked tasks / no proposal);
# override with "force" or "abandon(ed)" in the prompt. Does NOT block on multiple active
# changes -- archiving is exactly how you get back down to one.
# fail-open: any parsing doubt -> exit 0 with no stdout.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    printf '{"decision":"block","reason":"%s"}\n' "$reason"
    exit 0
}

printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*\$spec-archive|\\n[[:space:]]*\$spec-archive' || exit 0

# Deliberate override: the user explicitly said force / abandoned -- scoped to the
# prompt VALUE only (mirroring the pwsh twin's $data.prompt check); scanning the whole
# raw JSON would let a cwd path containing "force" silently bypass the gate (V-1)
PROMPT_VAL=$(printf '%s' "$STDIN" | sed -n 's/.*"prompt":"\([^"]*\)".*/\1/p')
printf '%s' "$PROMPT_VAL" | grep -Eiq '\bforce\b|\babandon(ed)?\b' && exit 0

CWD=$(printf '%s' "$STDIN" | sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
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

# Multiple active changes: let it through; $spec-archive asks which one to archive
[ $# -gt 1 ] && exit 0

change=$1
name=$(basename "$change")
findings=''

proposal="$change/proposal.md"
if [ -f "$proposal" ]; then
    # Same marker contract as the pwsh twin: only the <!-- APPROVED: --> comment form counts
    if ! grep -Eiq '<!--[[:space:]]*APPROVED[[:space:]]*[:>]' "$proposal"; then
        findings="$findings  - proposal.md has no APPROVED marker -- the HARD GATE was bypassed (code written without \$spec-apply?)
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
${findings}Fix first (\$spec-apply to finish, \$spec-verify to verify), or archive deliberately:
  \"\$spec-archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"\$spec-archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
