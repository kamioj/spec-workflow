#!/bin/sh
# Fixture runner for the Claude-side sh gates. Run after ANY gate edit:
#
#   sh hooks/run-fixtures.sh          (Windows Git Bash AND a real POSIX env, e.g. `wsl sh hooks/run-fixtures.sh`)
#
# Claude contract asserted per case: block = exit 2, allow = exit 0, and stdout MUST stay
# empty either way (a gate that "blocks" codex-style — stdout JSON + exit 0 — does not block
# on Claude Code; the built-in wrong-contract canary proves this runner catches that).
# Scenario-name sync: every run_case name in codex/hooks/run-fixtures.sh must have a Claude
# mirror in this file — a case added codex-side only fails this run (drift guard, V-3/V-6).

set -u
HOOKS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT="${TMPDIR:-/tmp}/sdd-claude-fixtures-$$"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT
command -v cygpath >/dev/null 2>&1 && TMP_ROOT=$(cygpath -m "$TMP_ROOT")

PASS=0
FAIL=0

# run_case <name> <hook-basename> <expected: block|allow> <project-cwd> <stdin-json>
# The JSON's own "cwd" field is deliberately set to garbage by the json helpers below —
# gates must take the project dir from $CLAUDE_PROJECT_DIR (env), never from stdin JSON.
run_case() {
    name=$1; hook=$2; expected=$3; cwd=$4; stdin=$5
    errf="$TMP_ROOT/stderr.$$"
    out=$(printf '%s' "$stdin" | CLAUDE_PROJECT_DIR="$cwd" sh "$HOOKS_DIR/$hook.sh" 2>"$errf")
    code=$?
    if [ -n "$out" ]; then
        got="stdout-output"           # Claude gates must never write stdout
    elif [ "$code" -eq 2 ]; then
        got=block
    elif [ "$code" -eq 0 ]; then
        got=allow
    else
        got="exit-$code"
    fi
    if [ "$got" = "$expected" ]; then
        PASS=$((PASS+1)); echo "PASS  $name"
    else
        FAIL=$((FAIL+1)); echo "FAIL  $name  expected=$expected got=$got"
        [ -s "$errf" ] && sed 's/^/      stderr: /' "$errf" | head -3
    fi
    rm -f "$errf"
}

mkproj() {
    p="$TMP_ROOT/$1"
    mkdir -p "$p/spec/changes"
    printf '%s' "$p"
}

