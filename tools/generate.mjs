#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const ROOT = process.cwd();
const CORE = "core";
const GENERATED_PREFIX = "GENERATED from ";
const HOST_OPEN = /^<!-- host:(claude|codex) -->\s*$/;
const HOST_CLOSE = /^<!-- \/host -->\s*$/;

function fail(message) {
  throw new Error(message);
}

function toPosix(value) {
  return value.split(path.sep).join("/");
}

function normalizeLf(value) {
  return value.replace(/\r\n?/g, "\n");
}

function ensureTrailingLf(value) {
  return value.endsWith("\n") ? value : `${value}\n`;
}

function readText(file) {
  return normalizeLf(fs.readFileSync(path.join(ROOT, file), "utf8"));
}

function writeText(baseDir, file, content) {
  const out = path.join(baseDir, file);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, ensureTrailingLf(content), "utf8");
}

function listFiles(dir) {
  const absolute = path.join(ROOT, dir);
  if (!fs.existsSync(absolute)) {
    return [];
  }
  const out = [];
  for (const entry of fs.readdirSync(absolute, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const child = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...listFiles(child));
    } else if (entry.isFile()) {
      out.push(toPosix(child));
    }
  }
  return out;
}

function selectHost(raw, host, sourcePath) {
  const lines = normalizeLf(raw).split("\n");
  const kept = [];
  let active = null;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const open = line.match(HOST_OPEN);
    if (open) {
      if (active) {
        fail(`${sourcePath}:${i + 1}: nested host marker inside host:${active}`);
      }
      active = open[1];
      continue;
    }
    if (HOST_CLOSE.test(line)) {
      if (!active) {
        fail(`${sourcePath}:${i + 1}: closing host marker without an open marker`);
      }
      active = null;
      continue;
    }
    // A marker sharing its line with other text is not recognized above, so it would leak
    // verbatim into BOTH hosts. Fail loudly instead; put each marker on its own line.
    if (/<!-- (host:|\/host)/.test(line)) {
      fail(`${sourcePath}:${i + 1}: host marker must sit alone on its line (inline markers leak into both hosts)`);
    }
    if (!active || active === host) {
      kept.push(line);
    }
  }
  if (active) {
    fail(`${sourcePath}: unclosed host:${active} marker`);
  }
  return kept.join("\n");
}

// The marker must be a comment in the target's own syntax: an HTML comment on line 1 of a
// shell or PowerShell script is a parse error, and inside JS/CSS it breaks the inlined page.
function generatedHeader(sourcePath, targetPath) {
  const marker = `${GENERATED_PREFIX}${sourcePath} — edit the core file and run node tools/generate.mjs; hand edits will be overwritten`;
  const ext = path.extname(targetPath);
  if ([".toml", ".yml", ".yaml", ".sh", ".ps1"].includes(ext)) return `# ${marker}\n`;
  if (ext === ".js") return `// ${marker}\n`;
  if (ext === ".css") return `/* ${marker} */\n`;
  return `<!-- ${marker} -->\n`;
}

// A leading comment BEFORE YAML frontmatter breaks frontmatter parsing in both hosts,
// so for frontmatter files the header goes right AFTER the closing `---` line.
function frontmatterEndIndex(lines) {
  if (lines[0] !== "---") return -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") return i;
  }
  return -1;
}

function stripGeneratedHeader(content) {
  const normalized = normalizeLf(content);
  const lines = normalized.split("\n");
  if (lines[0]?.includes(GENERATED_PREFIX)) {
    return lines.slice(1).join("\n");
  }
  if (lines[0]?.startsWith("#!") && lines[1]?.includes(GENERATED_PREFIX)) {
    return [lines[0], ...lines.slice(2)].join("\n");
  }
  const fmEnd = frontmatterEndIndex(lines);
  if (fmEnd !== -1 && lines[fmEnd + 1]?.includes(GENERATED_PREFIX)) {
    return [...lines.slice(0, fmEnd + 1), ...lines.slice(fmEnd + 2)].join("\n");
  }
  return normalized;
}

