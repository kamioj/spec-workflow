#!/bin/sh
# Codex port of the /spec:propose gate (POSIX sh twin of check-tbd.ps1 -- keep both in sync;
# the shared fixtures under fixtures/ are the sync contract).
# Trigger: UserPromptSubmit hook (Codex CLI).
# Codex contract (SCHEMA.md): stdin field `prompt`; blocking = stdout
# {"decision":"block","reason":...} + exit 0; invocation form `$spec-propose`.
# No jq dependency: the invocation test runs against the raw JSON (a `$spec-propose` at
# prompt start or after a literal \n); cwd is extracted with sed and un-escaped.
# fail-open: any parsing doubt -> exit 0 with no stdout.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    # $1: reason (may contain newlines -> encode as \n)
    reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    printf '{"decision":"block","reason":"%s"}\n' "$reason"
    exit 0
}

# Invocation (not mention): $spec-propose at the start of the prompt value or of a line inside it.
# In raw JSON the prompt value follows "prompt":" and inner newlines are literal \n.
printf '%s' "$STDIN" | grep -Eq '"prompt":"(\\n|[[:space:]])*\$spec-propose|\\n[[:space:]]*\$spec-propose' || exit 0

# Extract cwd (JSON-escaped: \\ for backslash); un-escape for filesystem use
CWD=$(printf '%s' "$STDIN" | sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
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
    block "SDD: no active change under $CHANGES_DIR (.paused / quick / fix / loop dirs do not count). Start with \$spec-research <direction>. Already researched one? It may sit in a DIFFERENT spec tree (another worktree / the main repo / a subproject) -- hooks only see the session cwd: move it here, or relaunch there"
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected under $CHANGES_DIR ($names). This workflow assumes a single active change -- \$spec-archive the rest (or clean them up) before \$spec-propose"
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
    block "SDD: change '$name' is missing research.md -- run \$spec-research <direction> first.
(gate inspected $CHANGES_DIR; '$name' holds: $found. Not the change you just researched? Yours likely sits in a DIFFERENT spec tree -- another worktree / the main repo / a subproject: hooks only see the session cwd; move it here, or relaunch the session where it lives)"
fi

# Scan ONLY the ## Open [TBD] section: [TBD-N] tokens elsewhere (Practices/Constraints/Decided)
# are provenance citations of a decision point, not open items. List the concrete IDs so the
# user can jump straight into $spec-ask on them.
open_tbds=$(awk '/^## *Open/{grab=1; next} /^## /{grab=0} grab' "$research" | grep -Eo '\[TBD-[0-9]+\]' | sort -u | tr '\n' ' ')
open_tbds=${open_tbds% }
if [ -n "$open_tbds" ]; then
    block "SDD: research.md ($name) has unresolved decision points: $open_tbds. Run \$spec-ask to resolve them first"
fi

exit 0
