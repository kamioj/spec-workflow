<HARD-GATE>
=== Proposal ready ===
Path: spec/changes/verify-adhoc-diff/proposal.md
 + tasks.md — trigger: >5 subtasks; split: 6 tasks — 共享规则 → verifier 分支 → verify diff 模式 → ship 改为引用 → 夹具 → 文档
   disagree with the need or the split → say so now, before /spec:apply

Escalated decisions:
  E1. (DEC-6) 无 spec 验证的记录放在 spec/archive/<日期>-verify-<名字>/ | basis: 放进 spec/changes/ 会被闸门当成活跃变更，archive/ 里本来就存着带日期的 fix 批次记录 | if wrong: archive/ 里不再只有已关闭的 change；撤销 = 改记录路径，已有记录是惰性文件

Changes (panel: reuse + fidelity + compat):
  1. 不走 spec 也能验证
     Problem: 你直接让 Claude 改了代码再跑 /spec:verify，因为它要求先有 proposal，行为没有定义，弱模型只能乱来。
     After:   项目里没有活跃 change 时，自动按 diff 验证：git、svn 都认，连未跟踪的新文件也算进去；两者都没有时，就验证本会话改过的文件。
     Cost:    同时有多个 change 且没设当前指针时，会先问你一句验哪个，而不是自己猜。
  2. 从改动推出该测什么，前后端都跑
     Problem: 改了几个文件，因为不知道对应哪些测试，要么没测，要么只说一句"应该没问题"。
     After:   按改动文件找出关联的测试并真的去跑（jest/vitest 能精确选出，其他按命名约定），最后再跑一次全量兜底；没有说明意图时，明确写"只验证了能跑和没有回归，没验证做没做完"。
     Cost:    动态 import、反射调用之类的关联靠全量兜底，跑得会慢一些。
  3. 截图证据一定落盘
     Problem: 改了页面但服务没起，因为截图挂在"做完没做完"这一项下面，它被跳过时截图也就跟着消失了。
     After:   动了 UI 就单独记一行"待真机截图：页面清单"；服务在跑就直接拍，存进记录目录的 screens/。
     Cost:    服务没起时，要你之后自己补看一次。
  4. 同一条审计规则只写一处
     Problem: "谁来审"的规则如果在 ship 和 verify 各写一份，因为两份各改各的，第一天就会出现分歧。
     After:   规则写进 skill.md 共享原则，ship 和 verify 都引用它；没有 proposal 时的审计契约由 verifier 的一个分支统一处理。
     Cost:    要改 ship.md 的一段措辞，但它的行为不变。

Decided without asking:
  - DEC-1 只有零个活跃 change 时自动进入 diff 模式；有多个时先问；可逆：只保留 --diff
  - DEC-3 意图来源依次为你的原话、提交信息、无；可逆：以后可以加一句追问
  - DEC-4 测试点按原生选择 → 命名约定 → 全量；可逆：只是文字规则
  - DEC-5 执行者沿用 ship 规则，只写一处；可逆：一行改成"总是派 verifier"
  - DEC-7 截图单独成行；DEC-8 只审计不归档，和 fix 批次重合时让给 ship
  - DEC-2 范围识别顺序 git → svn → 本会话改动，由调研定下
Unsourced additions: none — 记录位置已改为沿用现有的 spec/archive/ 命名（C-4），不再新增载体
Uncovered requirements:
  - R-3 "一起都做了吧" — 这是排期指令，由三个 change 并行推进来承接，不对应任何 What 条
Unresolved critique: none
Not in this change: hg/perforce；CI 集成；diff 模式自动提交或归档；ship 的行为
</HARD-GATE>
