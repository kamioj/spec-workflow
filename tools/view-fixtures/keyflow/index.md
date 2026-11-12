# Index: verify-adhoc-diff

Requirement source: the user's chat messages in this session, 2026-11-05 (verbatim)

## Requirements
- R-1: "我的验证命令，即使我们没有跑 spec，它也可以根据 上下文或者 git或者svn diff 找到需要测试的点" | source: user message
- R-2: "跑前后端测试以及截图证据收录" | source: same message
- R-3: "一起都做了吧" | source: user message (scope: this change runs alongside artifact-html-views and knowledge-lifecycle, each its own change)

## Assets
- A-1: spec-verifier agent (core/agents/spec-verifier.md) — Iron Law, finding format, refutation protocol, four dimensions, screenshot capture of missed screens (:51) | use: extend — startup reads (:35-42) assume a change dir; impact: verify.md, apply.md closing round, ship.md dispatch path all brief it by change name
- A-2: /spec:verify command (core/commands/verify.md) — dispatch + ledger bookkeeping + round rules | use: extend — target resolution has no "no change" branch; impact: workflow.md step 7, apply.md closing verification call into it
- A-3: /spec:ship executor rule — "this conversation wrote NONE of the entries → audit inline; wrote any → dispatch one spec-verifier" (ship.md:20-27) | use: pattern
- A-4: apply three-tier working-check order — tests → seam mocks → live items handed over as `pending live check` (apply.md:167-171) | use: reuse
- A-5: research delivery-channel precheck — test runner actually executes (skipTests-style config) (research.md step 6) | use: reuse — runner sanity before trusting a green run
- A-6: screens/ evidence map + three frontend checks (apply.md:175-176) | use: reuse — capture rules; home dir differs
- A-7: verification ledger format (verify.md § Verification ledger) | use: reuse
- A-8: charter machine pass (ast-grep rule pack, graceful not-run) | use: reuse
- A-9: hooks' active-change scan (check-gate.sh:33-41 and twins) | use: rejected as a home: any new dir under spec/changes/ without proposal/fix/loop/quick counts as active and trips the multi-active block; a dated dir under fixes/ without fix.md un-exempts the fixes tree
- A-10: VCS support | use: rejected: none beyond git — searched `grep -ril svn core` (only php-conventions.md prose)

## Exemplars
- E-1: diff-mode branch in verify.md → ship.md § Flow step 2 (executor choice + audit contract written as a short bounded list)

## Carriers
- C-1: "需要测试的点" (test points) → existing verify: clauses / F-N entries as claim anchors | derive — in diff mode the claims come from the intent source, the diff supplies scope
- C-2: diff source → `git diff` already named in spec-verifier.md:42 | extend to svn — no new carrier
- C-3: ad-hoc verification record (ledger + screens outside any change) → NOT FOUND (searched artifact map, fixes/ tree, archive/) | minting required — rides the gate
- C-4: ad-hoc verification record → `spec/archive/<YYYY-MM-DD>-verify-<slug>/` — existing dated-record home + ship counter-suffix naming (ship.md:49-52) | derive — supersedes C-3 minting after panel r0 (reuse V-6)
