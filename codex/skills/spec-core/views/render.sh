#!/bin/sh
# GENERATED from core/views/render.sh — edit the core file and run node tools/generate.mjs; hand edits will be overwritten
# render.sh — builds self-contained HTML views of sdd stage artifacts.
#
#   sh render.sh <dir> <stage> [standard|advanced] [lang=<code>]
#       stage: research | ask | design | proposal | verify | all   (tier default: advanced)
#       writes <dir>/view/<stage>.html, prints `view: <path>`, then `translation:` lines
#       (lang only), then `fallback:` lines; tokens after <dir> may come in any order
#   sh render.sh --check <dir>
#       prints `<path> stale — $spec-view <stage>` per view whose embedded stamps no
#       longer match the sources; prints nothing when every view is fresh
#   sh render.sh --stamp <file>
#       prints the stamp of <file> (`<crc> <bytes>`, POSIX cksum) — what data-cksum and
#       translation headers carry
#
# lang=<code> (code: 2-3 lowercase letters, optionally -<alnum>): for each embedded source
# <file>, <dir>/view/<code>/<file> is embedded instead when its first line is
#   <!-- sdd-translation: <file> · <code> · cksum <crc> <bytes> -->
# (one trailing CR tolerated) and that stamp equals the source's current stamp; the body
# after line 1 is embedded with data-lang="<code>" data-translated="1" and the source's
# own data-cksum, and the pre-check reads the translated text. Otherwise the source is
# embedded with data-translation="missing" (no file / no valid header) or "stale" (header
# stamp differs) and stdout gets `translation: <file> — missing|stale`.
# A source already written in <code> is marked by a translation file holding ONLY
#   <!-- sdd-translation: <file> · <code> · cksum <crc> <bytes> · same -->
# (blank lines after it tolerated): matching stamp -> the source is embedded with
# data-lang="<code>" data-translated="same" and no stdout line; differing stamp -> stale
# (the source changed, its language must be re-judged); body text after it -> missing.
#
# The script embeds and stamps; parsing and layout live in the page JS. render.ps1 is
# the PowerShell 7 twin and must produce byte-identical pages and identical stdout.
#
# Process budget (process start-up dominates on Git Bash): one `cksum` over every *.md
# of <dir> for the stamps, then ONE awk run that validates, assembles, escapes and
# pre-checks every requested page; `--check` is the same cksum plus one awk pass.
#
# Template placeholders (whole lines):
#   <!--SDD:TIER-->            tier meta tag (+ <meta name="sdd-lang"> when lang= is given)
#   <!--SDD:SRC:<file>-->      required source, embedded as a markdown data block
#   <!--SDD:OPT:<file>-->      optional source, dropped when the file is absent
#   <!--SDD:VENDOR:<file>-->   vendor/<file> inlined
#   <!--SDD:SHARED:<file>-->   shared/<file> inlined
#   <!--SDD:ADVANCED--> … <!--/SDD:ADVANCED-->  kept for advanced, removed for standard
# Lines containing "GENERATED from core/" are dropped from every inlined file; every
# inlined line is LF-terminated.
#
# Data block: <script type="text/markdown" data-src="<file>" data-cksum="<cksum output>">
# holding the source bytes with `&` -> `&amp;` then `<` -> `&lt;`; the page reverses
# both, so no source text can close or comment out the block.
#
# awk portability: POSIX awk only (gawk, mawk, BWK). BINMODE=3 stops gawk on MSYS/Git
# Bash from dropping the CR of CRLF on read and write; other awks ignore the variable.
# A source is read whole with RS set to "\001" (a byte markdown never holds), so its
# final newline — present or absent — is kept exactly.

LC_ALL=C
export LC_ALL

