#!/bin/sh
# tools/test-views.sh — regression checks for core/views (render.sh, render.ps1, precheck.js).
# Not shipped. Needs sh + cksum + node; pwsh and dash are used when found.
#
#   sh tools/test-views.sh
#
# Fixtures (tools/view-fixtures/): good (well-formed, all five stages), malformed (one broken
# section per stage), edge (</script> variants, <!--, Chinese, CRLF, empty file),
# diffrec (diff-mode verify record). Every run works on copies in a temp dir.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
VIEWS="${VIEWS_DIR:-$ROOT/core/views}"   # VIEWS_DIR=<generated tree>/views re-runs the suite against a shipped copy
# the Codex tree ships the sigil-transformed copy, so its stale lines name $spec-view
case "$VIEWS" in */codex/*) VIEW_CMD='$spec-view' ;; *) VIEW_CMD=/spec:view ;; esac
R="$VIEWS/render.sh"
FIX="$ROOT/tools/view-fixtures"
FIXTURES="good malformed edge diffrec keyflow flows badflow reqresp drill indented adv1 adv2 adv3 adv4 adv5 adv6 adv7 adv8 listcode listcode2 fence2 fence3 fence4 checkout"
STAGES="research ask design proposal verify"

command -v node > /dev/null 2>&1 || { echo "FAIL: node not found (needed for byte-level checks)"; exit 1; }

T=$(mktemp -d) || exit 1
cleanup() {
  case $T in
    /tmp/?*|*/Temp/?*|*/tmp/?*) rm -rf -- "$T" ;;
  esac
}
trap cleanup EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }
expect() {
  # expect <description> <expected> <actual>
  if [ "$2" = "$3" ]; then ok; else
    bad "$1"
    printf '  expected: %s\n  actual:   %s\n' "$2" "$3" | sed 's/^/  /'
  fi
}

