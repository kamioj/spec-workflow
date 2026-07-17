#!/bin/sh
# Claude Code Stop-event driver for /spec:loop (POSIX sh — one implementation for
# macOS/Linux sh and Windows Git Bash, invoked by hooks.json shell form).
#
# This is a DRIVER, not a gate: it decides whether the autonomous loop continues
# (re-inject the next round) or genuinely stops (acceptance met / fuse blown / paused).
#
# Stop contract (probe-verified on Claude Code 2.1.208, 2026-07-17 — NOT the
# UserPromptSubmit contract; see codex/hooks/SCHEMA.md for the Codex twin evidence):
#   re-inject = stdout {"decision":"block","reason":"<next input>","systemMessage":"..."} + exit 0
#               (probe: reason "Reply with exactly this single word: RESUMED-OK" -> the
#                model's next turn output was RESUMED-OK; the subsequent Stop arrived
#                with "stop_hook_active":true)
#   allow+notice = stdout {"systemMessage":"..."} + exit 0 (probe: exactly one Stop fired,
#                  session ended normally)
#   allow = exit 0, stdout empty
#   Stop stdin envelope observed verbatim (ids/paths redacted):
#     {"session_id":"ff435c00-...","transcript_path":"...","cwd":"...","prompt_id":"...",
#      "permission_mode":"bypassPermissions","effort":{"level":"xhigh"},
#      "hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"pong",
#      "background_tasks":[],"session_crons":[]}
#   $CLAUDE_PROJECT_DIR is exported to Stop hooks (this very script was located through it
#   in the probe). Re-run the probe when Claude Code bumps: scratch project, this file's
#   three output forms, a pong prompt.
#
# stop_hook_active is deliberately NOT an exit condition — it is true on every Stop that
# follows a driver re-injection, so gating on it would kill the loop after round 1. The
# loop is bounded by ledger state only: max_rounds cap (final acceptance may overrun it
# exactly once), no-progress fuse, retro-refusal cap.
#
# Write ownership (KD-1): loop.md is written by the model only; .loop-state by this driver
# only (plus the documented cold-start/resume session_id line in core/commands/loop.md).
# All signals are mechanical (checkbox counts / section presence / worktree+HEAD
# fingerprint) — the model's own claims of progress are never read. Frontmatter values
# tolerate a trailing "# comment" (stripped before validation); section headings must be
# exact (first "## Acceptance" section only — see loop-spec.md).
#
# Output discipline (V-11): every reason/systemMessage below is a fixed literal; the only
# dynamic insertions are driver-computed integers. Never interpolate ledger or filesystem
# strings into the JSON (no jq — there is no reliable escaping in POSIX sh).
# KEEP THE REINJECT TEMPLATES IN SYNC with core/commands/loop.md §Round protocol and
# §Final acceptance (and the codex twins) — this pair is a registered manual sync set.
#
# Fail direction: any internal doubt -> allow the stop (a driver bug must never trap the
# user in a loop; the loop dying is always the safe direction).

set -u

STDIN=$(cat) || exit 0
[ -n "$STDIN" ] || exit 0

CWD=${CLAUDE_PROJECT_DIR:-}
[ -n "$CWD" ] || exit 0

CHANGES_DIR="$CWD/spec/changes"
[ -d "$CHANGES_DIR" ] || exit 0

# frontmatter value: first match, strip trailing "# comment", strip all whitespace
fm_get() { # $1=ledger-file $2=key
    sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1 | sed 's/#.*//' | tr -d '[:space:]'
}

# ---- 1. locate exactly one running loop ledger ----
set --
for d in "$CHANGES_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "archive" ] && continue
    [ -f "$d/loop.md" ] || continue
    [ "$(fm_get "$d/loop.md" status)" = "running" ] && set -- "$@" "$d"
