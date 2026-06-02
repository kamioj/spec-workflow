# 工作流重设计:三域 + 契约指纹 + 动作级边界

> 状态:草案(`workflow-redesign` 分支)· 单一真相源 · 先纸面钉死,再碰实现
> 定位:把当前"11 个松散命令 + 2 个 UserPromptSubmit hook"重构为「**域内流体、域间硬卡**」的三域状态机,边界靠**动作级 hook + 契约指纹**强制,而非命令名匹配。

---

## 1. 为什么要改(现状的病)

当前边界靠两个挂在 `UserPromptSubmit` 的 hook(`check-tbd.ps1` / `check-gate.ps1`),按**用户输入字符串里有没有命令名**决定是否拦截。实测下来有四个洞:

1. **只覆盖两处转移**:propose 前查 [TBD]、apply 前查 APPROVED。verify / archive 完全不挡——可以对着空气做"三维验证",可以随时归档。
2. **一把梭整体绕过**:`/spec:workflow` 一把梭时用户只提交一次 `/spec:workflow`,research→propose→apply 全在**同一回合内**完成,中间**没有第二次 UserPromptSubmit**——两个 hook 一个都不触发。**硬约束在干活最多的模式下退化成纯软约束。**
3. **边界强度随模式漂移**:手动逐命令时硬,一把梭时软。同一套规则两种强度。
4. **APPROVED 是静态时间戳,永不失效**:批准后 proposal/design 被改、或 research 改了决策却没重审,代码照写,契约名存实亡。

根因:**编排(执行顺序)、工作(具体做什么)、enforcement(HARD GATE)三件事全糊在 markdown 软 prompt 里,没有分层,模型能偏。** "没明确边界" = 没分层。

---

## 2. 设计灵感与先例

### Claude Code Workflow 引擎(实证逆向)
引擎把三件事用"各自住在哪"物理分开:
- **计划层** = `meta`(纯字面量、静态可审)——纯数据
- **编排层** = JS 脚本控制流(确定性代码,模型碰不到)——决定谁何时跑、卡哪
- **工作层** = 各 subagent(模型驱动、`isSidechain` 独立上下文,无权自己跳 phase)

状态管理 = append-only `journal.jsonl`(真相,内容寻址 `key=v2:SHA256(prompt,opts)`,resume 时重放命中即跳过)+ 物化 `wf_*.json`(展示快照)。协同 = 一个 `agentId` 串起 journal/transcript/快照;phase 是纯元数据;隔离物理化(每 agent 独立 context)。

**可迁移主轴**:三层分离 + 阶段间用契约交接 + agent 边界 = context 边界。
**不可照搬**:引擎单回合、内存传值;我们跨多回合、用户当编排者、靠磁盘产物传递 → 我们的"编排层"不能是运行中的程序,只能是**无状态、每次从磁盘重推状态的 gate**(这恰好就是 hook 的形态)。

### 行业先例(我们在重造的轮子)
调研结论:**AI-dev 工具里没找到做齐"冻结契约 + 指纹自动失效 + 校验失败结构化回流"三环的**(Kiro/spec-kit/Conductor 是线性三件套+确认点;OpenSpec 故意无刚性 gate;superpowers 的 HARD GATE 靠 prompt;**Tessl 最接近但把"spec 变更让代码自动失效"列为未解开放问题**)。但底层子机制都成熟:

| 机制 | 范式 | 抄哪点 |
|---|---|---|
| 指纹绑定输入→产物、可封存 | **SLSA / in-toto attestation** | `subject.digest` + `resolvedDependencies` 结构(砍掉签名 PKI) |
| 输入变了产物失效 | Bazel / Nix(传递失效) | 概念参考;我们用**人分诊**代替机器自动失效 |
| 计划 hash + gate 绑定 | Terraform plan/apply | apply 前校验 hash 一致 |
| 策略即代码 | OPA / Conftest | gate 逻辑外化成声明文件,hook 当解释器 |
| 不可变决策记录 | ADR `Superseded-By` | 已批准契约不可原地改;**但用 git 实现,不堆 vN 文件** |
| 完整性 hash | npm lockfile `integrity` | `sha256-<hash>` 格式惯例 |

**关键认知**:Tessl 都没敢碰的"机器自动失效"是研究前沿;我们的设计**用人分诊回流绕开它**——这是日常开发流程,不难。我们站在 in-toto/git/OPA 的肩膀上,只是组合方式在 AI-dev 领域是新的。

---

## 3. 核心模型:三域(对应真实研发角色)

| 域 | 角色 | 职责 / 产物 | 域内特性 |
|---|---|---|---|
| **决策域** | 产品 | 需求 → 分析 → research / proposal / design / 计划表(tasks)/ 测试清单 | **可逆**:随便调研/拷问/改/换方向/捞废稿 |
| **实施域** | 开发 | 领计划表任务,写代码 | 接一份**冻结且过审**的契约 |
| **校验域** | 测试 | 拿代码 × 契约 × 测试清单 对齐审核,产出质量报告 | **独立上下文**,不看开发内心戏 |