function withGeneratedHeader(sourcePath, targetPath, body) {
  const header = generatedHeader(sourcePath, targetPath);
  const normalized = ensureTrailingLf(body);
  const lines = normalized.split("\n");
  const fmEnd = frontmatterEndIndex(lines);
  if (fmEnd !== -1) {
    return ensureTrailingLf([...lines.slice(0, fmEnd + 1), header.trimEnd(), ...lines.slice(fmEnd + 1)].join("\n"));
  }
  // a shebang must stay on line 1 or the script loses its interpreter line
  if (lines[0].startsWith("#!")) {
    return ensureTrailingLf([lines[0], header.trimEnd(), ...lines.slice(1)].join("\n"));
  }
  return ensureTrailingLf(`${header}${normalized}`);
}

function parseFrontmatter(content, sourcePath) {
  const normalized = normalizeLf(content);
  if (!normalized.startsWith("---\n")) {
    return { attrs: {}, body: normalized, hasFrontmatter: false };
  }
  const end = normalized.indexOf("\n---\n", 4);
  if (end < 0) {
    fail(`${sourcePath}: frontmatter opened but not closed`);
  }
  const raw = normalized.slice(4, end);
  const body = normalized.slice(end + 5);
  const attrs = {};
  const lines = raw.split("\n");
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.trim()) {
      continue;
    }
    const match = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (!match) {
      fail(`${sourcePath}: unsupported frontmatter line: ${line}`);
    }
    const key = match[1];
    const value = match[2] ?? "";
    if (value === ">") {
      const parts = [];
      i += 1;
      while (i < lines.length && /^(?:\s|$)/.test(lines[i])) {
        parts.push(lines[i].replace(/^\s{2}/, ""));
        i += 1;
      }
      i -= 1;
      attrs[key] = foldBlockScalar(parts);
    } else {
      attrs[key] = value;
    }
  }
  return { attrs, body, hasFrontmatter: true };
}

function foldBlockScalar(lines) {
  const paragraphs = [];
  let current = [];
  for (const line of lines) {
    if (line.trim() === "") {
      if (current.length) {
        paragraphs.push(current.join(" "));
        current = [];
      }
      paragraphs.push("");
    } else {
      current.push(line.trim());
    }
  }
  if (current.length) {
    paragraphs.push(current.join(" "));
  }
  return paragraphs.join("\n").trim();
}

function emitFrontmatter(attrs) {
  if (!attrs.description) {
    fail("frontmatter is missing description");
  }
  return `---\nname: ${attrs.name}\ndescription: ${attrs.description}\n---\n`;
}

function commandNameFromPath(sourcePath) {
  return `spec-${path.basename(sourcePath, ".md")}`;
}

function codexSkillName(sourcePath) {
  return sourcePath === "core/skill.md" ? "spec-core" : commandNameFromPath(sourcePath);
}

function transformSigils(text) {
  return text.replace(/(^|[^\w$])\/spec:([a-z][a-z-]*)\b/g, (_m, prefix, name) => `${prefix}$spec-${name}`);
}

// The rule pack has no fixed path on Codex: plugin installs live under a VERSIONED cache dir
// (~/.codex/plugins/cache/<mkt>/<plugin>/<ver>/skills/spec-core/rules/), script installs under
// ~/.agents/skills/spec-core/rules/ — so the text instructs the model to locate sgconfig.yml
// across both roots first (sort puts the plugin cache last → newest plugin install wins).
// A hardcoded single path here already failed once: a live verifier probed the wrong root and
// declared ast-grep not-run while the rule pack sat installed in the other.
const AST_GREP_FRAGMENT_CLAUDE =
  "`ast-grep scan --config ${CLAUDE_PLUGIN_ROOT}/rules/sgconfig.yml <changed files>`";
const AST_GREP_FRAGMENT_CODEX =
  "`ast-grep scan --config <sdd-rules>/sgconfig.yml <changed files>` — resolve `<sdd-rules>` first " +
  "(the installed sdd `spec-core/rules` directory; location depends on install method): " +
  "`find ~/.codex/plugins/cache ~/.agents/skills -path '*spec-core/rules/sgconfig.yml' 2>/dev/null | sort | tail -1` " +
  "(pwsh: `Get-ChildItem ~/.codex/plugins/cache, ~/.agents/skills -Recurse -Filter sgconfig.yml -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName`)";

