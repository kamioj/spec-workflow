---
description: Renders the current change's artifacts into self-contained HTML views for human reading — research, ask, design, proposal (gate), verify — in a standard tier (faithful render) or an advanced tier (stage-specific layout; the ask and proposal pages are interactive and produce a reply line to paste back). The model never writes HTML: fixed templates shipped with the plugin do the layout, so every model produces the same page. Pages show their content in the reader's language: a source written in another language gets a derived translation under view/<lang>/, refreshed only when its source changes. Markdown stays the source of truth; views and their translations are derived, overwritten in place, never edited by hand, never read by agents.
allowed-tools: Read, Glob, Edit, Write, Bash(sh:*)
---

# /spec:view

Arguments: $ARGUMENTS

## Arguments

`/spec:view [stage] [tier] [lang] [dir]` — every token optional, any order:

| Token | Values | Default |
|---|---|---|
| stage | `research` · `ask` · `design` · `proposal` · `verify` · `all` | `all` |
| tier | `standard` (faithful markdown render + section nav + stamp badge) · `advanced` (stage-specific layout; ask + proposal interactive) | `advanced` |
| lang | a language code — `zh`, `en`, `ja`, … — the language the page content is shown in | the language the user writes in this conversation |
| dir | a change dir, an archived change dir, or a diff-mode verify record dir (`spec/archive/<date>-verify-<slug>/`) | the current change |

Any other token is flagged to the user as a possible typo — nothing is silently ignored.

**`--view` / leading `view` on other commands is shorthand for this command**: `/spec:research view <direction>`, `/spec:ask view`, `/spec:design view <focus>`, `/spec:propose --view`, `/spec:verify --view` each finish their own work, then run `/spec:view <their stage>` (verify in diff mode passes its record dir). This command holds the render logic; the shorthand never re-implements it.

## Process

1. **Resolve the dir**: an explicit dir wins; otherwise the current change — `spec/changes/.current` naming an active change, else the single active change. More than one active and none selected → list them and ask which one (never pick by guess). No change and no dir → say so and stop.
2. **Localize the content** (the page is for a human reader, so its prose follows the reader's language — the md itself stays as written, because agents read it): for every source the stage embeds (references/view-spec.md § Format):
   - prose already in `<lang>` → write `<dir>/view/<lang>/<file>` as the header line alone with a `· same` suffix (`<!-- sdd-translation: <file> · <lang> · cksum <crc> <bytes> · same -->`), so the script embeds the source as is instead of reporting a missing translation; the stamp makes it re-judged when the source changes;
   - get the source's stamp with the render script's stamp mode (`--stamp <file>`; step 3 shows where the script lives) — never compute it yourself, because the script twins are the only stamp authority;
   - `<dir>/view/<lang>/<file>` exists and its first line records that same stamp → reuse it, no new translation (a translation is paid for once per source revision);
   - otherwise write it: line 1 exactly `<!-- sdd-translation: <file> · <lang> · cksum <crc> <bytes> -->`, then the source with its **prose only** translated — every heading line, list / table / blockquote marker, fenced or inline code, ID (R-N, A-N, C-N, DEC-N, TBD-N, V-N, E-N, F-N), file path, command, URL, frontmatter key, every layout key in references/view-spec.md § Parse contract — the `| refs:` / `| verify:` / `| candidates:` / `| select:` / `| source` / `| if wrong:` fields, the `| auto |` / `| escalated |` mode marks, the gate's `E<N>.` / numbered Changes lines, their `Problem:` / `After:` / `Cost:` labels and the gate's own section labels (`Escalated decisions`, `Changes`, `Decided without asking`, `Unsourced additions`, `Uncovered requirements`, `Unresolved critique`, `Not in this change`), the ask sub-line prefix `  - Q:`, the `select:` values `one` / `several` and the ` / ` between candidates, frontmatter values (`pass` / `fail` / `diff`) and the ledger's Severity / Status values — and the line-grammar separators (the ASCII `:` after an item name, ` — `, ` | `) stay byte-identical: a translated or full-width (`：` / `｜`) layout key silently drops cards and fields from the page with no fallback line, because the templates parse exactly those and the reply lines quote the IDs. Translate meaning, never add to it: a sentence the source does not say must not appear on the page.
3. **Run the render script** with `lang=<lang>` when step 2 wrote or reused any translation (the script embeds and stamps; it never interprets your markdown):
<!-- host:claude -->
   `sh "${CLAUDE_PLUGIN_ROOT}/skills/core/views/render.sh" <dir> <stage> <tier> [lang=<lang>]` — stamp mode: `sh "${CLAUDE_PLUGIN_ROOT}/skills/core/views/render.sh" --stamp <file>`
<!-- /host -->
<!-- host:codex -->
   Locate the installed views dir first (its path depends on install method): `find ~/.codex/plugins/cache ~/.agents/skills -path '*spec-core/views/render.sh' 2>/dev/null | sort | tail -1` (pwsh: `Get-ChildItem ~/.codex/plugins/cache, ~/.agents/skills -Recurse -Filter render.ps1 -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName`). Then macOS / Linux: `sh <views>/render.sh <dir> <stage> <tier> [lang=<lang>]`; Windows: `pwsh -NoProfile -File <views>/render.ps1 <dir> <stage> <tier> [lang=<lang>]` — the twins write byte-identical pages and identical stamps; stamp mode is `--stamp <file>` on either twin.
<!-- /host -->
4. **Read the script's stdout**: `view: <path>` per page, then `fallback: none` or one `fallback: <heading> — <reason>` line per section the advanced layout could not parse, and a `translation: <file> — missing|stale` line for any source shown in its original language instead. Exit 1 = a required source is missing or a token is unknown — report the message as-is. A translation line after step 2 means the header did not match: rewrite that translation once and re-render.
5. **Fallback lines are a formatting to-do, not a failure**: the page still shows those sections as plain markdown with a `format not recognized` tag. Fix ONLY the format of the named sections to the spec shape (references/view-spec.md § Parse contract) — never their content, because the page must show what the artifact says; a fallback inside a translation is fixed in the translation, never in the source — then re-render once. Still falling back → report the lines and stop; the standard tier always works.
6. **Report**: each page path, the content language (translated / original), the fallback state, and — for interactive pages — the paste-back instruction: ask page → "paste the reply line into `/spec:ask`"; proposal page → "paste the reply line as your gate reply".

## Staleness check (used by /spec:status)

The same script, check mode: `render.sh --check <dir>` (Windows Codex: `render.ps1 --check <dir>`) prints one `<path> stale — /spec:view <stage>` line per view whose embedded stamps no longer match its sources, nothing when all are fresh. Stamping and checking live only in the script twins — never compute the stamp yourself, because a hand-run `cksum` and the pwsh twin must agree byte-for-byte.

## What this command does NOT do

- Write or edit HTML by hand, or read a view as a source — markdown is the only source of truth, and a page edit would be overwritten on the next render
- Open a browser, start a server, or write anything back from a page — the page is one-way; decisions come back through the pasted reply line
- Touch any artifact other than the `view/` dir of the resolved target (step 5's format fix is the one exception, and it changes format only)
- Read a translation as a source, or translate a source in place — `view/<lang>/` is a derived reading copy; the md the agents read stays exactly as written