fresh() {
  # fresh <name>: a clean copy of all fixtures under $T/<name>
  mkdir -p "$T/$1"
  cp -r "$FIX"/* "$T/$1"/
}

nl='
'

# ---------- node helpers ----------

# Prints "<src>|<cksum attr>|<extra attrs>" per data block, and fails (exit 1) when a block
# holds a raw `<`, when un-escaping does not reproduce the embedded bytes (the source, or
# for data-translated blocks the translation body after its header line), or when the
# closing-tag count differs from the opening count.
NODE_BLOCKS='
const fs = require("fs"), path = require("path");
const page = process.argv[1], dir = process.argv[2];
const buf = fs.readFileSync(page), s = buf.toString("latin1");
const open = /<script type="text\/markdown" data-src="([^"]*)" data-cksum="([^"]*)"([^>]*)>/g;
let m, errs = [];
while ((m = open.exec(s))) {
  const start = m.index + m[0].length, end = s.indexOf("</script>", start);
  const body = s.slice(start, end);
  if (body.includes("<")) errs.push(m[1] + ": raw < inside data block");
  const back = Buffer.from(body.replace(/&lt;/g, "<").replace(/&amp;/g, "&"), "latin1");
  const tr = / data-lang="([^"]*)" data-translated="1"/.exec(m[3]);
  let want = fs.readFileSync(path.join(dir, m[1]));
  if (tr) {
    const t = fs.readFileSync(path.join(dir, "view", tr[1], m[1]));
    const nl = t.indexOf(10);
    want = nl < 0 ? Buffer.alloc(0) : t.subarray(nl + 1);
  }
  if (!back.equals(want)) errs.push(m[1] + ": round-trip differs from the embedded " + (tr ? "translation" : "source"));
  console.log(m[1] + "|" + m[2] + "|" + m[3].trim());
}
const closes = (s.match(/<\/script/gi) || []).length;
const opens = (s.match(/<script[\s>]/gi) || []).length;
if (closes !== opens) errs.push("closing </script count " + closes + " != opening count " + opens);
if (errs.length) { console.error(errs.join("\n")); process.exit(1); }
'

# Prints the `fallback:` lines sddPrecheck yields for <stage> over the files present in <dir>.
NODE_PRECHECK='
const fs = require("fs"), vm = require("vm"), path = require("path");
const [js, stage, dir] = process.argv.slice(1);
const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(js, "utf8"), ctx);
const names = { research: ["research.md", "index.md"], ask: ["research.md"], design: ["design.md"],
  proposal: ["proposal.md", "gate.md", "research.md", "index.md", "verify.md"], verify: ["verify.md"] }[stage];
const src = {};
for (const n of names) { const p = path.join(dir, n); if (fs.existsSync(p)) src[n] = fs.readFileSync(p, "utf8"); }
ctx.__src = src; ctx.__stage = stage;
const out = vm.runInContext("sddPrecheck(__stage, __src)", ctx);
if (!out.length) console.log("fallback: none");
for (const f of out) console.log("fallback: " + f.heading + " — " + f.reason);
'

PRECHECK_JS="$VIEWS/shared/precheck.js"
case $(uname -s 2>/dev/null) in
  MINGW*|MSYS*|CYGWIN*) command -v cygpath > /dev/null 2>&1 && PRECHECK_JS=$(cygpath -m "$PRECHECK_JS") ;;
esac

# ---------- 1. render: pages, fallback lines, tiers ----------

fresh sh
cd "$T/sh" || exit 1

for f in good malformed; do
  for tier in standard advanced; do
    out=$(sh "$R" "$f" all "$tier"); rc=$?
    expect "$f all $tier exit 0" 0 "$rc"
    expect "$f all $tier: five view lines" 5 "$(printf '%s\n' "$out" | grep -c '^view: ')"
    for s in $STAGES; do
      [ -f "$f/view/$s.html" ] && ok || bad "$f all $tier: $f/view/$s.html written"
    done
    [ "$tier" = standard ] && cp -r "$f/view" "$f/view-standard"
    eval "out_${f}_${tier}=\$out"
  done
done

expected_good="view: good/view/research.html
fallback: none
view: good/view/ask.html
fallback: none
view: good/view/design.html
fallback: none
view: good/view/proposal.html
fallback: none
view: good/view/verify.html
fallback: none"
expect "good advanced stdout" "$expected_good" "$out_good_advanced"

expected_malformed="view: malformed/view/research.html
fallback: Practices — no \`- <name> — <body>\` option lines
view: malformed/view/ask.html
fallback: [TBD-2] — no \`| candidates: ... | select: one|several\` fields
view: malformed/view/design.html
fallback: Interfaces — heading \`## Interfaces\` not found
view: malformed/view/proposal.html
fallback: What — no \`- \` or \`N. \` items
view: malformed/view/verify.html
fallback: frontmatter — no \`conclusion:\` in YAML frontmatter"
expect "malformed advanced stdout names each broken section" "$expected_malformed" "$out_malformed_advanced"

expect "malformed standard stdout: no fallbacks" 5 "$(printf '%s\n' "$out_malformed_standard" | grep -c '^fallback: none$')"
for s in $STAGES; do
  for f in good malformed; do
    n=$(grep -cE 'format not recognized|data-sdd-fallback' "$f/view-standard/$s.html")
    expect "standard $f $s.html carries no fallback marker ('format not recognized' / data-sdd-fallback)" 0 "$n"
  done
  grep -q 'data-sdd-fallback' "malformed/view/$s.html" && grep -q 'format not recognized' "malformed/view/$s.html" \
    && ok || bad "advanced malformed $s.html carries the fallback marker code"
done

# ---------- 1b. UI string table (zh / en) ----------

STRINGS_JS="$VIEWS/shared/strings.js"
command -v cygpath > /dev/null 2>&1 && STRINGS_JS=$(cygpath -m "$STRINGS_JS")
keys=$(node -e '
const fs = require("fs"), vm = require("vm"), ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const t = vm.runInContext("SDD_STRINGS", ctx), zh = Object.keys(t.zh).sort(), en = Object.keys(t.en).sort();
const onlyZh = zh.filter(k => !en.includes(k)), onlyEn = en.filter(k => !zh.includes(k));
console.log(onlyZh.length || onlyEn.length ? "mismatch zh-only=" + onlyZh + " en-only=" + onlyEn : "same " + zh.length);
' "$STRINGS_JS")
case $keys in "same "*) ok ;; *) bad "zh / en string tables have identical key sets ($keys)" ;; esac
heads=$(node -e '
const fs = require("fs"), vm = require("vm"), ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const t = vm.runInContext("SDD_STRINGS", ctx);
const h = l => Object.keys(t[l]).filter(k => k.startsWith("head.")).sort().join(",");
console.log(h("zh") === h("en") && h("zh") !== "" ? "same" : "zh=" + h("zh") + " en=" + h("en"));
' "$STRINGS_JS")
expect "head.* keys: identical non-empty sets in zh and en" same "$heads"
# canonical headers inside rendered markdown (the proposal page's verify.md ledger, the
# research page's index.md, plain fallbacks) go through SDD.headingLabel
APP_JS="$VIEWS/shared/app.js"
command -v cygpath > /dev/null 2>&1 && APP_JS=$(cygpath -m "$APP_JS")
labels=$(node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { navigator: {} };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
const out = [];
for (const lang of ["zh", "en"]) {
  ctx.SDD.lang = lang;
  out.push(lang + ":" + ["Findings", "Evidence (round 1)", "Requirements", "Some Custom Header"].map(ctx.SDD.headingLabel).join("|"));
}
console.log(out.join(" / "));
' "$STRINGS_JS" "$APP_JS")
expect "headingLabel maps the ledger / index headers (zh) and leaves others" \
  "zh:发现|证据 (round 1)|需求|Some Custom Header / en:Findings|Evidence (round 1)|Requirements|Some Custom Header" "$labels"
grep -q "var label = SDD.headingLabel(orig);" "$VIEWS/shared/app.js" && ok || bad "SDD.mdBlock labels the ## headers of rendered markdown"
for page in good/view/research.html good/view-standard/research.html; do
  grep -q '^var SDD_STRINGS = {' "$page" && ok || bad "English fixture page $page carries the string table"
done
sh "$R" edge research standard > /dev/null
for page in edge/view/research.html; do
  grep -q '^var SDD_STRINGS = {' "$page" && ok || bad "CJK fixture page $page carries the string table"
done
sh "$R" edge research > /dev/null
# Every literal SDD.t('key') used by the shipped JS exists in the table (prefix keys built
# at runtime — 'stage.' + stage, 'tier.' + tier, 'field.' + name — are covered by the
# zh/en key-set check and the browser run, not here).
used=$(cat "$VIEWS"/shared/*.js "$VIEWS"/template/*.html | grep -o "SDD\.t('[a-zA-Z.]*[a-zA-Z]'" | sed "s/SDD\.t('//; s/'$//" | sort -u)
for k in $used; do
  grep -q "^    '$k': " "$VIEWS/shared/strings.js" && ok || bad "UI string key '$k' used but missing from strings.js"
done

out=$(sh "$R" edge all); rc=$?
expect "edge all exit 0" 0 "$rc"
expect "edge all renders research, ask, design" "view: edge/view/research.html|view: edge/view/ask.html|view: edge/view/design.html" \
  "$(printf '%s\n' "$out" | grep '^view: ' | tr '\n' '|' | sed 's/|$//')"
out=$(sh "$R" diffrec all); rc=$?
expect "diff-mode record: verify only, no fallback" "view: diffrec/view/verify.html${nl}fallback: none" "$out"
sh "$R" edge all standard > /dev/null && cp -r edge/view edge/view-standard && sh "$R" edge all > /dev/null
sh "$R" diffrec all standard > /dev/null && cp -r diffrec/view diffrec/view-standard && sh "$R" diffrec all > /dev/null

# ---------- 1c. key-flow diagrams (proposal.md ## How) and the offline flowchart parser ----------

out=$(sh "$R" badflow all); rc=$?
expect "How key-flow block that is not a flowchart: named fallback" \
  "0|view: badflow/view/proposal.html${nl}fallback: How — key-flow diagram not parsed" "$rc|$out"
out=$(sh "$R" keyflow all | grep -v '^view: ' | sort -u)
expect "keyflow change (authored TD key-flow with bands): no fallback on any stage" "fallback: none" "$out"
out=$(sh "$R" flows all)
expect "design with TD-band, 16-node LR and a sequence diagram: no fallback" "view: flows/view/design.html${nl}fallback: none" "$out"
mkdir -p kf-variants
for v in "flowchart LR|ok" "graph TD;|ok" "%% note|ok" "sequenceDiagram|bad" "|bad"; do
  first=${v%|*}
  { printf '# Proposal: v\n\n## Why\nw\n\n## What\n1. **x** | refs: R-1\n\n## How\n```mermaid\n'
    [ -n "$first" ] && printf '%s\n' "$first"
    [ "$first" = "%% note" ] && printf 'flowchart TD\n'
    printf '  A --> B\n```\n\n## Risk\n- r\n'; } > kf-variants/proposal.md
  got=$(sh "$R" kf-variants proposal | grep -c 'fallback: How')
  [ "${v#*|}" = ok ] && want=0 || want=1
  expect "key-flow header '$first': fallback line count" "$want" "$got"
  jsgot=$(node -e "$NODE_PRECHECK" "$PRECHECK_JS" proposal kf-variants | grep -c 'fallback: How')
  expect "key-flow header '$first': precheck.js agrees" "$want" "$jsgot"
done
FLOW_JS="$VIEWS/shared/flow.js"
command -v cygpath > /dev/null 2>&1 && FLOW_JS=$(cygpath -m "$FLOW_JS")
flowcheck=$(node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { window: { SDD: {} } };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const flow = ctx.window.SDD.flow;
function blocks(file) {
  const out = []; let cur = null;
  fs.readFileSync(file, "utf8").split("\n").forEach(function (l) {
    if (cur === null && /^```mermaid\s*$/.test(l)) { cur = []; return; }
    if (cur !== null && /^```/.test(l)) { out.push(cur.join("\n")); cur = null; return; }
    if (cur !== null) cur.push(l);
  });
  return out;
}
const res = [];
const kf = flow.parse(blocks(process.argv[2])[0]);
res.push("keyflow " + kf.dir + " nodes=" + kf.order.length + " edges=" + kf.edges.length + " groups=" + kf.groups.length +
  " new=" + kf.order.filter(function (id) { return kf.nodes[id].isNew; }).length + " labelled=" + kf.edges.filter(function (e) { return e.label; }).length);
blocks(process.argv[3]).forEach(function (b, i) {
  const g = flow.parse(b);
  res.push("design" + i + " " + (g ? g.dir + " nodes=" + g.order.length + " edges=" + g.edges.length + " groups=" + g.groups.length + " thick=" + g.edges.filter(function (e) { return e.style === "thick"; }).length + " dotted=" + g.edges.filter(function (e) { return e.style === "dotted"; }).length : "null"));
});
const t = flow.parse("flowchart TD\n  A[\"title<br/>sub &amp; more\"] --> B\n  class A new");
res.push("label=" + JSON.stringify(t.nodes.A.label) + " new=" + t.nodes.A.isNew);
console.log(res.join("\n"));
' "$FLOW_JS" "$FIX/keyflow/proposal.md" "$FIX/flows/design.md")
expect "flow.js parses the authored key-flow, the band / LR charts, and rejects a sequence diagram" \
  "keyflow TD nodes=11 edges=13 groups=5 new=7 labelled=13${nl}design0 TD nodes=8 edges=8 groups=4 thick=1 dotted=0${nl}design1 LR nodes=16 edges=18 groups=0 thick=0 dotted=3${nl}design2 null${nl}label=\"title\\nsub & more\" new=true" \
  "$flowcheck"

# ---------- 1d. diagram geometry: request/response lanes, label collisions, band wrapping ----------
# flow.js layout with a deterministic text-width function (CJK 13px, other 7px): every
# request/response pair keeps two distinct paths, no edge label overlaps another label or
# a box, and a six-box band wraps into rows at card width.
NODE_GEO='
const fs = require("fs"), vm = require("vm");
const ctx = { window: { SDD: {} } };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const flow = ctx.window.SDD.flow;
const fit = Number(process.argv[2]);
function measure(text, kind) {
  let w = 0;
  for (const ch of text) w += /[⺀-鿿豈-﫿＀-￯]/.test(ch) ? 13 : (kind === "title" ? 7.5 : 7);
  return w;
}
function blocks(file) {
  const out = []; let cur = null;
  fs.readFileSync(file, "utf8").replace(/\r/g, "").split("\n").forEach(function (l) {
    if (cur === null && /^```mermaid\s*$/.test(l)) { cur = []; return; }
    if (cur !== null && /^```/.test(l)) { out.push(cur.join("\n")); cur = null; return; }
    if (cur !== null) cur.push(l);
  });
  return out;
}
function overlap(a, b) { return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1; }
function samples(pts) {
  const out = [];
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i], n = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / 4));
    for (let k = 0; k <= n; k++) out.push({ x: a.x + (b.x - a.x) * k / n, y: a.y + (b.y - a.y) * k / n });
  }
  return out;
}
function coincide(p, q) {
  const sp = samples(p), sq = samples(q);
  return sp.filter(function (s) { return sq.some(function (t) { return Math.hypot(s.x - t.x, s.y - t.y) < 2; }); }).length / sp.length;
}
const res = [];
process.argv.slice(3).forEach(function (file) {
  blocks(file).forEach(function (src, bi) {
    const g = flow.parse(src);
    if (!g) return;
    const L = flow.layout(g, { measure: measure, fitWidth: fit });
    const issues = [];
    const labels = L.edges.filter(function (e) { return e.label; });
    for (let i = 0; i < labels.length; i++) {
      for (let j = i + 1; j < labels.length; j++) if (overlap(labels[i].label, labels[j].label)) issues.push("labels " + labels[i].from + ">" + labels[i].to + " x " + labels[j].from + ">" + labels[j].to);
      L.nodes.forEach(function (n) { if (overlap(labels[i].label, n)) issues.push("label " + labels[i].from + ">" + labels[i].to + " on box " + n.id); });
    }
    function inside(p, r) { return p.x > r.x0 + 1 && p.x < r.x1 - 1 && p.y > r.y0 + 1 && p.y < r.y1 - 1; }
    L.edges.forEach(function (e) {
      L.nodes.forEach(function (n) {
        if (n.id === e.from || n.id === e.to) return;
        if (e.line.some(function (p) { return inside(p, n); })) issues.push("edge " + e.from + ">" + e.to + " crosses box " + n.id);
      });
    });
    /* V-37: no label on the line of another edge (a fan-out sibling sharing that label excepted) */
    labels.forEach(function (e) {
      L.edges.forEach(function (f) {
        if (f === e || (f.from === e.from && f.text === e.text)) return;
        if (f.line.some(function (p) { return inside(p, e.label); })) issues.push("label " + e.from + ">" + e.to + " on edge " + f.from + ">" + f.to);
      });
    });
    /* V-39: a label stays with its own edge: within 12px of it and nearer to it than to any other edge */
    function rectDist(r, p) {
      const dx = Math.max(r.x0 - p.x, 0, p.x - r.x1), dy = Math.max(r.y0 - p.y, 0, p.y - r.y1);
      return Math.hypot(dx, dy);
    }
    function lineDist(r, line) { return Math.min.apply(null, line.map(function (p) { return rectDist(r, p); }).concat([Infinity])); }
    labels.forEach(function (e) {
      const own = L.edges.filter(function (f) { return f === e || (f.from === e.from && f.text === e.text); });
      const mine = Math.min.apply(null, own.map(function (f) { return lineDist(e.label, f.line); }));
      if (mine > 12) issues.push("label " + e.from + ">" + e.to + " is " + Math.round(mine) + "px from its own edge");
      L.edges.forEach(function (f) {
        if (own.indexOf(f) >= 0) return;
        const d = lineDist(e.label, f.line);
        if (d <= mine) issues.push("label " + e.from + ">" + e.to + " nearer edge " + f.from + ">" + f.to + " (" + Math.round(d) + "px) than its own (" + Math.round(mine) + "px)");
      });
    });
    /* V-41: a label with no clear spot is a numbered badge on its own line: clear of every
       box, label, other badge and foreign line; numbered 1..n in reading order */
    const badged = L.edges.filter(function (e) { return e.badge; });
    badged.forEach(function (e) {
      const b = e.badge, tag = "badge " + b.n + " (" + e.from + ">" + e.to + ")";
      const r = { x0: b.x - b.r, y0: b.y - b.r, x1: b.x + b.r, y1: b.y + b.r };
      L.nodes.forEach(function (n) { if (overlap(r, n)) issues.push(tag + " on box " + n.id); });
      labels.forEach(function (f) { if (overlap(r, f.label)) issues.push(tag + " on label " + f.from + ">" + f.to); });
      badged.forEach(function (f) { if (f !== e && Math.hypot(f.badge.x - b.x, f.badge.y - b.y) < b.r + f.badge.r) issues.push(tag + " on badge " + f.badge.n); });
      L.edges.forEach(function (f) {
        if (f === e) return;
        if (f.line.some(function (p) { return Math.hypot(p.x - b.x, p.y - b.y) < b.r; })) issues.push(tag + " on edge " + f.from + ">" + f.to);
      });
      const onOwn = Math.min.apply(null, e.line.map(function (p) { return Math.hypot(p.x - b.x, p.y - b.y); }));
      if (onOwn > 2) issues.push(tag + " is " + Math.round(onOwn) + "px off its own edge");
      if (e.label) issues.push(tag + " also draws its label");
    });
    const order = badged.slice().sort(function (p, q) { return (p.badge.y - q.badge.y) || (p.badge.x - q.badge.x); });
    order.forEach(function (e, i) { if (e.badge.n !== i + 1) issues.push("badge " + e.badge.n + " out of reading order (expected " + (i + 1) + ")"); });
    const listed = L.badges.map(function (b) { return b.n + "=" + b.text; }).join(",");
    const drawnB = order.map(function (e) { return e.badge.n + "=" + e.text.replace(/\s*\n\s*/g, " "); }).join(",");
    if (listed !== drawnB) issues.push("badge list " + listed + " differs from the drawn badges " + drawnB);
    const badgeNote = badged.length ? " badges=" + badged.length : "";
    /* labels and badges keep off band titles and inside the bands */
    const marks = labels.map(function (e) { return { tag: "label " + e.from + ">" + e.to, r: e.label }; }).concat(badged.map(function (e) {
      const b = e.badge;
      return { tag: "badge " + b.n, r: { x0: b.x - b.r, y0: b.y - b.r, x1: b.x + b.r, y1: b.y + b.r } };
    }));
    marks.forEach(function (m) {
      (L.titles || []).forEach(function (t) { if (overlap(m.r, t)) issues.push(m.tag + " on a band title"); });
      if (L.bounds && (m.r.x0 < L.bounds.x0 || m.r.x1 > L.bounds.x1)) issues.push(m.tag + " outside the bands");
    });
    L.edges.forEach(function (e) {
      if (!e.text || e.label || e.badge) return;
      const twin = L.edges.some(function (f) { return f !== e && f.from === e.from && f.text === e.text && (f.label || f.badge); });
      if (!twin) issues.push("edge " + e.from + ">" + e.to + " lost its label " + e.text);
    });
    /* V-42: a lane shift never adds a crossing, and edges leaving one box never cross each other */
    const shiftNote = L.laneShifts.length ? " shifts=" + L.laneShifts.length : "";
    L.laneShifts.forEach(function (s) {
      if (s.after > s.before) issues.push("lane shift of " + s.from + ">" + s.to + " raised crossings " + s.before + " to " + s.after);
    });
    function cross(p, q) {
      let c = 0;
      const hit = function (a1, a2, b1, b2) {
        return Math.abs(a1.y - a2.y) < 0.5 && Math.abs(b1.x - b2.x) < 0.5 &&
          b1.x > Math.min(a1.x, a2.x) + 0.5 && b1.x < Math.max(a1.x, a2.x) - 0.5 && a1.y > Math.min(b1.y, b2.y) + 0.5 && a1.y < Math.max(b1.y, b2.y) - 0.5;
      };
      for (let k = 0; k + 1 < p.length; k++) for (let m = 0; m + 1 < q.length; m++) if (hit(p[k], p[k + 1], q[m], q[m + 1]) || hit(q[m], q[m + 1], p[k], p[k + 1])) c += 1;
      return c;
    }
    L.edges.forEach(function (e, i) {
      L.edges.forEach(function (f, j) {
        if (j <= i || !e.ortho || !f.ortho || e.from !== f.from) return;
        if (cross(e.pts, f.pts)) issues.push("edges " + e.from + ">" + e.to + " and " + f.from + ">" + f.to + " from one box cross each other");
      });
    });
    /* V-36: unrelated edges never run on one line (a fan-out trunk / fan-in merge is shared by design) */
    function run(p1, p2, q1, q2) {
      const ov = function (a1, a2, b1, b2) { return Math.min(Math.max(a1, a2), Math.max(b1, b2)) - Math.max(Math.min(a1, a2), Math.min(b1, b2)); };
      if (Math.abs(p1.y - p2.y) < 0.5 && Math.abs(q1.y - q2.y) < 0.5 && Math.abs(p1.y - q1.y) < 1) return ov(p1.x, p2.x, q1.x, q2.x);
      if (Math.abs(p1.x - p2.x) < 0.5 && Math.abs(q1.x - q2.x) < 0.5 && Math.abs(p1.x - q1.x) < 1) return ov(p1.y, p2.y, q1.y, q2.y);
      return 0;
    }
    L.edges.forEach(function (e, i) {
      L.edges.forEach(function (f, j) {
        if (j <= i || !e.ortho || !f.ortho || e.from === f.from || e.to === f.to) return;
        let worst = 0;
        for (let k = 0; k + 1 < e.pts.length; k++) for (let m = 0; m + 1 < f.pts.length; m++) worst = Math.max(worst, run(e.pts[k], e.pts[k + 1], f.pts[m], f.pts[m + 1]));
        if (worst > 4) issues.push("edges " + e.from + ">" + e.to + " and " + f.from + ">" + f.to + " share a " + Math.round(worst) + "px run");
      });
    });
    /* V-35: a fan-out with one identical label draws it once; distinct labels sit nearest their own branch */
    const fans = {};
    L.edges.forEach(function (e) {
      if (e.ortho && e.pts[1].y > e.pts[0].y && e.pts[e.pts.length - 1].y > e.pts[0].y) (fans[e.from] = fans[e.from] || []).push(e);
    });
    let fanNote = "";
    Object.keys(fans).forEach(function (src) {
      const grp = fans[src];
      if (grp.length < 2 || grp.some(function (e) { return !e.text; })) return;
      const same = grp.every(function (e) { return e.text === grp[0].text; });
      const drawn = grp.filter(function (e) { return e.label; });
      if (same) {
        fanNote += " fan " + src + "=once";
        const shown = grp.filter(function (e) { return e.label || e.badge; }).length;
        if (shown !== 1) issues.push("fan-out " + src + " draws its shared label " + shown + " times");
        return;
      }
      fanNote += " fan " + src + "=branches";
      const trunk = function (p) { return grp.every(function (f) { return f.line.some(function (q) { return Math.hypot(p.x - q.x, p.y - q.y) < 1; }); }); };
      drawn.forEach(function (e) {
        const c = { x: (e.label.x0 + e.label.x1) / 2, y: (e.label.y0 + e.label.y1) / 2 };
        const dist = function (f) { return Math.min.apply(null, f.line.filter(function (p) { return !trunk(p); }).map(function (p) { return Math.hypot(p.x - c.x, p.y - c.y); }).concat([Infinity])); };
        const mine = dist(e);
        if (grp.some(function (f) { return f !== e && dist(f) < mine; })) issues.push("fan-out label " + e.text + " sits nearer a sibling branch than its own");
      });
    });
    let pairs = 0;
    L.edges.forEach(function (e, i) {
      L.edges.forEach(function (f, j) {
        if (j <= i || e.from !== f.to || e.to !== f.from) return;
        pairs += 1;
        const c = coincide(e.pts, f.pts);
        if (c > 0.05) issues.push("pair " + e.from + "<>" + e.to + " shares " + Math.round(c * 100) + "% of its path");
      });
    });
    const rows = {};
    L.nodes.forEach(function (n) { if (/^C[1-6]$/.test(n.id)) rows[Math.round(n.y0)] = true; });
    const wrap = Object.keys(rows).length > 1 ? " six-box band rows=" + Object.keys(rows).length : "";
    res.push(file.split(/[\\/]/).slice(-2).join("/") + "#" + bi + " " + L.mode + " pairs=" + pairs + wrap + fanNote + badgeNote + shiftNote + (issues.length ? " ISSUES: " + issues.join("; ") : " ok"));
  });
});
console.log(res.join("\n"));
'
for w in 940 734 600; do
  geo=$(node -e "$NODE_GEO" "$FLOW_JS" "$w" "$FIX/reqresp/design.md" "$FIX/flows/design.md" "$FIX/keyflow/proposal.md" "$FIX/drill/proposal.md" \
    "$FIX/adv1/proposal.md" "$FIX/adv2/proposal.md" "$FIX/adv3/proposal.md" "$FIX/adv4/proposal.md" "$FIX/adv5/proposal.md" "$FIX/adv6/proposal.md" \
    "$FIX/adv7/proposal.md" "$FIX/adv8/proposal.md" "$FIX/checkout/proposal.md")
  case $geo in *ISSUES*) bad "diagram geometry at card width $w (labels, badges, boxes, foreign lines, shared runs, fan-outs, crossings): $(printf '%s\n' "$geo" | grep ISSUES)" ;; *) ok ;; esac
  # V-41: a chart whose labels all fit draws no badge; adv2 and checkout are the crowded
  # charts where a label may fall back to a numbered badge (checked like every other mark)
  expect "charts whose labels fit draw no numbered badge at width $w" "" "$(printf '%s\n' "$geo" | grep -v -E '^(adv2|checkout)/' | grep ' badges=')"
  case $(printf '%s\n' "$geo" | grep 'keyflow/proposal.md#0 ') in
    *" fan B=once"*" ok") ok ;;
    *) bad "key flow: the three identical fan-out labels drawn once on the trunk at width $w (got: $(printf '%s\n' "$geo" | grep 'keyflow/proposal.md#0 '))" ;;
  esac
  case $(printf '%s\n' "$geo" | grep 'reqresp/design.md#3 ') in
    *" fan Q=branches ok") ok ;;
    *) bad "distinct fan-out labels each on their own branch at width $w (got: $(printf '%s\n' "$geo" | grep 'reqresp/design.md#3 '))" ;;
  esac
  expect "request/response pairs drawn as separate lanes (TD bands: 3 pairs, LR: 2 pairs) at width $w" \
    "reqresp/design.md#0 bands pairs=3 ok|reqresp/design.md#1 layered pairs=2 ok" \
    "$(printf '%s\n' "$geo" | grep -E 'reqresp/design.md#[01] ' | tr '\n' '|' | sed 's/|$//')"
  case $(printf '%s\n' "$geo" | grep 'reqresp/design.md#2 ') in
    *"six-box band rows="[2-9]*" ok") ok ;;
    *) bad "six-box band wraps into rows at width $w (got: $(printf '%s\n' "$geo" | grep 'reqresp/design.md#2 '))" ;;
  esac
