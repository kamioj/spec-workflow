/* Advanced-tier building blocks (loaded only into advanced pages): fallback tagging
 * driven by sddPrecheck (shared/precheck.js — the same rules render.sh prints as
 * `fallback:` lines), document walking, the list-line field grammar and the components it
 * renders into (cards, row lists, quote cards, collapses), choice controls, the copy-back
 * reply bar and diagrams (offline flowcharts via shared/flow.js when present, mermaid CDN
 * otherwise). */
(function () {
  'use strict';
  var SDD = window.SDD;
  var h = SDD.h;
  /* Machine-detectable fallback marker (tests and verify clauses grep for it); the
   * visible label is the translated fallback.tag string. */
  var FB_MARK = 'format not recognized';

  SDD.MERMAID_SRC = 'https://cdn.jsdelivr.net/npm/mermaid@12.3.0/dist/mermaid.min.js';

  /* ---------- fallback ---------- */

  SDD.runPrecheck = function (stage) {
    SDD.fallbacks = sddPrecheck(stage, SDD.src);
    if (!SDD.fallbacks.length) return;
    var list = h('ul');
    SDD.fallbacks.forEach(function (f) {
      list.appendChild(h('li', null, [h('strong', { text: f.heading }), ' — ' + f.reason]));
    });
    SDD.main.appendChild(h('div', { class: 'banner banner-warning fallback-summary', role: 'note', 'data-sdd-fallback': FB_MARK }, [
      SDD.icon('alert'),
      h('div', null, [
        SDD.tagNode(),
        h('span', { text: ' ' + SDD.t('fallback.summary', SDD.fallbacks.length) }),
        list
      ])
    ]));
  };

  SDD.fallbackFor = function (heading) {
    for (var i = 0; i < SDD.fallbacks.length; i++) {
      if (SDD.fallbacks[i].heading === heading) return SDD.fallbacks[i];
    }
    return null;
  };

  SDD.tagNode = function () {
    return h('span', { class: 'chip chip-warning tag-fallback', 'data-sdd-fallback': FB_MARK, title: FB_MARK, text: SDD.t('fallback.tag') });
  };

  /* A section whose layout keys are missing: plain markdown plus the visible tag. */
  SDD.fallbackSection = function (title, src, fb, mdText) {
    var body = SDD.section(title, { src: src, extra: SDD.tagNode() });
    body.appendChild(h('div', { class: 'fallback-why' }, [SDD.icon('alert'), h('span', { text: fb.reason })]));
    if (mdText !== null && mdText.trim() !== '') body.appendChild(SDD.proseCard(mdText));
    return body;
  };

  /* ---------- text helpers ---------- */

  SDD.blockText = function (block) {
    return (block.head ? block.head + '\n' : '') + block.body.join('\n');
  };

  /* Splits on `sep` outside (), [], {} and `code` spans. */
  SDD.splitTop = function (s, sep) {
    var parts = [], depth = 0, tick = false, start = 0;
    for (var i = 0; i < s.length; i++) {
      var c = s.charAt(i);
      if (c === '`') tick = !tick;
      if (tick) continue;
      if (c === '(' || c === '[' || c === '{') depth += 1;
      else if ((c === ')' || c === ']' || c === '}') && depth > 0) depth -= 1;
      else if (depth === 0 && s.substr(i, sep.length) === sep) {
        parts.push(s.slice(start, i));
        start = i + sep.length;
        i = start - 1;
      }
    }
    parts.push(s.slice(start));
    return parts;
  };

  function nextIndented(lines, i) {
    for (var j = i + 1; j < lines.length; j++) {
      if (lines[j].trim() !== '') return /^[ \t]/.test(lines[j]);
    }
    return false;
  }

  /* Top-level list items (lines matching startRe outside fences, plus their indented
   * continuation) interleaved with runs of other lines. */
  SDD.items = function (lines, startRe) {
    var out = [], cur = null, text = null, fence = null;
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i], st = SDD.fenceStep(fence, l), inFence = st.inside;
      fence = st.open;
      if (!inFence && !st.marker && startRe.test(l)) {
        cur = { kind: 'item', first: l, cont: [] };
        out.push(cur);
        text = null;
        continue;
      }
      if (cur && (inFence || (st.marker && /^[ \t]/.test(l)) || /^[ \t]+\S/.test(l) || (l.trim() === '' && nextIndented(lines, i)))) {
        cur.cont.push(l);
        continue;
      }
      cur = null;
      if (!text) { text = { kind: 'text', lines: [] }; out.push(text); }
      text.lines.push(l);
    }
    return out.filter(function (b) {
      return b.kind === 'item' || b.lines.join('').trim() !== '';
    });
  };

  /* An item's text as one line: first line without its marker + trimmed continuation. */
  SDD.itemLine = function (item, markerRe) {
    return [item.first.replace(markerRe, '')].concat(item.cont.map(function (l) { return l.trim(); }))
      .join(' ').trim();
  };

  /* Continuation lines with their common indent removed. */
  SDD.dedent = function (lines) {
    var min = Infinity;
    lines.forEach(function (l) {
      if (l.trim() === '') return;
      min = Math.min(min, /^[ \t]*/.exec(l)[0].length);
    });
    if (min === Infinity) return lines.slice();
    return lines.map(function (l) { return l.slice(Math.min(min, /^[ \t]*/.exec(l)[0].length)); });
  };

  /* ---------- field grammar: `<main> | <k>: <v> | <flag> | revised rN: … ` ---------- */

  var FLAGS = { 'auto': 'auto', 'escalated': 'escalated', 'user decision': 'user', 'user-decision': 'user', 'user-override': 'user' };
  var BARE_KEYS = /^(source|rationale|basis|evidence|impact|refs)\s+(\S.*)$/i;

  SDD.parseFields = function (text) {
    var parts = SDD.splitTop(text, ' | ');
    var out = { main: parts[0].trim(), flags: [], fields: [], plain: [], revisions: [] };
    parts.slice(1).forEach(function (p) {
      var t = p.trim(), m;
      if (t === '') return;
      if ((m = /^revised (r\d+[\w-]*):\s*([\s\S]*)$/i.exec(t))) { out.revisions.push({ tag: m[1], text: m[2] }); return; }
      if (Object.prototype.hasOwnProperty.call(FLAGS, t.toLowerCase())) { out.flags.push(FLAGS[t.toLowerCase()]); return; }
      if ((m = /^([A-Za-z][A-Za-z -]{0,30}?):\s*([\s\S]*)$/.exec(t))) { out.fields.push({ key: m[1], value: m[2] }); return; }
      if ((m = BARE_KEYS.exec(t))) { out.fields.push({ key: m[1], value: m[2] }); return; }
      out.plain.push(t);
    });
    return out;
  };

  /* Localized label of a field key; a key outside the table is shown as written. */
  SDD.fieldLabel = function (key) {
    var k = 'field.' + key.toLowerCase().replace(/[^a-z]+/g, '-').replace(/^-|-$/g, '');
    return SDD.hasT(k) ? SDD.t(k) : key;
  };

  SDD.flagChip = function (flag) {
    if (flag === 'auto') return SDD.chip(SDD.t('flag.auto'), 'neutral');
    if (flag === 'escalated') return SDD.chip(SDD.t('flag.escalated'), 'warning', 'alert');
    if (flag === 'user') return SDD.chip(SDD.t('flag.user'), 'accent');
    return SDD.chip(flag, 'neutral');
  };

  /* Footer meta of a parsed line: labelled fields, unlabelled parts, review revisions. */
  SDD.fieldMeta = function (f, skip) {
    var rows = [];
    f.fields.forEach(function (x) {
      if (skip && skip.indexOf(x.key.toLowerCase()) >= 0) return;
      rows.push(h('div', { class: 'meta-row' }, [
        h('span', { class: 'meta-key', text: SDD.fieldLabel(x.key) }),
        h('span', { class: 'meta-val', html: SDD.mdInline(x.value) })
      ]));
    });
    f.plain.forEach(function (p) {
      rows.push(h('div', { class: 'meta-row' }, h('span', { class: 'meta-val', html: SDD.mdInline(p) })));
    });
    var nodes = [];
    if (rows.length) nodes.push(h('div', { class: 'meta' }, rows));
    f.revisions.forEach(function (r) {
      nodes.push(h('details', { class: 'revision' }, [
        h('summary', null, [SDD.icon('undo'), h('span', { text: SDD.t('more.revised', r.tag) })]),
        h('div', { class: 'meta-val', html: SDD.mdInline(r.text) })
      ]));
    });
    return nodes;
  };

  /* Card: title row (id chip, title, right-aligned chips), body, footer nodes. */
  SDD.card = function (o) {
    return h('article', { class: 'card' + (o.cls ? ' ' + o.cls : ''), 'data-id': o.dataId || null }, [
      h('div', { class: 'card-head' }, [
        o.icon ? SDD.icon(o.icon, 'card-icon') : null,
        o.id ? h('span', { class: 'id-chip', text: o.id }) : null,
        o.titleHtml !== undefined ? h('h3', { class: 'card-title', html: o.titleHtml }) : null,
        h('span', { class: 'spacer' }),
        o.chips || null
      ]),
      o.bodyHtml ? h('div', { class: 'card-body', html: o.bodyHtml }) : null,
      o.body || null,
      o.foot && o.foot.length ? h('div', { class: 'card-foot' }, o.foot) : null
    ]);
  };

  /* A parsed field line as a card. */
  SDD.fieldCard = function (id, f, o) {
    o = o || {};
    return SDD.card({
      id: id,
      icon: o.icon,
      cls: o.cls,
      dataId: o.dataId,
      titleHtml: o.titleHtml,
      bodyHtml: o.titleHtml === undefined ? SDD.mdInline(f.main) : null,
      chips: f.flags.map(SDD.flagChip).concat(o.chips || []),
      body: o.body,
      foot: SDD.fieldMeta(f, o.skip)
    });
  };

  /* Shows the first `n` nodes; the rest sit in a collapsed <details> with `label`. */
  SDD.collapse = function (nodes, n, label, wrapCls) {
    var frag = document.createDocumentFragment();
    var shown = h('div', { class: wrapCls || 'stack' }, nodes.slice(0, n));
    frag.appendChild(shown);
    if (nodes.length > n) {
      frag.appendChild(h('details', { class: 'more' }, [
        h('summary', null, [SDD.icon('chevron', 'chev'), h('span', { text: label(nodes.length - n) })]),
        h('div', { class: wrapCls || 'stack' }, nodes.slice(n))
      ]));
    }
    return frag;
  };

  /* Two-column row list; rows: [{ left: nodes, right: nodes }]; head: [left, right]. */
  SDD.rowList = function (rows, head) {
    return h('div', { class: 'rows' }, [
      head ? h('div', { class: 'row row-head' }, [h('div', { class: 'row-l', text: head[0] }), h('div', { class: 'row-r', text: head[1] })]) : null,
      rows.map(function (r) {
        return h('div', { class: 'row' + (r.cls ? ' ' + r.cls : '') }, [h('div', { class: 'row-l' }, r.left), h('div', { class: 'row-r' }, r.right)]);
      })
    ]);
  };

  SDD.quoteCard = function (chip, quote, meta) {
    return h('figure', { class: 'quote-card' }, [
      h('div', { class: 'quote-head' }, [h('span', { class: 'id-chip', text: chip }), SDD.icon('quote', 'quote-ico')]),
      h('blockquote', { html: SDD.mdInline(quote) }),
      meta && meta.length ? h('figcaption', null, meta) : null
    ]);
  };

  SDD.proseCard = function (text) {
    return h('div', { class: 'card prose-card' }, SDD.mdBlock(text));
  };

  /* Walks a sddDoc: the first block whose name starts with a handler key goes to that
   * handler — a key ending in `*` takes every matching block ('@pre' receives the block
   * before the first heading); every other block
   * renders as a prose section. */
  SDD.renderDoc = function (doc, src, handlers) {
    var used = {};
    doc.forEach(function (b) {
      var text = b.body.join('\n');
      if (b.kind === 'pre') {
        if (handlers && handlers['@pre']) handlers['@pre'](b);
        else if (text.trim() !== '') SDD.section(SDD.t('sec.preamble'), { src: src }).appendChild(h('div', { class: 'card prose-card' }, SDD.sourceBlock(src, text)));
        return;
      }
      if (b.kind === 'title') {
        if (text.trim() !== '') append(SDD.section(b.name, { src: src }), SDD.richBlocks(text));
        return;
      }
      var keys = Object.keys(handlers || {});
      for (var i = 0; i < keys.length; i++) {
        var every = keys[i].charAt(keys[i].length - 1) === '*';
        var key = every ? keys[i].slice(0, -1) : keys[i];
        if (keys[i] !== '@pre' && (every || !used[keys[i]]) && b.name.indexOf(key) === 0) {
          used[keys[i]] = true;
          handlers[keys[i]](b);
          return;
        }
      }
      var body = SDD.section(b.name, { src: src });
      if (text.trim() !== '') append(body, SDD.richBlocks(text));
    });
    SDD.loadPendingDiagrams();
  };

  function append(parent, nodes) { nodes.forEach(function (n) { parent.appendChild(n); }); }

  /* Count of lines matching re among a block's lines outside fences. */
  SDD.countLines = function (block, re) {
    if (!block) return 0;
    return sddOutside(block.body).filter(function (l) { return re.test(l); }).length;
  };

  /* ---------- controls ---------- */

  /* `pressed` is the option shown active; `value` starts equal to it and callers may
   * override it (a "keep" that stays visible but emits nothing). `initial` restores a
   * pressed option after a re-render. */
  SDD.seg = function (options, onChange, initial) {
    var state = { value: null, pressed: null };
    var buttons = [];
    var el = h('div', { class: 'seg', role: 'group' });
    function paint() {
      buttons.forEach(function (x) {
        var active = x.opt.value === state.pressed;
        x.btn.className = active ? 'on ' + x.opt.on : '';
        x.btn.setAttribute('aria-pressed', active ? 'true' : 'false');
      });
    }
    options.forEach(function (o) {
      var b = h('button', {
        type: 'button',
        'aria-pressed': 'false',
        onclick: function () {
          state.pressed = state.pressed === o.value ? null : o.value;
          state.value = state.pressed;
          paint();
          onChange(state.value);
        }
      }, [o.icon ? SDD.icon(o.icon) : null, h('span', { text: o.label })]);
      buttons.push({ btn: b, opt: o });
      el.appendChild(b);
    });
    if (initial !== undefined && initial !== null) {
      state.pressed = initial;
      state.value = initial;
      paint();
    }
    state.el = el;
    return state;
  };

  /* Copy-back bar, slim: title, live count, a one-line read-only preview of the reply
   * (selected on focus), copy button; the chevron opens the full textarea above it.
   * Copy: writeText -> execCommand('copy') on the opened, selected textarea -> the text
   * stays selected there for Ctrl+C. set(text, count) updates the reply. */
  SDD.replyBox = function (opts) {
    var ta = h('textarea', {
      rows: '3',
      spellcheck: 'false',
      'aria-label': opts.title,
      placeholder: opts.placeholder,
      onfocus: function () { ta.select(); }
    });
    var preview = h('input', {
      type: 'text',
      readonly: true,
      class: 'reply-preview',
      'aria-label': opts.title,
      onfocus: function () { preview.select(); }
    });
    var empty = h('span', { class: 'reply-empty', text: opts.hint });
    var count = SDD.chip(SDD.t('reply.count', 0), 'neutral', null, { class: 'reply-count' });
    var status = h('span', { class: 'copy-status', role: 'status' });
    var toggle = h('button', {
      class: 'icon-btn reply-toggle', type: 'button', title: SDD.t('reply.expand'), 'aria-label': SDD.t('reply.expand'), 'aria-expanded': 'false',
      onclick: function () { setOpen(!el.classList.contains('open')); }
    }, SDD.icon('chevron'));
    var panel = h('div', { class: 'reply-panel' }, h('div', { class: 'reply-panel-inner' }, [ta, h('div', { class: 'hint', text: opts.hint })]));
    function setOpen(open) {
      el.classList.toggle('open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    }
    function flash(msg) {
      status.textContent = msg;
      clearTimeout(flash.timer);
      flash.timer = setTimeout(function () { status.textContent = ''; }, 3500);
    }
    function execCopy() {
      setOpen(true);
      ta.focus();
      ta.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
      flash(ok ? SDD.t('reply.copied') : SDD.t('reply.blocked'));
    }
    function copy() {
      var text = ta.value;
      if (text === '') { flash(SDD.t('reply.empty')); return; }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { flash(SDD.t('reply.copied')); preview.select(); }, execCopy);
      } else {
        execCopy();
      }
    }
    var extra = (opts.buttons || []).map(function (b) {
      return h('button', { class: 'btn btn-small', type: 'button', onclick: b.onclick }, h('span', { text: b.label }));
    });
    var bar = h('div', { class: 'reply-bar' }, [
      h('span', { class: 'reply-title', text: opts.title }),
      count,
      h('span', { class: 'reply-mid' }, [preview, empty, status]),
      extra,
      toggle,
      h('button', { class: 'btn btn-primary btn-small', type: 'button', onclick: copy }, [SDD.icon('copy'), h('span', { text: SDD.t('reply.copy') })])
    ]);
    var el = h('div', { class: 'reply muted' }, [panel, bar]);
    SDD.main.appendChild(el);
    SDD.main.classList.add('has-reply');
    return {
      set: function (text, n) {
        ta.value = text;
        /* one line for the bar; the full text, line breaks included, is in the textarea */
        preview.value = text.replace(/\n/g, '  ⏎  ');
        count.lastChild.textContent = SDD.t('reply.count', n);
        el.classList.toggle('muted', text === '');
      }
    };
  };

  /* A collapsed block with a one-line summary ("Show 6 more"). */
  SDD.more = function (label, content) {
    return h('details', { class: 'more' }, [
      h('summary', null, [SDD.icon('chevron', 'chev'), h('span', { text: label })]),
      content
    ]);
  };

  /* ---------- diagrams ---------- */

  var pending = [];
  var mermaidState = 'idle';
  var MERMAID_OPEN = /^[ \t]*(`{3,}|~{3,})mermaid[ \t]*$/;

  function sourceDetails(src) {
    return h('details', { class: 'more diagram-src' }, [
      h('summary', null, [SDD.icon('chevron', 'chev'), h('span', { text: SDD.t('diagram.source') })]),
      h('pre', null, h('code', { text: src }))
    ]);
  }

  /* Legend rows for a chart's numbered badges ("1 send receipt"), in badge order; null
   * when every label fits on the chart. Focusing or hovering a badge marks its row. */
  SDD.badgeLegend = function (svg) {
    var list = svg && svg.sddBadges;
    if (!list || !list.length) return null;
    var rows = {};
    var ol = h('ol', { class: 'badge-legend', 'aria-label': SDD.t('diagram.badges') }, list.map(function (b) {
      rows[b.n] = h('li', { 'data-badge': String(b.n) }, [
        h('span', { class: 'badge-num' + (b.isNew ? ' new' : ''), 'aria-hidden': 'true', text: String(b.n) }),
        h('span', { class: 'badge-text', text: b.text })
      ]);
      return rows[b.n];
    }));
    Array.prototype.forEach.call(svg.querySelectorAll ? svg.querySelectorAll('.flow-badge') : [], function (g) {
      var row = rows[g.getAttribute('data-badge')];
      if (!row) return;
      function on() { row.classList.add('hot'); }
      function off() { row.classList.remove('hot'); }
      ['focus', 'mouseenter'].forEach(function (ev) { g.addEventListener(ev, on); });
      ['blur', 'mouseleave'].forEach(function (ev) { g.addEventListener(ev, off); });
    });
    return ol;
  };

  /* A diagram figure for a mermaid source: flowcharts render offline through SDD.flow
   * (flow.js, on pages that carry it) with a legend when the chart marks `new` nodes;
   * other types keep their source visible and queue for the mermaid CDN renderer. */
  SDD.diagramFigure = function (src, opts) {
    opts = opts || {};
    var fig = h('figure', { class: 'diagram card' + (opts.cls ? ' ' + opts.cls : ''), id: opts.id || null });
    if (opts.title) {
      fig.appendChild(h('div', { class: 'card-head' }, [
        h('h3', { class: 'card-title', text: opts.title }),
        h('span', { class: 'spacer' }),
        opts.src ? h('span', { class: 'sec-src' }, [SDD.icon('file'), h('span', { text: opts.src })]) : null
      ]));
    }
    var graph = SDD.flow ? SDD.flow.parse(src) : null;
    if (graph) {
      /* card inner width: main column minus the figure's padding and border */
      var fit = SDD.main && SDD.main.clientWidth ? SDD.main.clientWidth - 34 : 0;
      var svg = SDD.flow.svg(graph, { label: opts.title || SDD.t('tile.diagrams'), fitWidth: fit });
      fig.appendChild(h('div', { class: 'svg-wrap' }, svg));
      var key = SDD.badgeLegend(svg);
      if (key) fig.appendChild(key);
      var foot = [];
      if (svg.sddHasNew) {
        foot.push(h('span', { class: 'legend' }, [
          h('span', { class: 'swatch swatch-new' }), h('span', { text: SDD.t('legend.new') }),
          h('span', { class: 'swatch swatch-old' }), h('span', { text: SDD.t('legend.old') })
        ]));
      }
      if (svg.sddNodeCount > 15) foot.push(h('span', { class: 'diagram-note', text: SDD.t('diagram.many') }));
      if (foot.length) fig.appendChild(h('div', { class: 'diagram-foot' }, foot));
      fig.appendChild(sourceDetails(src));
      return fig;
    }
    var pre = h('pre', { class: 'diagram-code' }, h('code', { text: src }));
    var note = h('p', { class: 'diagram-note', text: SDD.t('diagram.loading') });
    fig.appendChild(pre);
    fig.appendChild(note);
    pending.push({ fig: fig, pre: pre, note: note, src: src });
    return fig;
  };

  /* Requests the mermaid CDN once for the queued non-flowchart diagrams; offline keeps
   * their source with a note. */
  SDD.loadPendingDiagrams = function () {
    if (!pending.length) return;
    function offline() {
      pending.forEach(function (f) { f.note.textContent = SDD.t('diagram.offline'); });
    }
    function renderAll() {
      if (!window.mermaid) { offline(); return; }
      var todo = pending;
      pending = [];
      window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'neutral' });
      var chain = Promise.resolve();
      todo.forEach(function (f, n) {
        chain = chain.then(function () {
          return window.mermaid.render('sdd-mermaid-' + Date.now() + '-' + n, f.src).then(function (r) {
            f.fig.insertBefore(h('div', { class: 'svg-wrap', html: r.svg }), f.pre);
            f.fig.insertBefore(sourceDetails(f.src), f.pre);
            f.pre.remove();
            f.note.remove();
          }, function (err) {
            f.note.className = 'diagram-note err';
            f.note.textContent = SDD.t('diagram.error', err && err.message ? err.message : String(err));
          });
        });
      });
    }
    if (window.mermaid) { renderAll(); return; }
    if (mermaidState === 'failed') { offline(); return; }
    if (mermaidState === 'loading') return;
    mermaidState = 'loading';
    var s = document.createElement('script');
    s.src = SDD.MERMAID_SRC;
    s.onerror = function () { mermaidState = 'failed'; offline(); };
    s.onload = function () { mermaidState = 'idle'; renderAll(); };
    document.head.appendChild(s);
  };

  /* Markdown text split around its mermaid blocks: prose cards and diagram figures.
   * replace(src, index) may return a node to stand in for a diagram (e.g. a pointer to a
   * diagram already shown elsewhere). */
  SDD.richBlocks = function (text, replace) {
    var lines = text.split('\n'), nodes = [], buf = [], fence = null, mer = null, merFence = null, count = 0;
    function flush() {
      if (buf.join('').trim() !== '') nodes.push(SDD.proseCard(buf.join('\n')));
      buf = [];
    }
    lines.forEach(function (l) {
      if (mer !== null) {
        if (SDD.fenceStep(merFence, l).marker) {
          var src = mer.join('\n'), alt = replace ? replace(src, count) : null;
          nodes.push(alt || SDD.diagramFigure(src));
          count += 1;
          mer = null;
        } else {
          mer.push(l);
        }
        return;
      }
      if (fence === null && MERMAID_OPEN.test(l)) { flush(); mer = []; merFence = SDD.fenceStep(null, l).open; return; }
      fence = SDD.fenceStep(fence, l).open;
      buf.push(l);
    });
    if (mer !== null) buf.push('```mermaid', mer.join('\n'));
    flush();
    return nodes;
  };

  /* First mermaid block of a markdown text (outside other fences); null when none. */
  SDD.firstMermaid = function (lines) {
    var fence = null, mer = null, merFence = null;
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i];
      if (mer !== null) {
        if (SDD.fenceStep(merFence, l).marker) return mer.join('\n');
        mer.push(l);
        continue;
      }
      if (fence === null && MERMAID_OPEN.test(l)) { mer = []; merFence = SDD.fenceStep(null, l).open; continue; }
      fence = SDD.fenceStep(fence, l).open;
    }
    return null;
  };

  /* Mermaid code blocks already rendered into `container` become diagram figures. */
  SDD.diagrams = function (container) {
    var codes = container.querySelectorAll('pre > code.language-mermaid');
    for (var i = 0; i < codes.length; i++) {
      var pre = codes[i].parentNode;
      pre.parentNode.replaceChild(SDD.diagramFigure(codes[i].textContent), pre);
    }
    SDD.loadPendingDiagrams();
  };
})();
