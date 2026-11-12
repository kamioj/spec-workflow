---
name: spec-knowledge
description: Tidies the project knowledge base on demand — the way an assistant tidies its own experience notes. Audits every fact (dead file / symbol anchors get a suspect mark, duplicates and contradictions listed), applies the reversible tidying automatically (merge duplicates, compress wording, newest evidence wins, fix index lines), then asks the user, in two rounds, what only they may decide — round 1 picks which candidates to delete, retire or promote (one question per class); round 2 asks per promoted lesson: new project skill, merge into an existing one, drop, or keep. $spec-archive runs the same pass after sedimenting.
---
<!-- GENERATED from core/commands/knowledge.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# $spec-knowledge

Focus (optional — a domain or subdoc to limit the pass to): $ARGUMENTS

## Process

1. **Read the base two-step**: `spec/knowledge.md` (the index) → the subdocs in scope (all of them unless a focus is given — tidying is the one task that legitimately reads every subdoc). No knowledge base → say so in one line and stop. Legacy flat knowledge.md → run the lazy migration first (references/knowledge-spec.md § Lifecycle), then tidy.
2. **Run the tidy pass** exactly as references/knowledge-spec.md § Tidy pass defines it — audit → auto-apply → ask. That section is the single definition shared with $spec-archive; this command adds no rules of its own, because two copies of the pass would drift.
3. **Questions** take the two-round shape of knowledge-spec.md § Tidy pass stage 3, delivered per $spec-ask's rules — each stem names the fact and why it is a candidate. A user who skips a class leaves those candidates untouched — they come back next tidy.
4. **Execute the picks**: delete → remove the line (its subdoc's index line stays unless the file empties); retire → move the doc to `spec/knowledge/archive/` and remove its index line; promote → write the skill per the pass's rules, ask the one other-host follow-up, replace the fact with its promotion pointer; drop (round 2) → remove the line like delete; merge into an existing skill → show the paragraph, write it, report the path.
5. **Report** the pass's `Tidy:` line, then every file written outside `spec/` with its path — skills live in user-owned dirs, so each one is named.

## What this command does NOT do

- Delete, retire or write a skill without the user's pick — reversible tidying is automatic, nothing else is
- Touch user-level skill dirs (`~/.claude/skills`, `~/.agents/skills`), CLAUDE.md or AGENTS.md — project-level skill dirs only
- Add facts — sedimenting new knowledge belongs to $spec-archive, $spec-ship and $spec-verify
