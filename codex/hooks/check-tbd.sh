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
    set -- "$@" "$d"
done

if [ $# -eq 0 ]; then
    block 'SDD: no active change. Start with $spec-research <direction>'
fi

if [ $# -gt 1 ]; then
    names=''
    for d in "$@"; do names="$names$(basename "$d"), "; done
    names=${names%, }
    block "SDD: multiple active changes detected ($names). This workflow assumes a single active change -- \$spec-archive the rest (or clean them up) before \$spec-propose"
fi

change=$1
name=$(basename "$change")
research="$change/research.md"

if [ ! -f "$research" ]; then
    block "SDD: $name is missing research.md. Run \$spec-research <direction> first"
fi

# Strip the ## Decided section (resolved citations, not open items), then scan for [TBD-N].
# Backstop: catches [TBD-N] buried in any non-Decided section even without an ## Open heading.
if awk '/^## *Decided/{skip=1; next} /^## /{skip=0} !skip' "$research" | grep -Eq '\[TBD-[0-9]+\]'; then
    block "SDD: research.md ($name) has unresolved [TBD] decision points. Run \$spec-ask to resolve them first"
fi

exit 0
