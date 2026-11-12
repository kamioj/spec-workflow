#!/usr/bin/env pwsh
# render.ps1 — PowerShell 7 twin of render.sh; same arguments, byte-identical pages,
# identical stdout (LF line endings, UTF-8).
#
#   pwsh -File render.ps1 <dir> <stage> [standard|advanced] [lang=<code>]
#   pwsh -File render.ps1 --check <dir>
#   pwsh -File render.ps1 --stamp <file>
#
# Translation contract (lang=<code>): see the header of render.sh.
#
# Bytes are handled as Latin-1 strings (one char per byte), so escaping and assembly are
# byte-exact for any UTF-8 content. Stamps implement POSIX `cksum` (CRC-32, polynomial
# 0x04C11DB7, MSB-first, length appended LSB-first, complemented) so a page stamped here
# checks clean under render.sh and vice versa. The fallback pre-check mirrors
# shared/precheck.js and render.sh rule for rule.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$Here = $PSScriptRoot
$Stages = @('research', 'ask', 'design', 'proposal', 'verify')
$Latin1 = [Text.Encoding]::Latin1
$Utf8 = [Text.UTF8Encoding]::new($false)
$Dash = [string][char]0x2014
$Usage = 'usage: render.ps1 <dir> <research|ask|design|proposal|verify|all> [standard|advanced] | render.ps1 --check <dir>'

function Out-Line([string]$s) { [Console]::Out.Write($s + "`n") }

function Fail([string]$msg) {
  [Console]::Error.Write('render: ' + $msg + "`n")
  exit 1
}

function Get-FullPath([string]$p) {
  [IO.Path]::GetFullPath($p, (Get-Location).ProviderPath)
}

function Test-File([string]$p) { [IO.File]::Exists((Get-FullPath $p)) }

function Read-Bytes([string]$p) { return , [IO.File]::ReadAllBytes((Get-FullPath $p)) }

# ---------- cksum ----------

$Mask = [uint64]4294967295
$CrcTable = [uint64[]]::new(256)
for ($i = 0; $i -lt 256; $i++) {
  $c = [uint64]$i -shl 24
  for ($k = 0; $k -lt 8; $k++) {
    if ($c -band [uint64]2147483648) { $c = (($c -shl 1) -band $Mask) -bxor [uint64]79764919 }
    else { $c = ($c -shl 1) -band $Mask }
  }
  $CrcTable[$i] = $c
}

function Get-Stamp([string]$p) {
  $bytes = Read-Bytes $p
  $t = $CrcTable
  $m = $Mask
  [uint64]$crc = 0
  foreach ($b in $bytes) {
    $crc = (($crc -shl 8) -band $m) -bxor $t[(($crc -shr 24) -bxor $b) -band 255]
  }
  [uint64]$n = $bytes.Length
  while ($n -gt 0) {
    $crc = (($crc -shl 8) -band $m) -bxor $t[(($crc -shr 24) -bxor ($n -band 255)) -band 255]
    $n = $n -shr 8
  }
  $crc = (-bnot $crc) -band $m
  return "$crc $($bytes.Length)"
}

# ---------- line helpers (render.sh semantics) ----------

# Lines of a byte string as `grep` / `read` see them: split on LF, a final unterminated
# line kept, no trailing empty element for a terminating LF.
function Split-Lines([string]$s) {
  if ($s.Length -eq 0) { return , @() }
  $parts = $s.Split("`n")
  if ($s.EndsWith("`n")) { $parts = $parts[0..($parts.Length - 2)] }
  return , $parts
}

# Inlined file: its lines minus GENERATED marker lines, every line LF-terminated.
function Get-Inline([string]$p) {
  if (-not (Test-File $p)) { Fail "missing template asset: $p" }
  $sb = [Text.StringBuilder]::new()
  foreach ($l in (Split-Lines ($Latin1.GetString((Read-Bytes $p))))) {
    if ($l.Contains('GENERATED from core/')) { continue }
    [void]$sb.Append($l).Append("`n")
  }
  return $sb.ToString()
}