# JSON "cwd" carries \u-escaped garbage on purpose: proves the env route is authoritative
json() {
    printf '{"session_id":"s","transcript_path":null,"cwd":"Z:\\\\u4e2d\\\\u6587\\\\u8def\\\\u5f84","hook_event_name":"UserPromptSubmit","permission_mode":"default","prompt":"%s"}' "$1"
}
json_stop() {
    printf '{"session_id":"s","transcript_path":null,"cwd":"Z:\\\\u4e2d\\\\u6587\\\\u8def\\\\u5f84","hook_event_name":"Stop","stop_hook_active":%s,"last_assistant_message":"done"}' "$1"
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
run_case gate-no-spec-dir          check-gate block "$P" "$(json '/spec:apply')"

P=$(mkproj gate-no-active)
run_case gate-no-active-change     check-gate block "$P" "$(json '/spec:apply')"

P=$(mkproj gate-no-proposal); mkdir -p "$P/spec/changes/my-change"
run_case gate-missing-proposal     check-gate block "$P" "$(json '/spec:apply')"

P=$(mkproj gate-partial); mkdir -p "$P/spec/changes/my-change"
printf '## Why\nw\n\n## What\nx\n' > "$P/spec/changes/my-change/proposal.md"
run_case gate-missing-sections     check-gate block "$P" "$(json '/spec:apply')"

P=$(mkproj gate-ok); mkdir -p "$P/spec/changes/my-change"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/my-change/proposal.md"
run_case gate-happy-path           check-gate allow "$P" "$(json '/spec:apply')"
run_case gate-mention-not-invoke   check-gate allow "$P" "$(json 'what does /spec:apply do?')"
run_case gate-invoke-second-line   check-gate block "$(mkproj gate-2nd)" "$(json 'some context\n/spec:apply')"

P=$(mkproj gate-multi); mkdir -p "$P/spec/changes/a" "$P/spec/changes/b"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/a/proposal.md"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/b/proposal.md"
run_case gate-multiple-changes     check-gate block "$P" "$(json '/spec:apply')"

# ---- check-tbd ----
P=$(mkproj tbd-open); mkdir -p "$P/spec/changes/c"
printf '# R\n\n## Open [TBD]\n- [TBD-1] pick one\n\n## Decided\n(none)\n' > "$P/spec/changes/c/research.md"
run_case tbd-open-blocks           check-tbd block "$P" "$(json '/spec:propose')"

P=$(mkproj tbd-clear); mkdir -p "$P/spec/changes/c"
printf '# R\n\n## Open [TBD]\n(none)\n\n## Decided\n- [DEC-1] chosen | source [TBD-1] | reason\n' > "$P/spec/changes/c/research.md"
run_case tbd-decided-only-allows   check-tbd allow "$P" "$(json '/spec:propose')"
run_case tbd-mention-not-invoke    check-tbd allow "$P" "$(json 'explain /spec:propose please')"

# ---- check-archive ----
P=$(mkproj arch-unapproved); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-no-approved       check-archive block "$P" "$(json '/spec:archive')"
run_case archive-force-overrides   check-archive allow "$P" "$(json '/spec:archive force')"

# V-1 regression: "force" as a word in the project PATH (not the prompt) must NOT bypass
P=$(mkproj arch-force-dir/proj); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-force-in-cwd-blocks check-archive block "$P" "$(json '/spec:archive')"

P=$(mkproj arch-ok); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case archive-approved-allows   check-archive allow "$P" "$(json '/spec:archive')"

P=$(mkproj arch-tasks); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf '# Tasks\n- [ ] 1. unfinished\n' > "$P/spec/changes/c/tasks.md"
run_case archive-unchecked-tasks   check-archive block "$P" "$(json '/spec:archive')"

# ---- check-verify-reminder (Stop) ----
P=$(mkproj rem-nudge); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case reminder-nudges           check-verify-reminder block "$P" "$(json_stop false)"
run_case reminder-loop-guard       check-verify-reminder allow "$P" "$(json_stop true)"

P=$(mkproj rem-ledger); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf -- '---\nround: 1\nconclusion: pass\n---\n# ledger\n' > "$P/spec/changes/c/verify.md"
run_case reminder-ledger-satisfied check-verify-reminder allow "$P" "$(json_stop false)"

# 0.4.x regression guard: a round-0 (propose-stage critique) ledger must NOT satisfy the
# reminder -- the implementation window still needs its own verification round
P=$(mkproj rem-round0); mkdir -p "$P/spec/changes/c"
printf '%s\n<!-- APPROVED: 2026-07-08 12:00 -->\n' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
printf -- '---\nround: 0\nstage: propose\nconclusion: pass\n---\n# ledger\n' > "$P/spec/changes/c/verify.md"
run_case reminder-round0-nudges    check-verify-reminder block "$P" "$(json_stop false)"

P=$(mkproj rem-unapproved); mkdir -p "$P/spec/changes/c"
printf '%s' "$FULL_PROPOSAL" > "$P/spec/changes/c/proposal.md"
run_case reminder-not-approved     check-verify-reminder allow "$P" "$(json_stop false)"

# ---- loop-driver (Stop DRIVER — opposite contract to the gates: stdout JSON + exit 0;
#       reinject = {"decision":"block",...}, notice = {"systemMessage":...} w/o decision,
#       quiet = empty stdout; probe evidence in loop-driver.sh header) ----

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

# run_driver_case <name> <expected: reinject|notice|quiet> <project> <state: - = none> <stdin> [require] [forbid] [pathprefix]
#   require    = stdout must contain this substring (distinguishes e.g. final-acceptance vs continue)
#   forbid     = stdout must NOT contain this substring (JSON-escaping canaries)
#   pathprefix = dir prepended to PATH (command shims, e.g. a failing git)
run_driver_case() {
    name=$1; expected=$2; proj=$3; state=$4; stdin=$5; require=${6:-}; forbid=${7:-}; pathpre=${8:-}
    sdir="$proj/spec/changes/g"
    if [ "$state" = "-" ]; then rm -f "$sdir/.loop-state" 2>/dev/null
    else printf '%s' "$state" > "$sdir/.loop-state"; fi
    if [ -n "$pathpre" ]; then
        out=$(printf '%s' "$stdin" | PATH="$pathpre:$PATH" CLAUDE_PROJECT_DIR="$proj" sh "$HOOKS_DIR/loop-driver.sh" 2>/dev/null)
    else
        out=$(printf '%s' "$stdin" | CLAUDE_PROJECT_DIR="$proj" sh "$HOOKS_DIR/loop-driver.sh" 2>/dev/null)
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
        PASS=$((PASS+1)); echo "PASS  $name"
    else
        FAIL=$((FAIL+1)); echo "FAIL  $name  expected=$expected got=$got"
        [ -n "$out" ] && echo "      stdout: $out" | head -2
    fi
}

# run_assert <name> <shell-function> — generic named assertion; the function returns 0 on pass.
# Named cases (run_case / run_driver_case / run_assert) all participate in scenario-name sync.
run_assert() {
    name=$1; fn=$2
    if "$fn" >/dev/null 2>&1; then
        PASS=$((PASS+1)); echo "PASS  $name"
    else
        FAIL=$((FAIL+1)); echo "FAIL  $name  (assertion function $fn returned nonzero)"
    fi
}

P=$(mkproj loop-none); mkdir -p "$P/spec/changes/g"
run_driver_case loop-no-ledger-quiet quiet "$P" - "$(json_stop false)"

P=$(mkproj loop-paused); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^status: running/status: paused/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-paused-quiet quiet "$P" - "$(json_stop false)"

P=$(mkproj loop-cont); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_driver_case loop-continue-reinjects reinject "$P" - "$(json_stop false)"
run_driver_case loop-session-mismatch-quiet quiet "$P" 'session_id=OTHER
rounds_injected=0
retro_reinjects=0
checked_history=
tree_fp_history=
' "$(json_stop false)"
run_driver_case loop-round-cap-notice notice "$P" 'session_id=s
rounds_injected=10
retro_reinjects=0
checked_history=1,1
tree_fp_history=na,na
' "$(json_stop false)"
run_driver_case loop-no-progress-fuse-notice notice "$P" 'session_id=s
rounds_injected=4
retro_reinjects=0
checked_history=1,1,1
tree_fp_history=na,na,na
' "$(json_stop false)"

P=$(mkproj loop-retro); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^lesson; next A-1$//' > "$P/spec/changes/g/loop.md"
run_driver_case loop-retro-missing-reinjects reinject "$P" - "$(json_stop false)"
run_driver_case loop-retro-refusal-notice notice "$P" 'session_id=s
rounds_injected=1
retro_reinjects=2
checked_history=1
tree_fp_history=na
' "$(json_stop false)"

P=$(mkproj loop-done); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-acceptance-met-reinjects reinject "$P" - "$(json_stop false)"

P=$(mkproj loop-corrupt); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^max_rounds: 10$/max_rounds: ten/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-corrupt-max-rounds-notice notice "$P" - "$(json_stop false)"

# V-7 invariant pin: a loop change dir (no proposal.md) must never wake the verify reminder
P=$(mkproj loop-remind); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_case loop-dir-reminder-allows  check-verify-reminder allow "$P" "$(json_stop false)"

# V-11 canary — now a framework case (forbid arg), so the scenario-name sync guard sees it
P=$(mkproj loop-escape); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^goal: g$/goal: EVILCANARY"quote\\\\backslash/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-json-escaping-canary reinject "$P" - "$(json_stop false)" '' EVILCANARY

# ---- 0.5.1 hardening cases ----

# authoritative-template regression: inline # comments in frontmatter must not silence the driver
P=$(mkproj loop-comment); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed -e 's/^status: running$/status: running        # running | paused | done | aborted/' \
    -e 's/^max_rounds: 10$/max_rounds: 10         # plain integer/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-commented-frontmatter-reinjects reinject "$P" - "$(json_stop false)"

P=$(mkproj loop-fuse0); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^max_rounds: 10$/max_rounds: 10\nno_progress_fuse: 0/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-fuse-zero-corrupt-notice notice "$P" - "$(json_stop false)" 'no_progress_fuse must be an integer'

P=$(mkproj loop-noacc); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^## Acceptance$/## Goals/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-acceptance-missing-corrupt-notice notice "$P" - "$(json_stop false)" 'no checkbox found'

P=$(mkproj loop-headvar); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^## Acceptance$/## Acceptance Criteria/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-heading-variant-corrupt-notice notice "$P" - "$(json_stop false)" 'no checkbox found'

# first exact section only: a second "## Acceptance" (e.g. quoted in a round) must not pollute counts
P=$(mkproj loop-dupacc); mkdir -p "$P/spec/changes/g"
{ printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/'
  printf '## Acceptance\n- [ ] FAKE quoted item (verify: x)\n'; } > "$P/spec/changes/g/loop.md"
run_driver_case loop-dup-acceptance-reinjects reinject "$P" - "$(json_stop false)" 'final acceptance'

# DEC-8 both directions: at the cap with all checked -> final acceptance; one past it -> cap notice
P=$(mkproj loop-capdone); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_driver_case loop-cap-boundary-acceptance-reinjects reinject "$P" 'session_id=s
rounds_injected=10
retro_reinjects=0
checked_history=2,2
tree_fp_history=na,na
' "$(json_stop false)" 'final acceptance'
run_driver_case loop-over-cap-acceptance-notice notice "$P" 'session_id=s
rounds_injected=11
retro_reinjects=0
checked_history=2,2,2
tree_fp_history=na,na,na
' "$(json_stop false)" 'max_rounds reached'

# V-fix (pipeline exit code): a git whose status fails must yield fp=na, never a constant checksum
SHIM="$TMP_ROOT/git-shim"; mkdir -p "$SHIM"
cat > "$SHIM/git" <<'EOF'
#!/bin/sh
for a in "$@"; do
    case "$a" in
        rev-parse) ;;
        status) exit 1 ;;
    esac