done
[ $# -eq 1 ] || exit 0
CHANGE=$1
LEDGER="$CHANGE/loop.md"
STATE="$CHANGE/.loop-state"

# JSON emitters — fixed literals + driver-computed integers only (V-11)
reinject() { # $1=reason $2=systemMessage
    printf '{"decision":"block","reason":"%s","systemMessage":"%s"}' "$1" "$2"
    exit 0
}
allow_notice() { # $1=systemMessage
    printf '{"systemMessage":"%s"}' "$1"
    exit 0
}

state_get() { # $1=key $2=default
    v=''
    [ -f "$STATE" ] && v=$(sed -n "s/^$1=//p" "$STATE" | head -1)
    [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"
}
state_write() { # $1=session $2=rounds $3=retro $4=checked_hist $5=fp_hist
    printf 'session_id=%s\nrounds_injected=%s\nretro_reinjects=%s\nchecked_history=%s\ntree_fp_history=%s\n' \
        "$1" "$2" "$3" "$4" "$5" > "$STATE" 2>/dev/null || true
}
trunc_csv() { # $1=csv $2=keep-last-k -> stdout
    printf '%s' "$1" | awk -F, -v k="$2" '{
        s = (NF > k) ? NF - k + 1 : 1; o = ""
        for (i = s; i <= NF; i++) { if (i > s) o = o ","; o = o $i }
        printf "%s", o }'
}

# ---- 2. session guard (another session in this project must not be hijacked;
#         resume re-binds the session_id line per core/commands/loop.md) ----
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

# ---- 3. numeric validity (V-9: POSIX test on a non-integer is silently false — the
#         round cap would degrade to "never fires" without this). no_progress_fuse must
#         be >= 1: k=0 makes the stale-window check vacuously true (fuse on round 2). ----
MAX_ROUNDS=$(fm_get "$LEDGER" max_rounds)
FUSE_N=$(fm_get "$LEDGER" no_progress_fuse)
[ -n "$FUSE_N" ] || FUSE_N=3
for v in "$MAX_ROUNDS" "$FUSE_N" "$ROUNDS" "$RETROS"; do
    case "$v" in
        ''|*[!0-9]*)
            allow_notice 'SPEC-LOOP halted: ledger corrupt -- max_rounds / no_progress_fuse in loop.md (or the .loop-state counters) is not a plain integer. Fix the frontmatter, then resume with /spec:loop.'
            ;;
    esac
done
if [ "$FUSE_N" -lt 1 ]; then
    allow_notice 'SPEC-LOOP halted: ledger corrupt -- no_progress_fuse must be an integer >= 1 (0 would blow the fuse unconditionally on round 2). Fix the frontmatter, then resume with /spec:loop.'
fi

# ---- acceptance counts: FIRST exact "## Acceptance" section only (strict heading —
#      the codex ps1 twin has the same semantics; variants like "## Acceptance Criteria"
#      are NOT recognized and fall into the loud corrupt notice below) ----
ACC=$(awk '/^## Acceptance[[:space:]]*$/ && !seen {f=1; seen=1; next} /^## /{f=0} f' "$LEDGER")
UNCHECKED=$(printf '%s\n' "$ACC" | grep -c '^- \[ \]')
CHECKED=$(printf '%s\n' "$ACC" | grep -c '^- \[[xX]\]')

# ---- 4. acceptance section unrecognized -> loud stop (never silently run to the cap) ----
if [ "$UNCHECKED" -eq 0 ] && [ "$CHECKED" -eq 0 ]; then
    allow_notice 'SPEC-LOOP halted: ledger corrupt -- no checkbox found under an exact ## Acceptance heading in the running loop.md (heading variants are not recognized). Fix the ledger per loop-spec, then resume with /spec:loop.'
fi

# ---- 5. acceptance met -> inject the final-acceptance turn. Runs BEFORE the cap so a
#         loop that finishes on its last budgeted round still gets its final acceptance;
#         the rounds guard allows exactly ONE overrun (next stop falls to the cap). ----
if [ "$UNCHECKED" -eq 0 ] && [ "$CHECKED" -ge 1 ] && [ "$ROUNDS" -le "$MAX_ROUNDS" ]; then
    state_write "$SESSION" $((ROUNDS + 1)) "$RETROS" "$CHECKED_HIST" "$FP_HIST"
    reinject 'SPEC-LOOP: every Acceptance item in the running loop ledger (spec/changes/*/loop.md, status: running) is checked. Run the final acceptance now: dispatch the spec-verifier agent (fresh context) to independently re-verify EVERY Acceptance item against its verify: clause, report the results to the user, and only if verification holds set status: done in the loop.md frontmatter. Do not end the turn before the report is written.' 'SPEC-LOOP: acceptance checklist complete -- injecting final acceptance'
fi

# ---- 6. round cap (primary safety mechanism, DEC-2) ----
if [ "$ROUNDS" -ge "$MAX_ROUNDS" ]; then
    allow_notice 'SPEC-LOOP fuse: max_rounds reached. The loop stopped at its round budget. Review the ledger (spec/changes/*/loop.md); raise max_rounds and resume with /spec:loop, or close out with /spec:archive.'
fi