function transformRulePaths(text) {
  const out = text.replaceAll(AST_GREP_FRAGMENT_CLAUDE, AST_GREP_FRAGMENT_CODEX);
  if (out.includes("${CLAUDE_PLUGIN_ROOT}/rules/")) {
    throw new Error(
      "unhandled ${CLAUDE_PLUGIN_ROOT}/rules/ reference — extend AST_GREP_FRAGMENT mapping in generate.mjs"
    );
  }
  // the views dir has no fixed path on Codex either (versioned plugin cache vs script install):
  // core prose keeps the Claude path inside a host:claude block and gives Codex its own locate step
  if (out.includes("${CLAUDE_PLUGIN_ROOT}/skills/core/views/")) {
    throw new Error(
      "unhandled ${CLAUDE_PLUGIN_ROOT}/skills/core/views/ reference in the Codex tree — wrap it in a host:claude block with a host:codex locate step"
    );
  }
  return out;
}

function transformSkillPaths(text) {
  return transformRulePaths(
    text
      .replaceAll("${CLAUDE_PLUGIN_ROOT}/skills/core/references/", "../spec-core/references/")
      .replaceAll("../skills/core/references/", "../spec-core/references/")
      .replaceAll("skills/core/references/", "../spec-core/references/")
      .replaceAll("skills/core/SKILL.md", "../spec-core/SKILL.md")
  );
}

function transformAgentPaths(text) {
  return transformRulePaths(
    text
      .replaceAll(
        "`${CLAUDE_PLUGIN_ROOT}/skills/core/references/code-charter.md`",
        "Read `code-charter.md` under the sdd spec-core skill's references directory (sibling of the skill that dispatched you)"
      )
      .replaceAll(
        "All paths are relative to `${CLAUDE_PLUGIN_ROOT}/skills/core/references/`.",
        "All reference files are under the sdd spec-core skill's references directory (sibling of the skill that dispatched you)."
      )
  );
}

function transformCodexMarkdown(text, context) {
  const withSigils = transformSigils(text);
  return context === "agent" ? transformAgentPaths(withSigils) : transformSkillPaths(withSigils);
}

// views ship as runtime assets (templates, scripts, inlined libraries), not prompts: only host
// selection and the command sigil apply, and third-party vendor files are copied untouched
function emitView(sourcePath, host, targetPath) {
  const raw = readText(sourcePath);
  if (sourcePath.startsWith("core/views/vendor/")) {
    return withGeneratedHeader(sourcePath, targetPath, raw);
  }
  const selected = selectHost(raw, host, sourcePath);
  const body = host === "codex" ? transformRulePaths(transformSigils(selected)) : selected;
  return withGeneratedHeader(sourcePath, targetPath, body);
}

function emitClaudeMarkdown(sourcePath) {
  const selected = selectHost(readText(sourcePath), "claude", sourcePath);
  return withGeneratedHeader(sourcePath, claudeTargetFor(sourcePath), selected);
}

function emitCodexSkill(sourcePath, targetPath) {
  const selected = selectHost(readText(sourcePath), "codex", sourcePath);
  const parsed = parseFrontmatter(selected, sourcePath);
  if (!parsed.hasFrontmatter) {
    const body = transformCodexMarkdown(selected, "skill");
    return withGeneratedHeader(sourcePath, targetPath, body);
  }
  const attrs = {
    name: codexSkillName(sourcePath),
    description: transformCodexMarkdown(parsed.attrs.description ?? "", "skill"),
  };
  const body = transformCodexMarkdown(parsed.body, "skill");
  return withGeneratedHeader(sourcePath, targetPath, `${emitFrontmatter(attrs)}${body}`);
}