done
case "$*" in
    *--is-inside-work-tree*) echo true; exit 0 ;;
    *"rev-parse HEAD"*) echo deadbeef; exit 0 ;;
esac
exit 0
EOF
chmod +x "$SHIM/git"
P=$(mkproj loop-gitfail); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_driver_case loop-git-status-fails-reinjects reinject "$P" 'session_id=s
rounds_injected=1
retro_reinjects=0
checked_history=0,2
tree_fp_history=na,na
' "$(json_stop false)" '' '' "$SHIM"
assert_gitfail_fp_na() { grep -q 'tree_fp_history=.*na$' "$P/spec/changes/g/.loop-state"; }
run_assert loop-git-status-fails-fp-na assert_gitfail_fp_na

# DEC-7: fingerprint includes HEAD — a per-round-committing workflow still registers progress
assert_head_fp_changes() {
    gp="$TMP_ROOT/git-real"; rm -rf "$gp"; mkdir -p "$gp/spec/changes/g"
    printf '%s' "$LOOP_RUNNING" > "$gp/spec/changes/g/loop.md"
    ( cd "$gp" && git init -q && git add -A && git -c user.email=f@x -c user.name=f commit -qm i ) || return 1
    printf '%s' "$(json_stop false)" | CLAUDE_PROJECT_DIR="$gp" sh "$HOOKS_DIR/loop-driver.sh" >/dev/null 2>&1
    f1=$(sed -n 's/^tree_fp_history=//p' "$gp/spec/changes/g/.loop-state")
    ( cd "$gp" && git -c user.email=f@x -c user.name=f commit -qm r2 --allow-empty ) || return 1
    printf '%s' "$(json_stop false)" | CLAUDE_PROJECT_DIR="$gp" sh "$HOOKS_DIR/loop-driver.sh" >/dev/null 2>&1
    f2=$(sed -n 's/^tree_fp_history=//p' "$gp/spec/changes/g/.loop-state")
    # after two runs with a commit in between, the last two fingerprints must be real and distinct
    case "$f2" in *,*) : ;; *) return 1 ;; esac
    last=${f2##*,}; prev=${f2%,*}; prev=${prev##*,}
    [ "$last" != "na" ] && [ "$prev" != "na" ] && [ "$last" != "$prev" ]
}
run_assert loop-git-head-fingerprint-changes assert_head_fp_changes

