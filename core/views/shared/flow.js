/* Offline flowchart renderer: the mermaid `flowchart` / `graph` subset parsed and laid
 * out as an SVG without any network. Colors come from app.css classes, so light / dark
 * follow the page theme. Two layouts:
 * - band layout (TD/TB with subgraphs): each top-level subgraph is a full-width
 *   horizontal band, stacked in declaration order (nodes outside every subgraph form
 *   implicit bands where they are declared); a band's nodes fill rows in declaration
 *   order, wrapping into more rows when they would not fit opts.fitWidth; down edges run
 *   orthogonally, same-row edges straight, edges to the row right above straight up, edges
 *   two or more rows up loop around the right side.
 * - layered layout (everything else): longest-path ranks, barycenter ordering sweeps,
 *   bezier edges; subgraphs drawn as grouped boxes.
 * A request/response pair (A->B and B->A) gets two parallel lanes, labels on each lane's
 * outer side. A fan-out's identical label is drawn once on the shared trunk, distinct ones
 * on their own branch. Unrelated edges never share a run (lane separation). Finally every
 * edge label slides along its edge until it overlaps no box, no other label and no other
 * edge's line.
 * Node labels `title<br/>subtitle`: first line as title, further lines as subtitle.
 * `:::new` / `class A,B new` marks nodes added by the change (teal); edges between two new
 * nodes and `==>` edges are drawn teal. SDD.flow.parse returns null for anything outside
 * the subset; the caller then falls back to the mermaid CDN.
 *
 *   SDD.flow.parse(source)     -> graph | null
 *   SDD.flow.header(source)    -> true when the first statement is a flowchart header
 *   SDD.flow.svg(graph, opts)  -> <svg> (properties: sddHasNew, sddNodeCount)
 *   SDD.flow.layout(graph, opts) -> geometry { mode, nodes, edges } (opts.measure: text width
 *                                   function for callers without a DOM) */