function emitCodexReference(sourcePath, targetPath) {
  const selected = selectHost(readText(sourcePath), "codex", sourcePath);
  return withGeneratedHeader(sourcePath, targetPath, transformCodexMarkdown(selected, "skill"));
}

function emitCodexRule(sourcePath, targetPath) {
  const selected = selectHost(readText(sourcePath), "codex", sourcePath);
  return withGeneratedHeader(sourcePath, targetPath, transformCodexMarkdown(selected, "skill"));
}

function tomlString(value) {
  return JSON.stringify(value);
}

function emitCodexAgent(sourcePath, targetPath) {
  const selected = selectHost(readText(sourcePath), "codex", sourcePath);
  const parsed = parseFrontmatter(selected, sourcePath);
  if (!parsed.hasFrontmatter) {
    fail(`${sourcePath}: agent source requires frontmatter`);
  }
  const body = transformCodexMarkdown(parsed.body, "agent").replace(/^\n/, "");
  if (body.includes("'''")) {
    fail(`${sourcePath}: agent body contains TOML triple-single-quote delimiter`);
  }
  const name = parsed.attrs.name ?? path.basename(sourcePath, ".md");
  const description = transformCodexMarkdown(parsed.attrs.description ?? "", "agent");
  const toml = [
    `name = ${tomlString(name)}`,
    `description = ${tomlString(description)}`,
    "developer_instructions = '''",
    ensureTrailingLf(body).replace(/\n$/, ""),
    "'''",
    "",
  ].join("\n");
  return withGeneratedHeader(sourcePath, targetPath, toml);
}