# DEC-4: check-archive understands loop changes — done+fully-checked passes, running blocks
P=$(mkproj arch-loop-done); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" | sed -e 's/^status: running$/status: done/' \
    -e 's/^- \[ \] A-1 thing (verify: x)$/- [x] A-1 thing (verify: x)/' > "$P/spec/changes/g/loop.md"
run_case archive-loop-done-allows   check-archive allow "$P" "$(json '/spec:archive')"
P=$(mkproj arch-loop-run); mkdir -p "$P/spec/changes/g"
printf '%s' "$LOOP_RUNNING" > "$P/spec/changes/g/loop.md"
run_case archive-loop-running-blocks check-archive block "$P" "$(json '/spec:archive')"
run_case archive-loop-force-overrides check-archive allow "$P" "$(json '/spec:archive force')"

# DEC-2: the documented resume re-bind command performs surgery on session_id ONLY
assert_resume_rebind() {
    rs="$TMP_ROOT/rebind"; mkdir -p "$rs"
    printf 'session_id=OLD\nrounds_injected=3\nretro_reinjects=1\nchecked_history=1,2\ntree_fp_history=na,na\n' > "$rs/.loop-state"
    ( cd "$rs" && awk -v s="NEWSESS" 'BEGIN{FS=OFS="="} $1=="session_id"{$2=s} 1' .loop-state > .loop-state.tmp && mv .loop-state.tmp .loop-state ) || return 1
    grep -q '^session_id=NEWSESS$' "$rs/.loop-state" && grep -q '^rounds_injected=3$' "$rs/.loop-state" && grep -q '^retro_reinjects=1$' "$rs/.loop-state"
}
run_assert loop-resume-rebind-cmd assert_resume_rebind

