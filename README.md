# kamioj-sdd marketplace

Personal Claude Code plugin marketplace for the SDD (Spec-driven Development) workflow.

## Plugins

| Plugin | Description |
|---|---|
| **sdd** | Spec-driven development workflow with `research → ask → propose → apply → verify → archive` lifecycle. 11 slash commands + 2 硬约束 hooks + 2 dev agents. 详见 [plugins/sdd/README.md](plugins/sdd/README.md) |

## Install

```pwsh
# Private repo requires GITHUB_TOKEN
$env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxx"

claude plugin marketplace add kamioj/sdd-plugin
claude plugin install sdd@kamioj-sdd
```

或在 claude 内：

```
/plugin marketplace add kamioj/sdd-plugin
/plugin install sdd@kamioj-sdd
```

## Update flow

1. 修改 `plugins/sdd/` 下的文件
2. `git commit` + `git push`
3. `claude plugin marketplace update kamioj-sdd` 同步 cache

或下次启动 claude 时自动 `git pull`（前提：GITHUB_TOKEN 已配置）。

## Development

开发期想跳过 marketplace 缓存直接测改动：

```pwsh
# 在 marketplace 根目录运行
claude --plugin-dir ./plugins/sdd
```

`--plugin-dir` 加载的源码副本**优先级高于** marketplace cache。

## Layout

```
.
├── .claude-plugin/
│   └── marketplace.json    # marketplace 清单
└── plugins/
    └── sdd/                # 实际 plugin
        ├── .claude-plugin/plugin.json
        ├── commands/       # 11 个 slash 命令
        ├── hooks/          # placeholder scan / HARD GATE
        ├── agents/         # frontend-dev / backend-dev
        ├── skills/sdd/     # plugin 总览
        └── references/     # 语言栈规范 + opt-in 加强 reference
```

## License

未公开发布。`plugins/sdd/references/` 含第三方语言规范文件（alibaba-java, bulletproof-react 等），各自版权归原作者。`agent-principles.md` 与 `frontend-aesthetics.md` 含 Anthropic 官方提示词原文，仅供本人在私有环境引用学习。
