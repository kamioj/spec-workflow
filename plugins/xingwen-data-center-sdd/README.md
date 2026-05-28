# Xingwen Data Center SDD Plugin

Codex/macOS 版数据中心 SDD 工作流插件。

它不复用 Claude Code 的 slash command / PowerShell hook 机制，而是通过 Codex skill + Python 校验脚本服务 Xingwen `x-data-center` 项目。

## 内容

- `skills/xingwen-data-center-sdd/SKILL.md`：数据中心阶段执行、grill、验收路线规则。
- `scripts/check_phase_sdd.py`：macOS 可直接运行的阶段 SDD 检查脚本。
- `references/review-route-template.md`：HIS -> Query 全链路 review 模板。

## 本地检查示例

```bash
python3 scripts/check_phase_sdd.py \
  --repo /Users/karasu/projects/Xgent4/x-data-center \
  --phase phase-03-ads-query-vector \
  --mode post
```
