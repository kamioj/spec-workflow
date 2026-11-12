---
name: spec-archive
description: Archives the current change to spec/archive/YYYY-MM-DD-<name>/. Only invoked when the user explicitly says "archive". Writes an archive-stage retrospect, mines the change for recurring lessons (fresh-context spec-reflector agent) and applies the ones the user selects to project skills / rules files, sediments the knowledge base, checks for uncommitted code, and is guarded by the check-archive hook.
---
<!-- GENERATED from core/commands/archive.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-archive

## Pre-flight checks

0. **Hook layer**: `codex/hooks/check-archive` has already screened this invocation — it blocks (outputs `{"decision":"block"}` to stdout) when the change bypassed the flow: proposal.md without the APPROVED marker / tasks.md with unchecked items / no proposal.md at all. Deliberate override: the user says `force` (archive as-is) or `abandoned` (drop the direction). When an override passed through, the reason **MUST be recorded in retrospect.md** (Process step 2).
1. **git status check**:
   - Uncommitted changes present → warn the user and ask "commit first or archive first?"
   - User chooses "archive first" → proceed; "commit first" → exit and prompt the user to run `git commit`
2. **Verification status**: read `spec/changes/<name>/verify.md` (the verification ledger) — latest round's `conclusion` + open findings
   - Recommended: `conclusion: pass` with zero open critical/major findings before archiving
   - Not passing / no ledger → warn but do not block (the user may intentionally want to archive a failed proposal)
   - **`pending live check` lines never count against archiving** — they are the live-acceptance handover (the machine-verifiable set is green; the live set is the user's own acceptance run, and failures there return through $spec-fix). List them in the archive summary so the user carries the list forward, and proceed

## Process

1. Resolve the target the same way the hook audited it: the change named in the invocation (`$spec-archive <name>`), else the one `spec/changes/.current` names, else the single active change. More than one active change and none selected → list them and ask which one to archive — never pick by guess, because the hook only audited a selected target and a guessed one would archive unaudited.
2. **Write `spec/changes/<name>/retrospect.md`** — the archive-stage audit (≤40 lines, plain language; an audit record, never a second proposal):

   ```markdown
   ---
   change: <change-name>
   archived_at: <YYYY-MM-DD>
   divergences: <N>
   evidence: attached | not-verified
   deferred: <N>
   override: none | force | abandoned
   ---

   # Retrospect: <change-name>

   ## Divergence review
   Re-read proposal ## What / ## How + design key decisions, spot-check the implementation.
   Every "docs say A, code does B" found, one line each with file:line — or "none found".

   ## Evidence
   Copy the latest round's Evidence lines from verify.md, the verification ledger (commands + results).
   verify never ran → write "not verified" plainly. Never omit this section.

   ## Unfinished / deferred
   Unchecked tasks.md items, one line each on why deferred — or "all done".

   ## Auto-decision calibration
   Only for changes that carried auto/escalated decisions (workflow auto triage): how many
   held up vs. were overturned (at the gate or later). Each misjudgment gets one line —
   the pattern, not the instance — and is synced into the knowledge base (step 4): that is
   the only channel through which the triage rules learn this project. All held → "all held".

   ## Lesson routing
   Filled by step 3: one line per candidate — `P-N <level> → <target> — applied | declined |
   $spec-fix suggested` — plus one line `dropped: <N> (<reasons>)`; skipped → the skip reason.

   ## Force / abandon note
   Only when archived via force/abandoned: one line on why.
   ```

   Why the divergence review earns its cost: "docs say A, code does B" is precisely the defect class that implementation and verify most often both miss — the archive review is the last set of eyes on it.
3. **Mine lessons into project skills and rules** — the change's record (every V-N finding across rounds, user corrections, stuck self-checks, divergences, rework commits) is a set of samples, not one; this step turns recurring classes into improvements the next change loads automatically:
   - **Signal pre-check** (cheap, from artifacts already read): skip the step when verify.md holds fewer than 2 findings and none is `source: user`, the retrospect found no divergences, no auto decision was overturned, and loop.md (if any) has no Lessons → write the skip reason under `## Lesson routing` (`skipped: no signal in the record`) and go to step 4. The user saying "mine lessons" runs it regardless
   - **Agent freshness pre-check** (once per session): compare the shipped `${PLUGIN_ROOT}/agents/spec-reflector.toml` with `~/.codex/agents/spec-reflector.toml` — missing → copy + one-line notice; differs → one-line notice + ask once (sync / keep — never clobber a customized agent silently); identical → proceed
   - **Spawn spec-reflector (defined in ~/.codex/agents/spec-reflector.toml)** with the change name and nothing else — a fresh context is the mechanism: the conversation that ran the change rationalizes its own detours, the record does not (`spawn_agent` parameter contract: EITHER `message` — plain text only — OR `items`; both together is rejected)
   - **The user selects, per $spec-ask's question rules**: ONE pick-several question over the `structure` / `skill-edit` / `skill-new` candidates (the host's delivery shape below), each option self-contained — the lesson, the target, what the edit says, how many record pointers back it. No pre-ticked or recommended options: a skill or rules edit changes every future agent in this project, so the user is the authority, and **an empty answer means nothing is applied** — a candidate the user leaves unanswered or omits is declined, never defaulted (this overrides $spec-ask's "omitted resolves to the recommended option" rule, because nothing here is recommended). `knowledge` candidates are not asked — they feed step 4 like any other durable fact
     Delivery: `request_user_input` is single-select with ≤3 options, so ask one include / skip call per candidate (per $spec-ask's pick-several adaptation) and echo the combined outcome once; no tool in the session → the plain-text batch form, where an omitted candidate is declined
   - **Apply only the selected**: `skill-edit` → Edit the target with the candidate's lines, in the file's own voice, nothing else touched; `skill-new` → create it in the skill directory the project already uses, else the host default below (frontmatter `name` + `description`, body from the candidate); `structure` → never written here, because archive does not write project source — the summary carries its `$spec-fix` entry line for the user to file. Never edit a target the reflector did not return, and never a plugin-cache or user-global file even if one is returned — those reach beyond this project
     Host default skill directory: `.agents/skills/<name>/SKILL.md` at the project root
   - **Record**: fill retrospect's `## Lesson routing` (applied / declined / suggested per candidate + the dropped count). Applied edits live outside `spec/` and are uncommitted — the summary says so
4. **Sediment the knowledge base** (`spec/knowledge.md` index + `spec/knowledge/` subdocs — format authority: `references/knowledge-spec.md`; lives OUTSIDE the change dir so it survives archiving; create on first use):
   - Extract from this change the durable facts future changes will need (plus step 3's `knowledge` candidates): topology / table ownership, verified mechanisms, hard-won gotchas; durable A-N assets and E-N exemplar designations from `index.md` sediment too (the next change's research reads them instead of re-surveying); a `$spec-loop` change's `loop.md ## Lessons` is a primary input — read it before the move. Change-specific R-N quotes stay in the archived change
   - **Route by kind into subdocs, never into the index**: each fact lands as a `- <fact> | evidence: <source> | <date> (<change>)` line in its domain file under `spec/knowledge/` (create on demand), or as a long-form experience doc (frontmatter `status: current`); then maintain the file's index line in knowledge.md (`- [kind/domain] file — hook`). A flat fact line written into the index re-flags it legacy — the one way to break the architecture
   - **Lazy migration**: knowledge.md still in legacy flat format (contains `^- ` lines with `| evidence:`) → restructure it in this same pass (facts into domain subdocs, index written, nothing dropped)
   - **Tidy pass** — right after sedimenting, run the knowledge-spec.md § Tidy pass over the whole base (audit → auto-apply → two question rounds — which candidates per action class, then new / merge / drop / keep per promote pick — delivered per $spec-ask's rules): this is the archive-time "audit, tidy, extract, then ask" — reversible tidying happens automatically, deletions / retirements / skill promotions only on the user's pick; nothing to decide → one line, no question. A lesson step 3 already applied to a skill or rules file this run is not offered again as a promote candidate, because the user just ruled on it there
   - **Correct, don't contradict**: a recorded fact this change proved wrong is replaced (correction noted), never left standing next to its refutation
   - Nothing durable to record → skip, never pad
5. Compute the archive path: `spec/archive/<YYYY-MM-DD>-<name>/` (use today's date — it is already in context; no shell call needed)
6. If the change was a `$spec-loop` run: delete `.loop-state` (the driver's machine state — dead weight once archived; loop.md itself travels with the directory; its Lessons were already consumed by steps 3–4)
7. `mv` the entire directory there
8. **Pointer upkeep**: `spec/changes/.current` points at the archived change → delete the pointer; other active changes remain → list them per SKILL § Gate-aware next steps and recommend the next `$spec-resume <name>` target (a dangling pointer is harmless — gates fall back — but the recommendation saves the bounce)
9. Output a summary:
   ```
   Archived: spec/archive/YYYY-MM-DD-<name>/
   Artifacts included: research.md, research/ (if present), index.md, design.md, proposal.md, tasks.md, verify.md, loop.md (if present), retrospect.md
   Retrospect: divergences <N / none> · evidence <attached / not verified> · deferred <M items / none>
   Lessons: <applied P-N → target, … / declined N / skipped: reason> · suggested: <"$spec-fix …" lines / none> · uncommitted: <edited skill/rules paths / none>
   Knowledge: <K facts sedimented/corrected (which subdocs) / nothing durable>
   Tidy: <S> suspect · <M> merged · <D> deleted · <R> retired · <P> promoted (<paths>) / nothing to decide
   ```

## Multi-owner scenario

- Only archive after all owner tasks are complete and all branches have been merged to the main trunk
- Any owner with incomplete tasks → refuse to archive; prompt "waiting for owner X to finish"

## Failed / abandoned archive

If the change is being abandoned (user says "this direction is wrong, drop it" / `$spec-archive abandoned`):
- Archive path: `spec/archive/YYYY-MM-DD-<name>-abandoned/`
- Add `ABANDONED.md` inside with the reason for abandonment
- retrospect.md is still written (its Force / abandon note points at ABANDONED.md)

## Anti-patterns

- ❌ Archiving without the user explicitly saying "archive"
- ❌ Defaulting to archive when git has uncommitted changes (risk of losing code)
- ❌ Archiving a failed proposal without a label (the archive directory must make it clear "this is a failed case")
- ❌ Archiving an unapproved proposal / unchecked tasks silently — the hook blocks it; going through `force` requires retrospect.md to record why
- ❌ Writing the retrospect as a solution recap — it is an audit: divergences + evidence + leftovers only
- ❌ Mining lessons in the archiving conversation itself instead of dispatching spec-reflector — it remembers its own rationalizations; the fresh agent sees only the record
- ❌ Applying a lesson the user did not select, or pre-ticking candidates — skill and rules edits steer every future agent, so silence means no
- ❌ Writing a new skill when an existing project skill or rules file already covers the trigger — the existing file is already loaded at the right moment; a parallel one splits the guidance
