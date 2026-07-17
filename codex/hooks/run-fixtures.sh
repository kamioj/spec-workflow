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
printf -- '---\nround: 1\nconclusion: pass\n---\n# ledger\n' > "$P/spec/changes/c/verify.md"
run_case reminder-ledger-satisfied check-verify-reminder allow "$(json_stop "$P" false)"

# 0.4.x regression guard: a round-0 (propose-stage critique) ledger must NOT satisfy the
# reminder -- the implementation window still needs its own verification round
P=$(mkproj rem-round0); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf -- '---\nround: 0\nstage: propose\nconclusion: pass\n---\n# ledger\n' > "$P/spec/changes/c/verify.md"
run_case reminder-round0-nudges    check-verify-reminder block "$(json_stop "$P" false)"

P=$(mkproj rem-unapproved); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case reminder-not-approved     check-verify-reminder allow "$(json_stop "$P" false)"

# ---- loop-driver (Stop DRIVER — reinject = {"decision":"block",...}, notice =
#       {"systemMessage":...} without decision, quiet = empty stdout; contract re-probed
#       on codex-cli 0.144.3, see SCHEMA.md "Stop re-injection") ----

LOOP_RUNNING='---
goal: g
status: running
max_rounds: 10
---
# Loop: g

## Acceptance
- [ ] A-1 thing (verify: x)
- [x] A-2 done (verify: y)

## Rounds
### Round 1
#### Plan
p
#### Retrospect
lesson; next A-1

## Lessons
'

# run_driver_case <name> <expected: reinject|notice|quiet> <project> <state: - = none> <stdin> [require] [forbid]
# The state file is reset before EACH twin so both implementations see identical input.
run_driver_case() {
    name=$1; expected=$2; proj=$3; state=$4; stdin=$5; require=${6:-}; forbid=${7:-}
    sdir="$proj/spec/changes/g"
    for impl in sh ps1; do
        [ "$impl" = "ps1" ] && [ $HAVE_PWSH -eq 0 ] && continue
        if [ "$state" = "-" ]; then rm -f "$sdir/.loop-state" 2>/dev/null
        else printf '%s' "$state" > "$sdir/.loop-state"; fi
        if [ "$impl" = "sh" ]; then
            out=$(printf '%s' "$stdin" | sh "$HOOKS_DIR/loop-driver.sh" 2>/dev/null)
        else
            out=$(printf '%s' "$stdin" | pwsh -NoProfile -NonInteractive -File "$HOOKS_DIR/loop-driver.ps1" 2>/dev/null)
        fi
        code=$?
        if [ "$code" -ne 0 ]; then got="exit-$code"
        else
            case "$out" in
                *'"decision":"block"'*) got=reinject ;;
                '')                     got=quiet ;;
                *'"systemMessage"'*)    got=notice ;;
                *)                      got=unexpected-output ;;
            esac
        fi
        if [ -n "$forbid" ]; then
            case "$out" in *"$forbid"*) got=forbidden-leak ;; esac
        fi
        if [ -n "$require" ] && [ "$got" = "$expected" ]; then
            case "$out" in *"$require"*) : ;; *) got="missing-required-text" ;; esac
        fi
        if [ "$got" = "$expected" ]; then
            PASS=$((PASS+1)); echo "PASS  $name [$impl]"
        else
            FAIL=$((FAIL+1)); echo "FAIL  $name [$impl]  expected=$expected got=$got"
            [ -n "$out" ] && echo "      stdout: $out" | head -2
        fi
    done
}

# run_assert <name> <shell-function> — generic named assertion, participates in name sync.
run_assert() {
    name=$1; fn=$2
    if "$fn" >/dev/null 2>&1; then
        PASS=$((PASS+1)); echo "PASS  $name"
    else
        FAIL=$((FAIL+1)); echo "FAIL  $name  (assertion function $fn returned nonzero)"
    fi
}

