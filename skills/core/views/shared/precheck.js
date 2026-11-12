// GENERATED from core/views/shared/precheck.js — edit the core file and run node tools/generate.mjs; hand edits will be overwritten
/* Advanced-tier layout-key check, shared by the page and the test runner.
 * render.sh and render.ps1 implement the same rules: for the same sources all three
 * must yield the same (heading, reason) list in the same order — the script prints it
 * as `fallback:` lines, the page tags those sections "format not recognized".
 *
 * Rules (identical in all three implementations):
 * - lines: split on LF, one trailing CR stripped per line
 * - fence: outside a fence, a line starting (after blockquote markers `>` and spaces /
 *   tabs) with 3+ backticks or 3+ tildes opens one at that quote depth — except a
 *   backtick run followed by text holding another backtick (an inline code span such as
 *   ```js```); only a line holding, after the same number of quote markers, nothing but
 *   the same character, at least as many, closes it; a line with fewer quote markers ends
 *   the quote and the fence with it (and is read afresh). Fence lines and fenced lines
 *   are never headings and never count as section content
 * - section <name>: body of the first line (outside fences) matching /^## +/ whose text
 *   after the marker starts with <name>, up to the next line matching /^##? /
 */

function sddLines(text) {
  return text.split('\n').map(function (l) { return l.replace(/\r$/, ''); });
}

/* Fence state step: state is null outside a fence, { c, n, q } inside one (opened by n
 * of char c at blockquote depth q). Returns the state after the line, whether the line
 * is a fence marker (opening or closing) and whether it lies inside a fence that was
 * already open (content or closing marker). */