function Get-InlineJs([string]$p) {
  if (-not (Test-File $p)) { Fail "missing template asset: $p" }
  $raw = $Latin1.GetString((Read-Bytes $p))
  if ($raw -match '(?i)<script|</script') { Fail "refusing to inline ${p}: it contains a script tag sequence" }
  return Get-Inline $p
}

# ---------- pre-check (mirrors shared/precheck.js) ----------

# Embedded text of a source path when it differs from the file (a fresh translation);
# the pre-check reads what the page embeds.
$Embedded = @{}

function Get-TextLines([string]$p) {
  $bytes = if ($Embedded.ContainsKey($p)) { , $Embedded[$p] } else { , (Read-Bytes $p) }
  $s = $Utf8.GetString($bytes)
  $out = [Collections.Generic.List[string]]::new()
  foreach ($l in $s.Split("`n")) { $out.Add(($l -replace "`r$", '')) }
  return , $out
}

# Fence state (sddFenceStep in precheck.js): $script:FenceChar is '' outside a fence, else
# the fence character; $script:FenceLen the opening length, $script:FenceQuote the
# blockquote depth it opened at. Returns $true when the line is a fence marker (opening or
# closing): after blockquote markers, 3+ backticks / tildes open (not a backtick run
# followed by text holding another backtick: an inline code span); only a line of nothing
# but that character, at least as long, after the same quote markers, closes; a line with
# fewer quote markers ends the quote and the fence with it and is read afresh.
$script:FenceChar = ''
$script:FenceLen = 0
$script:FenceQuote = 0
function Step-Fence([string]$l) {
  $t = $l
  $q = 0
  if ($script:FenceChar -ne '') {
    while ($q -lt $script:FenceQuote) {
      $m = [regex]::Match($t, '^[ \t]*>[ \t]?')
      if (-not $m.Success) { break }
      $t = $t.Substring($m.Length)
      $q++
    }
    if ($q -eq $script:FenceQuote) {
      $t = $t -creplace '^[ \t]+', '' -creplace '[ \t]+$', ''
      if ($t.Length -ge $script:FenceLen -and $t -cmatch ('^' + [regex]::Escape($script:FenceChar) + '+$')) {
        $script:FenceChar = ''
        return $true
      }
      return $false
    }
    $script:FenceChar = ''
    $t = $l
    $q = 0
  }
  while ($true) {
    $m = [regex]::Match($t, '^[ \t]*>[ \t]?')
    if (-not $m.Success) { break }
    $t = $t.Substring($m.Length)
    $q++
  }
  $m = [regex]::Match($t, '^[ \t]*(`{3,}|~{3,})([\s\S]*)$')
  if (-not $m.Success) { return $false }
  $c = $m.Groups[1].Value.Substring(0, 1)
  if ($c -eq '`' -and $m.Groups[2].Value.Contains('`')) { return $false }
  $script:FenceChar = $c
  $script:FenceLen = $m.Groups[1].Value.Length
  $script:FenceQuote = $q
  return $true
}

# Key-flow block of `## How` (sddKeyflow in precheck.js): 'none' without a ```mermaid
# block, 'ok' when its first statement (blank / %% lines skipped) is a flowchart header,
# 'bad' otherwise.
function Get-Keyflow([string]$p) {
  $script:FenceChar = ''
  $grab = $false
  $inb = $false
  foreach ($l in (Get-TextLines $p)) {
    if (-not $grab) {
      if ((Step-Fence $l) -or $script:FenceChar -ne '') { continue }
      if ($l -cmatch '^## +') {
        $h = $l -creplace '^## +', ''
        if ($h.StartsWith('How', [StringComparison]::Ordinal)) { $grab = $true }
      }
      continue
    }
    if (-not $inb) {
      if ($script:FenceChar -eq '' -and $l -cmatch '^##? ') { break }
      $opens = $script:FenceChar -eq '' -and $l -cmatch '^[ \t]*(`{3,}|~{3,})mermaid[ \t]*$'
      [void](Step-Fence $l)
      if ($opens) { $inb = $true }
      continue
    }
    if (Step-Fence $l) { return 'bad' }
    $t = $l -creplace '^[ \t]+', '' -creplace '[ \t]+$', ''
    if ($t -eq '' -or $t.StartsWith('%%', [StringComparison]::Ordinal)) { continue }
    if ($t -cmatch '^(flowchart|graph)([ \t]+(TB|TD|BT|RL|LR))?[ \t]*;?$') { return 'ok' }
    return 'bad'
  }
  if ($inb) { return 'bad' }
  return 'none'
}

