# Tasks: verify-adhoc-diff

- [x] 1. skill.md § Shared Principles：独立审计的执行者规则 + 无 proposal 审计契约（只写这一处）
- [x] 2. spec-verifier.md：无 proposal 启动分支（由简报提供声明清单 + 范围）；diff 模式的截图行  deps: 1
- [x] 3. verify.md：diff 模式段（触发、git/svn/会话范围、意图锚、测试点推导、记录路径与格式、让给 ship）+ `--diff` 参数（两个宿主）+ 原有账本路径语句补 diff 模式说明  deps: 1, 2
- [x] 4. ship.md：执行者规则原文换成对 skill.md 的引用，行为不变  deps: 1
- [x] 5. 夹具：两套 run-fixtures 各加 `verify-record-only-gates-unchanged`；git / svn / 无 VCS / jest 关联选择 / UI 无应用 五个 diff 模式演练夹具  deps: 3
- [x] 6. 文档：skill.md 命令索引与产物地图、README 中英文 verify 行与产物树、CLAUDE.md、AGENTS.md、codex/README.md；regenerate + --check；两套夹具实跑（Codex 套件确认无 `WARN: pwsh not found`）  deps: 4, 5