var SDD_QUOTE = /^[ \t]*>[ \t]?/;
function sddFenceStep(state, line) {
  var t = line, q = 0, m;
  if (state !== null) {
    while (q < state.q && (m = SDD_QUOTE.exec(t))) { t = t.slice(m[0].length); q += 1; }
    if (q === state.q) {
      var c = t.replace(/^[ \t]+/, '').replace(/[ \t]+$/, '');
      var closes = c.length >= state.n && c.split(state.c).join('') === '';
      return closes ? { open: null, marker: true, inside: true } : { open: state, marker: false, inside: true };
    }
    /* the quote holding the fence ended, and the fence with it */
    t = line; q = 0;
  }
  while ((m = SDD_QUOTE.exec(t))) { t = t.slice(m[0].length); q += 1; }
  m = /^[ \t]*(`{3,}|~{3,})([\s\S]*)$/.exec(t);
  if (!m || (m[1].charAt(0) === '`' && m[2].indexOf('`') >= 0)) return { open: null, marker: false, inside: false };
  return { open: { c: m[1].charAt(0), n: m[1].length, q: q }, marker: true, inside: false };
}

/* Split a markdown text into blocks at `# ` / `## ` lines outside fences.
 * kind: 'pre' (before the first boundary) | 'title' (# line) | 'sec' (## line). */
function sddDoc(text) {
  var lines = sddLines(text), blocks = [], cur = { kind: 'pre', name: '', head: null, body: [] };
  var fence = null;
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i], st = sddFenceStep(fence, l);
    fence = st.open;
    if (st.marker || st.inside) { cur.body.push(l); continue; }
    if (/^##? /.test(l)) {
      blocks.push(cur);
      if (/^## /.test(l)) cur = { kind: 'sec', name: l.replace(/^## +/, ''), head: l, body: [] };
      else cur = { kind: 'title', name: l.replace(/^# +/, ''), head: l, body: [] };
      continue;
    }
    cur.body.push(l);
  }
  blocks.push(cur);
  return blocks;
}

function sddSection(doc, name) {
  for (var i = 0; i < doc.length; i++) {
    if (doc[i].kind === 'sec' && doc[i].name.indexOf(name) === 0) return doc[i];
  }
  return null;
}

/* Body lines outside fences (fence markers dropped) — the lines the checks look at. */
function sddOutside(body) {
  var out = [], fence = null;
  for (var i = 0; i < body.length; i++) {
    var st = sddFenceStep(fence, body[i]);
    fence = st.open;
    if (!st.marker && !st.inside) out.push(body[i]);
  }
  return out;
}

function sddAny(lines, re) {
  for (var i = 0; i < lines.length; i++) if (re.test(lines[i])) return true;
  return false;
}

/* Key-flow block of a `## How` body (all lines, fences included): the first
 * ```mermaid block outside other fences. 'none' without one; 'ok' when its first
 * statement (blank and %% lines skipped) is a flowchart header the offline renderer
 * takes; 'bad' otherwise (other diagram type, empty or unclosed block). */
function sddKeyflow(body) {
  var fence = null, inBlock = false;
  for (var i = 0; i < body.length; i++) {
    var l = body[i];
    if (!inBlock) {
      var opens = fence === null && /^[ \t]*(`{3,}|~{3,})mermaid[ \t]*$/.test(l);
      fence = sddFenceStep(fence, l).open;
      if (opens) inBlock = true;
      continue;
    }
    if (sddFenceStep(fence, l).marker) return 'bad';
    var t = l.replace(/^[ \t]+/, '').replace(/[ \t]+$/, '');
    if (t === '' || t.indexOf('%%') === 0) continue;
    return /^(flowchart|graph)([ \t]+(TB|TD|BT|RL|LR))?[ \t]*;?$/.test(t) ? 'ok' : 'bad';
  }
  return inBlock ? 'bad' : 'none';
}

var SDD_GATE_END =/^ *(Register test|Decided without asking|Unsourced additions|Uncovered requirements|Unresolved critique|<\/HARD-GATE>)/;

/* sources: { 'research.md': text, ... } — only the embedded (present) files. */
function sddPrecheck(stage, sources) {
  var out = [];
  function add(heading, reason) { out.push({ heading: heading, reason: reason }); }
  function sec(file, name) {
    var b = sddSection(sddDoc(sources[file]), name);
    return b === null ? null : sddOutside(b.body);
  }

  if (stage === 'research') {
    var p = sec('research.md', 'Practices');
    if (p === null) add('Practices', 'heading `## Practices` not found');
    else if (!sddAny(p, /^- .*( — |: )/)) add('Practices', 'no `- <name> — <body>` option lines');
    if (sec('research.md', 'Open') === null) add('Open [TBD]', 'heading `## Open [TBD]` not found');
    if (sec('research.md', 'Decided') === null) add('Decided', 'heading `## Decided` not found');
  } else if (stage === 'ask') {
    var open = sec('research.md', 'Open');
    if (open === null) add('Open [TBD]', 'heading `## Open [TBD]` not found');
    else {
      for (var i = 0; i < open.length; i++) {
        var m = /^- *\[TBD-([0-9]+)\]/.exec(open[i]);
        if (m && !/\| *candidates: .*\| *select: *(one|several)/.test(open[i])) {
          add('[TBD-' + m[1] + ']', 'no `| candidates: ... | select: one|several` fields');
        }
      }
    }
  } else if (stage === 'design') {
    var itf = sec('design.md', 'Interfaces');
    if (itf === null) add('Interfaces', 'heading `## Interfaces` not found');
    else if (!sddAny(itf, /^- /)) add('Interfaces', 'no top-level `- ` bullets');
  } else if (stage === 'proposal') {
    var missing = [];
    ['Why', 'What', 'How', 'Risk'].forEach(function (h) {
      if (sec('proposal.md', h) === null) missing.push('`## ' + h + '`');
    });
    if (missing.length) add('proposal.md', 'missing ' + missing.join(', '));
    var what = sec('proposal.md', 'What');
    if (what !== null && !sddAny(what, /^([0-9]+\. |- )/)) add('What', 'no `- ` or `N. ` items');
    var how = sddSection(sddDoc(sources['proposal.md']), 'How');
    if (how !== null && sddKeyflow(how.body) === 'bad') add('How', 'key-flow diagram not parsed');
    if ('research.md' in sources && sec('research.md', 'Decided') === null) {
      add('Decided (research.md)', 'heading `## Decided` not found');
    }
    if ('gate.md' in sources) {
      var gl = sddLines(sources['gate.md']), start = -1, found = false;
      for (var g = 0; g < gl.length; g++) {
        if (/^ *Changes([^A-Za-z]|$)/.test(gl[g])) { start = g; break; }
      }
      if (start < 0) add('Changes (gate.md)', 'no `Changes` block');
      else {
        for (var j = start + 1; j < gl.length; j++) {
          if (SDD_GATE_END.test(gl[j])) break;
          if (/^ *[0-9]+\. /.test(gl[j])) { found = true; break; }
        }
        if (!found) add('Changes (gate.md)', 'no numbered blocks under `Changes`');
      }
    }
    if ('index.md' in sources && !sddAny(sddLines(sources['index.md']), /^- *R-[0-9]+:/)) {
      add('Requirements (index.md)', 'no `- R-N:` lines');
    }
  } else if (stage === 'verify') {
    var vl = sddLines(sources['verify.md']), concl = false;
    if (vl[0] === '---') {
      for (var k = 1; k < vl.length; k++) {
        if (vl[k] === '---') break;
        if (/^conclusion:/.test(vl[k])) { concl = true; break; }
      }
    }
    if (!concl) add('frontmatter', 'no `conclusion:` in YAML frontmatter');
    var f = sec('verify.md', 'Findings');
    if (f === null) add('Findings', 'heading `## Findings` not found');
    else {
      var table = false;
      for (var t = 0; t < f.length; t++) {
        if (/^ *\|/.test(f[t]) && /\| *Severity *\|/.test(f[t]) && /\| *Status *\|/.test(f[t])) { table = true; break; }
      }
      if (!table) add('Findings', 'no table with `Severity` and `Status` columns');
    }
  }
  return out;
}
