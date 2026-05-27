# Agent 共享精神（opt-in，默认不加载）

> ⚠️ **重要**：本文件**默认不被任何 agent 自动加载**——日常实施任务用 sdd plugin 总览 SKILL.md 的"共享精神"就够。
>
> 启用方式：用户在 `/sdd:apply` 后加 flag。
>
> | flag | 启用 |
> |---|---|
> | `solid` | § 一 反偷懒 |
> | `verify` | § 二 反幻觉 |
>
> 主对话识别 flag 后在派遣 prompt 里追加"启用 anti-laziness"或"启用 anti-hallucination"，agent 据此读对应段。
>
> **为什么是 opt-in**：这些规则在常规实施场景下会导致 agent 过度保守（拒绝合理 workaround、过度调查 Read、形式主义读文件）。仅在特定项目场景（评测压力 / 复杂代码库怕幻觉 / 一次性研究脚本要严防偷懒）才该启用。

---

## 一、反偷懒：High-Quality General Solution

官方原文（不修改）：

> Please write a high-quality, general-purpose solution using the standard tools available. Do not create helper scripts or workarounds to accomplish the task more efficiently. Implement a solution that works correctly for all valid inputs, not just the test cases. Do not hard-code values or create solutions that only work for specific test inputs. Instead, implement the actual logic that solves the problem generally.
>
> Focus on understanding the problem requirements and implementing the correct algorithm. Tests are there to verify correctness, not to define the solution. Provide a principled implementation that follows best practices and software design principles.
>
> If the task is unreasonable or infeasible, or if any of the tests are incorrect, please inform me rather than working around them. The solution should be robust, maintainable, and extendable.

### 在 sdd 上下文里的含义

- **不为通过 `/sdd:verify` 硬编码**：测试用例只是验证手段，不是实现依据。如果只对当前测试 work，换个输入就废，那是 hard-coding
- **不创建辅助脚本绕开 proposal 要求**：proposal 是"做什么"的真理。proposal 没说要写 helper script，就不写
- **proposal 的 What 没要求的事不做**：scope creep 也是一种偷懒——"顺手"加东西看似贴心，实际是让你的实施跟方案脱钩
- **任务不可行时立刻叫停**：proposal 自相矛盾 / 前提已变 / 工具不兼容到无法继续 → 走 sdd 的"任务不可行"汇报流程，不许硬凑

---

## 二、反幻觉：Investigate Before Answering

官方原文（不修改）：

> Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer - give grounded and hallucination-free answers.

### 在 sdd 上下文里的含义

- **写代码前必 Read 涉及文件**：proposal `## What` 提到要改的每个文件，动手前必须 Read 一遍——禁止凭训练印象写
- **必 Grep 调用链**：要修改的函数 / 接口 / 配置项，必须 Grep 看谁调用、被怎么用，再下笔
- **引用 reference 前确认存在**：写"按 alibaba-java.md 的 §X 规则"这种语句前，必须先 Read 那个 reference
- **不确定的事直接说"不确定"**：写"应该是 / 一般是 / 我记得"包装猜测——这是幻觉的 tell。改用"我没读到 / 没查到，需要先 Grep"
- **判据自检**：你的回答里出现具体文件路径、函数名、配置项、版本号时，问自己"这是我刚 Read 到的，还是凭印象写的？"——凭印象 = 幻觉，必须先查

---

## 三、协同精神（继承 sdd plugin 共享精神）

来自 `skills/sdd/SKILL.md` 的反作弊原则，所有 agent 同样遵守：

1. **不伪造结果**：未实际跑通的命令 / 测试 / PoC**不许汇报为"成功"**。拿不到结果就明说"未跑通"+ 已试切入点，不许编 stdout / 不许裁失败行
2. **不把绕过当解决**：mock 假响应、改 assert、patch 检查函数返回 true、跳过失败测试——这些**必须明说**"绕过，真因未解"，**禁止伪装为"已修复"**
3. **硬编码必标注**：偏移量 / 固定 hash / 一次性参数，在**代码注释 + tasks.md** 同时标"仅适用本场景"——一处标注 = 半个标注

---

## 三层精神的关系

```
反偷懒 ─┐
        ├─→ 都在打击「为了快速完成而妥协实现质量」
反幻觉 ─┘
              │
              ↓
   sdd 协同精神 ─→ 把这种"妥协"具象化为可识别的反模式
```

**违反任一层 = 这次 agent 派遣失败**，需要主对话重新派单或自理。

---

## 派遣 agent 时的最小义务

接到任务的开发 agent **必须**先做这三步：

1. Read 本文件
2. Read `spec/changes/<name>/proposal.md` 的 `## What` 段（明确做什么）
3. Read `spec/changes/<name>/design.md` 的 `## Interfaces` 段（若存在）

未完成上述三步即开始 Write/Edit 项目源码 = 违反"反幻觉"。
