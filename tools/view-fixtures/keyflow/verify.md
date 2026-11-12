---
change: verify-adhoc-diff
round: 4
stage: apply-fix
date: 2026-11-05
conclusion: pass
issues: { critical: 0, major: 0, minor: 0, open: 0 }
---

# Verify: verify-adhoc-diff

## Findings
| ID | Severity | Location | Finding | Status | Rounds |
|----|----------|----------|---------|--------|--------|
| V-1 | major | proposal What 1-4 | verify clauses text-presence only; diff mode and svn path never executed (fidelity) | fixed(r0) | r0 |
| V-2 | major | DEC-3/DEC-7 vs spec-verifier.md:51 | diff-only path skips Completeness, so missing screenshots yield no finding — opposite of R-2 (fidelity) | fixed(r0) | r0 |
| V-3 | minor | DEC-2 | R-1 offers conversation context as a scope source; no-VCS branch stopped instead (fidelity) | fixed(r0) | r0 |
| V-4 | major | ship.md:27-44 / DEC-5 | executor rule + no-proposal audit contract would exist twice and already diverge ("cannot tell") (reuse) | fixed(r0) | r0 |
| V-5 | major | DEC-1 / archive.md:26 | ">1 active, no pointer" treated as "no change" → a just-applied change silently loses its verify round (reuse) | fixed(r0) | r0 |
| V-6 | minor | DEC-6 / ship.md:49-52 | spec/archive/ already holds dated non-change records; new top-level spec/verify/ avoidable (reuse) | fixed(r0) | r0 |
| V-7 | major | verify.md:3,6,27,272,275 + docs | stronger existing sentences pin the ledger to spec/changes/<name>/ (would create an active dir); Codex "no flags"; README/CLAUDE/AGENTS/codex README unlisted (compat) | fixed(r0) | r0 |
| V-8 | minor | hooks/run-fixtures.sh:9-10,713-740 | new gate fixture must land in both suites under one name or the sync guard fails (compat) | fixed(r0) | r0 |
| V-9 | major | core/commands/verify.md:193,201 | diff-mode scope never drops the plugin's own spec/ tree → earlier records and fix.md enter the changed set; the step-7 fix-batch handoff can never match (drills a + b) | fixed(r2) | r1→r2 |
| V-10 | minor | hooks/run-fixtures.sh:153, codex/hooks/run-fixtures.sh:138 | verify-record-only fixture cannot fail — check-gate blocks wherever the record sits (circular proof) | fixed(r2) | r1→r2 |
| V-11 | minor | core/commands/verify.md:205,207 | ledger heading + "in the change directory" sentence missed the diff-mode note promised by the How landing step | fixed(r2) | r1→r2 |
| V-12 | minor | core/commands/verify.md:35,37 | § Independent verifier rules lack a change-mode qualifier — contradict diff mode's inline executor and its scope-carrying brief | fixed(r2) | r1→r2 |
| V-13 | major | core/commands/verify.md:198 | the V-9 fix dropped ALL of the launch root's spec/ — RSpec / Jasmine tests live there, so changed test files left the audit silently (Rails drill) | fixed(r3) | r2→r3 |
| V-14 | minor | core/commands/status.md:24 | diff-record detection sat inside the views step and claimed records "are not scanned" while reading every archived verify.md | fixed(r3) | r2→r3 |
| V-15 | minor | core/commands/verify.md:53,56 | "Four-dimension framework (executed by the dispatched spec-verifier; all modes)" contradicts diff mode's inline executor | fixed(r3) | r2→r3 |
| V-16 | minor | core/commands/verify.md:195 | hunks command `git diff HEAD` stayed repo-wide / repo-relative — flow-path hunks return, out-of-root edits vanish without a count | fixed(r4) | r3→r4 |
| V-17 | minor | core/commands/status.md:10,25,29-34 | Task line still excluded archive/; output templates had no slot for the step-7 record line | fixed after r4 — r4 found the active-change template still lacked the line; added; NOT independently re-verified (auto-fix round cap reached) | r3→r4 |