P=$(mkproj loop-none); mkdir -p "$P/spec/changes/g"
run_driver_case loop-no-ledger-quiet quiet "$P" - "$(json_stop "$P" false)"

P=$(mkproj loop-paused); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^status: running/status: paused/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-paused-quiet quiet "$P" - "$(json_stop "$P" false)"

P=$(mkproj loop-cont); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_driver_case loop-continue-reinjects reinject "$P" - "$(json_stop "$P" false)"
run_driver_case loop-session-mismatch-quiet quiet "$P" 'session_id=OTHER
rounds_injected=0
retro_reinjects=0
checked_history=
tree_fp_history=
' "$(json_stop "$P" false)"
run_driver_case loop-round-cap-notice notice "$P" 'session_id=s
rounds_injected=10
retro_reinjects=0
checked_history=1,1
tree_fp_history=na,na
' "$(json_stop "$P" false)"
run_driver_case loop-no-progress-fuse-notice notice "$P" 'session_id=s
rounds_injected=4
retro_reinjects=0
checked_history=1,1,1
tree_fp_history=na,na,na
' "$(json_stop "$P" false)"

P=$(mkproj loop-retro); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^lesson; next A-1$//' > "$P/spec/changes/g/loop.md"
run_driver_case loop-retro-missing-reinjects reinject "$P" - "$(json_stop "$P" false)"
run_driver_case loop-retro-refusal-notice notice "$P" 'session_id=s
rounds_injected=1
retro_reinjects=2
checked_history=1
tree_fp_history=na
' "$(json_stop "$P" false)"

P=$(mkproj loop-done); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-acceptance-met-reinjects reinject "$P" - "$(json_stop "$P" false)"

P=$(mkproj loop-corrupt); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^max_rounds: 10$/max_rounds: ten/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-corrupt-max-rounds-notice notice "$P" - "$(json_stop "$P" false)"

# V-7 invariant pin: a loop change dir (no proposal.md) must never wake the verify reminder
P=$(mkproj loop-remind); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_case loop-dir-reminder-allows  check-verify-reminder allow "$(json_stop "$P" false)"

# V-11 canary — now a framework case (forbid arg), so the scenario-name sync guard sees it
P=$(mkproj loop-escape); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^goal: g$/goal: EVILCANARY"quote\\\\backslash/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-json-escaping-canary reinject "$P" - "$(json_stop "$P" false)" '' EVILCANARY

# ---- 0.5.1 hardening cases (names mirrored on the Claude side) ----

P=$(mkproj loop-comment); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed -e 's/^status: running$/status: running        # running | paused | done | aborted/' \
    -e 's/^max_rounds: 10$/max_rounds: 10         # plain integer/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-commented-frontmatter-reinjects reinject "$P" - "$(json_stop "$P" false)"

P=$(mkproj loop-fuse0); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^max_rounds: 10$/max_rounds: 10\nno_progress_fuse: 0/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-fuse-zero-corrupt-notice notice "$P" - "$(json_stop "$P" false)" 'no_progress_fuse must be an integer'

P=$(mkproj loop-noacc); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^## Acceptance$/## Goals/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-acceptance-missing-corrupt-notice notice "$P" - "$(json_stop "$P" false)" 'no checkbox found'

P=$(mkproj loop-headvar); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^## Acceptance$/## Acceptance Criteria/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-heading-variant-corrupt-notice notice "$P" - "$(json_stop "$P" false)" 'no checkbox found'

P=$(mkproj loop-dupacc); mkdir -p "$P/spec/changes/g"
{ printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/'
  printf '## Acceptance\n- [ ] FAKE quoted item (verify: x)\n'; } > "$P/spec/changes/g/loop.md"
run_driver_case loop-dup-acceptance-reinjects reinject "$P" - "$(json_stop "$P" false)" 'final acceptance'

