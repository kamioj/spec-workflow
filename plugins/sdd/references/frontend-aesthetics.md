# 前端反 AI slop 原则（opt-in，默认不加载）

> ⚠️ **重要**：本文件**默认不被 sdd-frontend-dev 自动加载**——日常前端实施大头是工具型 UI / 后台 / 调试页，反 slop 反而违和。
>
> 启用方式：用户在 `/sdd:apply` 后加 `design` flag。
>
> ```
> /sdd:apply design          # 仅启用反 AI slop
> /sdd:apply design verify  # 同时启用反幻觉
> ```
>
> 主对话识别到 `design` flag 后在派遣 prompt 里追加"启用 anti-ai-slop"，sdd-frontend-dev 据此读本文件。
>
> **为什么是 opt-in**：你日常项目（公司同步工具 / 内部仪表盘 / 调试面板）属于"工作驱动"——可读性、一致性、可预测性压倒"独特"。强制反 slop 会让 agent 在不该折腾的地方折腾。

---

## 官方原文（不修改）

> You tend to converge toward generic, "on distribution" outputs. In frontend design, this creates what users call the "AI slop" aesthetic. Avoid this: make creative, distinctive frontends that surprise and delight.
>
> Focus on:
> - **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics.
> - **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes. Draw from IDE themes and cultural aesthetics for inspiration.
> - **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions.
> - **Backgrounds**: Create atmosphere and depth rather than defaulting to solid colors. Layer CSS gradients, use geometric patterns, or add contextual effects that match the overall aesthetic.
>
> Avoid generic AI-generated aesthetics:
> - Overused font families (Inter, Roboto, Arial, system fonts)
> - Clichéd color schemes (particularly purple gradients on white backgrounds)
> - Predictable layouts and component patterns
> - Cookie-cutter design that lacks context-specific character
>
> Interpret creatively and make unexpected choices that feel genuinely designed for the context. Vary between light and dark themes, different fonts, different aesthetics. You still tend to converge on common choices (Space Grotesk, for example) across generations. Avoid this: it is critical that you think outside the box!

---

## 在 sdd 上下文里的含义

### 1. 类型分流——不是所有前端都要反 slop

| UI 类型 | 反 slop 强度 |
|---|---|
| 营销页 / Landing page / 作品集 | 🔴 全力反 slop——独特字体、深色主题、几何背景、动画 |
| 用户端产品（App / 消费类 Web） | 🟡 适度——主色调要有性格但可读性优先 |
| **企业内部工具 / 后台仪表盘 / 配置面板** | 🟢 **反 slop 退场**——可读性、一致性、可预测性压倒"独特" |
| 调试面板 / 临时工具 | 🟢 完全不需要——能用就行 |

**判据**：用户是审美驱动来选用还是工作驱动来使用？审美驱动 → 反 slop。工作驱动 → 别折腾。

### 2. 跟项目品牌规范的优先级

如果项目有 `brand-guidelines` / 设计 system / UI 规范 → **品牌规范优先**。

反 slop 是"无规范时的默认良品率"，不是"凌驾于规范之上的美学要求"。

### 3. 跟 references/vue-style.md 等约束的关系

reference 里的代码规范（变量命名、组件结构、CSS 命名）是**硬约束**，反 slop 是**视觉美学**——两者不冲突：
- reference 管"代码长什么样"
- 反 slop 管"渲染出来看起来什么样"

### 4. 实施时的自检三问

写完一个组件 / 页面前问自己：

1. **字体是 Inter / Roboto / system-ui 吗？** 是 → 想想能不能换（除非工具型 UI）
2. **背景是纯色吗？** 是 → 想想能不能加渐变 / 几何图案 / 微纹理（适用场景下）
3. **配色是"紫色渐变 on 白底"或类似的 AI 默认调色板吗？** 是 → 重选

任一答"是"且任务**不是工具型 UI** → 改之。

---

## 跟 agent-principles.md 的关系

`agent-principles.md` 管**功能正确性**（不偷懒、不幻觉、不绕过）。
本文件管**视觉非平庸**。

两者层次不同，**都必须遵守**：
- 视觉再独特，功能错了也是失败
- 功能再对，视觉是 AI slop 也是失败（适用场景下）
