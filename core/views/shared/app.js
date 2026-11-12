/* sdd view runtime, both tiers: reads the embedded markdown sources, renders them
 * sanitized (marked -> DOMPurify) and builds the page frame — top bar (theme + language
 * toggles), hero (chips, the md H1, a verbatim quote, metric tiles), sticky TOC with
 * scrollspy, and the "sources" strip with one stamp badge per source. An advanced-tier
 * page also carries SDD.layout (stage layout); a standard-tier page has no layout code and
 * renders every source as a prose card. UI text comes from SDD_STRINGS (strings.js).
 * The page never reads files: freshness is checked by `render --check` (/spec:status). */
(function () {
  'use strict';
  var SDD = window.SDD = window.SDD || {};
  var LANG_KEY = 'sdd-view-lang';
  var THEME_KEY = 'sdd-view-theme';

  /* Reverses the render script's escape: `&lt;` -> `<` first, then `&amp;` -> `&`. */
  function unescapeBlock(s) {
    return s.replace(/&lt;/g, '<').replace(/&amp;/g, '&');
  }

  function readSources() {
    var list = [];
    var nodes = document.querySelectorAll('script[type="text/markdown"]');
    for (var i = 0; i < nodes.length; i++) {
      list.push({
        name: nodes[i].getAttribute('data-src'),
        cksum: nodes[i].getAttribute('data-cksum'),
        /* set by `render lang=<code>`: translated (data-lang) or why not (data-translation) */
        lang: nodes[i].getAttribute('data-translated') === '1' ? nodes[i].getAttribute('data-lang') : null,
        translation: nodes[i].getAttribute('data-translation'),
        text: unescapeBlock(nodes[i].textContent)
      });
    }
    return list;
  }

  /* UI string lookup; a missing key is a bug in the table and fails loudly. */
  SDD.t = function (key) {
    var table = SDD_STRINGS[SDD.lang];
    if (!Object.prototype.hasOwnProperty.call(table, key)) throw new Error('sdd view: missing UI string ' + SDD.lang + '.' + key);
    var args = Array.prototype.slice.call(arguments, 1);
    return table[key].replace(/\{(\d+)\}/g, function (_, n) { return String(args[Number(n)]); });
  };

  /* True when the table has the key (labels for open-ended keys such as field names). */
  SDD.hasT = function (key) {
    return Object.prototype.hasOwnProperty.call(SDD_STRINGS[SDD.lang], key);
  };

  function stored(key, allowed) {
    try {
      var v = window.localStorage.getItem(key);
      return allowed.indexOf(v) >= 0 ? v : null;
    } catch (e) {
      return null;
    }
  }

  function store(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* choice holds for this page view only */ }
  }

  /* Stored choice -> language requested at render time (<meta name="sdd-lang">, written
   * only by `render lang=<code>`; its primary subtag counts when it is zh or en) -> CJK
   * share of the letters in the sources (>= 30% -> zh) -> browser language -> en. */
  function pickLang(sources) {
    var chosen = stored(LANG_KEY, ['zh', 'en']);
    if (chosen) return chosen;
    var hint = document.querySelector('meta[name="sdd-lang"]');
    var requested = hint ? String(hint.getAttribute('content')).split('-')[0] : '';
    if (requested === 'zh' || requested === 'en') return requested;
    var text = sources.map(function (s) { return s.text; }).join('\n');
    var cjk = (text.match(/[㐀-鿿豈-﫿]/g) || []).length;
    var latin = (text.match(/[A-Za-z]/g) || []).length;
    if (cjk + latin > 0 && cjk / (cjk + latin) >= 0.3) return 'zh';
    if (String(navigator.language || '').toLowerCase().indexOf('zh') === 0) return 'zh';
    return 'en';
  }

  function append(el, kids) {
    if (kids === null || kids === undefined || kids === false) return;
    if (Array.isArray(kids)) { kids.forEach(function (k) { append(el, k); }); return; }
    if (typeof kids === 'string') { el.appendChild(document.createTextNode(kids)); return; }
    el.appendChild(kids);
  }

  /* Element builder. `html` must already be sanitized (SDD.md / SDD.mdInline output). */
  SDD.h = function (tag, attrs, kids) {
    var el = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        var v = attrs[k];
        if (v === null || v === undefined || v === false) return;
        if (k === 'class') el.className = v;
        else if (k === 'text') el.textContent = v;
        else if (k === 'html') el.innerHTML = v;
        else if (k.indexOf('on') === 0) el.addEventListener(k.slice(2), v);
        else el.setAttribute(k, v === true ? '' : v);
      });
    }
    append(el, kids);
    return el;
  };
  var h = SDD.h;

  /* ---------- icons: 24px-grid outline paths, drawn at 16px in currentColor ---------- */

  var ICONS = {
    'search': '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
    'git-branch': '<circle cx="6" cy="5.5" r="2"/><circle cx="6" cy="18.5" r="2"/><circle cx="18" cy="7" r="2"/><path d="M6 7.5v9M18 9c0 5-6 4-11 8"/>',
    'database': '<ellipse cx="12" cy="5.5" rx="7" ry="2.5"/><path d="M5 5.5v13c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-13"/><path d="M5 12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5"/>',
    'flask': '<path d="M9 3h6M10 3v6.5L5 18.5A1.7 1.7 0 0 0 6.5 21h11a1.7 1.7 0 0 0 1.5-2.5L14 9.5V3"/><path d="M7.5 15h9"/>',
    'check': '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    'alert': '<path d="M12 3.5l9 16H3z"/><path d="M12 10v4.5M12 17.2v.1"/>',
    'arrow-right': '<path d="M4.5 12h15M13.5 6l6 6-6 6"/>',
    'quote': '<path d="M6.5 7.5h4v4c0 3-1.4 4.7-4 5.5M13.5 7.5h4v4c0 3-1.4 4.7-4 5.5"/>',
    'undo': '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    'chevron': '<path d="M9 6l6 6-6 6"/>',
    'copy': '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h8"/>',
    'file': '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/>',
    'list': '<path d="M9 6h11M9 12h11M9 18h11"/><path d="M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>',
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4"/>',
    'moon': '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>'
  };

  SDD.icon = function (name, cls) {
    var span = document.createElement('span');
    span.className = 'ico' + (cls ? ' ' + cls : '');
    span.setAttribute('aria-hidden', 'true');
    span.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + ICONS[name] + '</svg>';
    return span;
  };

  /* Chip / pill. tone: neutral | accent | warning | success | danger. */
  SDD.chip = function (text, tone, icon, attrs) {
    var a = attrs || {};
    a['class'] = 'chip chip-' + (tone || 'neutral') + (a['class'] ? ' ' + a['class'] : '');
    return h('span', a, [icon ? SDD.icon(icon) : null, h('span', { text: text })]);
  };

  /* ---------- markdown ---------- */

  /* Inline HTML a markdown source may legitimately carry; any other bare `<word>` /
   * `<word-word>` / `<word_word>` is a placeholder (`<date>`, `<slug>`) and is escaped so
   * the sanitizer does not swallow it as an unknown tag. Fenced, indented and inline code
   * stay untouched (marked escapes those itself). */
  var HTML_TAGS = ['br', 'b', 'i', 'em', 'strong', 'code', 'kbd', 'sub', 'sup', 'mark', 'small', 'span', 'a', 'details', 'summary', 'img'];
  var PLACEHOLDER = /<(\/?)([A-Za-z][A-Za-z0-9]*(?:[-_][A-Za-z0-9]+)*)>/g;
  /* Fence state step (the rule of sddFenceStep in precheck.js): state null outside a
   * fence, { c, n, q } inside one opened by n >= 3 of char c at blockquote depth q (a
   * backtick opener whose info string holds a backtick is an inline code span, not a
   * fence); only a line of nothing but c, at least n long, after the same quote markers
   * closes it, and the fence ends with its quote. Returns the new state, whether the line
   * is a marker and whether it lies inside an already open fence. */
  var QUOTE = /^[ \t]*>[ \t]?/;
  SDD.fenceStep = function (state, line) {
    var t = line, q = 0, m;
    if (state !== null) {
      while (q < state.q && (m = QUOTE.exec(t))) { t = t.slice(m[0].length); q += 1; }
      if (q === state.q) {
        var c = t.replace(/^[ \t]+/, '').replace(/[ \t]+$/, '');
        var closes = c.length >= state.n && c.split(state.c).join('') === '';
        return closes ? { open: null, marker: true, inside: true } : { open: state, marker: false, inside: true };
      }
      /* the quote holding the fence ended, and the fence with it */
      t = line; q = 0;
    }
    while ((m = QUOTE.exec(t))) { t = t.slice(m[0].length); q += 1; }
    m = /^[ \t]*(`{3,}|~{3,})([\s\S]*)$/.exec(t);
    if (!m || (m[1].charAt(0) === '`' && m[2].indexOf('`') >= 0)) return { open: null, marker: false, inside: false };
    return { open: { c: m[1].charAt(0), n: m[1].length, q: q }, marker: true, inside: false };
  };

  function leadWidth(line) {
    var w = 0;
    for (var i = 0; i < line.length; i++) {
      var c = line.charAt(i);
      if (c === ' ') w += 1;
      else if (c === '\t') w += 4 - (w % 4);
      else break;
    }
    return w;
  }

  SDD.escapePlaceholders = function (text) {
    var fence = null, prevBlank = true, indented = false, listIndent = -1;
    return text.split('\n').map(function (line) {
      if (!indented) {
        var st = SDD.fenceStep(fence, line);
        fence = st.open;
        if (st.marker || st.inside) { prevBlank = false; return line; }
      }
      var blank = line.trim() === '', lead = leadWidth(line);
      /* an indented code block: after a blank line, 4 columns past the text of the
       * enclosing list item (4 outside lists); less indent continues the item as prose */
      var need = listIndent >= 0 ? listIndent + 4 : 4;
      if (!blank && lead >= need && (prevBlank || indented)) { indented = true; prevBlank = false; return line; }
      if (!blank) indented = false;
      var item = /^( *)([-*+]|[0-9]+[.)])( +|$)/.exec(line);
      if (item && item[1].length < need) listIndent = item[0].length + (item[3] === '' ? 1 : 0);
      else if (!blank && lead === 0) listIndent = -1;
      prevBlank = blank;
      return line.split(/(`+[^`]*`+)/).map(function (part, i) {
        if (i % 2) return part;
        return part.replace(PLACEHOLDER, function (m, slash, name) {
          return HTML_TAGS.indexOf(name.toLowerCase()) >= 0 ? m : '&lt;' + slash + name + '&gt;';
        });
      }).join('');
    }).join('\n');
  };

  SDD.md = function (text) { return DOMPurify.sanitize(marked.parse(SDD.escapePlaceholders(text))); };
  SDD.mdInline = function (text) { return DOMPurify.sanitize(marked.parseInline(SDD.escapePlaceholders(text))); };

  /* Rendered markdown; its `## ` headers show their UI-language label (SDD.headingLabel)
   * with the canonical English header kept beside it and in data-heading. */
  SDD.mdBlock = function (text) {
    var el = h('div', { class: 'prose', html: SDD.md(text) });
    el.querySelectorAll('h2').forEach(function (h2) {
      var orig = h2.textContent;
      var label = SDD.headingLabel(orig);
      h2.setAttribute('data-heading', orig);
      if (label === orig) return;
      h2.textContent = label;
      h2.appendChild(h('span', { class: 'sec-orig', text: orig }));
    });
    el.querySelectorAll('table').forEach(function (t) {
      var wrap = h('div', { class: 'table-wrap' });
      t.parentNode.insertBefore(wrap, t);
      wrap.appendChild(t);
    });
    return el;
  };

  /* A leading YAML frontmatter block (first line exactly `---`, closed by the next line
   * exactly `---` or by the end of text); null when the text has none. */
  SDD.frontmatter = function (text) {
    var t = text.replace(/\r\n/g, '\n');
    var m = /^---\n([\s\S]*?)(\n---(\n|$)|$)/.exec(t);
    return m ? { yaml: m[1], body: t.slice(m[0].length) } : null;
  };

  /* A whole source as faithful markdown; frontmatter kept visible as a code block
   * (marked would otherwise read it as a rule plus a setext heading); gate.md is plain
   * text and keeps its layout. */
  SDD.sourceBlock = function (name, text) {
    if (name === 'gate.md') return h('pre', { class: 'gate-text', text: text });
    var fm = SDD.frontmatter(text);
    if (!fm) return SDD.mdBlock(text);
    return h('div', null, [h('pre', { class: 'frontmatter' }, h('code', { text: '---\n' + fm.yaml + '\n---' })), SDD.mdBlock(fm.body)]);
  };

  /* In-page answer store: picks and reasons keyed by stable ids (TBD-N / DEC-N / Cn), so
   * a re-render (language toggle) rebuilds the controls with the same answers and the
   * same reply text. Memory only — a reload starts fresh. */
  SDD.answers = SDD.answers || {};
  SDD.answer = function (key) {
    if (!Object.prototype.hasOwnProperty.call(SDD.answers, key)) SDD.answers[key] = {};
    return SDD.answers[key];
  };

  /* Display label for an English canonical section header ("Open [TBD]", "Evidence (round 2 …)"):
   * the md keeps the header English for the hooks, the reader sees it in the UI language.
   * A header outside the table is returned untouched. */
  SDD.headingLabel = function (text) {
    var t = String(text).trim();
    var m = /^([A-Za-z][A-Za-z \/\[\]]*?)(\s*\(.*)?$/.exec(t);
    if (!m) return t;
    var key = 'head.' + m[1].toLowerCase().replace(/[^a-z]+/g, '-').replace(/^-|-$/g, '');
    var table = SDD_STRINGS[SDD.lang] || SDD_STRINGS.en;
    if (!Object.prototype.hasOwnProperty.call(table, key)) return t;
    return table[key] + (m[2] || '');
  };

  /* ---------- page parts ---------- */

  var secCount = 0;
  /* Appends a TOC-listed section to <main>; returns its body element.
   * opts: { src: source file label, extra: nodes after the title, count: TOC count } */
  SDD.section = function (title, opts) {
    opts = opts || {};
    secCount += 1;
    var label = SDD.headingLabel(title);
    var head = h('div', { class: 'sec-head' }, [
      h('h2', { class: 'sec-title' }, [
        h('span', { text: label }),
        label !== title ? h('span', { class: 'sec-orig', text: title }) : null
      ]),
      opts.extra || null,
      opts.src ? h('span', { class: 'sec-src' }, [SDD.icon('file'), h('span', { text: opts.src })]) : null
    ]);
    var body = h('div', { class: 'sec-body' });
    var sec = h('section', {
      class: 'sec',
      id: 'sec-' + secCount,
      'data-nav': label,
      'data-count': opts.count === undefined || opts.count === null ? null : String(opts.count)
    }, [head, body]);
    SDD.main.appendChild(sec);
    return body;
  };

  /* H1 of the first source (the stage's primary artifact), verbatim; null when absent. */
  SDD.docTitle = function () {
    var first = SDD.sources.length ? SDD.sources[0].text : '';
    var m = /^# +(.+)$/m.exec(first.replace(/\r/g, ''));
    return m ? m[1].trim() : null;
  };

  /* The change name an artifact title carries (`Research: <name>`); null when absent. */
  SDD.changeName = function (title) {
    var m = /^[A-Za-z][A-Za-z ]*:\s*(.+)$/.exec(title || '');
    return m ? m[1].trim() : null;
  };

  /* Verbatim R-1 quote from index.md (the text before its first ` | ` field). */
  SDD.r1Quote = function () {
    var t = SDD.src['index.md'];
    if (t === undefined) return null;
    var m = /^- *R-1: *(.+)$/m.exec(t.replace(/\r/g, ''));
    return m ? m[1].split(' | ')[0].trim() : null;
  };

  SDD.baseChips = function (title) {
    var name = SDD.changeName(title);
    return [
      SDD.chip(SDD.t('stage.' + SDD.stage), 'accent'),
      name ? SDD.chip(name, 'neutral', 'git-branch') : null
    ];
  };

  /* Hero: chips, H1, subtitle quote, optional visual (a diagram card), metric tiles. Tiles: [{ label, value, key }]; returns
   * { tile: key -> value element } for live updates. */
  SDD.hero = function (spec) {
    var tiles = {};
    var list = (spec.tiles || []).filter(Boolean);
    var tileRow = list.length ? h('div', { class: 'tiles' }, list.map(function (t) {
      var v = h('div', { class: 'tile-value', text: String(t.value) });
      if (t.key) tiles[t.key] = v;
      return h('div', { class: 'tile' + (t.tone ? ' tile-' + t.tone : '') }, [h('div', { class: 'tile-label', text: t.label }), v]);
    })) : null;
    var hero = h('header', { class: 'hero' }, [
      h('div', { class: 'chips' }, spec.chips),
      h('h1', { text: spec.title }),
      spec.subtitle ? h('p', { class: 'hero-quote' }, [SDD.icon('quote'), h('span', { text: spec.subtitle })]) : null,
      spec.visual ? h('div', { class: 'hero-visual' }, spec.visual) : null,
      tileRow
    ]);
    SDD.main.appendChild(hero);
    return { tile: tiles };
  };

  function translationBanner() {
    var notes = [];
    SDD.sources.forEach(function (s) {
      if (s.translation === 'missing' || s.translation === 'stale') {
        notes.push(h('div', {
          class: 'translation-note',
          role: 'note',
          'data-translation': s.translation
        }, [SDD.icon('alert'), h('span', { text: SDD.t('translation.' + s.translation, s.name) })]));
      }
    });
    return notes.length ? h('div', { class: 'notes' }, notes) : null;
  }

  function sourcesStrip() {
    var badges = SDD.sources.map(function (s) {
      return s.lang ? h('span', {
        class: 'pill stamp translated',
        'data-translated': s.lang,
        title: SDD.t('stamp.translatedTitle', s.name, s.lang, s.cksum),
        text: SDD.t('stamp.translated', s.name)
      }) : h('span', {
        class: 'pill stamp',
        title: SDD.t('stamp.title', s.cksum),
        text: SDD.t('stamp.badge', s.name, s.cksum.split(' ')[0])
      });
    });
    return h('footer', { class: 'sources' }, [
      h('span', { class: 'sources-title' }, [SDD.icon('file'), h('span', { text: SDD.t('sources.title') })]),
      h('div', { class: 'sources-badges' }, badges),
      h('span', { class: 'hint', text: SDD.t('stamp.hint') })
    ]);
  }

  function effectiveTheme() {
    var t = document.documentElement.getAttribute('data-theme');
    if (t === 'light' || t === 'dark') return t;
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function topbar(stage, tier) {
    var langs = h('span', { class: 'seg seg-small', role: 'group', 'aria-label': SDD.t('lang.toggle') });
    [['zh', '中'], ['en', 'EN']].forEach(function (pair) {
      langs.appendChild(h('button', {
        type: 'button',
        class: SDD.lang === pair[0] ? 'on' : '',
        'aria-pressed': SDD.lang === pair[0] ? 'true' : 'false',
        text: pair[1],
        onclick: function () {
          store(LANG_KEY, pair[0]);
          SDD.boot(SDD.stage, pair[0]);
        }
      }));
    });
    var theme = h('button', {
      type: 'button',
      class: 'icon-btn',
      title: SDD.t('theme.toggle'),
      'aria-label': SDD.t('theme.toggle'),
      onclick: function () {
        var next = effectiveTheme() === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        store(THEME_KEY, next);
        theme.textContent = '';
        theme.appendChild(SDD.icon(next === 'dark' ? 'sun' : 'moon'));
      }
    }, SDD.icon(effectiveTheme() === 'dark' ? 'sun' : 'moon'));
    return h('div', { class: 'topbar' }, [
      h('span', { class: 'brand', text: SDD.t('brand') + ' · ' + SDD.t('stage.' + stage) + ' · ' + SDD.t('tier.' + tier) }),
      h('span', { class: 'topbar-actions' }, [theme, langs])
    ]);
  }

  /* TOC: one entry per section (with its count), plus `##` sub-entries of prose sources on
   * the standard tier; the entry of the section being read is highlighted. */
  function buildToc(nav) {
    nav.appendChild(h('div', { class: 'toc-title', text: SDD.t('nav.title') }));
    var links = [];
    var subCount = 0;
    SDD.main.querySelectorAll('section[data-nav]').forEach(function (sec) {
      var count = sec.getAttribute('data-count');
      var a = h('a', { href: '#' + sec.id }, [
        h('span', { class: 'toc-label', text: sec.getAttribute('data-nav') }),
        count !== null ? h('span', { class: 'toc-count', text: count }) : null
      ]);
      nav.appendChild(a);
      links.push({ sec: sec, a: a });
      if (SDD.tier !== 'standard') return;
      sec.querySelectorAll('.prose h2').forEach(function (h2) {
        subCount += 1;
        h2.id = 'sub-' + subCount;
        nav.appendChild(h('a', { class: 'sub', href: '#' + h2.id, text: SDD.headingLabel(h2.getAttribute('data-heading') || h2.textContent) }));
      });
    });
    if (!links.length || !('IntersectionObserver' in window)) return;
    var visible = {};
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting; });
      var current = null;
      for (var i = 0; i < links.length; i++) {
        if (visible[links[i].sec.id]) { current = links[i]; break; }
      }
      links.forEach(function (l) { l.a.className = l === current ? 'active' : ''; });
    }, { rootMargin: '-15% 0px -60% 0px' });
    links.forEach(function (l) { io.observe(l.sec); });
  }

  function renderStandard() {
    var title = SDD.docTitle() || SDD.t('view.fallbackTitle', SDD.t('stage.' + SDD.stage));
    SDD.hero({ chips: SDD.baseChips(title), title: title, subtitle: SDD.r1Quote() });
    SDD.sources.forEach(function (s) {
      SDD.section(s.name).appendChild(h('div', { class: 'card prose-card' }, SDD.sourceBlock(s.name, s.text)));
    });
  }

  /* Renders the page; called again by the language toggle with the chosen language. */
  SDD.boot = function (stage, lang) {
    var root = document.getElementById('sdd-app');
    var tierMeta = document.querySelector('meta[name="sdd-tier"]');
    if (!tierMeta) throw new Error('sdd view: <meta name="sdd-tier"> missing — page was not built by render.sh');
    var theme = stored(THEME_KEY, ['light', 'dark']);
    if (theme) document.documentElement.setAttribute('data-theme', theme);
    SDD.stage = stage;
    SDD.tier = tierMeta.getAttribute('content');
    SDD.sources = readSources();
    SDD.src = {};
    SDD.sources.forEach(function (s) { SDD.src[s.name] = s.text; });
    SDD.lang = lang || pickLang(SDD.sources);
    document.documentElement.lang = SDD.lang === 'zh' ? 'zh-CN' : 'en';
    secCount = 0;

    var nav = h('nav', { class: 'toc', 'aria-label': SDD.t('nav.title') });
    SDD.main = h('main', { class: 'main' });
    root.textContent = '';
    root.appendChild(topbar(stage, SDD.tier));
    root.appendChild(h('div', { class: 'layout' }, [nav, SDD.main]));
    var notes = translationBanner();
    if (notes) SDD.main.appendChild(notes);

    if (SDD.tier === 'advanced') {
      try {
        SDD.layout(stage);
      } catch (err) {
        /* A layout bug must not cost the reader the content: say so, then show the
         * standard render of the same sources. */
        SDD.main.textContent = '';
        if (notes) SDD.main.appendChild(notes);
        SDD.main.appendChild(h('div', { class: 'banner banner-danger' }, [
          SDD.icon('alert'),
          h('div', null, [
            h('strong', { 'data-sdd-error': 'layout', text: SDD.t('error.layout', err && err.message ? err.message : String(err)) }),
            h('div', { text: SDD.t('error.layoutAfter') })
          ])
        ]));
        renderStandard();
        if (window.console) console.error(err);
      }
    } else {
      renderStandard();
    }
    SDD.main.appendChild(sourcesStrip());
    buildToc(nav);
  };
})();