**边界原则**:**域内流体,域间硬卡。** 灵活不是被砍掉,而是**收进决策域**——这保住了"比 superpowers 灵活"的差异化,只在三个域交界加硬边界。

### 转移图
```
决策域 ──(approval: 冻结契约 + 铸指纹)──► 实施域 ──(写完)──► 校验域
  ▲                                                              │
  │                                                    ┌─────────┴─────────┐
  │                                                  通过               不通过
  │                                                    │                   │
  │                                              产 PASS 裁决          产质量报告(复现+问题点)
  │                                                    │                   │
  │                                              gate 住归档          【分诊】需求? bug?
  │                                              (你手动扣扳机)         │           │
  └──────────────(需求原因: re-spec, 重铸指纹)──────────┘           bug 原因
                                                                        │
                                                  实施域(快道,指纹不变)◄┘
```

---

## 4. 契约指纹(provenance attestation)

### 是什么 / 何时铸
- **在 approval 那一刻铸**(决策→实施交界),覆盖**冻结的契约包**:proposal + design + tasks + 测试清单。
- **不含 research**(research 是上游脚手架,自己说过它不直接进实施环;research 变了要改契约文档,改了自然换指纹)。
- **不在 proposal 出生时铸**(决策域可逆,提案还在改时没有稳定指纹)。指纹是封印,不是出生证。

### 格式(抄 SLSA/in-toto,砍 PKI)
```
subject:
  - { name: "proposal.md", digest: { sha256: <hash> } }
  - { name: "design.md",   digest: { sha256: <hash> } }
  - { name: "tasks.md",    digest: { sha256: <hash> } }
  - { name: "test-checklist.md", digest: { sha256: <hash> } }
predicate:
  approvedBy: <user>
  approvedAt: <ISO8601>
  resolvedDependencies: [ <上游输入,可选> ]
```
- **不引 Sigstore/DSSE 签名**——单机个人插件不需要 PKI,抄结构、丢加密。
- **已定:按文件各自 digest**(每份契约文件一个 sha256,SLSA subject 本就是 list;漂移时能定位是哪份变了、支持精确失效)。

### 双职 + 防漂移
- 职一:**身份**(这一版冻结契约)。
- 职二:**防漂移封条**——`PreToolUse` 写源码时现算当前契约 hash,`≠ fp` 就拦。干掉"批准后偷改 proposal 再写代码"。

### 不可变性靠 git(否决堆 vN 文件)
- 已 APPROVED 的契约不可原地无痕改;但**不造 proposal-v2.md**——git 历史天生不可变、天生成链。
- **supersession 链 = 历次指纹序列**(写进 APPROVED 标记,git diff 可还原)。看旧契约 `git show`。

### 归档时"回收"
- archive 时把最终指纹封进归档记录当审计凭证("此 change 在 fp:X 下实施、校验通过"),然后失活。

---

## 5. 两条回流 + 分诊(校验失败时)

测试挂了不是只有一条"回决策"的路,按**失败性质**分两条:

| 失败性质 | 谁判 | 回到哪 | 指纹 | 要重审? |
|---|---|---|---|---|
| **bug(开发原因)** | 分诊 | **实施域(快道)** | **不变** | 不用,直接修代码 |
| **需求原因** | 分诊 | **决策域(re-spec)** | **重铸** | 要,重过 gate |

### 指纹 = 分诊的客观判据,且让分诊作弊不了
- bug 的定义 = 契约没错、只是代码错 → 修代码**不该动 proposal/design**。
- 需求错 = 契约错 → **必须动契约**。
- 所以"是 bug 还是需求"在"动没动契约"上**客观可测**:有人把需求缺陷标成 bug 想走快道偷偷改,**一改契约,PreToolUse 门就拦**:"你在动契约,这是需求变更,回决策域重审、重铸指纹"。
- **标签可以撒谎,'动没动契约'骗不了门。** 比纯人肉组织流程还强一点——现实团队的误分诊是隐形的,这里当场被挡。

### 约束
- **bug 快道绝不触发重审**(指纹没变,没必要)——否则修个 typo 还走一遍审批,没人受得了。

---

## 6. Enforcement:从 UserPromptSubmit 迁到 PreToolUse(核心架构变更)

把硬约束从"拦命令名"(`UserPromptSubmit`,模式相关、可被一把梭绕过)搬到"**拦动作**"(`PreToolUse`,模式无关、谁都绕不过)。