# Body lines (outside fences) of the first `## <name>…` section; $null when absent.
function Get-Section([string]$p, [string]$name) {
  $script:FenceChar = ''
  $grab = $false
  $got = $null
  foreach ($l in (Get-TextLines $p)) {
    if ((Step-Fence $l) -or $script:FenceChar -ne '') { continue }
    if ($grab) {
      if ($l -cmatch '^##? ') { break }
      $got.Add($l)
      continue
    }
    if ($l -cmatch '^## +') {
      $h = $l -creplace '^## +', ''
      if ($h.StartsWith($name, [StringComparison]::Ordinal)) {
        $grab = $true
        $got = [Collections.Generic.List[string]]::new()
      }
    }
  }
  if ($null -eq $got) { return $null }
  return , $got
}

function Test-Any($lines, [string]$re) {
  foreach ($l in $lines) { if ($l -cmatch $re) { return $true } }
  return $false
}

function Get-Fallbacks([string]$stage, [string]$dir) {
  $out = [Collections.Generic.List[string]]::new()
  function Add-Fb([string]$h, [string]$r) { $out.Add("fallback: $h $Dash $r") }
  $em = $Dash
  switch ($stage) {
    'research' {
      $f = "$dir/research.md"
      $p = Get-Section $f 'Practices'
      if ($null -eq $p) { Add-Fb 'Practices' 'heading `## Practices` not found' }
      elseif (-not (Test-Any $p "^- .*( $em |: )")) { Add-Fb 'Practices' "no ``- <name> $em <body>`` option lines" }
      if ($null -eq (Get-Section $f 'Open')) { Add-Fb 'Open [TBD]' 'heading `## Open [TBD]` not found' }
      if ($null -eq (Get-Section $f 'Decided')) { Add-Fb 'Decided' 'heading `## Decided` not found' }
    }
    'ask' {
      $open = Get-Section "$dir/research.md" 'Open'
      if ($null -eq $open) { Add-Fb 'Open [TBD]' 'heading `## Open [TBD]` not found' }
      else {
        foreach ($l in $open) {
          $m = [regex]::Match($l, '^- *\[TBD-([0-9]+)\]')
          if ($m.Success -and -not ($l -cmatch '\| *candidates: .*\| *select: *(one|several)')) {
            Add-Fb "[TBD-$($m.Groups[1].Value)]" 'no `| candidates: ... | select: one|several` fields'
          }
        }
      }
    }
    'design' {
      $itf = Get-Section "$dir/design.md" 'Interfaces'
      if ($null -eq $itf) { Add-Fb 'Interfaces' 'heading `## Interfaces` not found' }
      elseif (-not (Test-Any $itf '^- ')) { Add-Fb 'Interfaces' 'no top-level `- ` bullets' }
    }
    'proposal' {
      $f = "$dir/proposal.md"
      $missing = @()
      foreach ($h in @('Why', 'What', 'How', 'Risk')) {
        if ($null -eq (Get-Section $f $h)) { $missing += ('`## ' + $h + '`') }
      }
      if ($missing.Count) { Add-Fb 'proposal.md' ('missing ' + ($missing -join ', ')) }
      $what = Get-Section $f 'What'
      if ($null -ne $what -and -not (Test-Any $what '^([0-9]+\. |- )')) { Add-Fb 'What' 'no `- ` or `N. ` items' }
      if ((Get-Keyflow $f) -ceq 'bad') { Add-Fb 'How' 'key-flow diagram not parsed' }
      if ((Test-File "$dir/research.md") -and $null -eq (Get-Section "$dir/research.md" 'Decided')) {
        Add-Fb 'Decided (research.md)' 'heading `## Decided` not found'
      }
      if (Test-File "$dir/gate.md") {
        $gl = Get-TextLines "$dir/gate.md"
        $start = -1
        for ($g = 0; $g -lt $gl.Count; $g++) {
          if ($gl[$g] -cmatch '^ *Changes([^A-Za-z]|$)') { $start = $g; break }
        }
        if ($start -lt 0) { Add-Fb 'Changes (gate.md)' 'no `Changes` block' }
        else {
          $found = $false
          for ($j = $start + 1; $j -lt $gl.Count; $j++) {
            if ($gl[$j] -cmatch '^ *(Register test|Decided without asking|Unsourced additions|Uncovered requirements|Unresolved critique|</HARD-GATE>)') { break }
            if ($gl[$j] -cmatch '^ *[0-9]+\. ') { $found = $true; break }
          }
          if (-not $found) { Add-Fb 'Changes (gate.md)' 'no numbered blocks under `Changes`' }
        }
      }
      if ((Test-File "$dir/index.md") -and -not (Test-Any (Get-TextLines "$dir/index.md") '^- *R-[0-9]+:')) {
        Add-Fb 'Requirements (index.md)' 'no `- R-N:` lines'
      }
    }
    'verify' {
      $f = "$dir/verify.md"
      $vl = Get-TextLines $f
      $concl = $false
      if ($vl[0] -ceq '---') {
        for ($k = 1; $k -lt $vl.Count; $k++) {
          if ($vl[$k] -ceq '---') { break }
          if ($vl[$k] -cmatch '^conclusion:') { $concl = $true; break }
        }
      }
      if (-not $concl) { Add-Fb 'frontmatter' 'no `conclusion:` in YAML frontmatter' }
      $fs = Get-Section $f 'Findings'
      if ($null -eq $fs) { Add-Fb 'Findings' 'heading `## Findings` not found' }
      else {
        $table = $false
        foreach ($l in $fs) {
          if ($l -cmatch '^ *\|' -and $l -cmatch '\| *Severity *\|' -and $l -cmatch '\| *Status *\|') { $table = $true; break }
        }
        if (-not $table) { Add-Fb 'Findings' 'no table with `Severity` and `Status` columns' }
      }
    }
  }
  return , $out
}

