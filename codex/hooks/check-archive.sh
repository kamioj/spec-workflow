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

printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*\$spec-(archive|ship)|\\n[[:space:]]*\$spec-(archive|ship)' || exit 0

# Deliberate override: the user explicitly said force / abandoned -- scoped to the
# prompt VALUE only (mirroring the pwsh twin's $data.prompt check); scanning the whole
# raw JSON would let a cwd path containing "force" silently bypass the gate (V-1)
PROMPT_VAL=$(printf '%s' "$STDIN" | sed -n 's/.*"prompt":"\([^"]*\)".*/\1/p')
printf '%s' "$PROMPT_VAL" | grep -Eiq '\bforce\b|\babandon(ed)?\b' && exit 0

CWD=$(printf '%s' "$STDIN" | sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"

# $spec-ship invocation: precondition audit ONLY (fix batch exists with >=1 entry).
# Deliberately NOT checked here: status: shipped / ## Audit -- ship itself writes them
# AFTER this hook fires (requiring them here = the pre-0.2.3 happy-path deadlock shape);
# they are audited on the $spec-archive path below instead.
if printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*\$spec-ship|\\n[[:space:]]*\$spec-ship'; then
    FIXMD="$CHANGES_DIR/fixes/fix.md"
    if [ ! -f "$FIXMD" ]; then
        block 'SDD: no fix batch to ship -- start one with $spec-fix'
    fi
    if [ -f "$CHANGES_DIR/fixes/proposal.md" ]; then
        block 'SDD: the fixes dir has grown a proposal.md -- it is a full change now (precedence: proposal.md wins); close it via $spec-verify + $spec-archive'
    fi
    fentries=$(grep -Ec '^## F-[0-9]+' "$FIXMD") || fentries=0
    if [ "$fentries" -eq 0 ]; then
        block 'SDD: the fix batch is empty (no F-N entries) -- nothing to ship'
    fi
    exit 0
fi

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

# $spec-loop change: no proposal.md by design — the ledger is the flow record. Trust
# model (0.5.1): status: done is written by the final-acceptance turn, the same class of
# flow-moment anchor as the APPROVED marker.
if [ -f "$change/loop.md" ]; then
    lstatus=$(sed -n 's/^status:[[:space:]]*//p' "$change/loop.md" | head -1 | sed 's/#.*//' | tr -d '[:space:]')
    lacc=$(awk '/^## Acceptance[[:space:]]*$/ && !seen {f=1; seen=1; next} /^## /{f=0} f' "$change/loop.md")
    lunchecked=$(printf '%s\n' "$lacc" | grep -c '^- \[ \]')
    lchecked=$(printf '%s\n' "$lacc" | grep -c '^- \[[xX]\]')
    if [ "$lstatus" = "done" ] && [ "$lunchecked" -eq 0 ] && [ "$lchecked" -ge 1 ]; then
        exit 0
    fi
    block "SDD: archive blocked for '$name' -- the loop is not finished:
  - loop.md must have status: done AND a fully checked ## Acceptance list (run the final acceptance via \$spec-loop)
Or archive deliberately:
  \"\$spec-archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"\$spec-archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
fi

# $spec-quick change (quick.md present, proposal.md absent -- precedence: proposal.md wins,
# so an upgraded quick dir falls through to the normal APPROVED audit below): light-tier
# flow record -- status: done + non-empty Evidence = flow honored (same trust model as the
# loop branch above).
if [ -f "$change/quick.md" ] && [ ! -f "$change/proposal.md" ]; then
    qstatus=$(sed -n 's/^status:[[:space:]]*//p' "$change/quick.md" | head -1 | sed 's/#.*//' | tr -d '[:space:]')
    qev=$(awk '/^## Evidence[[:space:]]*$/ && !seen {f=1; seen=1; next} /^## /{f=0} f' "$change/quick.md" | grep -c '[^[:space:]]') || qev=0
    if [ "$qstatus" = "done" ] && [ "$qev" -ge 1 ]; then
        exit 0
    fi
    block "SDD: archive blocked for '$name' -- the quick change is not finished:
  - quick.md must have status: done AND a non-empty ## Evidence section (legacy pre-0.6.0 quick change; if it cannot be finished, archive deliberately below)
Or archive deliberately:
  \"\$spec-archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"\$spec-archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
fi

# $spec-fix batch (fix.md present, proposal.md absent -- precedence: proposal.md wins, so
# an upgraded fixes dir falls through to the normal APPROVED audit below): streaming
# light-tier ledger -- status: shipped + non-empty Audit = the batch went through
# $spec-ship's audit (same trust model as the loop/quick branches).
if [ -f "$change/fix.md" ] && [ ! -f "$change/proposal.md" ]; then
    fstatus=$(sed -n 's/^status:[[:space:]]*//p' "$change/fix.md" | head -1 | sed 's/#.*//' | tr -d '[:space:]')
    fau=$(awk '/^## Audit[[:space:]]*$/ && !seen {f=1; seen=1; next} /^## /{f=0} f' "$change/fix.md" | grep -c '[^[:space:]]') || fau=0
    if [ "$fstatus" = "shipped" ] && [ "$fau" -ge 1 ]; then
        exit 0
    fi
    block "SDD: archive blocked for '$name' -- the fix batch is not shipped:
  - fix.md must have status: shipped AND a non-empty ## Audit section (close the batch via \$spec-ship)
Or archive deliberately:
  \"\$spec-archive force\"     -- archive as-is; the reason gets recorded in retrospect.md
  \"\$spec-archive abandoned\" -- drop the direction; archived as *-abandoned with ABANDONED.md"
fi

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
