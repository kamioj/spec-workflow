#!/bin/sh
# Claude Code Stop-event reminder (POSIX sh — one implementation for macOS/Linux sh and
# Windows Git Bash, invoked by hooks.json shell form).
# Reminder, not gate: fires when Claude ends its turn; if the single active change has an
# APPROVED proposal but no verify.md ledger, exit 2 nudges Claude back to run the closing
# verification. stop_hook_active is the loop guard (one nudge per stop cycle).
# Claude contract: blocking = reason on stderr + exit 2; allow = exit 0. NEVER print to stdout.
# cwd from $CLAUDE_PROJECT_DIR only — never parsed from stdin JSON (\uXXXX trap, V-2).
# fail-open: any parsing doubt -> exit 0.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    printf '%s\n' "$1" >&2
    exit 2
}

# Loop guard: a stop hook already fired in this stop cycle -- let the turn end
printf '%s' "$STDIN" | grep -q '"stop_hook_active":true' && exit 0

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

# Only nudge in the unambiguous single-active-change window
[ $# -eq 1 ] || exit 0

change=$1
name=$(basename "$change")

proposal="$change/proposal.md"
[ -f "$proposal" ] || exit 0

# Same marker contract as check-archive: implementation window = APPROVED present
grep -Eiq '<!--[[:space:]]*APPROVED[[:space:]]*[:>]' "$proposal" || exit 0

# A ledger only counts once it has an implementation round (round >= 1). Round 0 is the
# propose-stage critique panel (written BEFORE any code exists) -- treating it as "verified"
# would disarm this reminder for the whole implementation window, letting premature
# turn-endings mid-apply pass silently (the 0.4.0-0.4.2 regression).
if [ -f "$change/verify.md" ]; then
    grep -Eq '^round:[[:space:]]*[1-9]' "$change/verify.md" && exit 0
fi

block "SDD: change '$name' has an approved proposal but no implementation-round verification (verify.md absent, or holds only the round-0 critique).
If implementation is unfinished (unchecked tasks.md items / What items not landed): CONTINUE implementing -- do not end the turn.
If implementation just finished: run the closing three-dimension verification now and write the ledger round (see /spec:verify -- findings with V-N IDs + Evidence).
If you are deliberately pausing (stuck self-check / awaiting a user decision): say so explicitly to the user, then stop."