# ---- Claude-specific extras ----

# V-2: non-ASCII project path — gate must still bite (env route is encoding-immune)
P=$(mkproj "unicode-中文路径/项目")
run_case unicode-path-blocks       check-gate block "$P" "$(json '/spec:apply')"

# fail-open when the host did not export CLAUDE_PROJECT_DIR (authorized by proposal How)
P=$(mkproj env-missing)
stdin=$(json '/spec:apply')
out=$(printf '%s' "$stdin" | env -u CLAUDE_PROJECT_DIR sh "$HOOKS_DIR/check-gate.sh" 2>/dev/null); code=$?
if [ -z "$out" ] && [ "$code" -eq 0 ]; then
    PASS=$((PASS+1)); echo "PASS  env-missing-fail-open"
else
    FAIL=$((FAIL+1)); echo "FAIL  env-missing-fail-open  expected=allow got=exit-$code stdout=$out"
fi

# Wrong-contract canary (V-1): a gate that "blocks" codex-style (stdout JSON + exit 0) must
# NOT register as block here — if the runner ever reports it as block, the runner is broken.
canary="$TMP_ROOT/canary-gate.sh"
printf '#!/bin/sh\ncat >/dev/null\nprintf %s "{\\"decision\\":\\"block\\",\\"reason\\":\\"x\\"}"\nexit 0\n' > "$canary"
out=$(printf '%s' "$(json '/spec:apply')" | CLAUDE_PROJECT_DIR="$TMP_ROOT" sh "$canary" 2>/dev/null); code=$?
if [ -n "$out" ] && [ "$code" -eq 0 ]; then
    PASS=$((PASS+1)); echo "PASS  wrong-contract-canary (codex-style output correctly detected as NOT blocking)"
else
    FAIL=$((FAIL+1)); echo "FAIL  wrong-contract-canary  a codex-contract gate was not distinguishable (out='$out' code=$code)"
fi

# ---- scenario-name sync against the codex fixture set (V-3/V-6 drift guard) ----
CODEX_RUNNER="$HOOKS_DIR/../codex/hooks/run-fixtures.sh"
if [ -f "$CODEX_RUNNER" ]; then
    for n in $(sed -n -e 's/^run_\(driver_\)\{0,1\}case[[:space:]]\{1,\}\([a-z0-9-]\{1,\}\).*/\2/p' \
                      -e 's/^run_assert[[:space:]]\{1,\}\([a-z0-9-]\{1,\}\).*/\1/p' "$CODEX_RUNNER"); do
        if grep -Eq "run_((driver_)?case|assert) $n " "$0"; then
            PASS=$((PASS+1)); echo "PASS  scenario-sync:$n"
        else
            FAIL=$((FAIL+1)); echo "FAIL  scenario-sync:$n  codex case has no Claude mirror"
        fi
    done
else
    echo "WARN: codex runner not found -- scenario-name sync skipped (repo checkout only)"
fi

echo "----"
echo "pass=$PASS fail=$FAIL"
[ $FAIL -eq 0 ] || exit 1
exit 0
