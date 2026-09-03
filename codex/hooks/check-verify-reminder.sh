#!/bin/sh
# Codex port of the Stop-event reminder (POSIX sh twin of check-verify-reminder.ps1 --
# keep both in sync; the shared fixtures under fixtures/ are the sync contract).
# Trigger: Stop hook (fires when the Codex agent ends its turn).
# Codex contract (SCHEMA.md): blocking = stdout {"decision":"block","reason":...} + exit 0;
# stop_hook_active is the loop guard (one nudge per stop cycle). Block-on-Stop is assumed
# symmetrical with UserPromptSubmit but not yet observed live -- smoke test must confirm.
# fail-open: any parsing doubt -> exit 0 with no stdout.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

block() {
    reason=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    printf '{"decision":"block","reason":"%s"}\n' "$reason"
    exit 0
}

# Loop guard: a stop hook already fired in this stop cycle -- let the agent stop
printf '%s' "$STDIN" | grep -q '"stop_hook_active":true' && exit 0

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
    # Without this filter an unarchived quick/fix/loop/paused dir inflates the count and
    # silences the single-active window.
    [ -f "$d/.paused" ] && continue
    [ -f "$d/quick.md" ] && [ ! -f "$d/proposal.md" ] && continue
    [ -f "$d/fix.md" ] && [ ! -f "$d/proposal.md" ] && continue
    [ -f "$d/loop.md" ] && [ ! -f "$d/proposal.md" ] && continue
    set -- "$@" "$d"
done

# Only nudge in the unambiguous single-active-change window
[ $# -eq 1 ] || exit 0

change=$1
name=$(basename "$change")

proposal="$change/proposal.md"
[ -f "$proposal" ] || exit 0

# Same marker contract as check-gate: implementation window = APPROVED present
grep -Eiq '<!--[[:space:]]*APPROVED[[:space:]]*[:>]' "$proposal" || exit 0

# A ledger only counts once it has an implementation round (round >= 1). Round 0 is the
# propose-stage critique panel (written BEFORE any code exists) -- treating it as "verified"
# would disarm this reminder for the whole implementation window, letting premature
# turn-endings mid-apply pass silently.
if [ -f "$change/verify.md" ]; then
    grep -Eq '^round:[[:space:]]*[1-9]' "$change/verify.md" && exit 0
fi

block "SDD: change '$name' has an approved proposal but no implementation-round verification (verify.md absent, or holds only the round-0 critique).
If implementation is unfinished (unchecked tasks.md items / What items not landed): CONTINUE implementing -- do not end the turn.
If implementation just finished: run the closing verification now (four dimensions + charter audit) and write the ledger round (see \$spec-verify -- findings with V-N IDs + Evidence).
If you are deliberately pausing (stuck self-check / awaiting a user decision): say so explicitly to the user, then stop."