case $0 in
  */*) here=${0%/*} ;;
  *) here=. ;;
esac
STAGES="research ask design proposal verify"
usage="usage: render.sh <dir> <research|ask|design|proposal|verify|all> [standard|advanced] [lang=<code>] | render.sh --check <dir> | render.sh --stamp <file>"

die() {
  printf 'render: %s\n' "$1" >&2
  exit 1
}

# Stamps of every markdown file in $1, one `<crc> <bytes> <path>` line each (empty when
# the directory holds none).
stamps() {
  set -- "$1"/*.md
  [ -f "$1" ] || return 0
  cksum "$@"
}

# Shared awk: stamp table from ENVIRON["SDD_STAMPS"] and the error exit.
AWK_COMMON='
function load_stamps(   n, i, line, p, crc, rest, q, path) {
  n = split(ENVIRON["SDD_STAMPS"], SL, "\n")
  for (i = 1; i <= n; i++) {
    line = SL[i]
    if (line == "") continue
    p = index(line, " "); crc = substr(line, 1, p - 1); rest = substr(line, p + 1)
    q = index(rest, " "); path = substr(rest, q + 1)
    sub(/.*\//, "", path)
    STAMP[path] = crc " " substr(rest, 1, q - 1)
  }
}
function fail(msg) {
  print "render: " msg | "cat 1>&2"
  close("cat 1>&2")
  exit 1
}
'

AWK_RENDER='
# Whole file, byte-exact (see header). optional = 1: an unreadable file sets
# SLURP_MISSING and returns "" instead of failing.
function slurp(f, optional,   old, s, rec, n, r) {
  old = RS; RS = "\001"; s = ""; n = 0
  SLURP_MISSING = 0
  while ((r = (getline rec < f)) > 0) { s = (n++ ? s "\001" : "") rec }
  close(f); RS = old
  if (r < 0 && n == 0 && optional) { SLURP_MISSING = 1; return "" }
  if (r < 0) fail("cannot read " f)
  return s
}

# Translation state of source <name> for lang: "fresh" (TBODY = body after the header),
# "same" (the source is already in lang), "stale" or "missing" — the contract is in the
# header of this script.
function translation(name,   t, p, h1, pre, suf, mid, rest) {
  TBODY = ""
  t = slurp(dir "/view/" lang "/" name, 1)
  if (SLURP_MISSING) return "missing"
  p = index(t, "\n")
  if (p) { h1 = substr(t, 1, p - 1); TBODY = substr(t, p + 1) } else h1 = t
  sub(/\r$/, "", h1)
  pre = "<!-- sdd-translation: " name " · " lang " · cksum "
  suf = " · same -->"
  if (length(h1) > length(pre) + length(suf) && substr(h1, 1, length(pre)) == pre && substr(h1, length(h1) - length(suf) + 1) == suf) {
    rest = TBODY
    gsub(/[\r\n]/, "", rest)
    if (rest != "") return "missing"
    mid = substr(h1, length(pre) + 1, length(h1) - length(pre) - length(suf))
    if (mid == STAMP[name]) return "same"
    if (mid ~ /^[0-9]+ [0-9]+$/) return "stale"
    return "missing"
  }
  suf = " -->"
  if (length(h1) <= length(pre) + length(suf)) return "missing"
  if (substr(h1, 1, length(pre)) != pre || substr(h1, length(h1) - length(suf) + 1) != suf) return "missing"
  mid = substr(h1, length(pre) + 1, length(h1) - length(pre) - length(suf))
  if (mid == STAMP[name]) return "fresh"
  if (mid ~ /^[0-9]+ [0-9]+$/) return "stale"
  return "missing"
}

# The <file> of a placeholder line `<!--SDD:<KIND>:<file>-->`.
function placeholder_name(line,   s) {
  s = line; sub(/^<!--SDD:[A-Z]+:/, "", s); sub(/-->$/, "", s)
  return s
}

# Pass 1: the stage renders only when every required source exists and every inlined
# asset exists and (for JS) holds no script tag sequence. Returns the missing source
# path, "" when the stage can render.
function validate(stage,   tpl, line, r, a, l, ar) {
  tpl = here "/template/" stage ".html"
  while ((r = (getline line < tpl)) > 0) {
    if (line ~ /^<!--SDD:SRC:.*-->$/) {
      a = placeholder_name(line)
      if (!(a in STAMP)) { close(tpl); return dir "/" a }
      continue
    }
    a = ""
    if (line ~ /^<!--SDD:VENDOR:.*-->$/) a = here "/vendor/" placeholder_name(line)
    else if (line ~ /^<!--SDD:SHARED:.*-->$/) a = here "/shared/" placeholder_name(line)
    if (a == "") continue
    while ((ar = (getline l < a)) > 0) {
      if (a ~ /\.js$/ && tolower(l) ~ /<\/?script/) fail("refusing to inline " a ": it contains a script tag sequence")
    }
    if (ar < 0) fail("missing template asset: " a)
    close(a)
  }
  if (r < 0) fail("missing template: " tpl)
  close(tpl)
  return ""
}

function inline(f, out,   l) {
  while ((getline l < f) > 0) {
    if (index(l, "GENERATED from core/") == 0) print l > out
  }
  close(f)
}

# Pass 2: assemble the page; fills SRC[] with the embedded sources for the pre-check.
function assemble(stage, out,   tpl, line, skip, name, body, attrs, st) {
  tpl = here "/template/" stage ".html"
  skip = 0
  NTRL = 0
  for (name in SRC) delete SRC[name]
  while ((getline line < tpl) > 0) {
    if (index(line, "GENERATED from core/")) continue
    if (line == "<!--SDD:ADVANCED-->") { if (tier == "standard") skip = 1; continue }
    if (line == "<!--/SDD:ADVANCED-->") { skip = 0; continue }
    if (skip) continue
    if (line == "<!--SDD:TIER-->") {
      print "<meta name=\"sdd-tier\" content=\"" tier "\">" > out
      if (lang != "") print "<meta name=\"sdd-lang\" content=\"" lang "\">" > out
    } else if (line ~ /^<!--SDD:(SRC|OPT):.*-->$/) {
      name = placeholder_name(line)
      if (!(name in STAMP)) continue
      body = slurp(dir "/" name, 0)
      attrs = ""
      if (lang != "") {
        st = translation(name)
        if (st == "fresh") {
          body = TBODY
          attrs = " data-lang=\"" lang "\" data-translated=\"1\""
        } else if (st == "same") {
          attrs = " data-lang=\"" lang "\" data-translated=\"same\""
        } else {
          attrs = " data-translation=\"" st "\""
          TRL[++NTRL] = "translation: " name " — " st
        }
      }
      SRC[name] = body
      gsub(/&/, "\\&amp;", body)
      gsub(/</, "\\&lt;", body)
      printf "%s", "<script type=\"text/markdown\" data-src=\"" name "\" data-cksum=\"" STAMP[name] "\"" attrs ">" body "</script>\n" > out
    } else if (line ~ /^<!--SDD:VENDOR:.*-->$/) {
      inline(here "/vendor/" placeholder_name(line), out)
    } else if (line ~ /^<!--SDD:SHARED:.*-->$/) {
      inline(here "/shared/" placeholder_name(line), out)
    } else {
      print line > out
    }
  }
  close(tpl)
  close(out)
}

# ---------- advanced-tier pre-check: same rules and order as shared/precheck.js ----------

function fb(h, r) { print "fallback: " h " — " r; NFB++ }

# Fence state (sddFenceStep in precheck.js): FC is "" outside a fence, else the fence
# character; FN the opening length, FQ the blockquote depth it opened at. Returns 1 when
# l is a fence marker (opening or closing): after blockquote markers, 3+ backticks /
# tildes open (not a backtick run followed by text holding another backtick: an inline
# code span); only a line of nothing but FC, at least FN long, after FQ quote markers,
# closes; a line with fewer quote markers ends the quote and the fence with it and is
# read afresh.
function fence_step(l,   t, q, r) {
  t = l; q = 0
  if (FC != "") {
    while (q < FQ && match(t, /^[ \t]*>[ \t]?/)) { t = substr(t, RLENGTH + 1); q++ }
    if (q == FQ) {
      sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (length(t) >= FN && ((FC == "`" && t ~ /^`+$/) || (FC == "~" && t ~ /^~+$/))) { FC = ""; return 1 }
      return 0
    }
    FC = ""; t = l; q = 0
  }
  while (match(t, /^[ \t]*>[ \t]?/)) { t = substr(t, RLENGTH + 1); q++ }
  if (t !~ /^[ \t]*(```+|~~~+)/) return 0
  sub(/^[ \t]*/, "", t)
  r = substr(t, 1, 1); FN = 0
  while (substr(t, FN + 1, 1) == r) FN++
  if (r == "`" && index(substr(t, FN + 1), "`")) return 0
  FC = r; FQ = q
  return 1
}