# ---- 7. retrospect gate (the hard version of "no blind next round", DEC-12) ----
LAST_ROUND=$(awk '/^### Round /{buf=""} /^### Round /,0{if($0 ~ /^## /){exit}; buf=buf $0 "\n"} END{printf "%s", buf}' "$LEDGER")
RETRO_OK=0
if [ -n "$LAST_ROUND" ]; then
    RETRO_BODY=$(printf '%s' "$LAST_ROUND" | awk '/^#### Retrospect[[:space:]]*$/{on=1;next} /^#### /{on=0} on{print}' | grep -c '[^[:space:]]') || RETRO_BODY=0
    [ "$RETRO_BODY" -ge 1 ] && RETRO_OK=1
fi
if [ "$RETRO_OK" -eq 0 ]; then
    if [ "$RETROS" -ge 2 ]; then
        allow_notice 'SPEC-LOOP halted: the retrospect for the current round was still missing after 2 re-injections. This is a refusal-to-retrospect stop, NOT a normal fuse -- inspect the ledger and the last round before resuming with /spec:loop.'
    fi
    state_write "$SESSION" "$ROUNDS" $((RETROS + 1)) "$CHECKED_HIST" "$FP_HIST"
    reinject 'SPEC-LOOP: the current round in the running loop ledger (spec/changes/*/loop.md, status: running) has no non-empty #### Retrospect -- create the round section (### Round N) if it is missing entirely, then write its retrospect: the lesson learned (add durable ones to ## Lessons) plus the next-round plan. The loop will not advance without it. Then end the turn.' 'SPEC-LOOP: retrospect missing -- re-injecting (not counted as a new round)'
fi

# ---- 8. no-progress fuse (mechanical signals only, DEC-7). Fingerprint = HEAD + working
#         tree, so per-round-committing workflows still register progress; the pipeline
#         exit code is captured explicitly (a pipe's status is its LAST command — cksum/tr
#         always succeed, so `$(pipe) || FP=na` can never fire; that was finding V-... the
#         0.5.0 bug where a timed-out git yielded a constant empty-input checksum). ----
FP=na
if command -v git >/dev/null 2>&1 && git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        PORC=$(timeout 5 git -C "$CWD" status --porcelain 2>/dev/null); PORC_RC=$?
    else
        PORC=$(git -C "$CWD" status --porcelain 2>/dev/null); PORC_RC=$?
    fi
    if [ "$PORC_RC" -eq 0 ]; then
        HEAD_SHA=$(git -C "$CWD" rev-parse HEAD 2>/dev/null) || HEAD_SHA=none
        FP=$(printf '%s\n%s' "$HEAD_SHA" "$PORC" | cksum | tr -d ' \t')
        [ -n "$FP" ] || FP=na
    fi
fi
tail_all_equal() { # $1=csv-history $2=k $3=current -> prints 1 if the last k entries all == current
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
        allow_notice 'SPEC-LOOP fuse: no measurable progress for no_progress_fuse consecutive rounds (acceptance checkbox count and worktree+HEAD fingerprint both unchanged). The loop stopped early. Review the ledger Lessons, adjust the plan or the acceptance list, then resume with /spec:loop.'
    fi
fi

# ---- 9. continue: next round ----
# Displayed round number comes from the ledger's own section count (the cold-start turn
# already wrote Round 1 before the first Stop); rounds_injected stays the cap counter.
# Histories are truncated to the last FUSE_N entries on write (older entries are never
# read; the loop lifetime already bounds them, truncation just keeps the file flat).
ROUND_COUNT=$(grep -c '^### Round ' "$LEDGER") || ROUND_COUNT=0
NEXT=$((ROUND_COUNT + 1))
CH="$CHECKED"; [ -n "$CHECKED_HIST" ] && CH=$(trunc_csv "$CHECKED_HIST,$CHECKED" "$FUSE_N")
FH="$FP"; [ -n "$FP_HIST" ] && FH=$(trunc_csv "$FP_HIST,$FP" "$FUSE_N")
state_write "$SESSION" $((ROUNDS + 1)) 0 "$CH" "$FH"
reinject "SPEC-LOOP: start round $NEXT of $MAX_ROUNDS. Read the running loop ledger (spec/changes/*/loop.md, status: running) in full -- Acceptance, the latest Retrospect, Lessons. Pick exactly ONE next item from the last retrospect plan (or the first unchecked Acceptance item). Search the ledger and the codebase before assuming anything is unimplemented. Then implement it, verify through the spec-verifier agent (self-review does not count), check off any Acceptance item only with verifier evidence, and write this round's ### Round $NEXT section with a non-empty #### Retrospect before ending the turn. To pause the loop instead, set status: paused in loop.md frontmatter." "SPEC-LOOP: round $NEXT of $MAX_ROUNDS injected"