## Evidence (round 4 — scoped to V-16/V-17, run by the artifact-html-views r2 verifier)
monorepo drill launched from app/ → `git diff --relative HEAD -- <kept>` returns only kept hunks; out-of-root other/b.js visible via `git diff --name-only HEAD` for the count; untracked kept files carry no hunk (now: read whole)
status.md → Task line admits the archive read; no-active template has the record line; active template lacked it (fixed after the round)

## Evidence (round 3 — fix round, scoped to V-13..V-15)
verifier: fresh-context spec-verifier
Rails drill (root launch) → kept {app/models/user.rb, spec/models/user_spec.rb, spec/models/post_spec.rb}, dropped=3 (knowledge.md, archive record, fix.md)
subdirectory launch (svc/ with its own spec/) → --relative changed set and ls-files share the svc/ base; kept 2, dropped 2; step 7 vs fix.md files: exact match → /spec:ship
status.md step 7 standalone, frontmatter-based; "not scanned" grep → 0
four-dimension headings consistent with SKILL § Independent audit (both hosts)
generate --check OK 130
not run: hook suites (no hook/fixture file in this fix diff); svn subdirectory drill (out of scope)

## Evidence (round 2 — fix round, scoped to V-9..V-12 + fix diff)
verifier: fresh-context spec-verifier, fix-round scoping
generate --check OK 130; hook suites 293/0 and 190/0 (sh + ps1), no WARN
V-9 drill → after the drop the changed set = {app.js} = F-1 files → step 7 recommends /spec:ship; nested src/spec/ kept
V-10 probe → record under archive: allow on Claude sh, Codex sh, Codex ps1; moved under changes: all three block ("multiple active changes")
V-11/V-12 → wording present in both trees
RSpec drill → spec/models/user_spec.rb dropped silently (V-13)
note: from a repo subdirectory `git diff --name-only HEAD` (repo-relative) and `git ls-files --others` (cwd-relative) disagree on path base — fixed with V-13 by `--relative`

## Evidence (round 1, collapsed)
fresh verifier: drills git / svn / jest / UI / fix-batch; 1 major + 3 minor

## Evidence (round 1)
verifier: fresh-context spec-verifier (general-purpose agent running core/agents/spec-verifier.md)
node tools/generate.mjs --check → exit 0, OK 130
sh hooks/run-fixtures.sh → pass=293 fail=0; sh codex/hooks/run-fixtures.sh (pwsh on PATH) → pass=190 fail=0, no WARN
git drill ($TEMP) → scope = tracked.js + untracked.js (What 2 git half met)
svn drill (svnadmin + file:// checkout) → wc-root on stdout rc=0; status shows ? loose.txt, M tracked.txt, X ext; outside a WC svn rc=1 empty stdout, git rc=128 → conversation-scope branch reached
jest drill (jest@29 in $TEMP) → --findRelatedTests sum.js selects 1 suite rc=0; full run 2 passed; passWithNoTests config → vacuous green, covered by "name it if found"
UI drill (no app on 5173/3000/8080) → record with mode: diff + scope + intent + "screens: pending live check — src/pages/Login.vue"; render.sh renders it; gates unchanged
fix-batch drill → changed set {app.js, spec/changes/fixes/2026-11-05/fix.md} (V-9)
executor rule → exactly once (skill.md § Independent audit); ship.md + verify.md reference it
Codex tree → no /spec: / AskUserQuestion / CLAUDE_PLUGIN_ROOT leaks; --diff in the Codex flag line
not run: wsl suite pass; live screenshot capture (no app in fixtures — pending path exercised)

## Evidence (round 0, collapsed)
panel: reuse + fidelity + compat pass (workflow roster; one critic per lens across all three changes)
refutation: all 8 adopted; reuse cross-change note (single home for kept-inactive records) adopted for this change's record (V-6)