# ---------- render ----------

function Get-RequiredSources([string]$stage) {
  $out = @()
  foreach ($l in (Split-Lines ($Latin1.GetString((Read-Bytes "$Here/template/$stage.html"))))) {
    if ($l -cmatch '^<!--SDD:SRC:(.*)-->$') { $out += $Matches[1] }
  }
  return , $out
}

function Get-MissingRequired([string]$stage, [string]$dir) {
  foreach ($s in (Get-RequiredSources $stage)) {
    if (-not (Test-File "$dir/$s")) { return "$dir/$s" }
  }
  return $null
}

# Translation of <src> for <lang> (see render.sh header): @{ State = fresh|same|stale|missing;
# Body = Latin-1 string of the text after the header line }.
function Get-Translation([string]$dir, [string]$src, [string]$lang, [string]$stamp) {
  $p = "$dir/view/$lang/$src"
  if (-not (Test-File $p)) { return @{ State = 'missing'; Body = '' } }
  $t = $Latin1.GetString((Read-Bytes $p))
  $i = $t.IndexOf("`n")
  if ($i -ge 0) { $h1 = $t.Substring(0, $i); $body = $t.Substring($i + 1) } else { $h1 = $t; $body = '' }
  if ($h1.EndsWith("`r")) { $h1 = $h1.Substring(0, $h1.Length - 1) }
  $dot = $Latin1.GetString($Utf8.GetBytes(' ' + [char]0xB7 + ' '))
  $pre = '<!-- sdd-translation: ' + $src + $dot + $lang + $dot + 'cksum '
  $suf = $dot + 'same -->'
  if ($h1.Length -gt $pre.Length + $suf.Length -and
      $h1.StartsWith($pre, [StringComparison]::Ordinal) -and
      $h1.EndsWith($suf, [StringComparison]::Ordinal)) {
    if (($body -replace "[`r`n]", '') -ne '') { return @{ State = 'missing'; Body = '' } }
    $mid = $h1.Substring($pre.Length, $h1.Length - $pre.Length - $suf.Length)
    if ($mid -ceq $stamp) { return @{ State = 'same'; Body = '' } }
    if ($mid -cmatch '^[0-9]+ [0-9]+$') { return @{ State = 'stale'; Body = '' } }
    return @{ State = 'missing'; Body = '' }
  }
  $suf = ' -->'
  if ($h1.Length -le $pre.Length + $suf.Length -or
      -not $h1.StartsWith($pre, [StringComparison]::Ordinal) -or
      -not $h1.EndsWith($suf, [StringComparison]::Ordinal)) {
    return @{ State = 'missing'; Body = '' }
  }
  $mid = $h1.Substring($pre.Length, $h1.Length - $pre.Length - $suf.Length)
  if ($mid -ceq $stamp) { return @{ State = 'fresh'; Body = $body } }
  if ($mid -cmatch '^[0-9]+ [0-9]+$') { return @{ State = 'stale'; Body = '' } }
  return @{ State = 'missing'; Body = '' }
}