function claudeTargetFor(sourcePath) {
  if (sourcePath.startsWith("core/commands/")) {
    return `commands/${path.basename(sourcePath)}`;
  }
  if (sourcePath === "core/skill.md") {
    return "skills/core/SKILL.md";
  }
  if (sourcePath.startsWith("core/references/")) {
    return sourcePath.replace(/^core\/references\//, "skills/core/references/");
  }
  if (sourcePath.startsWith("core/rules/")) {
    return sourcePath.replace(/^core\/rules\//, "rules/");
  }
  if (sourcePath.startsWith("core/agents/")) {
    return `agents/${path.basename(sourcePath)}`;
  }
  if (sourcePath.startsWith("core/views/")) {
    return sourcePath.replace(/^core\/views\//, "skills/core/views/");
  }
  fail(`no Claude target for ${sourcePath}`);
}

function codexTargetFor(sourcePath) {
  if (sourcePath.startsWith("core/commands/")) {
    const name = path.basename(sourcePath, ".md");
    return `codex/skills/spec-${name}/SKILL.md`;
  }
  if (sourcePath === "core/skill.md") {
    return "codex/skills/spec-core/SKILL.md";
  }
  if (sourcePath.startsWith("core/references/")) {
    return sourcePath.replace(/^core\/references\//, "codex/skills/spec-core/references/");
  }
  if (sourcePath.startsWith("core/rules/")) {
    return sourcePath.replace(/^core\/rules\//, "codex/skills/spec-core/rules/");
  }
  if (sourcePath.startsWith("core/agents/")) {
    return `codex/agents/${path.basename(sourcePath, ".md")}.toml`;
  }
  if (sourcePath.startsWith("core/views/")) {
    return sourcePath.replace(/^core\/views\//, "codex/skills/spec-core/views/");
  }
  fail(`no Codex target for ${sourcePath}`);
}

function buildPlan() {
  const sources = [
    ...listFiles("core/commands").filter((file) => file.endsWith(".md")),
    "core/skill.md",
    ...listFiles("core/references"),
    ...listFiles("core/rules"),
    ...listFiles("core/agents").filter((file) => file.endsWith(".md")),
    ...listFiles("core/views"),
  ];
  // fail-loud: a missing source is a broken core tree, never a file to silently skip
  const missing = sources.filter((file) => !fs.existsSync(path.join(ROOT, file)));
  if (missing.length > 0) {
    fail(`missing core source file(s): ${missing.join(", ")}`);
  }
  sources.sort((a, b) => a.localeCompare(b));

  const outputs = [];
  for (const sourcePath of sources) {
    if (sourcePath.startsWith("core/views/")) {
      for (const host of ["claude", "codex"]) {
        const targetPath = host === "claude" ? claudeTargetFor(sourcePath) : codexTargetFor(sourcePath);
        outputs.push({ host, sourcePath, targetPath, content: emitView(sourcePath, host, targetPath) });
      }
      continue;
    }
    const claudeTarget = claudeTargetFor(sourcePath);
    outputs.push({
      host: "claude",
      sourcePath,
      targetPath: claudeTarget,
      content: emitClaudeMarkdown(sourcePath),
    });

    const codexTarget = codexTargetFor(sourcePath);
    let content;
    if (sourcePath.startsWith("core/agents/")) {
      content = emitCodexAgent(sourcePath, codexTarget);
    } else if (sourcePath.startsWith("core/commands/") || sourcePath === "core/skill.md") {
      content = emitCodexSkill(sourcePath, codexTarget);
    } else if (sourcePath.startsWith("core/rules/")) {
      content = emitCodexRule(sourcePath, codexTarget);
    } else {
      content = emitCodexReference(sourcePath, codexTarget);
    }
    outputs.push({
      host: "codex",
      sourcePath,
      targetPath: codexTarget,
      content,
    });
  }
  return outputs.sort((a, b) => a.targetPath.localeCompare(b.targetPath));
}

function writeOutputs(baseDir, outputs) {
  for (const output of outputs) {
    writeText(baseDir, output.targetPath, output.content);
  }
}

function compareNormalized(expected, actual) {
  return stripGeneratedHeader(expected) === stripGeneratedHeader(actual);
}

function lineSummary(expected, actual) {
  const left = stripGeneratedHeader(expected).split("\n");
  const right = stripGeneratedHeader(actual).split("\n");
  const max = Math.max(left.length, right.length);
  for (let i = 0; i < max; i += 1) {
    if (left[i] !== right[i]) {
      return `first difference at line ${i + 1}; generated lines=${left.length}, working-tree lines=${right.length}`;
    }
  }
  return `generated lines=${left.length}, working-tree lines=${right.length}`;
}

function runCheck(outputs) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "sdd-generate-"));
  writeOutputs(temp, outputs);

  const drifts = [];
  for (const output of outputs) {
    const target = path.join(ROOT, output.targetPath);
    if (!fs.existsSync(target)) {
      drifts.push({ path: output.targetPath, summary: "missing from working tree" });
      continue;
    }
    const actual = normalizeLf(fs.readFileSync(target, "utf8"));
    if (!compareNormalized(output.content, actual)) {
      drifts.push({ path: output.targetPath, summary: lineSummary(output.content, actual) });
    }
  }

  if (process.env.GENERATE_KEEP_TEMP === "1") {
    console.log(`TEMP ${temp}`);
  } else {
    fs.rmSync(temp, { recursive: true, force: true });
  }

  if (drifts.length) {
    console.error(`DRIFT ${drifts.length} file(s) differ`);
    for (const drift of drifts) {
      console.error(`- ${drift.path}: ${drift.summary}`);
    }
    return 1;
  }
  const hosts = outputs.reduce((acc, output) => {
    acc[output.host] = (acc[output.host] ?? 0) + 1;
    return acc;
  }, {});
  console.log(`OK ${outputs.length} generated file(s) match (claude=${hosts.claude ?? 0}, codex=${hosts.codex ?? 0})`);
  return 0;
}

function usage() {
  console.error("usage: node tools/generate.mjs [--check]");
}

try {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== "--check")) {
    usage();
    process.exit(2);
  }
  if (!fs.existsSync(path.join(ROOT, CORE))) {
    fail("core/ does not exist; seed it before running the generator");
  }
  const outputs = buildPlan();
  if (args[0] === "--check") {
    process.exit(runCheck(outputs));
  }
  writeOutputs(ROOT, outputs);
  console.log(`WROTE ${outputs.length} generated file(s)`);
} catch (error) {
  console.error(`ERROR ${error.message}`);
  process.exit(1);
}