P=$(mkproj loop-capdone); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-cap-boundary-acceptance-reinjects reinject "$P" 'session_id=s
rounds_injected=10
retro_reinjects=0
checked_history=2,2
tree_fp_history=na,na
' "$(json_stop "$P" false)" 'final acceptance'
run_driver_case loop-over-cap-acceptance-notice notice "$P" 'session_id=s
rounds_injected=11
retro_reinjects=0
checked_history=2,2,2
tree_fp_history=na,na,na
' "$(json_stop "$P" false)" 'max_rounds reached'

# DEC-7: fingerprint includes HEAD — verified for BOTH twins (each computes its own format)
assert_head_fp_changes() {
    for impl in sh ps1; do
        [ "$impl" = "ps1" ] && [ $HAVE_PWSH -eq 0 ] && continue
        gp="$TMP_ROOT/git-real-$impl"; rm -rf "$gp"; mkdir -p "$gp/spec/changes/g"
        printf '%s' "$LOOP_RUNNING" > "$gp/spec/changes/g/loop.md"
        ( cd "$gp" && git init -q && git add -A && git -c user.email=f@x -c user.name=f commit -qm i ) || return 1
        if [ "$impl" = "sh" ]; then
            printf '%s' "$(json_stop "$gp" false)" | sh "$HOOKS_DIR/loop-driver.sh" >/dev/null 2>&1
        else
            printf '%s' "$(json_stop "$gp" false)" | pwsh -NoProfile -NonInteractive -File "$HOOKS_DIR/loop-driver.ps1" >/dev/null 2>&1
        fi
        ( cd "$gp" && git -c user.email=f@x -c user.name=f commit -qm r2 --allow-empty ) || return 1
        if [ "$impl" = "sh" ]; then
            printf '%s' "$(json_stop "$gp" false)" | sh "$HOOKS_DIR/loop-driver.sh" >/dev/null 2>&1
        else
            printf '%s' "$(json_stop "$gp" false)" | pwsh -NoProfile -NonInteractive -File "$HOOKS_DIR/loop-driver.ps1" >/dev/null 2>&1
        fi
        f2=$(sed -n 's/^tree_fp_history=//p' "$gp/spec/changes/g/.loop-state")
        case "$f2" in *,*) : ;; *) return 1 ;; esac
        last=${f2##*,}; prev=${f2%,*}; prev=${prev##*,}
        [ "$last" != "na" ] && [ "$prev" != "na" ] && [ "$last" != "$prev" ] || return 1
    done
    return 0
}
run_assert loop-git-head-fingerprint-changes assert_head_fp_changes

# DEC-4: check-archive understands loop changes — done+fully-checked passes, running blocks
P=$(mkproj arch-loop-done); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed -e 's/^status: running$/status: done/' \
    -e 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_case archive-loop-done-allows   check-archive allow "$(json "$P" '$spec-archive')"
P=$(mkproj arch-loop-run); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_case archive-loop-running-blocks check-archive block "$(json "$P" '$spec-archive')"
run_case archive-loop-force-overrides check-archive allow "$(json "$P" '$spec-archive force')"

# DEC-2: the documented resume re-bind command performs surgery on session_id ONLY
assert_resume_rebind() {
    rs="$TMP_ROOT/rebind"; mkdir -p "$rs"
    printf 'session_id=OLD\nrounds_injected=3\nretro_reinjects=1\nchecked_history=1,2\ntree_fp_history=na,na\n' > "$rs/.loop-state"
    ( cd "$rs" && awk -v s="NEWSESS" 'BEGIN{FS=OFS="="} $1=="session_id"{$2=s} 1' .loop-state > .loop-state.tmp && mv .loop-state.tmp .loop-state ) || return 1
    grep -q '^session_id=NEWSESS$' "$rs/.loop-state" && grep -q '^rounds_injected=3$' "$rs/.loop-state" && grep -q '^retro_reinjects=1$' "$rs/.loop-state"
}
run_assert loop-resume-rebind-cmd assert_resume_rebind

echo "----"
echo "pass=$PASS fail=$FAIL"
[ $FAIL -eq 0 ] || exit 1
exit 0
