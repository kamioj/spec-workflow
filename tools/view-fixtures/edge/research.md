# Research: 边界用例 edge

## Practices
- 方案 A — 内联 `</script>` 和 </SCRIPT> 以及 <!-- 注释 --> 都不能截断页面 | 理由: 转义可逆
- 方案 B — <script>alert(1)</script> 应被净化; &amp; 与 &lt; 字面量保持原样 | 理由: DOMPurify
- Mixed: </ScRiPt > and <!--[if IE]> and a lone < and & | why: case-insensitive closers

## Open [TBD]
- [TBD-1] 选哪一个 | candidates: 方案 A (evidence: Practices 方案 A) / 方案 B / skip-or-minimal | select: one
  - Q: 用户在页面上看到 </script> 时会发生什么？
  - 1: 安全 / 需要转义

## Decided
- [DEC-1] 数据块用转义而不是 base64 | source: Practices | rationale: 中文 atob 会抛错

Last line without newline: </script>