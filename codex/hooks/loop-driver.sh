#!/bin/sh
# Codex Stop-event driver for $spec-loop (POSIX sh twin of loop-driver.ps1 -- keep both
# in sync; the shared fixtures are the sync contract).
# Codex contract (SCHEMA.md, re-probed on codex-cli 0.144.3, 2026-07-17): re-inject =
# stdout {"decision":"block","reason":...} + exit 0 -- the reason is fed back as the next
# turn's input (probe: RESUMED-OK). {"systemMessage":...} on allow is best-effort (harmless
# if the host ignores it). cwd is parsed from stdin JSON (no $CLAUDE_PROJECT_DIR on Codex).
# stop_hook_active is deliberately NOT an exit condition (true on every driver-continued
# stop); the loop is bounded by ledger state only. Write ownership: loop.md model-only,
# .loop-state driver-only; all signals mechanical. Output discipline: fixed literals +
# driver-computed integers only. Fail direction: any doubt -> exit 0, loop ends.

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

CWD=$(printf '%s' "$STDIN" | sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
[ -d "$CHANGES_DIR" ] || exit 0

set --
for d in "$CHANGES_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "archive" ] && continue
    [ -f "$d/loop.md" ] || continue
    grep -Eq '^status:[[:space:]]*running[[:space:]]*$' "$d/loop.md" && set -- "$@" "$d"
done
[ $# -eq 1 ] || exit 0
CHANGE=$1
LEDGER="$CHANGE/loop.md"
STATE="$CHANGE/.loop-state"

reinject() {
    printf '{"decision":"block","reason":"%s","systemMessage":"%s"}' "$1" "$2"
    exit 0
}
allow_notice() {
    printf '{"systemMessage":"%s"}' "$1"
    exit 0
}

state_get() {
    v=''
    [ -f "$STATE" ] && v=$(sed -n "s/^$1=//p" "$STATE" | head -1)
    [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"
}
state_write() {
    printf 'session_id=%s\nrounds_injected=%s\nretro_reinjects=%s\nchecked_history=%s\ntree_fp_history=%s\n' \
        "$1" "$2" "$3" "$4" "$5" > "$STATE" 2>/dev/null || true
}

STDIN_SESSION=$(printf '%s' "$STDIN" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p')
SESSION=$(state_get session_id '')
if [ -n "$SESSION" ] && [ -n "$STDIN_SESSION" ] && [ "$SESSION" != "$STDIN_SESSION" ]; then
    exit 0
fi
[ -z "$SESSION" ] && SESSION=$STDIN_SESSION

ROUNDS=$(state_get rounds_injected 0)
RETROS=$(state_get retro_reinjects 0)
CHECKED_HIST=$(state_get checked_history '')
FP_HIST=$(state_get tree_fp_history '')

MAX_ROUNDS=$(sed -n 's/^max_rounds:[[:space:]]*//p' "$LEDGER" | head -1 | tr -d '[:space:]')
FUSE_N=$(sed -n 's/^no_progress_fuse:[[:space:]]*//p' "$LEDGER" | head -1 | tr -d '[:space:]')
[ -n "$FUSE_N" ] || FUSE_N=3
for v in "$MAX_ROUNDS" "$FUSE_N" "$ROUNDS" "$RETROS"; do
    case "$v" in
        ''|*[!0-9]*)
            allow_notice 'SPEC-LOOP halted: ledger corrupt -- max_rounds / no_progress_fuse in loop.md (or the .loop-state counters) is not a plain integer. Fix the frontmatter, then resume with $spec-loop.'
            ;;
    esac
done

if [ "$ROUNDS" -ge "$MAX_ROUNDS" ]; then
    allow_notice 'SPEC-LOOP fuse: max_rounds reached. The loop stopped at its round budget. Review the ledger (spec/changes/*/loop.md); raise max_rounds and resume with $spec-loop, or close out with $spec-archive.'
fi

ACC=$(awk '/^## Acceptance/{f=1;next} /^## /{f=0} f' "$LEDGER")
UNCHECKED=$(printf '%s\n' "$ACC" | grep -c '^- \[ \]')
CHECKED=$(printf '%s\n' "$ACC" | grep -c '^- \[[xX]\]')

if [ "$UNCHECKED" -eq 0 ] && [ "$CHECKED" -ge 1 ]; then
    state_write "$SESSION" $((ROUNDS + 1)) "$RETROS" "$CHECKED_HIST" "$FP_HIST"
    reinject 'SPEC-LOOP: every Acceptance item in the running loop ledger (spec/changes/*/loop.md, status: running) is checked. Run the final acceptance now: dispatch the spec-verifier agent (fresh context) to independently re-verify EVERY Acceptance item against its verify: clause, report the results to the user, and only if verification holds set status: done in the loop.md frontmatter. Do not end the turn before the report is written.' 'SPEC-LOOP: acceptance checklist complete -- injecting final acceptance'
fi

LAST_ROUND=$(awk '/^### Round /{buf=""} /^### Round /,0{if($0 ~ /^## /){exit}; buf=buf $0 "\n"} END{printf "%s", buf}' "$LEDGER")
RETRO_OK=0
if [ -n "$LAST_ROUND" ]; then
    RETRO_BODY=$(printf '%s' "$LAST_ROUND" | awk '/^#### Retrospect/{on=1;next} /^#### /{on=0} on{print}' | grep -c '[^[:space:]]') || RETRO_BODY=0
    [ "$RETRO_BODY" -ge 1 ] && RETRO_OK=1
fi
if [ "$RETRO_OK" -eq 0 ]; then
    if [ "$RETROS" -ge 2 ]; then
        allow_notice 'SPEC-LOOP halted: the retrospect for the current round was still missing after 2 re-injections. This is a refusal-to-retrospect stop, NOT a normal fuse -- inspect the ledger and the last round before resuming with $spec-loop.'
    fi
    state_write "$SESSION" "$ROUNDS" $((RETROS + 1)) "$CHECKED_HIST" "$FP_HIST"
    reinject 'SPEC-LOOP: the current round in the running loop ledger (spec/changes/*/loop.md, status: running) has no non-empty #### Retrospect -- create the round section (### Round N) if it is missing entirely, then write its retrospect: the lesson learned (add durable ones to ## Lessons) plus the next-round plan. The loop will not advance without it. Then end the turn.' 'SPEC-LOOP: retrospect missing -- re-injecting (not counted as a new round)'
fi

FP=na
if command -v git >/dev/null 2>&1 && git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        FP=$(timeout 5 git -C "$CWD" status --porcelain 2>/dev/null | cksum | tr -d ' \t') || FP=na
    else
        FP=$(git -C "$CWD" status --porcelain 2>/dev/null | cksum | tr -d ' \t') || FP=na
    fi
    [ -n "$FP" ] || FP=na
fi
tail_all_equal() {
    printf '%s' "$1" | awk -F, -v k="$2" -v cur="$3" '
        { if (NF < k) { print 0; exit }
          ok = 1
          for (i = NF - k + 1; i <= NF; i++) if ($i != cur) ok = 0
          print ok }'
}
if [ -n "$CHECKED_HIST" ]; then
    C_STALE=$(tail_all_equal "$CHECKED_HIST" "$FUSE_N" "$CHECKED")
    F_STALE=1
    [ "$FP" != "na" ] && F_STALE=$(tail_all_equal "$FP_HIST" "$FUSE_N" "$FP")
    if [ "${C_STALE:-0}" = "1" ] && [ "${F_STALE:-0}" = "1" ]; then
        allow_notice 'SPEC-LOOP fuse: no measurable progress for no_progress_fuse consecutive rounds (acceptance checkbox count and worktree fingerprint both unchanged). The loop stopped early. Review the ledger Lessons, adjust the plan or the acceptance list, then resume with $spec-loop.'
    fi
fi

ROUND_COUNT=$(grep -c '^### Round ' "$LEDGER") || ROUND_COUNT=0
NEXT=$((ROUND_COUNT + 1))
CH="$CHECKED"; [ -n "$CHECKED_HIST" ] && CH="$CHECKED_HIST,$CHECKED"
FH="$FP"; [ -n "$FP_HIST" ] && FH="$FP_HIST,$FP"
state_write "$SESSION" $((ROUNDS + 1)) 0 "$CH" "$FH"
reinject "SPEC-LOOP: start round $NEXT of $MAX_ROUNDS. Read the running loop ledger (spec/changes/*/loop.md, status: running) in full -- Acceptance, the latest Retrospect, Lessons. Pick exactly ONE next item from the last retrospect plan (or the first unchecked Acceptance item). Search the ledger and the codebase before assuming anything is unimplemented. Then implement it, verify through the spec-verifier agent (self-review does not count), check off any Acceptance item only with verifier evidence, and write this round's ### Round $NEXT section with a non-empty #### Retrospect before ending the turn. To pause the loop instead, set status: paused in loop.md frontmatter." "SPEC-LOOP: round $NEXT of $MAX_ROUNDS injected"
