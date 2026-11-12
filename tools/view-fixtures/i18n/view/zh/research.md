<!-- sdd-translation: research.md · zh · cksum 93566495 775 -->
# Research: export-csv

## Practices
- 流式 A — 边读边写行，内存占用恒定 | candidate: 大批量导出
- 流式 B — 先在内存中生成整个文件再发送 | candidate: 仅限小批量导出

## Constraints
- 导出可达 200 万行 | 内存中整体生成会耗尽内存

## Open [TBD]
- [TBD-1] 先上线哪种导出方式 | candidates: 流式（依据：Practices 流式 A） / 内存（依据：Practices 流式 B） / skip-or-minimal | select: one
  - Q: 经理导出一整年的订单时，用哪种方式生成文件？
  - 1: 内存恒定 / 代码路径更多
  - 2: 代码最简单 / 大批量导出会失败

## Decided
- [DEC-1] 列名与报表页面保持一致 | source: R-1 | rationale: 用户会把两者对照查看
