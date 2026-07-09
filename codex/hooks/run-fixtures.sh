#!/bin/sh
# Shared fixture runner for the SDD Codex gates -- the sync contract between the pwsh and
# sh twins: every case is fed (same stdin JSON, same project state) to BOTH implementations
# and both must produce the same verdict (block / allow). Run after ANY gate edit.
#
#   sh codex/hooks/run-fixtures.sh
#
# Requires: sh + coreutils; pwsh optional (skipped with a warning if absent -- but a gate
# edit is only DONE when both twins pass).

set -u
HOOKS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT="${TMPDIR:-/tmp}/sdd-codex-fixtures-$$"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT
# On Git Bash/MSYS, pwsh cannot resolve /tmp-style paths -- convert to C:/-style so the
# same cwd works for both twins
command -v cygpath >/dev/null 2>&1 && TMP_ROOT=$(cygpath -m "$TMP_ROOT")

HAVE_PWSH=0
command -v pwsh >/dev/null 2>&1 && HAVE_PWSH=1
[ $HAVE_PWSH -eq 0 ] && echo "WARN: pwsh not found -- testing sh twins only (NOT a full pass)"

PASS=0
FAIL=0

# run_case <name> <hook-basename> <expected: block|allow> <stdin-json>
run_case() {
    name=$1; hook=$2; expected=$3; stdin=$4

    for impl in sh ps1; do
        [ "$impl" = "ps1" ] && [ $HAVE_PWSH -eq 0 ] && continue
        if [ "$impl" = "sh" ]; then
            out=$(printf '%s' "$stdin" | sh "$HOOKS_DIR/$hook.sh" 2>/dev/null)
        else
            out=$(printf '%s' "$stdin" | pwsh -NoProfile -NonInteractive -File "$HOOKS_DIR/$hook.ps1" 2>/dev/null)
        fi
        case "$out" in
            *'"decision":"block"'*|*'"decision": "block"'*) got=block ;;
            '') got=allow ;;
            *) got="unexpected-output" ;;
        esac
        if [ "$got" = "$expected" ]; then
            PASS=$((PASS+1))
            echo "PASS  $name [$impl]"
        else
            FAIL=$((FAIL+1))
            echo "FAIL  $name [$impl]  expected=$expected got=$got"
            [ -n "$out" ] && echo "      stdout: $out"
        fi
    done
}

# mkproj <subdir> -> creates a project skeleton, echoes its path
mkproj() {
    p="$TMP_ROOT/$1"
    mkdir -p "$p/spec/changes"
    printf '%s' "$p"
}

json() {
    # json <cwd> <prompt-with-\n-as-literal-backslash-n> [extra]
    printf '{"session_id":"s","turn_id":"t","transcript_path":null,"cwd":"%s","hook_event_name":"UserPromptSubmit","model":"m","permission_mode":"default","prompt":"%s"%s}' "$1" "$2" "${3:-}"
}
json_stop() {
    # json_stop <cwd> <stop_hook_active: true|false>
    printf '{"session_id":"s","turn_id":"t","transcript_path":null,"cwd":"%s","hook_event_name":"Stop","model":"m","permission_mode":"default","stop_hook_active":%s,"last_assistant_message":"done"}' "$1" "$2"
}

FULL_PROPOSAL='# Proposal: x

## Why
w

## What
- item | verify: v

## How
h

## Risk
r
'

# ---- check-gate ----
P=$(mkproj gate-no-changes-dir); rm -rf "$P/spec"
run_case gate-no-spec-dir          check-gate block "$(json "$P" '$spec-apply')"

P=$(mkproj gate-no-active)
run_case gate-no-active-change     check-gate block "$(json "$P" '$spec-apply')"

P=$(mkproj gate-no-proposal); mkdir -p "$P/spec/changes/my-change"
run_case gate-missing-proposal     check-gate block "$(json "$P" '$spec-apply')"

P=$(mkproj gate-partial); mkdir -p "$P/spec/changes/my-change"
printf '## Why\nw\n\n## What\nx\n' > "$P/spec/changes/my-change/proposal.md"
run_case gate-missing-sections     check-gate block "$(json "$P" '$spec-apply')"

P=$(mkproj gate-ok); mkdir -p "$P/spec/changes/my-change"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/my-change/proposal.md"
run_case gate-happy-path           check-gate allow "$(json "$P" '$spec-apply')"
run_case gate-mention-not-invoke   check-gate allow "$(json "$P" 'what does $spec-apply do?')"
run_case gate-invoke-second-line   check-gate block "$(json "$(mkproj gate-2nd)" 'some context\n$spec-apply')"

P=$(mkproj gate-multi); mkdir -p "$P/spec/changes/a" "$P/spec/changes/b"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/a/proposal.md"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/b/proposal.md"
run_case gate-multiple-changes     check-gate block "$(json "$P" '$spec-apply')"

# ---- check-tbd ----
P=$(mkproj tbd-open); mkdir -p "$P/spec/changes/c"
printf '# R\n\n## Open [TBD]\n- [TBD-1] pick one\n\n## Decided\n(none)\n' > "$P/spec/changes/c/research.md"
run_case tbd-open-blocks           check-tbd block "$(json "$P" '$spec-propose')"

P=$(mkproj tbd-clear); mkdir -p "$P/spec/changes/c"
printf '# R\n\n## Open [TBD]\n(none)\n\n## Decided\n- [DEC-1] chosen | source [TBD-1] | reason\n' > "$P/spec/changes/c/research.md"
run_case tbd-decided-only-allows   check-tbd allow "$(json "$P" '$spec-propose')"
run_case tbd-mention-not-invoke    check-tbd allow "$(json "$P" 'explain $spec-propose please')"

# ---- check-archive ----
P=$(mkproj arch-unapproved); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-no-approved       check-archive block "$(json "$P" '$spec-archive')"
run_case archive-force-overrides   check-archive allow "$(json "$P" '$spec-archive force')"

# V-1 regression: "force" as a word in the cwd PATH (not the prompt) must NOT trigger the override
P=$(mkproj arch-force-dir/proj); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-force-in-cwd-blocks check-archive block "$(json "$P" '$spec-archive')"

P=$(mkproj arch-ok); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-approved-allows   check-archive allow "$(json "$P" '$spec-archive')"

P=$(mkproj arch-tasks); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf '# Tasks\n- [ ] 1. unfinished\n' > "$P/spec/changes/c/tasks.md"
run_case archive-unchecked-tasks   check-archive block "$(json "$P" '$spec-archive')"

# ---- check-verify-reminder (Stop) ----
P=$(mkproj rem-nudge); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case reminder-nudges           check-verify-reminder block "$(json_stop "$P" false)"
run_case reminder-loop-guard       check-verify-reminder allow "$(json_stop "$P" true)"

P=$(mkproj rem-ledger); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf '# ledger\n' > "$P/spec/changes/c/verify.md"
run_case reminder-ledger-satisfied check-verify-reminder allow "$(json_stop "$P" false)"

P=$(mkproj rem-unapproved); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case reminder-not-approved     check-verify-reminder allow "$(json_stop "$P" false)"

echo "----"
echo "pass=$PASS fail=$FAIL"
[ $FAIL -eq 0 ] || exit 1
exit 0