done
ADV_JS="$VIEWS/shared/advanced.js"; CHECKOUT_MD="$FIX/checkout/proposal.md"; ADV2_MD="$FIX/adv2/proposal.md"; KEYFLOW_MD="$FIX/keyflow/proposal.md"
command -v cygpath > /dev/null 2>&1 && { ADV_JS=$(cygpath -m "$ADV_JS"); CHECKOUT_MD=$(cygpath -m "$CHECKOUT_MD"); ADV2_MD=$(cygpath -m "$ADV2_MD"); KEYFLOW_MD=$(cygpath -m "$KEYFLOW_MD"); }
# V-42: the lane shift weighs every candidate (+-8 / +-16 / +-24) and never adds a crossing.
# Synthetic case = the routing adv7 produced before drop lanes nested: B>X runs on A>Y
# (two shared segments); shifting it +8 crosses B>R right under box B, -8 does not.
lane=$(node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { window: { SDD: {} } };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const flow = ctx.window.SDD.flow;
const V = {};
[["A", -80, 54], ["B", 80, 54], ["P", -160, 175], ["Q", 0, 175], ["R", 160, 175], ["S", -80, 267], ["T", 80, 267], ["X", -80, 359], ["Y", 80, 359]]
  .forEach(function (b) { V[b[0]] = { x: b[1], y: b[2], w: 120, h: 40 }; });
function P(a) { return a.map(function (p) { return { x: p[0], y: p[1] }; }); }
const edges = [
  { e: { from: "A", to: "Y" }, ortho: true, pts: P([[-80, 74], [-80, 121], [-236, 121], [-236, 305], [80, 305], [80, 339]]) },
  { e: { from: "B", to: "X" }, ortho: true, pts: P([[80, 74], [80, 121], [-236, 121], [-236, 305], [-80, 305], [-80, 339]]) },
  { e: { from: "A", to: "P" }, ortho: true, pts: P([[-80, 74], [-80, 121], [-160, 121], [-160, 155]]) },
  { e: { from: "B", to: "R" }, ortho: true, pts: P([[80, 74], [80, 121], [160, 121], [160, 155]]) }
];
const shifts = [];
flow.separateRuns(edges, V, shifts);
function cross(p, q) {
  let c = 0;
  const hit = function (a1, a2, b1, b2) {
    return Math.abs(a1.y - a2.y) < 0.5 && Math.abs(b1.x - b2.x) < 0.5 &&
      b1.x > Math.min(a1.x, a2.x) + 0.5 && b1.x < Math.max(a1.x, a2.x) - 0.5 && a1.y > Math.min(b1.y, b2.y) + 0.5 && a1.y < Math.max(b1.y, b2.y) - 0.5;
  };
  for (let k = 0; k + 1 < p.length; k++) for (let m = 0; m + 1 < q.length; m++) if (hit(p[k], p[k + 1], q[m], q[m + 1]) || hit(q[m], q[m + 1], p[k], p[k + 1])) c += 1;
  return c;
}
const out = [];
out.push("shifts=" + shifts.length + (shifts.every(function (s) { return s.after <= s.before; }) ? " none-raised" : " RAISED " + JSON.stringify(shifts)));
out.push("B>X x B>R=" + cross(edges[1].pts, edges[3].pts));
console.log(out.join(" "));
' "$FLOW_JS")
expect "lane shift picks the candidate adding no crossing (synthetic adv7 routing: B>X clears B>R)" "shifts=1 none-raised B>X x B>R=0" "$lane"

# V-41: badge legend in the page DOM (fake DOM): one row per badge, same number and
# exact label text as the badge (title + aria-label); none when every label fits
legend=$(node -e '
const fs = require("fs"), vm = require("vm");
function Node(tag) { this.tagName = tag; this.attrs = {}; this.children = []; this.text = ""; this.style = {}; this.className = ""; }
Node.prototype.setAttribute = function (k, v) { this.attrs[k] = String(v); if (k === "class") this.className = String(v); };
Node.prototype.getAttribute = function (k) { return k === "class" ? this.className : (k in this.attrs ? this.attrs[k] : null); };
Node.prototype.appendChild = function (c) { this.children.push(c); return c; };
Node.prototype.insertBefore = function (c) { this.children.push(c); return c; };
Node.prototype.addEventListener = function () {};
Node.prototype.remove = function () {};
Object.defineProperty(Node.prototype, "textContent", {
  get: function () { return this.text + this.children.map(function (c) { return c.textContent; }).join(""); },
  set: function (v) { this.text = String(v); this.children = []; }
});
Object.defineProperty(Node.prototype, "innerHTML", { set: function () {}, get: function () { return ""; } });
Node.prototype.classList = null;
Node.prototype.all = function () { let r = [this]; this.children.forEach(function (c) { r = r.concat(c.all()); }); return r; };
Node.prototype.querySelectorAll = function (sel) {
  const cls = sel.replace(/^\./, "");
  return this.all().filter(function (n) { return n !== this && (" " + n.className + " ").indexOf(" " + cls + " ") >= 0; }, this);
};
const doc = {
  createElement: function (t) {
    const n = new Node(t);
    if (t === "canvas") n.getContext = function () {
      return { font: "", measureText: function (s) {
        let w = 0;
        for (const ch of s) w += /[⺀-鿿豈-﫿＀-￯]/.test(ch) ? 13 : (this.font.indexOf("500") === 0 ? 7.5 : 7);
        return { width: w };
      } };
    };
    return n;
  },
  createElementNS: function (ns, t) { const n = new Node(t); n.setAttribute = function (k, v) { Node.prototype.setAttribute.call(this, k, v); }; return n; },
  createTextNode: function (t) { const n = new Node("#text"); n.text = String(t); return n; },
  documentElement: new Node("html"),
  body: new Node("body")
};
const ctx = { navigator: { languages: ["en"] }, document: doc, getComputedStyle: function () { return { fontFamily: "sans-serif" }; }, localStorage: { getItem: function () { return null; }, setItem: function () {} } };
ctx.window = ctx;
vm.createContext(ctx);
for (let i = 1; i <= 4; i++) vm.runInContext(fs.readFileSync(process.argv[i], "utf8"), ctx);
const SDD = ctx.SDD;
SDD.lang = "en";
SDD.main = { clientWidth: Number(process.argv[5]) + 34 };
function mermaid(file) { return /```mermaid\n([\s\S]*?)\n```/.exec(fs.readFileSync(file, "utf8").replace(/\r/g, ""))[1]; }
const out = [];
process.argv.slice(6).forEach(function (file) {
  const fig = SDD.diagramFigure(mermaid(file), { title: "t" });
  const nodes = fig.all();
  const badges = nodes.filter(function (n) { return /(^| )flow-badge( |$)/.test(n.className || n.getAttribute("class") || ""); });
  const kids = fig.children.map(function (c) { return c.className || c.getAttribute("class") || c.tagName; });
  const lists = nodes.filter(function (n) { return n.className === "badge-legend"; });
  const rows = lists.length ? lists[0].children : [];
  const bs = badges.map(function (b) {
    const title = b.children.filter(function (c) { return c.tagName === "title"; })[0];
    return b.getAttribute("data-badge") + "=" + b.getAttribute("aria-label") + (title && title.textContent === b.getAttribute("aria-label") ? "" : " (title differs)");
  }).sort().join(",");
  const ls = rows.map(function (r) { return r.getAttribute("data-badge") + "=" + r.children[1].textContent; }).sort().join(",");
  const where = lists.length ? (kids.indexOf("badge-legend") === kids.indexOf("svg-wrap") + 1 && (kids.indexOf("diagram-foot") < 0 || kids.indexOf("diagram-foot") > kids.indexOf("badge-legend")) ? "below-chart" : "MISPLACED " + kids.join("|")) : "none";
  out.push(file.split(/[\\/]/).slice(-2).join("/") + " badges[" + bs + "] legend[" + ls + "] " + where + (bs === ls ? "" : " MISMATCH"));
});
console.log(out.join("\n"));
' "$STRINGS_JS" "$APP_JS" "$FLOW_JS" "$ADV_JS" 940 "$CHECKOUT_MD" "$ADV2_MD" "$KEYFLOW_MD")
expect "badge legend rows match the badges one-to-one (number + exact label text), sit below the chart above the new/existing legend; none when labels fit" \
  "checkout/proposal.md badges[] legend[] none${nl}adv2/proposal.md badges[1=parallel a] legend[1=parallel a] below-chart${nl}keyflow/proposal.md badges[] legend[] none" \
  "$legend"
out=$(sh "$R" reqresp all)
expect "request/response fixture renders without fallback" "view: reqresp/view/design.html${nl}fallback: none" "$out"

# ---------- 1e. What items: bullets (proposal-spec form) or numbered ----------
mkdir -p bullets && cp good/*.md bullets/
sed 's/^\([0-9]\)\. \*\*/- **/' good/proposal.md > bullets/proposal.md
grep -q '^- \*\*Order read cache\*\*' bullets/proposal.md && ok || bad "bullet What fixture prepared"
expect "bullet What items: no fallback" "view: bullets/view/proposal.html${nl}fallback: none" "$(sh "$R" bullets proposal)"
expect "precheck.js agrees on bullet What items" "fallback: none" "$(node -e "$NODE_PRECHECK" "$PRECHECK_JS" proposal bullets)"
expect "numbered What items: no fallback" "view: good/view/proposal.html${nl}fallback: none" "$(sh "$R" good proposal)"

# ---------- 1f. placeholders survive markdown, real inline HTML still renders ----------
MARKED_JS="$VIEWS/vendor/marked.umd.js"
command -v cygpath > /dev/null 2>&1 && MARKED_JS=$(cygpath -m "$MARKED_JS")
ph=$(node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { window: {}, navigator: {} };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
const esc = ctx.SDD.escapePlaceholders;
const cases = [
  "record at spec/archive/<date>-verify-<slug>/",
  "line one<br/>line two",
  "a <b>bold</b> word, <word_word> and </closing-tag>",
  "inline `<code>` and `x <y>` stay",
  "```\n<pre-block>\n```"
];
console.log(cases.map(function (c) { return JSON.stringify(esc(c)); }).join("\n"));
' "$STRINGS_JS" "$APP_JS"; node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { window: {}, navigator: {}, module: { exports: {} } };
ctx.window = ctx; ctx.exports = ctx.module.exports;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
const marked = ctx.module.exports.marked || ctx.module.exports;
console.log("marked:" + marked.parse("spec/archive/&lt;date&gt;-verify-&lt;slug&gt;/").trim());
' "$MARKED_JS")
expect "placeholder escaping keeps <date>/<slug>, real tags and code untouched; marked shows them as text" \
  "\"record at spec/archive/&lt;date&gt;-verify-&lt;slug&gt;/\"${nl}\"line one<br/>line two\"${nl}\"a <b>bold</b> word, &lt;word_word&gt; and &lt;/closing-tag&gt;\"${nl}\"inline \`<code>\` and \`x <y>\` stay\"${nl}\"\`\`\`\\n<pre-block>\\n\`\`\`\"${nl}marked:<p>spec/archive/&lt;date&gt;-verify-&lt;slug&gt;/</p>" \
  "$ph"
INDENT_MD="$FIX/indented/design.md"
command -v cygpath > /dev/null 2>&1 && INDENT_MD=$(cygpath -m "$INDENT_MD")
ind=$(node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { navigator: {} };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
const out = ctx.SDD.escapePlaceholders(fs.readFileSync(process.argv[3], "utf8").replace(/\r/g, "")).split("\n");
console.log(out.filter(function (l) { return /slug|name/.test(l); }).join("\n"));
' "$STRINGS_JS" "$APP_JS" "$INDENT_MD")
expect "indented code block keeps <slug> raw (marked escapes it once); prose and list continuation are escaped" \
  "Records land in spec/archive/&lt;date&gt;-verify-&lt;slug&gt;/ (prose placeholder).${nl}    spec/archive/<date>-verify-<slug>/   (indented code block)${nl}    second line <name>${nl}After the block: &lt;slug&gt; again.${nl}    list continuation with &lt;slug&gt;" \
  "$ind"
expect "indented-code fixture renders without fallback" "view: indented/view/design.html${nl}fallback: none" "$(sh "$R" indented design)"
# V-40: a code block indented inside a list item, and a ``` fence holding a ~~~ line
esc_file() {
  node -e '
const fs = require("fs"), vm = require("vm");
const ctx = { navigator: {} };
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8"), ctx);
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
const out = ctx.SDD.escapePlaceholders(fs.readFileSync(process.argv[3], "utf8").replace(/\r/g, "")).split("\n");
console.log(out.filter(function (l) { return /slug|~~~/.test(l); }).join("\n"));
' "$STRINGS_JS" "$APP_JS" "$1"
}
LISTCODE_MD="$FIX/listcode/design.md"; FENCE2_MD="$FIX/fence2/design.md"
command -v cygpath > /dev/null 2>&1 && { LISTCODE_MD=$(cygpath -m "$LISTCODE_MD"); FENCE2_MD=$(cygpath -m "$FENCE2_MD"); }
expect "code block indented inside a list item stays raw; a ~~~ line does not close a \`\`\` fence; prose after it escaped" \
  "       sh render.sh spec/archive/<date>-verify-<slug> all${nl}~~~${nl}Records live at spec/archive/&lt;date&gt;-verify-&lt;slug&gt;/." \
  "$(esc_file "$LISTCODE_MD")"
expect "fence2: ~~~ inside a \`\`\` fence keeps the fence open; prose after the close escaped" \
  "~~~${nl}Records at &lt;slug&gt;." \
  "$(esc_file "$FENCE2_MD")"
# V-43: a line opening with an inline ```js``` code span is no fence; a fence inside a
# blockquote is tracked (and ends with its quote)
FENCE3_MD="$FIX/fence3/design.md"; FENCE4_MD="$FIX/fence4/design.md"
command -v cygpath > /dev/null 2>&1 && { FENCE3_MD=$(cygpath -m "$FENCE3_MD"); FENCE4_MD=$(cygpath -m "$FENCE4_MD"); }
expect "fence3: a line opening with an inline \`\`\`js\`\`\` span is prose (placeholders escaped, no fence swallowing the file)" \
  "\`\`\`js\`\`\` blocks hold the sample for &lt;slug&gt;.${nl}Records at &lt;slug&gt;." \
  "$(esc_file "$FENCE3_MD")"
expect "fence4: a fence inside a blockquote keeps its placeholders raw; prose after it escaped; a quote left open ends its fence" \
  "> sh render.sh spec/archive/<date>-verify-<slug> all${nl}Records at &lt;slug&gt;." \
  "$(esc_file "$FENCE4_MD")"
for f in listcode listcode2 fence2 fence3 fence4; do
  expect "$f: ## Interfaces found after the fence (no fallback)" "view: $f/view/design.html${nl}fallback: none" "$(sh "$R" "$f" design)"
  expect "$f: precheck.js agrees" "fallback: none" "$(node -e "$NODE_PRECHECK" "$PRECHECK_JS" design "$f")"
done

# ---------- 1g. band title contrast (WCAG ratio >= 4.5 on both band tints, both themes) ----------
CSS_FILE="$VIEWS/shared/app.css"
command -v cygpath > /dev/null 2>&1 && CSS_FILE=$(cygpath -m "$CSS_FILE")
contrast=$(node -e '
const css = require("fs").readFileSync(process.argv[1], "utf8");
function block(start) { const i = css.indexOf(start); return css.slice(i, css.indexOf("}", i)); }
function v(b, name) { const m = new RegExp("--" + name + ":\\s*(#[0-9A-Fa-f]{6})").exec(b); return m[1]; }
function lum(hex) {
  const c = [1, 3, 5].map(function (i) { const x = parseInt(hex.substr(i, 2), 16) / 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function ratio(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
const rule = /\.flow-band-title \{([^}]*)\}/.exec(css)[1];
const out = [];
[["light", block(":root {")], ["dark", block(":root[data-theme=\"dark\"] {")]].forEach(function (t) {
  const fg = v(t[1], "text-secondary");
  ["surface-0", "surface-1"].forEach(function (s) { out.push(t[0] + " " + s + " " + ratio(fg, v(t[1], s)).toFixed(2)); });
});
console.log(out.join(" | ") + " || " + rule.trim());
' "$CSS_FILE")
printf '  band title contrast: %s\n' "$contrast"
case $contrast in *"font-size: 13px; font-weight: 500; fill: var(--text-secondary);"*) ok ;; *) bad "band title rule is 13px / 500 / text-secondary (got: $contrast)" ;; esac
low=$(printf '%s\n' "$contrast" | sed 's/ || .*//' | tr '|' '\n' | awk '{ if ($3 + 0 < 4.5) print }')
expect "band title contrast >= 4.5 on both band tints in light and dark" "" "$low"

# ---------- 2+3. data blocks: no raw `<`, closing-tag count, byte round-trip, stamps ----------

for f in $FIXTURES; do
  for vd in view view-standard; do
    for page in "$f/$vd"/*.html; do
      [ -f "$page" ] || continue
      blocks=$(node -e "$NODE_BLOCKS" "$page" "$f" 2> "$T/err"); rc=$?
      if [ "$rc" = 0 ]; then ok; else bad "$page data blocks: $(cat "$T/err")"; fi
      while IFS="|" read -r bsrc bsum battrs; do
        [ -n "$bsrc" ] || continue
        expect "$page stamp of $bsrc equals cksum" "$(cksum < "$f/$bsrc")" "$bsum"
      done <<EOF
$blocks
EOF
    done
  done
done
grep -q 'data-src="index.md" data-cksum="4294967295 0"></script>' edge/view/research.html && ok || bad "empty index.md embedded with the empty-file stamp"

# ---------- 2b. page precheck (precheck.js) agrees with render.sh ----------

for f in $FIXTURES; do
  out=$(sh "$R" "$f" all)
  for s in $STAGES; do
    [ -f "$f/view/$s.html" ] || continue
    want=$(printf '%s\n' "$out" | awk -v v="view: $f/view/$s.html" '$0 == v { on = 1; next } /^view: / { on = 0 } on')
    got=$(node -e "$NODE_PRECHECK" "$PRECHECK_JS" "$s" "$f")
    expect "precheck.js agrees with render.sh: $f $s" "$want" "$got"
  done
done

# ---------- 4. --check ----------

out=$(sh "$R" --check good); rc=$?
expect "--check right after render: silent" "" "$out"
expect "--check exit 0" 0 "$rc"

mkdir -p one && cp good/research.md good/index.md one/
sh "$R" one research > /dev/null
echo "- appended line" >> one/research.md
expect "--check after editing a source: exactly the stale line" "one/view/research.html stale — $VIEW_CMD research" "$(sh "$R" --check one)"

mkdir -p two && cp good/*.md two/
sh "$R" two all > /dev/null
echo "x" >> two/design.md
expect "--check names only the view embedding the edited source" "two/view/design.html stale — $VIEW_CMD design" "$(sh "$R" --check two)"
rm two/gate.md
expect "--check: deleted optional source makes its view stale" \
  "two/view/design.html stale — $VIEW_CMD design${nl}two/view/proposal.html stale — $VIEW_CMD proposal" "$(sh "$R" --check two)"

mkdir -p noview && cp good/research.md noview/
expect "--check on a dir without view/: silent" "" "$(sh "$R" --check noview 2>&1)"

# ---------- 5. errors ----------

mkdir -p nodesign && cp good/research.md nodesign/
err=$(sh "$R" nodesign design 2>&1 > /dev/null); rc=$?
expect "missing required source: exit 1" 1 "$rc"
case $err in *design.md*) ok ;; *) bad "missing required source: message names design.md (got: $err)" ;; esac
err=$(sh "$R" good bogus 2>&1 > /dev/null); rc=$?
expect "unknown stage: exit 1" 1 "$rc"
case $err in *"unknown stage 'bogus'"*) ok ;; *) bad "unknown stage: message names it (got: $err)" ;; esac
err=$(sh "$R" good research fancy 2>&1 > /dev/null); rc=$?
expect "unknown tier: exit 1" 1 "$rc"
mkdir -p empty
err=$(sh "$R" empty all 2>&1 > /dev/null); rc=$?
expect "all with no sources: exit 1" 1 "$rc"

# ---------- 5b. translations (lang=<code>) and --stamp ----------
# i18n: English sources plus a Chinese gate.md; view/zh/ holds research.md (fresh
# header), design.md (stale header), proposal.md (malformed header), gate.md (`· same`
# header, current stamp), index.md (`· same` header, old stamp); verify.md has none.

expected_i18n="view: i18n/view/research.html
translation: index.md — stale
fallback: none
view: i18n/view/ask.html
translation: index.md — stale
fallback: none
view: i18n/view/design.html
translation: design.md — stale
translation: index.md — stale
fallback: none
view: i18n/view/proposal.html
translation: proposal.md — missing
translation: index.md — stale
translation: verify.md — missing
fallback: none
view: i18n/view/verify.html
translation: verify.md — missing
fallback: none"
out=$(sh "$R" i18n lang=zh all); rc=$?
expect "lang=zh before the stage: exit 0" 0 "$rc"
expect "lang=zh stdout names stale and missing translations (same-language gate.md: no line)" "$expected_i18n" "$out"
out_i18n_tier=$(sh "$R" i18n all standard lang=zh | grep -c '^translation: ')
expect "lang token after the tier: same translation lines" 8 "$out_i18n_tier"
sh "$R" i18n all lang=zh > /dev/null

block() { grep -o "<script type=\"text/markdown\" data-src=\"$2\"[^>]*>" "$1"; }
expect "fresh translation: data-lang + data-translated + SOURCE stamp" \
  "<script type=\"text/markdown\" data-src=\"research.md\" data-cksum=\"$(cksum < i18n/research.md)\" data-lang=\"zh\" data-translated=\"1\">" \
  "$(block i18n/view/research.html research.md)"
expect "stale translation: source embedded, data-translation=stale" \
  "<script type=\"text/markdown\" data-src=\"design.md\" data-cksum=\"$(cksum < i18n/design.md)\" data-translation=\"stale\">" \
  "$(block i18n/view/design.html design.md)"
expect "malformed header counts as missing" \
  "<script type=\"text/markdown\" data-src=\"proposal.md\" data-cksum=\"$(cksum < i18n/proposal.md)\" data-translation=\"missing\">" \
  "$(block i18n/view/proposal.html proposal.md)"
expect "absent translation: data-translation=missing" \
  "<script type=\"text/markdown\" data-src=\"verify.md\" data-cksum=\"$(cksum < i18n/verify.md)\" data-translation=\"missing\">" \
  "$(block i18n/view/verify.html verify.md)"
expect "same-language source, current stamp: source embedded, data-translated=same" \
  "<script type=\"text/markdown\" data-src=\"gate.md\" data-cksum=\"$(cksum < i18n/gate.md)\" data-lang=\"zh\" data-translated=\"same\">" \
  "$(block i18n/view/proposal.html gate.md)"
expect "same-language marker with an old stamp: stale" \
  "<script type=\"text/markdown\" data-src=\"index.md\" data-cksum=\"$(cksum < i18n/index.md)\" data-translation=\"stale\">" \
  "$(block i18n/view/proposal.html index.md)"
grep -q '导出改为流式' i18n/view/proposal.html && ok || bad "same-language gate.md: source text embedded"
# a `· same` header followed by body text is malformed
mkdir -p i18nd && cp -r i18n/*.md i18n/view i18nd/
{ sed -n 1p i18n/view/zh/gate.md; echo "  1. 多写的正文"; } > i18nd/view/zh/gate.md
expect "same-language marker with body lines: missing" \
  "view: i18nd/view/proposal.html${nl}translation: proposal.md — missing${nl}translation: gate.md — missing${nl}translation: index.md — stale${nl}translation: verify.md — missing${nl}fallback: none" \
  "$(sh "$R" i18nd proposal lang=zh)"
expect "same-language marker with body lines: data-translation=missing" \
  "<script type=\"text/markdown\" data-src=\"gate.md\" data-cksum=\"$(cksum < i18nd/gate.md)\" data-translation=\"missing\">" \
  "$(block i18nd/view/proposal.html gate.md)"
{ sed -n 1p i18n/view/zh/gate.md; printf '\r\n\n'; } > i18nd/view/zh/gate.md
expect "same-language marker followed only by blank lines: still same" \
  "view: i18nd/view/proposal.html${nl}translation: proposal.md — missing${nl}translation: index.md — stale${nl}translation: verify.md — missing${nl}fallback: none" \
  "$(sh "$R" i18nd proposal lang=zh)"
grep -q '流式 A — 边读边写行' i18n/view/research.html && ok || bad "fresh translation body embedded in research.html"
grep -q 'Stream A — write rows' i18n/view/research.html && bad "research.html still embeds the English source" || ok
grep -q 'exportCsv(query)` streams rows' i18n/view/design.html && ok || bad "stale translation: English source embedded in design.html"
for page in i18n/view/*.html; do
  node -e "$NODE_BLOCKS" "$page" i18n > /dev/null 2> "$T/err" && ok || bad "$page data blocks: $(cat "$T/err")"
done
for k in "'stamp.translated': '译文 · {0}'" "'stamp.translated': 'translation · {0}'" \
  "'translation.missing': '{0} 的译文缺失（显示原文）'" "'translation.stale': '{0} 的译文已过期（显示原文）'"; do
  grep -qF "$k" i18n/view/research.html && ok || bad "page carries the badge / notice string $k"
done

# the pre-check reads the embedded (translated) text
mkdir -p i18nb && cp -r i18n/*.md i18n/view i18nb/ 2> /dev/null
{ sed -n 1p i18n/view/zh/research.md; printf '# Research: export-csv\n\n## Practices\n只有一段说明，没有方案列表。\n\n## Open [TBD]\n\n## Decided\n'; } > i18nb/view/zh/research.md
expect "pre-check on a translation that lost the Practices options" \
  "view: i18nb/view/research.html${nl}translation: index.md — stale${nl}fallback: Practices — no \`- <name> — <body>\` option lines" "$(sh "$R" i18nb research lang=zh)"
expect "same source without lang: no fallback" "view: i18nb/view/research.html${nl}fallback: none" "$(sh "$R" i18nb research)"

# no lang token: no translation attributes, sources embedded as they are
mkdir -p i18n0 && cp -r i18n/*.md i18n/view i18n0/
sh "$R" i18n0 all > /dev/null
n=$(cat i18n0/view/*.html | grep "^<script type=\"text/markdown\"" | grep -cE 'data-lang="|data-translat')
expect "no lang token: no translation attributes on any data block" 0 "$n"
n=$(cat i18n/view/*.html | grep "^<script type=\"text/markdown\"" | grep -cE 'data-lang="|data-translat')
expect "lang=zh: every data block carries a translation attribute (control: 12 blocks over 5 pages)" 12 "$n"
# requested-language hint: present only with lang=
for page in i18n/view/*.html; do
  expect "$page: one <meta name=\"sdd-lang\" content=\"zh\">" 1 "$(grep -c '^<meta name="sdd-lang" content="zh">$' "$page")"
done
expect "no lang token: no sdd-lang meta in any page" 0 "$(cat i18n0/view/*.html good/view/*.html | grep -c '^<meta name="sdd-lang"')"

# --check stays source-stamp based
expect "--check after a lang render: silent" "" "$(sh "$R" --check i18n)"
mkdir -p i18nc && cp -r i18n/*.md i18n/view i18nc/
sh "$R" i18nc all lang=zh > /dev/null
echo "- one more constraint" >> i18nc/research.md
expect "--check after editing a translated source: its views are stale" \
  "i18nc/view/ask.html stale — $VIEW_CMD ask${nl}i18nc/view/proposal.html stale — $VIEW_CMD proposal${nl}i18nc/view/research.html stale — $VIEW_CMD research" \
  "$(sh "$R" --check i18nc)"
expect "edited source makes the fresh translation stale on re-render" \
  "view: i18nc/view/research.html${nl}translation: research.md — stale${nl}translation: index.md — stale${nl}fallback: none" "$(sh "$R" i18nc research lang=zh)"

# --stamp and token errors
expect "--stamp equals cksum <" "$(cksum < i18n/research.md)" "$(sh "$R" --stamp i18n/research.md)"
expect "--stamp on an empty file" "$(cksum < edge/index.md)" "$(sh "$R" --stamp edge/index.md)"
err=$(sh "$R" --stamp i18n/nope.md 2>&1 > /dev/null); rc=$?
expect "--stamp on a missing file: exit 1" 1 "$rc"
for tok in lang=ZH lang=zh- lang=z lang=zhzh lang=zh_CN lang=; do
  err=$(sh "$R" i18n research "$tok" 2>&1 > /dev/null); rc=$?
  expect "$tok: exit 1" 1 "$rc"
  case $err in *"unknown token '$tok'"*) ok ;; *) bad "$tok: message names the token (got: $err)" ;; esac
done
out=$(sh "$R" i18n research lang=zh-Hans); rc=$?
expect "lang=zh-Hans accepted (no view/zh-Hans/: all missing)" "0|view: i18n/view/research.html${nl}translation: research.md — missing${nl}translation: index.md — missing${nl}fallback: none" "$rc|$out"
sh "$R" i18n all lang=zh > /dev/null

# ---------- 6. pwsh twin parity ----------

PW=
for c in pwsh pwsh.exe "${LOCALAPPDATA:-/nonexistent}/Microsoft/WindowsApps/pwsh.exe" "/c/Program Files/PowerShell/7/pwsh.exe"; do
  if command -v "$c" > /dev/null 2>&1 || [ -x "$c" ]; then PW=$c; break; fi
done

if [ -z "$PW" ]; then
  echo "WARN: pwsh not found — ps1 parity not run"
else
  PS1="$VIEWS/render.ps1"
  command -v cygpath > /dev/null 2>&1 && PS1=$(cygpath -w "$PS1")
  ps() { "$PW" -NoProfile -NonInteractive -File "$PS1" "$@"; }
  fresh ps
  cd "$T/ps" || exit 1
  for f in $FIXTURES; do
    for tier in advanced standard; do
      (cd "$T/sh" && sh "$R" "$f" all "$tier") > "$T/sh.out"
      ps "$f" all "$tier" > "$T/ps.out"; rc=$?
      expect "ps1 $f all $tier exit 0" 0 "$rc"
      if cmp -s "$T/sh.out" "$T/ps.out"; then ok; else bad "ps1 $f all $tier stdout differs from render.sh"; diff "$T/sh.out" "$T/ps.out" | head -5; fi
      for page in "$f"/view/*.html; do
        if cmp -s "$page" "$T/sh/$page"; then ok; else bad "ps1 page $page ($tier) differs from render.sh"; cmp "$page" "$T/sh/$page" | head -2; fi
      done
    done
  done
  # stamps: CRLF, Chinese, empty file
  for src in edge/design.md edge/research.md edge/index.md good/research.md; do
    d=${src%/*}
    stamp=$(sed -n 's/.*data-src="'"${src##*/}"'" data-cksum="\([^"]*\)".*/\1/p' "$d/view/research.html" "$d/view/design.html" 2> /dev/null | head -1)
    expect "ps1 stamp of $src equals cksum" "$(cksum < "$src")" "$stamp"
  done
  # --check parity and cross-host freshness
  expect "ps1 --check right after render: silent" "" "$(ps --check good)"
  expect "sh --check accepts pages stamped by ps1" "" "$(sh "$R" --check good)"
  mkdir -p two && cp good/*.md two/
  ps two all > /dev/null
  echo "x" >> two/design.md
  rm two/gate.md
  expect "ps1 --check matches sh --check after edit + delete" "$(sh "$R" --check two)" "$(ps --check two)"
  err=$(ps "$T/sh/nodesign" design 2>&1 > /dev/null); rc=$?
  expect "ps1 missing required source: exit 1" 1 "$rc"
  err=$(ps good bogus 2>&1 > /dev/null); rc=$?
  expect "ps1 unknown stage: exit 1" 1 "$rc"
  # translations: same stdout and pages for fresh / stale / missing / malformed headers
  for spec in "lang=zh all" "all standard lang=zh" "research lang=zh-Hans"; do
    # shellcheck disable=SC2086
    (cd "$T/sh" && sh "$R" i18n $spec) > "$T/sh.out"
    # shellcheck disable=SC2086
    ps i18n $spec > "$T/ps.out"; rc=$?
    expect "ps1 i18n $spec exit 0" 0 "$rc"
    if cmp -s "$T/sh.out" "$T/ps.out"; then ok; else bad "ps1 i18n $spec stdout differs"; diff "$T/sh.out" "$T/ps.out" | head -5; fi
    for page in i18n/view/*.html; do
      if cmp -s "$page" "$T/sh/$page"; then ok; else bad "ps1 page $page ($spec) differs from render.sh"; fi
    done
  done
  mkdir -p i18nb/view && cp i18n/*.md i18nb/ && cp -r "$T/sh/i18nb/view/zh" i18nb/view/
  expect "ps1 pre-check reads the translated text" "$(cd "$T/sh" && sh "$R" i18nb research lang=zh)" "$(ps i18nb research lang=zh)"
  # `· same` marker followed by body text (missing) and by blank lines only (same)
  for variant in body blank; do
    for side in "$T/sh" "$T/ps"; do
      mkdir -p "$side/i18n-$variant/view/zh" && cp "$side"/i18n/*.md "$side/i18n-$variant/" && cp "$side"/i18n/view/zh/*.md "$side/i18n-$variant/view/zh/"
      if [ "$variant" = body ]; then
        { sed -n 1p "$side/i18n/view/zh/gate.md"; echo "  1. 多写的正文"; } > "$side/i18n-$variant/view/zh/gate.md"
      else
        { sed -n 1p "$side/i18n/view/zh/gate.md"; printf '\r\n\n'; } > "$side/i18n-$variant/view/zh/gate.md"
      fi
    done
    (cd "$T/sh" && sh "$R" "i18n-$variant" proposal lang=zh) > "$T/sh.out"
    ps "i18n-$variant" proposal lang=zh > "$T/ps.out"
    if cmp -s "$T/sh.out" "$T/ps.out"; then ok; else bad "ps1 same-marker ($variant) stdout differs"; diff "$T/sh.out" "$T/ps.out" | head -5; fi
    if cmp -s "i18n-$variant/view/proposal.html" "$T/sh/i18n-$variant/view/proposal.html"; then ok; else bad "ps1 same-marker ($variant) page differs"; fi
  done
  expect "ps1 --stamp equals cksum <" "$(cksum < i18n/research.md)" "$(ps --stamp i18n/research.md)"
  expect "ps1 --stamp on an empty file" "$(cksum < edge/index.md)" "$(ps --stamp edge/index.md)"
  err=$(ps --stamp i18n/nope.md 2>&1 > /dev/null); rc=$?
  expect "ps1 --stamp on a missing file: exit 1" 1 "$rc"
  for tok in lang=ZH lang=zh- lang=zh_CN; do
    err=$(ps i18n research "$tok" 2>&1 > /dev/null); rc=$?
    expect "ps1 $tok: exit 1" 1 "$rc"
  done
  expect "ps1 --check after a lang render: silent" "" "$(ps --check i18n)"
fi

# ---------- 7. dash ----------

if command -v dash > /dev/null 2>&1; then
  fresh dash
  cd "$T/dash" || exit 1
  for f in good malformed edge; do
    (cd "$T/sh" && sh "$R" "$f" all) > "$T/sh.out"
    dash "$R" "$f" all > "$T/dash.out"
    if cmp -s "$T/sh.out" "$T/dash.out"; then ok; else bad "dash $f stdout differs"; fi
    for page in "$f"/view/*.html; do
      if cmp -s "$page" "$T/sh/$page"; then ok; else bad "dash page $page differs"; fi
    done
  done
  expect "dash --check silent" "" "$(dash "$R" --check good)"
else
  echo "WARN: dash not found — dash run skipped"
fi

cd "$ROOT" || exit 1
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