# Loads the body lines (outside fences) of the first `## <name>…` section of SRC[file]
# into SEC[1..NSEC]; returns 1 when the heading exists, 0 otherwise.
function section(file, name,   n, i, l, grab, h) {
  NSEC = 0
  n = split(SRC[file], LN, "\n")
  FC = ""; grab = 0
  for (i = 1; i <= n; i++) {
    l = LN[i]; sub(/\r$/, "", l)
    if (fence_step(l) || FC != "") continue
    if (grab) { if (l ~ /^##? /) break; SEC[++NSEC] = l; continue }
    if (l ~ /^## +/) { h = l; sub(/^## +/, "", h); if (index(h, name) == 1) grab = 1 }
  }
  return grab
}

# Key-flow block of proposal.md `## How` (sddKeyflow in precheck.js): "none" without a
# ```mermaid block, "ok" when its first statement (blank / %% lines skipped) is a
# flowchart header, "bad" otherwise.
function keyflow(   n, i, l, grab, h, inb, t, opens) {
  n = split(SRC["proposal.md"], LN, "\n")
  FC = ""; grab = 0; inb = 0
  for (i = 1; i <= n; i++) {
    l = LN[i]; sub(/\r$/, "", l)
    if (!grab) {
      if (fence_step(l) || FC != "") continue
      if (l ~ /^## +/) { h = l; sub(/^## +/, "", h); if (index(h, "How") == 1) grab = 1 }
      continue
    }
    if (!inb) {
      if (FC == "" && l ~ /^##? /) break
      opens = (FC == "" && l ~ /^[ \t]*(```+|~~~+)mermaid[ \t]*$/)
      fence_step(l)
      if (opens) inb = 1
      continue
    }
    if (fence_step(l)) return "bad"
    t = l; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
    if (t == "" || substr(t, 1, 2) == "%%") continue
    return (t ~ /^(flowchart|graph)([ \t]+(TB|TD|BT|RL|LR))?[ \t]*;?$/) ? "ok" : "bad"
  }
  return inb ? "bad" : "none"
}

function precheck(stage,   i, ok, n, missing, hs, nh, start, found, l) {
  NFB = 0
  if (stage == "research") {
    if (!section("research.md", "Practices")) fb("Practices", "heading `## Practices` not found")
    else {
      ok = 0
      for (i = 1; i <= NSEC; i++) if (SEC[i] ~ /^- .*( — |: )/) ok = 1
      if (!ok) fb("Practices", "no `- <name> — <body>` option lines")
    }
    if (!section("research.md", "Open")) fb("Open [TBD]", "heading `## Open [TBD]` not found")
    if (!section("research.md", "Decided")) fb("Decided", "heading `## Decided` not found")
  } else if (stage == "ask") {
    if (!section("research.md", "Open")) fb("Open [TBD]", "heading `## Open [TBD]` not found")
    else for (i = 1; i <= NSEC; i++) {
      if (SEC[i] ~ /^- *\[TBD-[0-9]+\]/ && SEC[i] !~ /\| *candidates: .*\| *select: *(one|several)/) {
        n = SEC[i]; sub(/^- *\[TBD-/, "", n); sub(/\].*$/, "", n)
        fb("[TBD-" n "]", "no `| candidates: ... | select: one|several` fields")
      }
    }
  } else if (stage == "design") {
    if (!section("design.md", "Interfaces")) fb("Interfaces", "heading `## Interfaces` not found")
    else {
      ok = 0
      for (i = 1; i <= NSEC; i++) if (SEC[i] ~ /^- /) ok = 1
      if (!ok) fb("Interfaces", "no top-level `- ` bullets")
    }
  } else if (stage == "proposal") {
    missing = ""
    nh = split("Why What How Risk", hs, " ")
    for (i = 1; i <= nh; i++) {
      if (!section("proposal.md", hs[i])) missing = missing (missing == "" ? "" : ", ") "`## " hs[i] "`"
    }
    if (missing != "") fb("proposal.md", "missing " missing)
    if (section("proposal.md", "What")) {
      ok = 0
      for (i = 1; i <= NSEC; i++) if (SEC[i] ~ /^([0-9]+\. |- )/) ok = 1
      if (!ok) fb("What", "no `- ` or `N. ` items")
    }
    if (keyflow() == "bad") fb("How", "key-flow diagram not parsed")
    if (("research.md" in SRC) && !section("research.md", "Decided")) fb("Decided (research.md)", "heading `## Decided` not found")
    if ("gate.md" in SRC) {
      n = split(SRC["gate.md"], LN, "\n")
      start = 0; found = 0
      for (i = 1; i <= n; i++) {
        l = LN[i]; sub(/\r$/, "", l)
        if (!start) { if (l ~ /^ *Changes([^A-Za-z]|$)/) start = 1; continue }
        if (l ~ /^ *(Register test|Decided without asking|Unsourced additions|Uncovered requirements|Unresolved critique|<\/HARD-GATE>)/) break
        if (l ~ /^ *[0-9]+\. /) { found = 1; break }
      }
      if (!start) fb("Changes (gate.md)", "no `Changes` block")
      else if (!found) fb("Changes (gate.md)", "no numbered blocks under `Changes`")
    }
    if ("index.md" in SRC) {
      n = split(SRC["index.md"], LN, "\n")
      found = 0
      for (i = 1; i <= n; i++) { l = LN[i]; sub(/\r$/, "", l); if (l ~ /^- *R-[0-9]+:/) found = 1 }
      if (!found) fb("Requirements (index.md)", "no `- R-N:` lines")
    }
  } else if (stage == "verify") {
    n = split(SRC["verify.md"], LN, "\n")
    ok = 0
    l = LN[1]; sub(/\r$/, "", l)
    if (l == "---") {
      for (i = 2; i <= n; i++) {
        l = LN[i]; sub(/\r$/, "", l)
        if (l == "---") break
        if (l ~ /^conclusion:/) { ok = 1; break }
      }
    }
    if (!ok) fb("frontmatter", "no `conclusion:` in YAML frontmatter")
    if (!section("verify.md", "Findings")) fb("Findings", "heading `## Findings` not found")
    else {
      ok = 0
      for (i = 1; i <= NSEC; i++) if (SEC[i] ~ /^ *\|/ && SEC[i] ~ /\| *Severity *\|/ && SEC[i] ~ /\| *Status *\|/) ok = 1
      if (!ok) fb("Findings", "no table with `Severity` and `Status` columns")
    }
  }
  if (NFB == 0) print "fallback: none"
}

BEGIN {
  here = ENVIRON["SDD_HERE"]
  dir = ENVIRON["SDD_DIR"]
  load_stamps()
  n = split(stages, ST, " ")
  rendered = 0
  for (k = 1; k <= n; k++) {
    s = ST[k]
    missing = validate(s)
    if (missing != "") {
      if (n == 1) fail("required source missing for stage " s ": " missing)
      continue
    }
    out = dir "/view/" s ".html"
    assemble(s, out)
    rendered = 1
    print "view: " out
    for (i = 1; i <= NTRL; i++) print TRL[i]
    if (tier == "advanced") precheck(s)
    else print "fallback: none"
  }
  if (!rendered) fail("no stage has its required source in " dir)
  exit 0
}
'

AWK_CHECK='
function flush(   st) {
  if (cur != "" && stale) {
    st = cur; sub(/^.*\//, "", st); sub(/\.html$/, "", st)
    print cur " stale — $spec-view " st
  }
}
BEGIN { load_stamps() }
FNR == 1 { flush(); cur = FILENAME; stale = 0 }
/^<script type="text\/markdown" data-src="[^"]*" data-cksum="[^"]*"/ {
  s = $0
  sub(/^<script type="text\/markdown" data-src="/, "", s)
  name = s; sub(/".*$/, "", name)
  sum = s; sub(/^[^"]*" data-cksum="/, "", sum); sub(/".*$/, "", sum)
  if (!(name in STAMP) || STAMP[name] != sum) stale = 1
}
END { flush() }
'

trim_dir() {
  td=$1
  while [ "$td" != / ] && [ "${td%/}" != "$td" ]; do td=${td%/}; done
  printf '%s' "$td"
}

[ $# -ge 1 ] || die "$usage"

if [ "$1" = --check ]; then
  [ $# -eq 2 ] || die "$usage"
  dir=$(trim_dir "$2")
  [ -d "$dir" ] || die "not a directory: $dir"
  set -- "$dir"/view/*.html
  [ -f "$1" ] || exit 0
  SDD_STAMPS=$(stamps "$dir") || die "cksum failed in $dir"
  export SDD_STAMPS
  awk "$AWK_COMMON$AWK_CHECK" "$@" || exit 1
  exit 0
fi

if [ "$1" = --stamp ]; then
  [ $# -eq 2 ] || die "$usage"
  [ -f "$2" ] || die "no such file: $2"
  cksum < "$2" || die "cksum failed on $2"
  exit 0
fi

[ $# -ge 2 ] && [ $# -le 4 ] || die "$usage"
dir=$(trim_dir "$1")
shift
stage=
tier=
lang=
bad_lang="code: 2-3 lowercase letters, optionally -<letters/digits>"
for tok in "$@"; do
  case $tok in
    lang=*)
      [ -z "$lang" ] || die "$usage"
      code=${tok#lang=}
      base=${code%%-*}
      case $base in
        [a-z][a-z]|[a-z][a-z][a-z]) ;;
        *) die "unknown token '$tok' ($bad_lang)" ;;
      esac
      if [ "$base" != "$code" ]; then
        case ${code#"$base"-} in
          ''|*[!A-Za-z0-9]*) die "unknown token '$tok' ($bad_lang)" ;;
        esac
      fi
      lang=$code
      ;;
    *)
      if [ -z "$stage" ]; then stage=$tok
      elif [ -z "$tier" ]; then tier=$tok
      else die "$usage"
      fi
      ;;
  esac
done
[ -n "$stage" ] || die "$usage"
tier=${tier:-advanced}
[ -d "$dir" ] || die "not a directory: $dir"
case $tier in
  standard|advanced) ;;
  *) die "unknown tier '$tier' (standard|advanced)" ;;
esac
case $stage in
  all) stages=$STAGES ;;
  research|ask|design|proposal|verify) stages=$stage ;;
  *) die "unknown stage '$stage' (research|ask|design|proposal|verify|all)" ;;
esac

SDD_STAMPS=$(stamps "$dir") || die "cksum failed in $dir"
export SDD_STAMPS
made_view=0
if [ ! -d "$dir/view" ]; then
  mkdir -p "$dir/view" || die "cannot create $dir/view"
  made_view=1
fi
# Paths travel through ENVIRON: -v would interpret backslashes in them.
SDD_HERE=$here
SDD_DIR=$dir
export SDD_HERE SDD_DIR
if ! awk -v BINMODE=3 -v tier="$tier" -v stages="$stages" -v lang="$lang" "$AWK_COMMON$AWK_RENDER"; then
  [ "$made_view" = 1 ] && rmdir "$dir/view" 2> /dev/null
  exit 1
fi
exit 0