| 交界 | 怎么强制 | 强度 |
|---|---|---|
| 决策→实施 | **PreToolUse** 拦"写 `spec/` 外源码"动作:要 APPROVED + 当前契约 hash == fp | **硬** |
| 实施→校验 | 软(校验是读+审,代价低) | 软 |
| 校验→归档 | archive 被 **PASS 裁决产物** gate(但**你手动扣扳机**,不自动归档) | **硬** |
| 实施/校验→决策(回流) | 写「缺陷/失败」文档即合法转移 | 软+留痕 |

- PreToolUse 门必须 **scope 在"有活跃 change 时才生效"**,否则污染日常写代码。
- 它**只拦写 `spec/` 之外的源码**;写 spec 产物(research/proposal 等)不拦。
- 这一条同时干掉"一把梭绕过"和"批准后偷改"两个洞——因为它拦的是写代码动作,不是命令名。
- 归档不自动触发:延续既有"verify 只验证不越权推归档"(commit 3904a99)和"不主动 push archive"的决定。

---

## 7. 上下文隔离 + 模型选择(每域可配,安全默认)

**原则**:agent 边界 = context 边界(引擎同款)。隔离逼着跨域沟通只能走磁盘契约 → **契约+指纹是隔离模型下唯一的通信信道**,且指纹保证测试方测的正是开发方冻结的那一版。

| 域 | 隔离 | 默认模型 | 输入边界 |
|---|---|---|---|
| 决策域 | 跟主对话共享(协作型) | 主模型 | 你的需求 + research/废稿 |
| 实施域 | 独立子代理(已有 fe/be-dev) | 可选(默认 inherit) | 冻结契约@fp + 代码库 |
| **校验域** | **默认强制独立 + 异构** | **默认换一个模型** | **只给 契约@fp + git diff + 现读代码——禁喂实施对话** |

- 校验域是隔离最值钱的地方(干掉"自己批自己作业");`--codex` 异构他审就是它的现成特例,这里把它**升格成全局原则**。
- **隔离的真正开关是"喂什么",不是"换不换对话"**:测试方 brief 只准含产物(契约+diff+现读代码),**绝不含实施推理过程**,否则开发的虚假信心泄进来,异构白做。

### 共享/独立是用户的选择权,但默认安全 + 必须如实记录
- **选择权交给用户**:`isolation: shared | subagent` 每域可配,per-run 可用 flag 覆盖(如 `/verify --shared`)。
- **默认走安全档**(校验 = subagent + 异构);弱档要**显式主动选**,用户自己担。
- **裁决产物必须如实记录实际用了哪档**——**不许共享档(自审)冒充独立验证**(延续 SKILL.md `反作弊`:弱验证必须明说,不许伪装成强验证)。

---

## 8. 计划层:声明式单一真相源(hook 当解释器)

把"三域 + 转移条件 + 指纹规则 + 隔离/模型默认"写成**一份声明式数据文件**,hook 去读它判断,而非把逻辑焊死在 pwsh 里。

- **好处**:规则可版本化、可测试;**移植 Codex 只需换一个薄 bash 解释器,规则文件不变**(直接服务可移植性目标)。
- check-gate.ps1 本质是条 Rego policy → 外化成声明文件后,pwsh hook 和未来 bash hook 都只是它的执行器。
- **格式已定:JSON**(pwsh `ConvertFrom-Json` 原生解析、现有 hook 已用;jq / python / node 通用 → 利于 Codex 移植)。

---

## 9. 产物与字段

### 契约包(决策域产出,approval 冻结)
`proposal.md` + `design.md` + `tasks.md`(计划表)+ `test-checklist.md`(测试清单 = 验收标准,在决策域作者化)。
- **测试清单格式已定**:带稳定 ID 的可勾 markdown 清单——每点 `[ ] T-N: <验收条件>`,校验逐点引用 `T-N` 回填 pass/fail。

### 裁决 / 质量报告(校验域产出)
**落点已定**:逐点明细写独立 `verdict.md`;proposal 末尾留一行 `<!-- VERIFIED: <时间> fp:<hash> verdict:pass -->` 当 archive 的 gate 锚点。

| 字段 | 例 | 作用 |
|---|---|---|
| `isolation` | `subagent` / `shared` | 这次是独立还是自审 |
| `model` | `claude-opus` / `codex` / … | 谁审的(异构与否一目了然) |
| `verdict` | `pass` / `fail` | 结论(`pass` gate 住归档) |
| `fp` | `sha256:…` | 对着哪版契约审的 |
| 逐点状态 | `point-N: pass/fail` | 每个测试点 |
| 失败明细 | 复现步骤 + 问题点 + **分诊结论(需求/bug + 谁判的)** | 回流输入 + 责任链留痕 |

---

## 10. 不做什么(范围纪律 / 否决记录)

