<!-- GENERATED from core/references/view-spec.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->
# view-spec — HTML views of stage artifacts

`<target>/view/<stage>.html` is the **derived, human-facing view** of a stage's markdown artifacts, produced by `/spec:view` (or the `--view` / leading `view` shorthand on research / ask / design / propose / verify). Markdown stays the single source of truth: agents read and write md only; a view is overwritten on every render, never hand-edited, never read as a source.

## Format

```
<target>/view/
├── research.html     sources: research.md (+ index.md)
├── ask.html          sources: research.md (+ index.md)
├── design.html       sources: design.md (+ index.md)
├── proposal.html     sources: proposal.md (+ research.md DEC lines, gate.md, index.md, tasks.md, verify.md)
└── verify.html       sources: verify.md (change ledger, or a diff-mode record ledger)
```

`<target>` = a change dir, an archived change dir, or a diff-mode verify record dir. `<target>/view/<lang>/<file>` holds derived translations of the sources (§ Translations). Each page is one self-contained file: the shipped template, the inlined renderer (marked + DOMPurify), and every source embedded as `<script type="text/markdown" data-src="<file>" data-cksum="<crc> <bytes>">` after the reversible escape `&`→`&amp;`, `<`→`&lt;` (so no `</script>` or `<!--` in a source can end the block). Mermaid `flowchart` / `graph` blocks are drawn by the template itself, offline: each `subgraph` becomes a full-width layer band, `:::new` boxes are highlighted with an automatic legend, an arrow back two or more layers is routed around the side so the loop stays visible, and a request / response pair keeps two parallel arrows with both labels. Other diagram types load mermaid from a CDN; offline, their source stays visible with an `offline: diagram source shown` note.

## Translations (content in the reader's language)

The page is for a human reader, so its prose is shown in the reader's language (default: the language the user writes in the conversation; `/spec:view <lang>` overrides); the md sources stay as written, because agents read them. A source in another language gets a derived copy:

```
<!-- sdd-translation: <file> · <lang> · cksum <crc> <bytes> -->
<the source, prose translated>
```

- **Stamp in line 1** = the source's stamp when translated, taken from the render script's `--stamp <file>` mode. The script embeds the translation only while that stamp equals the source's current stamp; otherwise it embeds the source and prints `translation: <file> — stale` (or `— missing` when the file or its header is absent), and the page shows the original with a notice — a stale translation is never shown as current.
- **Prose only**: headings, list / table / blockquote markers, code, IDs (R-N, A-N, C-N, DEC-N, TBD-N, V-N, E-N, F-N), paths, commands, URLs, frontmatter keys, every layout key of § Parse contract (the `| refs:` / `| verify:` / `| candidates:` / `| select:` / `| source` / `| if wrong:` fields, the `| auto |` / `| escalated |` marks, the gate's `E<N>.` / numbered Changes lines with their `Problem:` / `After:` / `Cost:` labels and the gate's section labels, the ask `  - Q:` prefix, the `select:` values and the ` / ` between candidates, frontmatter values, the ledger's Severity / Status values) and the line-grammar separators (the ASCII `:` after an item name, ` — `, ` | `) stay byte-identical — a translated or full-width (`：` / `｜`) layout key silently drops cards and fields with no fallback line — the templates parse them and reply lines quote the IDs. English canonical headings are shown in the UI language by the template's heading labels, so they never need translating.
- **Translate meaning, never add**: the page must not say anything the source does not.
- **Already in the reader's language** → the file holds the header line alone with a `· same` suffix; the script embeds the source as is (no notice), and a source change makes it stale so the language is judged again.
- Reused until the source changes — one translation per source revision. Agents never read `view/`.

## Tiers

- **standard** — every source rendered as plain markdown, section nav, a stamp badge per source. Needs no layout keys; works on any md.
- **advanced** — the stage layout below; any section whose layout keys are missing renders as plain markdown with a visible `format not recognized` tag (never a blank page), and the render script lists it on a `fallback:` line.

## Parse contract (advanced tier — headings are the contract; all other text renders as markdown)

| Stage | Layout keys | Layout |
|---|---|---|
| research | `## Practices` option lines; `## Open [TBD]` `[TBD-N] … \| candidates: … \| select: one\|several`; `## Decided` `[DEC-N]` | options side by side; open / decided board |
| ask | `## Open [TBD]` `[TBD-N]` lines; letters A, B, C… follow the `candidates:` order; optional sub-lines `  - Q: <scenario stem>` and `  - <n>: <benefit> / <cost>` keyed by candidate position | one card per question, radio or checkbox by `select:`, reply box |
| design | ` ```mermaid ` blocks; `## Interfaces` top-level bullets; `## Key Decisions` Problem / Solution / Cost | diagrams drawn offline (layer bands, new-part highlight, loop routing); one card per interface; decisions as problem → solution → cost rows |
| proposal | research.md `[DEC-N] … \| escalated \| …` and `\| auto \|` lines; gate.md `Changes` numbered blocks with `Problem:` / `After:` / `Cost:`; proposal.md four sections, the first ```mermaid block of `## How` (key flow); tasks.md `deps:` (task graph); index.md R-N vs What `refs:` | the How key-flow diagram as the page's lead visual (proposal-spec.md § Key flow diagram); escalated pinned top (keep / overturn); auto decisions listed; one card per change (adopt / refute); coverage strip |
| verify | frontmatter `conclusion`; `## Findings` table | conclusion banner; findings table filterable by severity / status |

## Reply protocol (interactive pages → chat; identical on both hosts)

- **ask page**: `1A 3C` · multi-select `2: A C` · free answer `3: <text>` · `all recommended`. Question numbers follow the `[TBD-N]` order on the page; questions left out resolve to their recommended option (the /spec:ask rule).
- **proposal page**: one line per touched item — `DEC-13: overturn — <reason>` · `C2: refute — <reason>` · `C3: adopt`. Untouched items are not emitted (silence = stands, the gate rule). DEC-N is stable across `/spec:revise`; Changes numbers come from the current gate.md.
- **Delivery**: copy button → `navigator.clipboard.writeText` → on rejection `execCommand('copy')` → the text always also sits in a visible, pre-selected textarea.

## Lifecycle

| Event | Who | Action |
|---|---|---|
| Render | `/spec:view` (or the shorthand) | the render script writes `view/<stage>.html`, overwriting; prints fallback lines |
| Format fix | the rendering command | fix the FORMAT of the sections named on `fallback:` lines, never their content; re-render once |
| Staleness | `/spec:status` | runs the script's `--check` mode; a page whose embedded stamps differ from its sources is reported stale |
| Archive | `/spec:archive` | `view/` travels with the change dir; `/spec:view <dir>` still renders archived targets |

## Anti-patterns

- ❌ The model writing or editing HTML — page quality then depends on the model and the page can show content the md does not have; run the render script instead
- ❌ Reading a view as an input — it is a derived copy; read the md it was rendered from
- ❌ Fixing a fallback by changing what a section says — the fix is format only, because the page exists to show the artifact as written
- ❌ Computing stamps by hand — only the render twins stamp and check, so sh and pwsh always agree
- ❌ Translating a source in place, or reading a translation as a source — the md stays as written for the agents; `view/<lang>/` is a reading copy
- ❌ A translation that changes structure (headings, IDs, grammar fields) — the template stops parsing it and replies quote wrong IDs; translate prose only
- ❌ Writing views anywhere but `<target>/view/` — a dir directly under `spec/changes/` counts as an active change and trips the gates