function Invoke-RenderStage([string]$stage, [string]$dir, [string]$tier, [string]$lang) {
  $tpl = "$Here/template/$stage.html"
  if (-not (Test-File $tpl)) { Fail "missing template: $tpl" }
  $missing = Get-MissingRequired $stage $dir
  if ($null -ne $missing) { Fail "required source missing for stage ${stage}: $missing" }
  [void][IO.Directory]::CreateDirectory((Get-FullPath "$dir/view"))
  $out = "$dir/view/$stage.html"
  $sb = [Text.StringBuilder]::new()
  $skip = $false
  $Embedded.Clear()
  $trl = [Collections.Generic.List[string]]::new()
  foreach ($line in (Split-Lines (Get-Inline $tpl))) {
    if ($line -ceq '<!--SDD:ADVANCED-->') { if ($tier -eq 'standard') { $skip = $true }; continue }
    if ($line -ceq '<!--/SDD:ADVANCED-->') { $skip = $false; continue }
    if ($skip) { continue }
    if ($line -ceq '<!--SDD:TIER-->') {
      [void]$sb.Append("<meta name=`"sdd-tier`" content=`"$tier`">`n")
      if ($lang) { [void]$sb.Append("<meta name=`"sdd-lang`" content=`"$lang`">`n") }
    }
    elseif ($line -cmatch '^<!--SDD:(SRC|OPT):(.*)-->$') {
      $src = $Matches[2]
      if (Test-File "$dir/$src") {
        $stamp = Get-Stamp "$dir/$src"
        $raw = $Latin1.GetString((Read-Bytes "$dir/$src"))
        $attrs = ''
        if ($lang) {
          $tr = Get-Translation $dir $src $lang $stamp
          if ($tr.State -ceq 'fresh') {
            $raw = $tr.Body
            $Embedded["$dir/$src"] = $Latin1.GetBytes($raw)
            $attrs = " data-lang=`"$lang`" data-translated=`"1`""
          }
          elseif ($tr.State -ceq 'same') {
            $attrs = " data-lang=`"$lang`" data-translated=`"same`""
          }
          else {
            $attrs = " data-translation=`"$($tr.State)`""
            $trl.Add("translation: $src $Dash $($tr.State)")
          }
        }
        $body = $raw.Replace('&', '&amp;').Replace('<', '&lt;')
        [void]$sb.Append("<script type=`"text/markdown`" data-src=`"$src`" data-cksum=`"$stamp`"$attrs>")
        [void]$sb.Append($body).Append("</script>`n")
      }
    }
    elseif ($line -cmatch '^<!--SDD:VENDOR:(.*)-->$') {
      [void]$sb.Append((Get-InlineJs "$Here/vendor/$($Matches[1])"))
    }
    elseif ($line -cmatch '^<!--SDD:SHARED:(.*\.js)-->$') {
      [void]$sb.Append((Get-InlineJs "$Here/shared/$($Matches[1])"))
    }
    elseif ($line -cmatch '^<!--SDD:SHARED:(.*)-->$') {
      [void]$sb.Append((Get-Inline "$Here/shared/$($Matches[1])"))
    }
    else {
      [void]$sb.Append($line).Append("`n")
    }
  }
  [IO.File]::WriteAllBytes((Get-FullPath $out), $Latin1.GetBytes($sb.ToString()))
  Out-Line "view: $out"
  foreach ($t in $trl) { Out-Line $t }
  $fbs = if ($tier -eq 'advanced') { Get-Fallbacks $stage $dir } else { @() }
  if ($fbs.Count) { foreach ($f in $fbs) { Out-Line $f } }
  else { Out-Line 'fallback: none' }
}

function Invoke-Check([string]$dir) {
  if (-not [IO.Directory]::Exists((Get-FullPath $dir))) { Fail "not a directory: $dir" }
  $viewDir = Get-FullPath "$dir/view"
  if (-not [IO.Directory]::Exists($viewDir)) { return }
  $names = [IO.Directory]::GetFiles($viewDir, '*.html') | ForEach-Object { [IO.Path]::GetFileName($_) }
  $names = [string[]]@($names)
  [Array]::Sort($names, [StringComparer]::Ordinal)
  foreach ($n in $names) {
    $page = "$dir/view/$n"
    $stale = $false
    foreach ($l in (Split-Lines ($Latin1.GetString((Read-Bytes $page))))) {
      $m = [regex]::Match($l, '^<script type="text/markdown" data-src="([^"]*)" data-cksum="([^"]*)"')
      if (-not $m.Success) { continue }
      $src = "$dir/$($m.Groups[1].Value)"
      if (-not (Test-File $src) -or (Get-Stamp $src) -cne $m.Groups[2].Value) { $stale = $true }
    }
    if ($stale) { Out-Line ($page + ' stale ' + $Dash + ' /spec:view ' + $n.Substring(0, $n.Length - 5)) }
  }
}

function Get-TrimmedDir([string]$d) {
  while ($d -ne '/' -and $d.EndsWith('/')) { $d = $d.Substring(0, $d.Length - 1) }
  return $d
}

if ($args.Count -lt 1) { Fail $Usage }

if ($args[0] -ceq '--check') {
  if ($args.Count -ne 2) { Fail $Usage }
  Invoke-Check (Get-TrimmedDir $args[1])
  exit 0
}

if ($args[0] -ceq '--stamp') {
  if ($args.Count -ne 2) { Fail $Usage }
  if (-not (Test-File $args[1])) { Fail "no such file: $($args[1])" }
  Out-Line (Get-Stamp $args[1])
  exit 0
}

if ($args.Count -lt 2 -or $args.Count -gt 4) { Fail $Usage }
$dir = Get-TrimmedDir $args[0]
$stage = ''
$tier = ''
$lang = ''
$badLang = 'code: 2-3 lowercase letters, optionally -<letters/digits>'
foreach ($tok in $args[1..($args.Count - 1)]) {
  if ($tok.StartsWith('lang=', [StringComparison]::Ordinal)) {
    if ($lang) { Fail $Usage }
    $code = $tok.Substring(5)
    if ($code -cnotmatch '^[a-z]{2,3}(-[A-Za-z0-9]+)?$') { Fail "unknown token '$tok' ($badLang)" }
    $lang = $code
  }
  elseif (-not $stage) { $stage = $tok }
  elseif (-not $tier) { $tier = $tok }
  else { Fail $Usage }
}
if (-not $stage) { Fail $Usage }
if (-not $tier) { $tier = 'advanced' }
if (-not [IO.Directory]::Exists((Get-FullPath $dir))) { Fail "not a directory: $dir" }
if ($tier -cne 'standard' -and $tier -cne 'advanced') { Fail "unknown tier '$tier' (standard|advanced)" }

if ($stage -ceq 'all') {
  $rendered = $false
  foreach ($s in $Stages) {
    if ($null -eq (Get-MissingRequired $s $dir)) {
      Invoke-RenderStage $s $dir $tier $lang
      $rendered = $true
    }
  }
  if (-not $rendered) { Fail "no stage has its required source in $dir" }
}
elseif ($Stages -ccontains $stage) {
  Invoke-RenderStage $stage $dir $tier $lang
}
else {
  Fail "unknown stage '$stage' (research|ask|design|proposal|verify|all)"
}
exit 0
