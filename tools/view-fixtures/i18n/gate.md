<HARD-GATE>
=== 提案就绪 ===
Path: spec/changes/export-csv/proposal.md

Changes — 给决策者的解释层。

  1. 导出改为流式
     Problem: 经理导出整年订单时，因为整个文件在内存中生成，导出会失败。
     After:   同样的导出改为边读边写，所以不再耗尽内存。
     Cost:    多一条代码路径

Decided without asking: none
</HARD-GATE>