(function () {
  'use strict';
  var SDD = window.SDD;
  var NS = 'http://www.w3.org/2000/svg';
  var TITLE_H = 18;
  var SUB_H = 16;
  var svgCount = 0;
  var HEADER_RE = /^(flowchart|graph)(?:\s+(TB|TD|BT|RL|LR))?\s*$/;

  /* ---------- parsing ---------- */

  var SHAPES = [
    ['(((', ')))', 'circle'], ['((', '))', 'circle'], ['([', '])', 'stadium'], ['[[', ']]', 'subroutine'],
    ['[(', ')]', 'cylinder'], ['{{', '}}', 'hexagon'], ['[/', null, 'rect'], ['[\\', null, 'rect'],
    ['(', ')', 'round'], ['[', ']', 'rect'], ['{', '}', 'diamond'], ['>', ']', 'rect']
  ];
  var ID_RE = /^[A-Za-z0-9_À-￿]+(?:[-.](?=[A-Za-z0-9_À-￿])[A-Za-z0-9_À-￿]*)*/;

  function decodeEntities(s) {
    return s
      .replace(/&#x([0-9a-fA-F]+);/g, function (_, n) { return String.fromCharCode(parseInt(n, 16)); })
      .replace(/&#([0-9]+);/g, function (_, n) { return String.fromCharCode(Number(n)); })
      .replace(/&lt;/g, '\x3c').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
      .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&');
  }

  /* Label text as shown: quotes and markdown-string backticks removed, <br> -> newline,
   * other tags dropped, entities decoded. */
  function cleanLabel(raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.charAt(0) === '"' && s.charAt(s.length - 1) === '"') s = s.slice(1, -1);
    if (s.length >= 2 && s.charAt(0) === '`' && s.charAt(s.length - 1) === '`') s = s.slice(1, -1);
    s = s.replace(/\x3cbr\s*\/?>/gi, '\n').replace(/\x3c\/?[A-Za-z][^>]*>/g, '');
    s = s.replace(/^fa:fa-[\w-]+\s*/, '');
    return decodeEntities(s).split('\n').map(function (l) { return l.trim(); }).filter(function (l, i) { return l !== '' || i === 0; }).join('\n').trim();
  }

  /* Statements: lines, further split on `;` outside quotes and brackets. */
  function statements(src) {
    var out = [];
    src.split('\n').forEach(function (line) {
      var l = line.replace(/\r$/, '');
      if (/^\s*%%/.test(l)) return;
      var depth = 0, quote = false, start = 0;
      for (var i = 0; i < l.length; i++) {
        var c = l.charAt(i);
        if (c === '"') quote = !quote;
        if (quote) continue;
        if (c === '[' || c === '(' || c === '{') depth += 1;
        else if ((c === ']' || c === ')' || c === '}') && depth > 0) depth -= 1;
        else if (c === ';' && depth === 0) { out.push(l.slice(start, i)); start = i + 1; }
      }
      out.push(l.slice(start));
    });
    return out.map(function (s) { return s.trim(); }).filter(function (s) { return s !== ''; });
  }

  function header(src) {
    var st = statements(src);
    return st.length > 0 && HEADER_RE.test(st[0]);
  }

  function parse(src) {
    var st = statements(src);
    if (!st.length) return null;
    var head = HEADER_RE.exec(st[0]);
    if (!head) return null;
    var g = { dir: (head[2] || 'TD').toUpperCase(), nodes: {}, order: [], edges: [], groups: [] };
    if (g.dir === 'TB') g.dir = 'TD';
    var stack = [];
    var seq = 0;

    function touch(id, label, shape) {
      var n = g.nodes[id];
      if (!n) {
        n = g.nodes[id] = { id: id, label: id, shape: 'rect', group: null, seq: seq, isNew: false };
        g.order.push(id);
      }
      if (label !== null) { n.label = cleanLabel(label); n.shape = shape; }
      if (stack.length && n.group === null) {
        n.group = stack[stack.length - 1].id;
        stack[stack.length - 1].members.push(id);
      }
      return id;
    }

    for (var k = 1; k < st.length; k++) {
      seq = k;
      var s = st[k];
      var sub = /^subgraph\s+(.*)$/i.exec(s);
      if (sub) {
        var rest = sub[1].trim(), id, title;
        var m1 = /^([^\s\[]+)\s*\[(.*)\]$/.exec(rest);
        if (m1) { id = m1[1]; title = cleanLabel(m1[2]); }
        else if (/^".*"$/.test(rest)) { id = 'sg' + g.groups.length; title = cleanLabel(rest); }
        else { id = rest; title = cleanLabel(rest); }
        var grp = { id: id, title: title, members: [], parent: stack.length ? stack[stack.length - 1].id : null, seq: k };
        g.groups.push(grp);
        stack.push(grp);
        continue;
      }
      if (/^end$/i.test(s)) { if (!stack.length) return null; stack.pop(); continue; }
      var cls = /^class\s+(.+?)\s+([\w-]+)\s*$/.exec(s);
      if (cls) {
        if (cls[2] === 'new') cls[1].split(',').forEach(function (x) { g.nodes[touch(x.trim(), null)].isNew = true; });
        continue;
      }
      if (/^(classDef|style|linkStyle|click|direction|accTitle|accDescr)\b/.test(s)) continue;
      if (!parseChain(s, touch, g)) return null;
    }
    if (stack.length || !g.order.length) return null;
    return g;
  }

  /* `A & B -->|x| C --> D` style chains; false when the statement is outside the subset. */
  function parseChain(s, touch, g) {
    var pos = 0;
    function ws() { while (pos < s.length && /\s/.test(s.charAt(pos))) pos += 1; }
    function node() {
      ws();
      var m = ID_RE.exec(s.slice(pos));
      if (!m) return null;
      var id = m[0];
      pos += id.length;
      var label = null, shape = 'rect';
      for (var i = 0; i < SHAPES.length; i++) {
        var open = SHAPES[i][0];
        if (s.substr(pos, open.length) !== open) continue;
        var p = pos + open.length, end, closeLen;
        if (s.charAt(p) === '"') {
          var q = s.indexOf('"', p + 1);
          if (q < 0) return null;
          end = q + 1;
        } else {
          end = p;
        }
        if (SHAPES[i][1] === null) {
          var a = s.indexOf('/]', end), b = s.indexOf('\\]', end);
          if (a < 0 && b < 0) return null;
          var c = a < 0 ? b : (b < 0 ? a : Math.min(a, b));
          label = s.slice(p, c); closeLen = 2; end = c;
        } else {
          var cl = s.indexOf(SHAPES[i][1], end);
          if (cl < 0) return null;
          label = s.slice(p, cl); closeLen = SHAPES[i][1].length; end = cl;
        }
        pos = end + closeLen;
        shape = SHAPES[i][2];
        break;
      }
      var created = touch(id, label, shape);
      var cls = /^:::([\w-]+)/.exec(s.slice(pos));
      if (cls) {
        pos += cls[0].length;
        if (cls[1] === 'new') g.nodes[created].isNew = true;
      }
      return created;
    }
    function group() {
      var list = [node()];
      if (list[0] === null) return null;
      for (;;) {
        ws();
        if (s.charAt(pos) !== '&') return list;
        pos += 1;
        var n = node();
        if (n === null) return null;
        list.push(n);
      }
    }
    function op() {
      ws();
      var rest = s.slice(pos), m, e = { label: '', style: 'solid', arrow: true, arrowStart: false };
      m = /^(<?)(--|==|-\.)\s*([^\s>\-=.|][\s\S]*?)\s*(-->|---|==>|===|\.->|\.-)/.exec(rest);
      if (m) {
        e.arrowStart = m[1] === '<';
        e.label = cleanLabel(m[3]);
        e.style = m[2] === '==' ? 'thick' : (m[2] === '-.' ? 'dotted' : 'solid');
        e.arrow = />$/.test(m[4]);
        pos += m[0].length;
        return e;
      }
      m = /^(<?)(-{2,}>|-{3,}|={2,}>|={3,}|-\.+->|-\.+-|--[ox]|==[ox])/.exec(rest);
      if (!m) return null;
      e.arrowStart = m[1] === '<';
      e.style = m[2].indexOf('.') >= 0 ? 'dotted' : (m[2].charAt(0) === '=' ? 'thick' : 'solid');
      e.arrow = /[>ox]$/.test(m[2]);
      pos += m[0].length;
      ws();
      if (s.charAt(pos) === '|') {
        var close = s.indexOf('|', pos + 1);
        if (close < 0) return null;
        e.label = cleanLabel(s.slice(pos + 1, close));
        pos = close + 1;
      }
      return e;
    }
    var left = group();
    if (left === null) return false;
    for (;;) {
      ws();
      if (pos >= s.length) return true;
      var e = op();
      if (e === null) return false;
      var right = group();
      if (right === null) return false;
      left.forEach(function (a) {
        right.forEach(function (b) {
          g.edges.push({ from: a, to: b, label: e.label, style: e.style, arrow: e.arrow, arrowStart: e.arrowStart });
        });
      });
      left = right;
    }
  }

  /* ---------- text ---------- */

  /* Text width: canvas measurement in the page; SDD.flow.layout callers without a DOM
   * (the geometry tests) pass opts.measure instead. */
  var ctx2d = null, family = null, measureOverride = null;
  function measure(text, kind) {
    if (measureOverride) return measureOverride(text, kind);
    if (!ctx2d) {
      ctx2d = document.createElement('canvas').getContext('2d');
      family = getComputedStyle(document.body).fontFamily;
    }
    ctx2d.font = kind === 'title' ? '500 13px ' + family : (kind === 'label' ? '12px ' + family : '12px ' + family);
    return ctx2d.measureText(text).width;
  }

  var CJK = /[⺀-鿿豈-﫿＀-￯]/;
  /* Wraps a line at maxW: words for latin text, characters for CJK. */
  function wrapLine(line, maxW, kind) {
    var tokens = line.match(/[⺀-鿿豈-﫿＀-￯]|[^\s⺀-鿿豈-﫿＀-￯]+|\s+/g) || [''];
    var out = [], cur = '';
    tokens.forEach(function (t) {
      if (cur !== '' && /\S/.test(t) && measure((cur + t).replace(/\s+$/, ''), kind) > maxW) {
        out.push(cur.trim());
        cur = /^\s+$/.test(t) ? '' : t;
      } else {
        cur += t;
      }
    });
    out.push(cur.trim());
    return out;
  }

  /* Node text: first label line is the title, further lines the subtitle. */
  function nodeText(label, maxW) {
    var parts = label.split('\n');
    var lines = [];
    wrapLine(parts[0], maxW, 'title').forEach(function (t) { lines.push({ text: t, kind: 'title' }); });
    parts.slice(1).forEach(function (p) {
      wrapLine(p, maxW, 'sub').forEach(function (t) { lines.push({ text: t, kind: 'sub' }); });
    });
    return lines;
  }

  function linesHeight(lines) {
    return lines.reduce(function (s, l) { return s + (l.kind === 'title' ? TITLE_H : SUB_H); }, 0);
  }

  function nodeBox(n, maxW, minW) {
    var lines = nodeText(n.label, maxW);
    var tw = 0;
    lines.forEach(function (l) { tw = Math.max(tw, measure(l.text, l.kind)); });
    var th = linesHeight(lines);
    var w = Math.max(tw + 32, minW), h = th + 22;
    if (n.shape === 'diamond') { w = Math.max(tw + 64, minW); h = th + 44; }
    else if (n.shape === 'hexagon') { w = Math.max(tw + 56, minW); }
    else if (n.shape === 'circle') { w = h = Math.max(tw + 30, th + 30); }
    else if (n.shape === 'cylinder') { h = th + 34; }
    else if (n.shape === 'stadium' || n.shape === 'round') { w = Math.max(tw + 44, minW); }
    return { lines: lines, w: Math.ceil(w), h: Math.ceil(h) };
  }

  function labelBox(text, maxW) {
    if (!text) return null;
    var lines = [];
    text.split('\n').forEach(function (p) { lines = lines.concat(wrapLine(p, maxW || 150, 'label')); });
    var w = 0;
    lines.forEach(function (l) { w = Math.max(w, measure(l, 'label')); });
    return { lines: lines, w: Math.ceil(w) + 14, h: lines.length * 15 + 6 };
  }

  /* Places nodes of one row at want[] positions, keeping order and minimum separations. */
  function settle(row, want, sep, X) {
    var n = row.length, A = [], B = [], C = [], i;
    for (i = 0; i < n; i++) A[i] = i ? Math.max(want[i], A[i - 1] + sep(row[i - 1], row[i])) : want[i];
    for (i = n - 1; i >= 0; i--) B[i] = i < n - 1 ? Math.min(want[i], B[i + 1] - sep(row[i], row[i + 1])) : want[i];
    for (i = 0; i < n; i++) C[i] = (A[i] + B[i]) / 2;
    for (i = 1; i < n; i++) C[i] = Math.max(C[i], C[i - 1] + sep(row[i - 1], row[i]));
    row.forEach(function (id, j) { X[id] = C[j]; });
  }

  function isNewEdge(g, e) {
    return e.style === 'thick' || (g.nodes[e.from].isNew && g.nodes[e.to].isNew);
  }

  /* ---------- band layout ---------- */

  function topGroup(g, gid) {
    var cur = gid;
    for (;;) {
      var grp = null;
      for (var i = 0; i < g.groups.length; i++) if (g.groups[i].id === cur) grp = g.groups[i];
      if (!grp || grp.parent === null) return cur;
      cur = grp.parent;
    }
  }

  /* Index of the edge running the other way between the same two nodes, or -1. */
  function reverseOf(g, i) {
    var e = g.edges[i];
    for (var j = 0; j < g.edges.length; j++) {
      if (j !== i && g.edges[j].from === e.to && g.edges[j].to === e.from) return j;
    }
    return -1;
  }

  var LANE = 9;

  /* Bands of rows: a band's boxes fill rows of at most `fitWidth` (wrapping into more
   * rows, the band grows taller); rows are the layout unit for edge routing. */
  function bandLayout(g, fitWidth) {
    var V = {};
    g.order.forEach(function (id) {
      var b = nodeBox(g.nodes[id], 200, 120);
      V[id] = { id: id, w: b.w, h: b.h, lines: b.lines };
    });
    var events = g.groups.filter(function (x) { return x.parent === null; }).map(function (x) { return { seq: x.seq, gid: x.id, title: x.title }; });
    g.order.forEach(function (id) { if (g.nodes[id].group === null) events.push({ seq: g.nodes[id].seq, node: id }); });
    events.sort(function (a, b) { return a.seq - b.seq || (a.gid ? -1 : 1); });
    var bands = [], cur = null;
    events.forEach(function (e) {
      if (e.gid) { bands.push({ title: e.title, gid: e.gid, nodes: [] }); cur = null; return; }
      if (!cur) { cur = { title: '', gid: null, nodes: [] }; bands.push(cur); }
      cur.nodes.push(e.node);
    });
    bands.forEach(function (b) {
      if (b.gid === null) return;
      g.order.forEach(function (id) { if (g.nodes[id].group !== null && topGroup(g, g.nodes[id].group) === b.gid) b.nodes.push(id); });
    });
    bands = bands.filter(function (b) { return b.nodes.length; });
    var bandOf = {};
    bands.forEach(function (b, k) { b.nodes.forEach(function (id) { bandOf[id] = k; }); });

    var labels = g.edges.map(function (e) { return labelBox(e.label); });
    function sameRowLabel(a, b) {
      var w = 0;
      g.edges.forEach(function (e, i) {
        if (labels[i] && ((e.from === a && e.to === b) || (e.from === b && e.to === a))) w = Math.max(w, labels[i].w);
      });
      return w;
    }
    function sep(a, b) { return (V[a].w + V[b].w) / 2 + Math.max(40, sameRowLabel(a, b) + 28); }

    /* room right of the boxes for loops back up: one lane each plus the widest label */
    var upCount = 0, upLabel = 0;
    g.edges.forEach(function (e, i) {
      if (bandOf[e.to] < bandOf[e.from] - 1) { upCount += 1; if (labels[i]) upLabel = Math.max(upLabel, labels[i].w); }
    });
    var laneRoom = upCount ? 28 + upCount * 18 + upLabel + 8 : 0;
    var maxRowW = fitWidth ? Math.max(fitWidth - 56 - laneRoom, 160) : Infinity;

    var rows = [];
    bands.forEach(function (b, k) {
      var row = null, width = 0;
      b.nodes.forEach(function (id) {
        var add = row && row.nodes.length ? sep(row.nodes[row.nodes.length - 1], id) - V[row.nodes[row.nodes.length - 1]].w / 2 + V[id].w / 2 : V[id].w;
        if (!row || (row.nodes.length && width + add > maxRowW)) {
          row = { band: k, first: !row, nodes: [] };
          rows.push(row);
          width = V[id].w;
        } else {
          width += add;
        }
        row.nodes.push(id);
      });
    });
    var rowOf = {};
    rows.forEach(function (r, i) { r.nodes.forEach(function (id) { rowOf[id] = i; }); });

    /* x: declaration order per row, aligned toward neighbors in other rows */
    var X = {}, nbr = {};
    g.order.forEach(function (id) { nbr[id] = []; });
    g.edges.forEach(function (e) {
      if (e.from === e.to || rowOf[e.from] === rowOf[e.to]) return;
      nbr[e.from].push(e.to); nbr[e.to].push(e.from);
    });
    rows.forEach(function (r) {
      var x = 0;
      r.nodes.forEach(function (id, i) { if (i) x += sep(r.nodes[i - 1], id); X[id] = x; });
      r.nodes.forEach(function (id) { X[id] -= x / 2; });
    });
    for (var pass = 0; pass < 8; pass++) {
      (pass % 2 ? rows.slice().reverse() : rows).forEach(function (r) {
        settle(r.nodes, r.nodes.map(function (id) {
          return nbr[id].length ? nbr[id].reduce(function (s, n) { return s + X[n]; }, 0) / nbr[id].length : X[id];
        }), sep, X);
      });
    }

    /* keep every row inside the common width, so wrapped rows plus the loop lanes fit */
    if (maxRowW !== Infinity) {
      rows.forEach(function (r) {
        var l = Infinity, rt = -Infinity;
        r.nodes.forEach(function (id) { l = Math.min(l, X[id] - V[id].w / 2); rt = Math.max(rt, X[id] + V[id].w / 2); });
        var shift = 0;
        if (l < -maxRowW / 2) shift = -maxRowW / 2 - l;
        if (rt + shift > maxRowW / 2) shift = maxRowW / 2 - rt;
        if (shift) r.nodes.forEach(function (id) { X[id] += shift; });
      });
    }

    /* y: band title row on a band's first row, room under a row for labels and loops */
    var below = rows.map(function () { return 0; }), loopFrom = rows.map(function () { return false; });
    var above = rows.map(function () { return 0; });
    g.edges.forEach(function (e, i) {
      var a = rowOf[e.from], b = rowOf[e.to];
      if (b > a && labels[i]) below[a] = Math.max(below[a], labels[i].h + 8);
      if (b === a - 1 && labels[i]) above[a] = Math.max(above[a], labels[i].h + 8);
      if (b < a - 1) loopFrom[a] = true;
    });
    var y = 0;
    rows.forEach(function (r, i) {
      var maxH = 0;
      r.nodes.forEach(function (id) { maxH = Math.max(maxH, V[id].h); });
      r.top = y;
      r.rowY = y + (r.first ? 34 : 14) + above[i] + maxH / 2;
      r.nodeTop = r.rowY - maxH / 2;
      r.nodeBottom = r.rowY + maxH / 2;
      r.bottom = r.nodeBottom + 18 + below[i] + (loopFrom[i] ? 12 : 0);
      r.nodes.forEach(function (id) { V[id].x = X[id]; V[id].y = r.rowY; });
      y = r.bottom;
    });
    var bandRects = bands.map(function (b, k) {
      var mine = rows.filter(function (r) { return r.band === k; });
      return { title: b.title, top: mine[0].top, bottom: mine[mine.length - 1].bottom };
    });

    var minX = Infinity, maxX = -Infinity;
    g.order.forEach(function (id) { minX = Math.min(minX, V[id].x - V[id].w / 2); maxX = Math.max(maxX, V[id].x + V[id].w / 2); });

    function blocked(x, ra, rb) {
      for (var k = ra + 1; k < rb; k++) {
        if (rows[k].nodes.some(function (id) { return Math.abs(V[id].x - x) < V[id].w / 2 + 8; })) return true;
      }
      return false;
    }

    /* A column clear of every box in the rows between ra and rb, nearest to x1 and x2:
     * gaps between boxes, then the sides of the widest row. */
    function freeColumn(x1, x2, ra, rb) {
      var cands = [x1, x2], lo = Infinity, hi = -Infinity, taken = [];
      for (var k = ra + 1; k < rb; k++) {
        var xs = rows[k].nodes.map(function (id) { return { id: id, l: V[id].x - V[id].w / 2, r: V[id].x + V[id].w / 2 }; })
          .sort(function (p, q) { return p.l - q.l; });
        for (var j = 1; j < xs.length; j++) {
          /* a gap carrying an edge between its two neighbours (and that edge's label) is taken */
          var p0 = xs[j - 1].id, p1 = xs[j].id;
          var used = g.edges.some(function (e) { return (e.from === p0 && e.to === p1) || (e.from === p1 && e.to === p0); });
          if (used) taken.push({ l: xs[j - 1].r, r: xs[j].l });
          else cands.push((xs[j - 1].r + xs[j].l) / 2);
        }
        lo = Math.min(lo, xs[0].l); hi = Math.max(hi, xs[xs.length - 1].r);
      }
      cands.push(lo - 16, hi + 16);
      var best = null;
      cands.forEach(function (x) {
        if (blocked(x, ra, rb) || taken.some(function (t) { return x > t.l && x < t.r; })) return;
        var cost = Math.abs(x - x1) + Math.abs(x - x2);
        if (best === null || cost < best.cost) best = { x: x, cost: cost };
      });
      return best.x;
    }

    /* back edges two or more rows up loop around the right side, one lane each: the
     * shortest loop takes the innermost lane so nested loops never cross */
    var backLane = {}, backs = [];
    g.edges.forEach(function (e, i) {
      if (e.from === e.to || rowOf[e.to] > rowOf[e.from] - 2) return;
      backs.push({ i: i, span: rows[rowOf[e.from]].bottom - (V[e.to].y - V[e.to].h / 2) });
    });
    backs.sort(function (p, q) { return p.span - q.span || p.i - q.i; }).forEach(function (b, k) { backLane[b.i] = k + 1; });
    var fanDistinct = {};
    g.order.forEach(function (id) {
      var down = g.edges.filter(function (e) { return e.from === id && e.to !== id && rowOf[e.to] > rowOf[id]; });
      fanDistinct[id] = down.length > 1 && down.some(function (e) { return e.label !== down[0].label; });
    });
    var edges = [], laneMax = maxX;
    g.edges.forEach(function (e, i) {
      if (e.from === e.to) return;
      var a = V[e.from], b = V[e.to], ra = rowOf[e.from], rb = rowOf[e.to], lb = labels[i], path, lpos = null, drop = null;
      var rev = reverseOf(g, i);
      /* a request/response pair: each direction in its own lane, labels on the outer side */
      var pairSide = 0;
      if (rev >= 0) {
        if (rb === ra) pairSide = i < rev ? -1 : 1;
        else if (rb === ra + 1) pairSide = -1;
        else if (rb === ra - 1) pairSide = 1;
      }
      var d = pairSide * LANE;
      if (rb > ra) {
        var x1 = a.x + d, x2 = b.x + d, y1 = a.y + a.h / 2, y2 = b.y - b.h / 2;
        if (rb > ra + 1 && (blocked(x1, ra, rb) || blocked(x2, ra, rb))) {
          /* rows in between: drop through a free column, turning under the source row and
           * above the target row */
          var xf = freeColumn(x1, x2, ra, rb), t1 = rows[ra].bottom + pairSide * 5, t2 = rows[rb].top + pairSide * 5;
          /* a branch of a fan-out with distinct labels leaves its box on the side facing its
           * column, so it does not share the trunk and its label or badge has a line of its own */
          if (!pairSide && fanDistinct[e.from]) x1 = Math.max(a.x - a.w / 2 + 14, Math.min(a.x + a.w / 2 - 14, xf));
          path = [{ x: x1, y: y1 }, { x: x1, y: t1 }, { x: xf, y: t1 }, { x: xf, y: t2 }, { x: x2, y: t2 }, { x: x2, y: y2 }];
          drop = pairSide ? null : { col: xf, side: xf < minX ? -1 : (xf > maxX ? 1 : 0), rb: rb };
        } else if (Math.abs(x1 - x2) < 2) {
          path = [{ x: x1, y: y1 }, { x: x1, y: y2 }];
        } else {
          var turn = (rb === ra + 1 ? rows[ra].bottom : (blocked(x1, ra, rb) ? rows[ra].bottom : rows[rb].top)) + pairSide * 5;
          path = [{ x: x1, y: y1 }, { x: x1, y: turn }, { x: x2, y: turn }, { x: x2, y: y2 }];
        }
        if (lb) lpos = { x: d < 0 ? x1 - 6 - lb.w : x1 + 6, y: y1 + 4, align: 'start', fillBand: bandOf[e.from], axis: 'y', seg: 0 };
      } else if (rb === ra) {
        var leftToRight = b.x > a.x;
        var between = rows[ra].nodes.some(function (id) {
          return id !== e.from && id !== e.to && V[id].x > Math.min(a.x, b.x) && V[id].x < Math.max(a.x, b.x);
        });
        if (!between) {
          var sx = a.x + (leftToRight ? a.w / 2 : -a.w / 2), tx = b.x + (leftToRight ? -b.w / 2 : b.w / 2);
          path = [{ x: sx, y: a.y + d }, { x: tx, y: b.y + d }];
          if (lb) lpos = { x: (sx + tx) / 2, y: d > 0 ? a.y + d + 3 : (d < 0 ? a.y + d - lb.h - 3 : a.y - lb.h / 2), align: 'middle', fillBand: bandOf[e.from], axis: 'x', seg: 0 };
        } else {
          /* over the row, from off-center ports so it never merges with edges arriving at a node center */
          var top = rows[ra].nodeTop - 10 + d, dir = leftToRight ? 1 : -1;
          var px = a.x + dir * a.w / 4, qx = b.x - dir * b.w / 4;
          path = [{ x: px, y: a.y - a.h / 2 }, { x: px, y: top }, { x: qx, y: top }, { x: qx, y: b.y - b.h / 2 }];
          if (lb) lpos = { x: (px + qx) / 2, y: top - lb.h / 2, align: 'middle', fillBand: bandOf[e.from], axis: 'x', seg: 1 };
        }
      } else if (rb === ra - 1) {
        /* up to the row right above: straight through the boundary */
        var ux1 = a.x + d, ux2 = b.x + d, uy1 = a.y - a.h / 2, uy2 = b.y + b.h / 2, mid = rows[ra].top + pairSide * 5;
        path = Math.abs(ux1 - ux2) < 2 ? [{ x: ux1, y: uy1 }, { x: ux1, y: uy2 }]
          : [{ x: ux1, y: uy1 }, { x: ux1, y: mid }, { x: ux2, y: mid }, { x: ux2, y: uy2 }];
        if (lb) lpos = { x: d < 0 ? ux1 - 6 - lb.w : ux1 + 6, y: uy1 - lb.h - 4, align: 'start', fillBand: bandOf[e.from], axis: 'y', seg: 0 };
      } else {
        /* back two or more rows up: around the right side */
        var lx = maxX + 28 + (backLane[i] - 1) * 18;
        var exitY = rows[ra].bottom - 8, entryY = b.y - b.h / 2 - 10;
        path = [{ x: a.x, y: a.y + a.h / 2 }, { x: a.x, y: exitY }, { x: lx, y: exitY }, { x: lx, y: entryY }, { x: b.x, y: entryY }, { x: b.x, y: b.y - b.h / 2 }];
        laneMax = Math.max(laneMax, lx);
        if (lb) { lpos = { x: lx + 8, y: (exitY + entryY) / 2 - lb.h / 2, align: 'start', fillBand: null, axis: 'y', seg: 3 }; laneMax = Math.max(laneMax, lx + 8 + lb.w); }
      }
      edges.push({ e: e, pts: path, ortho: true, label: lb, lpos: lpos, isNew: isNewEdge(g, e), drop: drop });
    });

    /* edges dropping through one outer column into one row: each gets a lane of its own
     * there (the lanes step outward from the column), the edge reaching farther along its
     * bottom run inner and turning higher, so the lanes nest without crossing and every
     * edge keeps a line of its own to carry its label */
    var drops = {}, laneMin = minX;
    edges.forEach(function (x) {
      if (!x.drop || !x.drop.side) return;
      var key = Math.round(x.drop.col) + '@' + x.drop.rb;
      (drops[key] = drops[key] || []).push(x);
    });
    Object.keys(drops).forEach(function (key) {
      var grp = drops[key];
      if (grp.length < 2) return;
      var col = grp[0].drop.col, side = grp[0].drop.side, n = grp.length;
      var base = grp[0].pts[3].y, room = Math.min.apply(null, grp.map(function (x) { return x.pts[5].y; })) - 12 - base;
      var step = Math.max(4, Math.min(LANE, room / (n - 1)));
      grp.sort(function (p, q) { return Math.abs(p.pts[5].x - col) - Math.abs(q.pts[5].x - col); });
      grp.forEach(function (x, k) {
        var c = col + side * (n - 1 - k) * LANE, t2 = base + (n - 1 - k) * step;
        x.pts = [x.pts[0], x.pts[1], { x: c, y: x.pts[1].y }, { x: c, y: t2 }, { x: x.pts[4].x, y: t2 }, x.pts[5]];
        laneMin = Math.min(laneMin, c);
        laneMax = Math.max(laneMax, c);
      });
    });

    fanOutLabels(edges, rowOf, bandOf);
    var laneShifts = [];
    separateRuns(edges, V, laneShifts);
    return { V: V, edges: edges, bands: bandRects, left: Math.min(minX - 28, laneMin - 16), right: Math.max(laneMax, maxX) + 24, laneShifts: laneShifts };
  }

  /* Fan-out (several edges down from one box): one identical label is drawn once, on the
   * shared trunk; distinct labels each sit on their own branch, beside its last run into
   * the target, so no label hangs at the split detached from its branch. */
  function fanOutLabels(edges, rowOf, bandOf) {
    var bySrc = {};
    edges.forEach(function (x) {
      if (rowOf[x.e.to] > rowOf[x.e.from]) (bySrc[x.e.from] = bySrc[x.e.from] || []).push(x);
    });
    Object.keys(bySrc).forEach(function (src) {
      var all = bySrc[src], named = all.filter(function (x) { return x.label; });
      if (all.length < 2 || !named.length) return;
      var same = named.length === all.length && named.every(function (x) { return x.e.label === named[0].e.label; });
      if (same) {
        named.slice(1).forEach(function (x) { x.lpos = null; });
        named[0].sharedWith = all;
        return;
      }
      /* on the branch's own run: the longest segment shared neither with a sibling (same
       * source) nor with another edge into the same target; the pill sits on that line */
      named.forEach(function (x) {
        var best = -1, bestLen = 0;
        for (var k = 0; k + 1 < x.pts.length; k++) {
          var a = x.pts[k], b = x.pts[k + 1];
          var shared = edges.some(function (y) {
            if (y === x || !y.pts || (y.e.from !== x.e.from && y.e.to !== x.e.to)) return false;
            for (var m = 0; m + 1 < y.pts.length; m++) if (runLength(a, b, y.pts[m], y.pts[m + 1]) > 4) return true;
            return false;
          });
          var len = Math.hypot(b.x - a.x, b.y - a.y);
          if (!shared && len > bestLen) { best = k; bestLen = len; }
        }
        var n = x.pts.length;
        if (best < 0) best = n - 2;
        var p = x.pts[best], q = x.pts[best + 1];
        var mid = best === n - 2 && Math.abs(p.x - q.x) < 0.5 ? { x: q.x, y: q.y - 8 - x.label.h / 2 } : { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 };
        x.lpos = { x: mid.x, y: mid.y - x.label.h / 2, align: 'middle', fillBand: bandOf[x.e.to], axis: 'y', seg: best };
      });
    });
  }

  function overlap1d(a1, a2, b1, b2) {
    return Math.min(Math.max(a1, a2), Math.max(b1, b2)) - Math.max(Math.min(a1, a2), Math.min(b1, b2));
  }

  /* Length two segments run on top of each other (same horizontal / vertical line). */
  function runLength(p1, p2, q1, q2) {
    var ph = Math.abs(p1.y - p2.y) < 0.5, qh = Math.abs(q1.y - q2.y) < 0.5;
    var pv = Math.abs(p1.x - p2.x) < 0.5, qv = Math.abs(q1.x - q2.x) < 0.5;
    if (ph && qh && Math.abs(p1.y - q1.y) < 1) return overlap1d(p1.x, p2.x, q1.x, q2.x);
    if (pv && qv && Math.abs(p1.x - q1.x) < 1) return overlap1d(p1.y, p2.y, q1.y, q2.y);
    return 0;
  }

  /* Proper crossings of two orthogonal polylines: a horizontal segment of one passing
   * through the interior of a vertical segment of the other. Recorded by point, so lines
   * crossing a shared trunk count once. */
  function crossings(p, q, into) {
    function hit(a1, a2, b1, b2) {
      var ah = Math.abs(a1.y - a2.y) < 0.5, bv = Math.abs(b1.x - b2.x) < 0.5;
      if (!ah || !bv || Math.abs(a1.x - a2.x) < 0.5 || Math.abs(b1.y - b2.y) < 0.5) return;
      if (b1.x > Math.min(a1.x, a2.x) + 0.5 && b1.x < Math.max(a1.x, a2.x) - 0.5 &&
        a1.y > Math.min(b1.y, b2.y) + 0.5 && a1.y < Math.max(b1.y, b2.y) - 0.5) into[Math.round(b1.x) + ',' + Math.round(a1.y)] = true;
    }
    for (var k = 0; k + 1 < p.length; k++) {
      for (var m = 0; m + 1 < q.length; m++) { hit(p[k], p[k + 1], q[m], q[m + 1]); hit(q[m], q[m + 1], p[k], p[k + 1]); }
    }
    return into;
  }

  /* Edges from one box share their trunk, edges into one box share their merge: those
   * runs are intended; any other two edges must not run on one line. */
  function related(x, y) { return x.e.from === y.e.from || x.e.to === y.e.to; }

  function runs(x, y) {
    var worst = 0;
    for (var k = 0; k + 1 < x.pts.length; k++) {
      for (var m = 0; m + 1 < y.pts.length; m++) worst = Math.max(worst, runLength(x.pts[k], x.pts[k + 1], y.pts[m], y.pts[m + 1]));
    }
    return worst;
  }

  /* Moves segment k of an orthogonal path sideways by delta (both end points). */
  function shiftSegment(pts, k, delta) {
    var horizontal = Math.abs(pts[k].y - pts[k + 1].y) < 0.5;
    return pts.map(function (p, i) {
      if (i !== k && i !== k + 1) return p;
      return horizontal ? { x: p.x, y: p.y + delta } : { x: p.x + delta, y: p.y };
    });
  }

  /* A path's end points must stay on the side of their boxes. */
  function portsHold(x, pts, V) {
    var a = V[x.e.from], b = V[x.e.to], p0 = pts[0], p1 = pts[pts.length - 1];
    var firstVertical = Math.abs(pts[0].x - pts[1].x) < 0.5, lastVertical = Math.abs(pts[pts.length - 2].x - p1.x) < 0.5;
    var okA = firstVertical ? Math.abs(p0.x - a.x) <= a.w / 2 - 6 : Math.abs(p0.y - a.y) <= a.h / 2 - 6;
    var okB = lastVertical ? Math.abs(p1.x - b.x) <= b.w / 2 - 6 : Math.abs(p1.y - b.y) <= b.h / 2 - 6;
    return okA && okB;
  }

  /* Lane separation for unrelated edges that would share a run. First one segment steps
   * aside 8 / 16 / 24 px; when the shared run spans several segments (one segment alone
   * cannot clear it), the whole lane of one edge moves: every bend shifts, the end points
   * slide along their box sides. Labels ride along; no move may cut through a box. */
  function separateRuns(edges, V, shifts) {
    var routed = edges.filter(function (x) { return x.pts; });
    function clashes(x, pts) {
      return routed.some(function (y) { return y !== x && !related(x, y) && runs({ pts: pts }, y) > 4; });
    }
    function throughBox(x, pts) {
      var line = edgeSamples({ pts: pts, ortho: true });
      return Object.keys(V).some(function (id) {
        if (id === x.e.from || id === x.e.to) return false;
        var v = V[id];
        return line.some(function (p) { return Math.abs(p.x - v.x) < v.w / 2 - 1 && Math.abs(p.y - v.y) < v.h / 2 - 1; });
      });
    }
    function accept(x, np) { return portsHold(x, np, V) && !clashes(x, np) && !throughBox(x, np); }
    function tryMove(x, k) {
      var deltas = [8, -8, 16, -16, 24, -24];
      for (var t = 0; t < deltas.length; t++) {
        var np = shiftSegment(x.pts, k, deltas[t]);
        if (!accept(x, np)) continue;
        var horizontal = Math.abs(x.pts[k].y - x.pts[k + 1].y) < 0.5;
        if (x.lpos && x.lpos.seg === k) { if (horizontal) x.lpos.y += deltas[t]; else x.lpos.x += deltas[t]; }
        x.pts = np;
        return true;
      }
      return false;
    }
    /* Crossings of a path with every other edge; a run shared with an unrelated edge
     * counts as one too (it hides where the two lines part), so clearing the run is
     * weighed against the crossings the move would add. */
    function crossingsOf(x, pts) {
      var at = {};
      routed.forEach(function (y) {
        if (y === x) return;
        crossings(pts, y.pts, at);
        if (related(x, y)) return;
        for (var k = 0; k + 1 < pts.length; k++) {
          for (var m = 0; m + 1 < y.pts.length; m++) if (runLength(pts[k], pts[k + 1], y.pts[m], y.pts[m + 1]) > 4) at['run' + k + ',' + y.e.from + '>' + y.e.to] = true;
        }
      });
      return Object.keys(at).length;
    }
    /* Every candidate shift (dx, dy in +-8 / +-16 / +-24) is weighed. Of those that clear
     * the run without cutting a box and add no crossing, the one with the fewest
     * crossings wins, the smallest displacement breaking ties; when every candidate adds
     * a crossing the lane stays put. */
    function tryLane(x) {
      var pts = x.pts, n = pts.length;
      var firstVertical = Math.abs(pts[0].x - pts[1].x) < 0.5, lastVertical = Math.abs(pts[n - 2].x - pts[n - 1].x) < 0.5;
      var steps = [8, -8, 16, -16, 24, -24];
      var before = crossingsOf(x, pts), best = null;
      for (var a = 0; a < steps.length; a++) {
        for (var b = 0; b < steps.length; b++) {
          var dx = steps[a], dy = steps[b];
          var np = pts.map(function (p, i) {
            if (i === 0) return firstVertical ? { x: p.x + dx, y: p.y } : { x: p.x, y: p.y + dy };
            if (i === n - 1) return lastVertical ? { x: p.x + dx, y: p.y } : { x: p.x, y: p.y + dy };
            return { x: p.x + dx, y: p.y + dy };
          });
          if (!accept(x, np)) continue;
          var after = crossingsOf(x, np);
          var cost = Math.abs(dx) + Math.abs(dy);
          if (after > before || (best && (after > best.after || (after === best.after && cost >= best.cost)))) continue;
          best = { dx: dx, dy: dy, pts: np, cost: Math.abs(dx) + Math.abs(dy), after: after };
        }
      }
      if (!best) return false;
      if (x.lpos) { x.lpos.x += best.dx; x.lpos.y += best.dy; }
      x.pts = best.pts;
      shifts.push({ from: x.e.from, to: x.e.to, dx: best.dx, dy: best.dy, before: before, after: best.after });
      return true;
    }
    for (var round = 0; round < 8; round++) {
      var moved = false;
      for (var i = 0; i < routed.length; i++) {
        for (var j = i + 1; j < routed.length; j++) {
          var x = routed[i], y = routed[j];
          if (related(x, y) || runs(x, y) <= 4) continue;
          var done = false;
          for (var k = 0; !done && k + 1 < x.pts.length; k++) {
            for (var m = 0; !done && m + 1 < y.pts.length; m++) {
              if (runLength(x.pts[k], x.pts[k + 1], y.pts[m], y.pts[m + 1]) <= 4) continue;
              done = tryMove(y, m) || tryMove(x, k);
            }
          }
          if (!done && runs(x, y) > 4) done = tryLane(y) || tryLane(x);
          if (done) moved = true;
        }
      }
      if (!moved) break;
    }
  }

  /* Points along the drawn path of an edge, every ~3px (bezier segments for the layered
   * layout, straight runs for the orthogonal one). */
  function edgeSamples(x) {
    var out = [], pts = x.pts;
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1], b = pts[i];
      var len = Math.hypot(b.x - a.x, b.y - a.y), n = Math.max(1, Math.ceil(len / 3));
      for (var k = 0; k <= n; k++) {
        var t = k / n;
        if (x.ortho) { out.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }); continue; }
        var c1 = x.horizontal ? { x: (a.x + b.x) / 2, y: a.y } : { x: a.x, y: (a.y + b.y) / 2 };
        var c2 = x.horizontal ? { x: (a.x + b.x) / 2, y: b.y } : { x: b.x, y: (a.y + b.y) / 2 };
        var u = 1 - t;
        out.push({
          x: u * u * u * a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * b.x,
          y: u * u * u * a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * b.y
        });
      }
    }
    return out;
  }

  /* ---------- layered layout ---------- */

  function layeredLayout(g) {
    var horizontal = g.dir === 'LR' || g.dir === 'RL';
    var ids = g.order.slice();
    var V = {};
    ids.forEach(function (id) {
      var b = nodeBox(g.nodes[id], horizontal ? 190 : 210, 110);
      V[id] = { id: id, real: true, w: b.w, h: b.h, lines: b.lines, group: g.nodes[id].group, rank: 0 };
    });

    var out = {};
    ids.forEach(function (id) { out[id] = []; });
    g.edges.forEach(function (e, i) { if (e.from !== e.to) out[e.from].push(i); });
    var seen = {}, onStack = {}, reversed = {};
    function dfs(u) {
      seen[u] = true; onStack[u] = true;
      out[u].forEach(function (i) {
        var v = g.edges[i].to;
        if (onStack[v]) reversed[i] = true;
        else if (!seen[v]) dfs(v);
      });
      onStack[u] = false;
    }
    ids.forEach(function (id) { if (!seen[id]) dfs(id); });
    var L = [];
    g.edges.forEach(function (e, i) {
      if (e.from === e.to) return;
      L.push(reversed[i] ? { a: e.to, b: e.from, edge: i } : { a: e.from, b: e.to, edge: i });
    });

    var indeg = {}, succ = {}, pred = {};
    ids.forEach(function (id) { indeg[id] = 0; succ[id] = []; pred[id] = []; });
    L.forEach(function (l) { indeg[l.b] += 1; succ[l.a].push(l.b); pred[l.b].push(l.a); });
    var queue = ids.filter(function (id) { return indeg[id] === 0; }), topo = [];
    while (queue.length) {
      var u = queue.shift();
      topo.push(u);
      succ[u].forEach(function (v) {
        V[v].rank = Math.max(V[v].rank, V[u].rank + 1);
        if (--indeg[v] === 0) queue.push(v);
      });
    }
    topo.slice().reverse().forEach(function (u) {
      if (pred[u].length || !succ[u].length) return;
      var m = Math.min.apply(null, succ[u].map(function (v) { return V[v].rank; }));
      V[u].rank = Math.max(V[u].rank, m - 1);
    });

    var chains = [];
    L.forEach(function (l, li) {
      var chain = [l.a], ra = V[l.a].rank, rb = V[l.b].rank;
      for (var r = ra + 1; r < rb; r++) {
        var did = '~d' + li + '_' + r;
        var ga = V[l.a].group, gb = V[l.b].group;
        V[did] = { id: did, real: false, w: 8, h: 8, rank: r, group: ga && ga === gb ? ga : null };
        chain.push(did);
      }
      chain.push(l.b);
      chains.push({ chain: chain, edge: l.edge, reversed: l.a !== g.edges[l.edge].from });
    });

    var maxRank = 0;
    Object.keys(V).forEach(function (k) { maxRank = Math.max(maxRank, V[k].rank); });
    var layers = [];
    for (var r = 0; r <= maxRank; r++) layers.push([]);
    var placed = {};
    function place(id) { if (!placed[id]) { placed[id] = true; layers[V[id].rank].push(id); } }
    ids.forEach(place);
    chains.forEach(function (c) { c.chain.forEach(place); });

    var up = {}, down = {};
    Object.keys(V).forEach(function (k) { up[k] = []; down[k] = []; });
    chains.forEach(function (c) {
      for (var i = 0; i + 1 < c.chain.length; i++) { down[c.chain[i]].push(c.chain[i + 1]); up[c.chain[i + 1]].push(c.chain[i]); }
    });

    function indexOf(layer) { var m = {}; layer.forEach(function (id, i) { m[id] = i; }); return m; }
    function sortLayer(layer, ref, nbrs) {
      var pos = indexOf(ref), cur = indexOf(layer), key = {};
      layer.forEach(function (id) {
        var ns = nbrs[id].filter(function (n) { return n in pos; });
        key[id] = ns.length ? ns.reduce(function (s, n) { return s + pos[n]; }, 0) / ns.length : cur[id];
      });
      var gk = {}, gc = {};
      layer.forEach(function (id) {
        var gr = V[id].group;
        if (gr === null || gr === undefined) return;
        gk[gr] = (gk[gr] || 0) + key[id]; gc[gr] = (gc[gr] || 0) + 1;
      });
      layer.sort(function (a, b) {
        var ga = V[a].group, gb = V[b].group;
        var ka = ga ? gk[ga] / gc[ga] : key[a], kb = gb ? gk[gb] / gc[gb] : key[b];
        if (ka !== kb) return ka - kb;
        if (ga !== gb) return String(ga) < String(gb) ? -1 : 1;
        return key[a] - key[b] || cur[a] - cur[b];
      });
    }
    for (var it = 0; it < 12; it++) {
      if (it % 2 === 0) for (var d = 1; d <= maxRank; d++) sortLayer(layers[d], layers[d - 1], up);
      else for (var u2 = maxRank - 1; u2 >= 0; u2--) sortLayer(layers[u2], layers[u2 + 1], down);
    }

    function crossSize(id) { return horizontal ? V[id].h : V[id].w; }
    function mainSize(id) { return horizontal ? V[id].w : V[id].h; }
    function sep(a, b) {
      var base = (V[a].real && V[b].real) ? (horizontal ? 22 : 30) : 12;
      if (V[a].group !== V[b].group) base += 28;
      return (crossSize(a) + crossSize(b)) / 2 + base;
    }
    var X = {};
    layers.forEach(function (layer) {
      var x = 0;
      layer.forEach(function (id, i) { if (i) x += sep(layer[i - 1], id); X[id] = x; });
      layer.forEach(function (id) { X[id] -= x / 2; });
    });
    for (var pass = 0; pass < 6; pass++) {
      var downward = pass % 2 === 0;
      for (var q = downward ? 1 : maxRank - 1; downward ? q <= maxRank : q >= 0; q += downward ? 1 : -1) {
        var layer = layers[q], nb = downward ? up : down;
        settle(layer, layer.map(function (id) {
          var ns = nb[id];
          return ns.length ? ns.reduce(function (s, n) { return s + X[n]; }, 0) / ns.length : X[id];
        }), sep, X);
      }
    }

    var labels = g.edges.map(function (e) { return labelBox(e.label); });
    var labelRoom = [];
    for (var lr = 0; lr <= maxRank; lr++) labelRoom.push(0);
    chains.forEach(function (c) {
      var lb = labels[c.edge];
      if (!lb) return;
      var r0 = V[c.chain[0]].rank;
      if (c.chain.length === 2) labelRoom[r0] = Math.max(labelRoom[r0], horizontal ? lb.w : lb.h);
    });
    var M = [], mainCur = 0;
    for (var rr = 0; rr <= maxRank; rr++) {
      var ms = 0;
      layers[rr].forEach(function (id) { ms = Math.max(ms, mainSize(id)); });
      if (rr) mainCur += M[rr - 1].size / 2 + (horizontal ? 60 : 50) + labelRoom[rr - 1] + ms / 2;
      M.push({ pos: mainCur, size: ms });
    }
    Object.keys(V).forEach(function (id) {
      var mainP = M[V[id].rank].pos, crossP = X[id];
      if (g.dir === 'BT' || g.dir === 'RL') mainP = -mainP;
      V[id].x = horizontal ? mainP : crossP;
      V[id].y = horizontal ? crossP : mainP;
    });

    function port(v, toward) {
      if (!v.real) return { x: v.x, y: v.y };
      if (horizontal) return { x: v.x + (toward.x >= v.x ? v.w / 2 : -v.w / 2), y: v.y };
      return { x: v.x, y: v.y + (toward.y >= v.y ? v.h / 2 : -v.h / 2) };
    }
    var edges = chains.map(function (c) {
      var e = g.edges[c.edge];
      var cids = c.reversed ? c.chain.slice().reverse() : c.chain;
      var pts = cids.map(function (id) { return { x: V[id].x, y: V[id].y }; });
      pts[0] = port(V[cids[0]], pts[1]);
      pts[pts.length - 1] = port(V[cids[cids.length - 1]], pts[pts.length - 2]);
      /* a request/response pair: each direction on its own lane across the main axis */
      var rev = reverseOf(g, c.edge);
      var d = rev < 0 ? 0 : (c.edge < rev ? -LANE : LANE);
      if (d) pts = pts.map(function (p) { return horizontal ? { x: p.x, y: p.y + d } : { x: p.x + d, y: p.y }; });
      var lb = labels[c.edge], lpos = null;
      if (lb) {
        var mid;
        if (pts.length > 2) {
          var k = Math.floor((pts.length - 1) / 2);
          mid = pts.length % 2 ? pts[k] : { x: (pts[k].x + pts[k + 1].x) / 2, y: (pts[k].y + pts[k + 1].y) / 2 };
        } else {
          mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
        }
        lpos = { x: mid.x, y: mid.y - lb.h / 2, align: 'middle', fillBand: null, axis: horizontal ? 'x' : 'y' };
        /* paired labels sit on their lane's outer side */
        if (d && horizontal) lpos.y = d < 0 ? mid.y - lb.h - 3 : mid.y + 3;
        if (d && !horizontal) { lpos.align = 'start'; lpos.x = d < 0 ? mid.x - 6 - lb.w : mid.x + 6; }
      }
      return { e: e, pts: pts, ortho: false, horizontal: horizontal, label: lb, lpos: lpos, isNew: isNewEdge(g, e) };
    });
    g.edges.forEach(function (e) {
      if (e.from !== e.to) return;
      var v = V[e.from];
      edges.push({ e: e, loop: v, label: null, isNew: isNewEdge(g, e) });
    });

    /* subgraph boxes: member nodes and nested boxes, innermost first */
    var boxOf = {};
    g.groups.slice().reverse().forEach(function (grp) {
      var b = null;
      function add(x0, y0, x1, y1) {
        b = b ? { x0: Math.min(b.x0, x0), y0: Math.min(b.y0, y0), x1: Math.max(b.x1, x1), y1: Math.max(b.y1, y1) } : { x0: x0, y0: y0, x1: x1, y1: y1 };
      }
      Object.keys(V).forEach(function (id) {
        var v = V[id];
        if ((v.real ? g.nodes[id].group : v.group) !== grp.id) return;
        add(v.x - v.w / 2, v.y - v.h / 2, v.x + v.w / 2, v.y + v.h / 2);
      });
      g.groups.forEach(function (child) {
        var cb = child.parent === grp.id ? boxOf[child.id] : null;
        if (cb) add(cb.x0, cb.y0, cb.x1, cb.y1);
      });
      if (!b) return;
      var box = { title: grp.title, x0: b.x0 - 16, y0: b.y0 - 34, x1: b.x1 + 16, y1: b.y1 + 14 };
      var tw = measure(grp.title, 'label') + 24;
      if (box.x1 - box.x0 < tw) { var extra = (tw - (box.x1 - box.x0)) / 2; box.x0 -= extra; box.x1 += extra; }
      boxOf[grp.id] = box;
    });
    var boxes = g.groups.map(function (grp) { return boxOf[grp.id]; }).filter(Boolean);
    return { V: V, edges: edges, boxes: boxes };
  }

  /* ---------- SVG ---------- */

  function el(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag);
    Object.keys(attrs || {}).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (parent) parent.appendChild(e);
    return e;
  }

  function shapeEl(shape, v, parent) {
    var x = v.x - v.w / 2, y = v.y - v.h / 2, w = v.w, h = v.h;
    switch (shape) {
      case 'diamond':
        return el('polygon', { points: [v.x + ',' + y, (x + w) + ',' + v.y, v.x + ',' + (y + h), x + ',' + v.y].join(' ') }, parent);
      case 'hexagon': {
        var k = Math.min(18, w / 4);
        return el('polygon', { points: [(x + k) + ',' + y, (x + w - k) + ',' + y, (x + w) + ',' + v.y, (x + w - k) + ',' + (y + h), (x + k) + ',' + (y + h), x + ',' + v.y].join(' ') }, parent);
      }
      case 'circle':
        return el('ellipse', { cx: v.x, cy: v.y, rx: w / 2, ry: h / 2 }, parent);
      case 'cylinder': {
        var ry = 6, gg = el('g', {}, parent);
        el('path', { d: 'M' + x + ',' + (y + ry) + ' a' + (w / 2) + ',' + ry + ' 0 0,1 ' + w + ',0 v' + (h - 2 * ry) + ' a' + (w / 2) + ',' + ry + ' 0 0,1 ' + (-w) + ',0 z' }, gg);
        el('path', { class: 'flow-rim', d: 'M' + x + ',' + (y + ry) + ' a' + (w / 2) + ',' + ry + ' 0 0,0 ' + w + ',0' }, gg);
        return gg;
      }
      case 'stadium':
        return el('rect', { x: x, y: y, width: w, height: h, rx: h / 2 }, parent);
      case 'subroutine': {
        var sg = el('g', {}, parent);
        el('rect', { x: x, y: y, width: w, height: h, rx: 8 }, sg);
        el('path', { class: 'flow-rim', d: 'M' + (x + 8) + ',' + y + ' v' + h + ' M' + (x + w - 8) + ',' + y + ' v' + h }, sg);
        return sg;
      }
      default:
        return el('rect', { x: x, y: y, width: w, height: h, rx: shape === 'round' ? 16 : 10 }, parent);
    }
  }

  function nodeLabel(parent, lines, cx, cy) {
    var total = linesHeight(lines);
    var t = el('text', { 'text-anchor': 'middle', class: 'flow-text' }, parent);
    var y = cy - total / 2;
    lines.forEach(function (l) {
      var lh = l.kind === 'title' ? TITLE_H : SUB_H;
      var ts = el('tspan', { x: cx, y: (y + lh / 2).toFixed(1), 'dominant-baseline': 'central', class: l.kind === 'title' ? 'flow-title' : 'flow-sub' }, t);
      ts.textContent = l.text;
      y += lh;
    });
  }

  function fmt(n) { return n.toFixed(1); }

  /* Orthogonal polyline with rounded corners. */
  function orthoPath(pts) {
    var d = 'M' + fmt(pts[0].x) + ',' + fmt(pts[0].y);
    for (var i = 1; i < pts.length - 1; i++) {
      var p = pts[i - 1], c = pts[i], n = pts[i + 1];
      var r = Math.min(8, Math.hypot(c.x - p.x, c.y - p.y) / 2, Math.hypot(n.x - c.x, n.y - c.y) / 2);
      var a = { x: c.x - Math.sign(c.x - p.x) * r, y: c.y - Math.sign(c.y - p.y) * r };
      var b = { x: c.x + Math.sign(n.x - c.x) * r, y: c.y + Math.sign(n.y - c.y) * r };
      d += ' L' + fmt(a.x) + ',' + fmt(a.y) + ' Q' + fmt(c.x) + ',' + fmt(c.y) + ' ' + fmt(b.x) + ',' + fmt(b.y);
    }
    var last = pts[pts.length - 1];
    return d + ' L' + fmt(last.x) + ',' + fmt(last.y);
  }

  function curvePath(pts, horizontal) {
    var d = 'M' + fmt(pts[0].x) + ',' + fmt(pts[0].y);
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1], b = pts[i];
      var c1 = horizontal ? { x: (a.x + b.x) / 2, y: a.y } : { x: a.x, y: (a.y + b.y) / 2 };
      var c2 = horizontal ? { x: (a.x + b.x) / 2, y: b.y } : { x: b.x, y: (a.y + b.y) / 2 };
      d += ' C' + fmt(c1.x) + ',' + fmt(c1.y) + ' ' + fmt(c2.x) + ',' + fmt(c2.y) + ' ' + fmt(b.x) + ',' + fmt(b.y);
    }
    return d;
  }

  function labelRect(x) {
    var p = x.lpos, lb = x.label;
    var x0 = p.align === 'middle' ? p.x - lb.w / 2 : p.x;
    return { x0: x0, y0: p.y, x1: x0 + lb.w, y1: p.y + lb.h };
  }

  function overlaps(a, b) { return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1; }

  /* Final label pass. A label belongs where it reads as its edge's: touching or right
   * beside its own line (within LABEL_REACH px), nearer to it than to any other edge, on
   * no other edge's line, over no box and no other label. The routed spot is kept when it
   * qualifies; otherwise the nearest qualifying spot along the own line (on it, beside it
   * left / right, above / below) wins; failing that the label is wrapped narrower and the
   * search repeats; a label that still fits nowhere becomes a numbered badge (placeBadges). */
  var LABEL_REACH = 12;

  function rectDist(r, p) {
    var dx = Math.max(r.x0 - p.x, 0, p.x - r.x1), dy = Math.max(r.y0 - p.y, 0, p.y - r.y1);
    return Math.sqrt(dx * dx + dy * dy);
  }

  function resolveLabels(lay, g) {
    var boxes = g.order.map(function (id) {
      var v = lay.V[id];
      return { x0: v.x - v.w / 2 - 2, y0: v.y - v.h / 2 - 2, x1: v.x + v.w / 2 + 2, y1: v.y + v.h / 2 + 2 };
    }).concat(lay.titles || []);
    /* in band mode a label stays inside the bands */
    function outside(r) { return lay.bandMode && (r.x0 < lay.left + 2 || r.x1 > lay.right - 2); }
    var placed = [];
    var lines = lay.edges.filter(function (x) { return x.pts; }).map(function (x) { return { edge: x, pts: edgeSamples(x) }; });
    function nearest(r, pts) {
      var m = Infinity;
      for (var i = 0; i < pts.length; i++) { var d = rectDist(r, pts[i]); if (d < m) m = d; }
      return m;
    }
    function fits(r, own, ownPts) {
      if (outside(r)) return false;
      if (boxes.some(function (b) { return overlaps(r, b); }) || placed.some(function (b) { return overlaps(r, b); })) return false;
      var mine = nearest(r, ownPts);
      if (mine > LABEL_REACH) return false;
      return !lines.some(function (l) {
        if (own.indexOf(l.edge) >= 0) return false;
        return nearest(r, l.pts) <= mine;
      });
    }
    function spots(lb, ownPts, anchor) {
      var out = [];
      for (var i = 0; i < ownPts.length; i += 3) {
        var p = ownPts[i];
        [[p.x - lb.w / 2, p.y - lb.h / 2], [p.x + 6, p.y - lb.h / 2], [p.x - 6 - lb.w, p.y - lb.h / 2],
          [p.x - lb.w / 2, p.y - 4 - lb.h], [p.x - lb.w / 2, p.y + 4]].forEach(function (c) {
          out.push({ x0: c[0], y0: c[1], x1: c[0] + lb.w, y1: c[1] + lb.h });
        });
      }
      out.sort(function (a, b) {
        return Math.hypot((a.x0 + a.x1) / 2 - anchor.x, (a.y0 + a.y1) / 2 - anchor.y) - Math.hypot((b.x0 + b.x1) / 2 - anchor.x, (b.y0 + b.y1) / 2 - anchor.y);
      });
      return out;
    }
    lay.edges.forEach(function (x) {
      if (!x.label || !x.lpos) return;
      var own = x.sharedWith || [x];
      var ownPts = [];
      lines.forEach(function (l) { if (own.indexOf(l.edge) >= 0) ownPts = ownPts.concat(l.pts); });
      var base = labelRect(x);
      var anchor = { x: (base.x0 + base.x1) / 2, y: (base.y0 + base.y1) / 2 };
      if (!fits(base, own, ownPts)) {
        var widths = [x.label.w, 96, 64], found = null;
        for (var w = 0; w < widths.length && !found; w++) {
          var lb = w === 0 ? x.label : labelBox(x.e.label, widths[w] - 14);
          if (w > 0 && lb.w >= x.label.w) continue;
          var cand = spots(lb, ownPts, anchor);
          for (var c = 0; c < cand.length; c++) {
            if (fits(cand[c], own, ownPts)) { found = { r: cand[c], lb: lb }; break; }
          }
        }
        if (!found) { x.badge = { anchor: anchor }; return; }
        x.label = found.lb;
        x.lpos.align = 'start';
        x.lpos.x = found.r.x0;
        x.lpos.y = found.r.y0;
      }
      placed.push(labelRect(x));
    });
    placeBadges(lay, boxes, placed, lines, outside);
  }

  /* A label with no qualifying spot becomes a numbered badge on its own line: a small
   * circle clear of every box, label, other badge and foreign line (never on an arrow
   * head or a port), nearest the label's routed spot. Badges are numbered in reading
   * order (top to bottom, then left to right) and listed under the chart. */
  var BADGE_R = 9;

  function placeBadges(lay, boxes, placed, lines, outside) {
    var todo = lay.edges.filter(function (x) { return x.badge; });
    var done = [];
    todo.forEach(function (x) {
      var own = lines.filter(function (l) { return l.edge === x; })[0];
      var pts = own ? own.pts : [];
      var along = [0];
      for (var i = 1; i < pts.length; i++) along.push(along[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
      var total = along[along.length - 1] || 0;
      function clearance(p) {
        var r = { x0: p.x - BADGE_R, y0: p.y - BADGE_R, x1: p.x + BADGE_R, y1: p.y + BADGE_R };
        if (outside(r) || boxes.some(function (b) { return overlaps(r, b); }) || placed.some(function (b) { return overlaps(r, b); })) return -1;
        var m = Infinity;
        done.forEach(function (b) { m = Math.min(m, Math.hypot(b.x - p.x, b.y - p.y) - 2 * BADGE_R); });
        lines.forEach(function (l) {
          if (l.edge === x) return;
          for (var k = 0; k < l.pts.length; k++) m = Math.min(m, Math.hypot(l.pts[k].x - p.x, l.pts[k].y - p.y) - BADGE_R);
        });
        return m;
      }
      var a = x.badge.anchor, best = null, bestScore = -Infinity, fallback = null;
      var cands = pts.map(function (p, k) { return { p: p, k: k }; }).filter(function (c) {
        return along[c.k] >= 16 && total - along[c.k] >= 18;
      });
      if (!cands.length && pts.length) cands = [{ p: pts[Math.floor(pts.length / 2)], k: 0 }];
      cands.sort(function (c, d) { return Math.hypot(c.p.x - a.x, c.p.y - a.y) - Math.hypot(d.p.x - a.x, d.p.y - a.y); });
      for (var c = 0; c < cands.length; c++) {
        var s = clearance(cands[c].p);
        if (s >= 3) { best = cands[c].p; break; }
        if (s > bestScore) { bestScore = s; fallback = cands[c].p; }
      }
      var p = best || fallback || a;
      x.badge = { x: p.x, y: p.y, r: BADGE_R, n: 0 };
      done.push(x.badge);
    });
    todo.slice().sort(function (p, q) { return (p.badge.y - q.badge.y) || (p.badge.x - q.badge.x); })
      .forEach(function (x, i) { x.badge.n = i + 1; });
  }

  function labelText(x) { return x.e.label.replace(/\s*\n\s*/g, ' '); }

  function compute(g, opts) {
    measureOverride = opts.measure || null;
    try {
      var bandMode = g.dir === 'TD' && g.groups.length > 0;
      var lay = bandMode ? bandLayout(g, opts.fitWidth || 0) : layeredLayout(g);
      lay.bandMode = bandMode;
      /* bands span the card: widen them (content stays centered) up to opts.fitWidth */
      if (bandMode && opts.fitWidth && lay.right - lay.left < opts.fitWidth - 2) {
        var extra = (opts.fitWidth - 2 - (lay.right - lay.left)) / 2;
        lay.left -= extra;
        lay.right += extra;
      }
      /* band titles (drawn at left + 14, baseline top + 18) are obstacles for labels */
      lay.titles = bandMode ? lay.bands.filter(function (b) { return b.title; }).map(function (b) {
        return { x0: lay.left + 12, y0: b.top + 3, x1: lay.left + 16 + measure(b.title, 'title'), y1: b.top + 23 };
      }) : [];
      resolveLabels(lay, g);
      return lay;
    } finally {
      measureOverride = null;
    }
  }

  /* Geometry only (no DOM): node rects, edge polylines, label rects. */
  function layoutInfo(g, opts) {
    var lay = compute(g, opts || {});
    return {
      mode: lay.bandMode ? 'bands' : 'layered',
      nodes: g.order.map(function (id) {
        var v = lay.V[id];
        return { id: id, x0: v.x - v.w / 2, y0: v.y - v.h / 2, x1: v.x + v.w / 2, y1: v.y + v.h / 2 };
      }),
      edges: lay.edges.filter(function (x) { return !x.loop; }).map(function (x) {
        return {
          from: x.e.from, to: x.e.to, text: x.e.label, ortho: !!x.ortho, pts: x.pts, line: edgeSamples(x),
          label: x.label && x.lpos && !x.badge ? labelRect(x) : null,
          badge: x.badge ? { n: x.badge.n, x: x.badge.x, y: x.badge.y, r: x.badge.r } : null
        };
      }),
      badges: badgeList(lay),
      titles: lay.titles,
      bounds: lay.bandMode ? { x0: lay.left, x1: lay.right } : null,
      laneShifts: lay.laneShifts || []
    };
  }

  function badgeList(lay) {
    return lay.edges.filter(function (x) { return x.badge; })
      .map(function (x) { return { n: x.badge.n, text: labelText(x), isNew: !!x.isNew, from: x.e.from, to: x.e.to }; })
      .sort(function (a, b) { return a.n - b.n; });
  }

  function svg(g, opts) {
    opts = opts || {};
    var lay = compute(g, opts);
    var bandMode = lay.bandMode;
    var V = lay.V;
    svgCount += 1;
    var mk = 'sdd-flow-arrow-' + svgCount, mkNew = mk + '-new';
    var root = el('svg', { class: 'flow' + (bandMode ? ' flow-bands' : ''), role: 'img', 'aria-label': opts.label || 'diagram' });
    var defs = el('defs', {}, root);
    [[mk, 'flow-arrow'], [mkNew, 'flow-arrow new']].forEach(function (m) {
      var marker = el('marker', { id: m[0], viewBox: '0 0 10 10', refX: '9', refY: '5', markerWidth: '7', markerHeight: '7', orient: 'auto-start-reverse' }, defs);
      el('path', { d: 'M0,1 L9,5 L0,9 z', class: m[1] }, marker);
    });

    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    function grow(x0, y0, x1, y1) { minX = Math.min(minX, x0); minY = Math.min(minY, y0); maxX = Math.max(maxX, x1); maxY = Math.max(maxY, y1); }
    g.order.forEach(function (id) { var v = V[id]; grow(v.x - v.w / 2, v.y - v.h / 2, v.x + v.w / 2, v.y + v.h / 2); });

    var back = el('g', { class: 'flow-back' }, root);
    if (bandMode) {
      lay.bands.forEach(function (b, k) {
        var gg = el('g', { class: 'flow-band' + (k % 2 ? ' odd' : ' even') }, back);
        el('rect', { x: lay.left, y: b.top, width: lay.right - lay.left, height: b.bottom - b.top }, gg);
        if (b.title) {
          var t = el('text', { x: lay.left + 14, y: b.top + 18, class: 'flow-band-title' }, gg);
          t.textContent = b.title;
        }
      });
      grow(lay.left, lay.bands[0].top, lay.right, lay.bands[lay.bands.length - 1].bottom);
    } else {
      lay.boxes.forEach(function (b) {
        var gg = el('g', { class: 'flow-group' }, back);
        el('rect', { x: b.x0, y: b.y0, width: b.x1 - b.x0, height: b.y1 - b.y0, rx: 12 }, gg);
        var t = el('text', { x: b.x0 + 12, y: b.y0 + 19, class: 'flow-band-title' }, gg);
        t.textContent = b.title;
        grow(b.x0, b.y0, b.x1, b.y1);
      });
    }

    var edgeLayer = el('g', { class: 'flow-edges' }, root);
    var labelLayer = el('g', { class: 'flow-elabels' }, root);
    var hasNew = false;
    lay.edges.forEach(function (x) {
      var e = x.e;
      if (x.isNew) hasNew = true;
      var cls = 'flow-edge ' + e.style + (x.isNew ? ' new' : '');
      var marker = 'url(#' + (x.isNew ? mkNew : mk) + ')';
      var d;
      if (x.loop) {
        var lx = x.loop.x + x.loop.w / 2, ly = x.loop.y;
        d = 'M' + lx + ',' + (ly - 8) + ' c 28,-24 28,40 0,16';
        grow(lx, ly - 30, lx + 30, ly + 30);
      } else {
        d = x.ortho ? orthoPath(x.pts) : curvePath(x.pts, x.horizontal);
        x.pts.forEach(function (p) { grow(p.x - 4, p.y - 4, p.x + 4, p.y + 4); });
      }
      var attrs = { d: d, class: cls };
      if (e.arrow) attrs['marker-end'] = marker;
      if (e.arrowStart) attrs['marker-start'] = marker;
      el('path', attrs, edgeLayer);
      if (x.badge) {
        var bt = labelText(x);
        var bg = el('g', { class: 'flow-badge' + (x.isNew ? ' new' : ''), tabindex: '0', role: 'img', 'aria-label': bt, 'data-badge': String(x.badge.n) }, labelLayer);
        el('title', {}, bg).textContent = bt;
        el('circle', { cx: fmt(x.badge.x), cy: fmt(x.badge.y), r: x.badge.r }, bg);
        var bn = el('text', { x: fmt(x.badge.x), y: fmt(x.badge.y), 'text-anchor': 'middle', 'dominant-baseline': 'central', class: 'flow-badge-num', 'aria-hidden': 'true' }, bg);
        bn.textContent = String(x.badge.n);
        grow(x.badge.x - x.badge.r, x.badge.y - x.badge.r, x.badge.x + x.badge.r, x.badge.y + x.badge.r);
      } else if (x.label && x.lpos) {
        var lb = x.label, p = x.lpos;
        var x0 = p.align === 'middle' ? p.x - lb.w / 2 : p.x;
        var lg = el('g', { class: 'flow-elabel' + (p.fillBand !== null && p.fillBand !== undefined ? (p.fillBand % 2 ? ' on-odd' : ' on-even') : '') + (x.isNew ? ' new' : '') }, labelLayer);
        el('rect', { x: x0, y: p.y, width: lb.w, height: lb.h, rx: Math.min(8, lb.h / 2) }, lg);
        var tt = el('text', { class: 'flow-elabel-text' }, lg);
        lb.lines.forEach(function (l, i) {
          var ts = el('tspan', { x: x0 + lb.w / 2, y: fmt(p.y + 3 + 7.5 + i * 15), 'text-anchor': 'middle', 'dominant-baseline': 'central' }, tt);
          ts.textContent = l;
        });
        grow(x0, p.y, x0 + lb.w, p.y + lb.h);
      }
    });

    var nodeLayer = el('g', { class: 'flow-nodes' }, root);
    g.order.forEach(function (id) {
      var n = g.nodes[id], v = V[id];
      if (n.isNew) hasNew = true;
      var tone = n.isNew ? ' tone-new' : (n.tone ? ' tone-' + n.tone : '');
      var ng = el('g', { class: 'flow-node shape-' + n.shape + tone, 'data-id': id }, nodeLayer);
      var tip = el('title', {}, ng);
      tip.textContent = n.tip || n.label;
      shapeEl(n.shape, v, ng);
      nodeLabel(ng, v.lines, v.x, v.y);
    });

    var pad = bandMode ? 1 : 12;
    var W = Math.ceil(maxX - minX + 2 * pad), H = Math.ceil(maxY - minY + 2 * pad);
    root.setAttribute('viewBox', fmt(minX - pad) + ' ' + fmt(minY - pad) + ' ' + W + ' ' + H);
    root.setAttribute('width', W);
    root.setAttribute('height', H);
    /* scales down to the card; scrolls instead once it would shrink below 90% */
    root.style.width = '100%';
    root.style.maxWidth = W + 'px';
    root.style.minWidth = Math.round(W / 1.1) + 'px';
    root.style.height = 'auto';
    root.sddHasNew = hasNew;
    root.sddNodeCount = g.order.length;
    /* numbered badges (labels with no clear spot) for the legend under the chart; the
     * chart turns into a labelled group then so its focusable badges stay reachable */
    root.sddBadges = badgeList(lay);
    if (root.sddBadges.length) root.setAttribute('role', 'group');
    return root;
  }

  /* separateRuns is exposed for the view suite (synthetic routing cases) */
  SDD.flow = { parse: parse, header: header, svg: svg, layout: layoutInfo, separateRuns: separateRuns };
})();