- ❌ **机器自动失效/自动重生成代码**(Tessl 都 punt 的研究前沿)→ 用**人分诊**回流代替。
- ❌ **内容寻址 resume 缓存(SHA256 key 跳过重算)**→ 磁盘产物本身就是 checkpoint,没有昂贵重算要省。
- ❌ **manifest sidecar(`.sdd-state.json`)**→ 状态从磁盘产物直接推,sidecar 只会漂移。
- ❌ **proposal-v2.md 版本文件**→ 不可变性靠 git。
- ❌ **Sigstore/DSSE 签名 PKI**→ 单机插件过度。
- ❌ **一上来就建全套三硬门 + 失效环**→ 见分期。

---

## 11. 分期落地(80/20)

最高杠杆是**决策→实施那一个门**(它吃掉绝大部分价值)。建议:

**v1(最小可用)** ✅ 已落地（commit aa23ca8）
1. 计划层声明文件 `config/workflow-model.json`
2. 契约指纹 `scripts/contract-lib.ps1`（per-file sha256，剔除标记+规一化）+ `mint-fingerprint.ps1`
3. **PreToolUse 门** `hooks/check-source-gate.ps1`：写源码要 APPROVED + 当前契约 hash == fp
→ 已干掉:一把梭绕过、批准后偷改、上游漂移不失效。fixture 6/6。

**v2(补完状态机)** ✅ 已落地（commit 2e3e4d6）
4. 裁决产物 `verdict.md` + `scripts/stamp-verdict.ps1`（VERIFIED 标记）+ archive 门 `hooks/check-archive-gate.ps1`（PASS + fp 匹配，`--abandon` 豁免）
5. 两条回流（bug 快道指纹不变 / 需求重审重铸）+ `test-checklist.md` 验收契约 + 分诊留痕；PreToolUse 门防误分诊。fixture 5/5。

**v3(隔离/模型)** ⬜ 待做
6. 每域 `isolation`（shared/subagent）/ `model`（inherit/指定/异构）可配 + 安全默认（校验=subagent+异构）+ 回写 verdict
7. hook 外化成 `config/workflow-model.json` 的解释器（Codex 可移植性：换薄 bash 解释器，规则不变）

---

## 12. 已定决策(ask 敲定)

| # | 决策点 | 定论 | 谁定 |
|---|---|---|---|
| 1 | 指纹粒度 | **按文件各自 digest**(每份契约一个 sha256,能定位漂移源,SLSA subject 本就是 list) | 用户 |
| 2 | 裁决落点 | **独立 `verdict.md` 存明细 + proposal 末尾 `VERIFIED` 标记当 gate 锚** | 用户 |
| 3 | 测试清单格式 | **带稳定 ID 的可勾 markdown 清单**(`[ ] T-N: <验收条件>`,逐点回填) | 用户 |
| 4 | PreToolUse 源码判别 | **路径前缀**:`spec/` 内算契约产物放行,`spec/` 外算源码受门管;边角后续细化 | Claude(技术现状) |
| 5 | 声明文件格式 | **JSON**(pwsh ConvertFrom-Json 原生 + jq/python/node 通用,利于 Codex 移植) | 用户 |

实现期再展开的细节(非阻塞):`verdict.md` / 声明文件 / 测试清单的**具体字段 schema**,留到各自实现时定。

**JSON 维护取舍(确认保留)**:声明文件保持 JSON——它是唯一零依赖、pwsh `ConvertFrom-Json` 原生 + jq/python/node 都能解析的格式,正服务 Codex 可移植目标(YAML/TOML/.psd1 要么引解析依赖、要么绑死单语言)。无注释的软肋用 `_comment` 字段解决(JSON 通行变通,不是 smell);详尽的"为什么"住本 doc,不塞进 JSON。换格式只动 `Read-WorkflowModel` 一处,故不锁死。曾考虑的 `$doc` 指针得不偿失(把解释删了换来指向 doc 的弱指针),否决。

---

## 参考
- [SLSA attestation model](https://slsa.dev/spec/v1.0/attestation-model) · [Build Provenance](https://slsa.dev/spec/draft/build-provenance) · [in-toto + SLSA](https://slsa.dev/blog/2023/05/in-toto-and-slsa)
- [Bazel Skyframe](https://bazel.build/versions/7.0.0/reference/skyframe) · [Nix content-addressed derivation](https://nix.dev/manual/nix/2.34/store/derivation/)
- [Terraform drift detection](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)
- [OPA CI/CD](https://www.openpolicyagent.org/docs/cicd) · [Conftest](https://www.conftest.dev/)
- [npm lockfile integrity](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/)
- [ADR process (AWS)](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html) · [Martin Fowler — ADR](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html)
- [Martin Fowler — SDD 3 tools (Kiro/spec-kit/Tessl)](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) · [Tessl SDD docs](https://docs.tessl.io/use/spec-driven-development-with-tessl)
