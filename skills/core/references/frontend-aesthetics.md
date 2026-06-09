# Frontend Anti-AI-Slop Principles (opt-in, not loaded by default)

> ⚠️ **Important**: This file is **not auto-loaded by spec-dev (frontend scope)** — the bulk of everyday frontend work involves tooling UIs, admin panels, and debug pages where anti-slop would feel out of place.
>
> How to enable: add the `design` flag after `/spec:apply`.
>
> ```
> /spec:apply design          # enable anti-AI-slop only
> /spec:apply design verify  # enable both anti-AI-slop and anti-hallucination
> ```
>
> When the main loop detects the `design` flag, it appends "enable anti-ai-slop" to the dispatch prompt; spec-dev (frontend scope) reads this file accordingly.
>
> **Why opt-in**: Most projects (internal sync tools / dashboards / debug panels) are work-driven — readability, consistency, and predictability outrank "distinctiveness". Forcing anti-slop makes the agent fuss over things that should not be fussed over.

---

## Core Anti-AI-Slop Principles

> Distilled from broad frontend design consensus. AI outputs tend to converge on generic, mediocre results — in frontend terms, this is "AI slop." Push back against it: build interfaces that are distinctive and genuinely striking.

Four levers to pull:

- **Typography**: Choose typefaces with character and personality; avoid catch-all fonts like Arial or Inter
- **Color**: Define a cohesive aesthetic system using CSS variables for consistency; **a strong primary color with a crisp accent** beats timid, evenly distributed palettes — draw inspiration from IDE themes or cultural aesthetics
- **Motion**: Use animation for micro-interactions; prefer pure CSS in HTML projects, Motion library in React; **concentrate the best effects on high-impact moments** — one carefully orchestrated loading sequence (staggered reveals) lands harder than scattered micro-animations everywhere
- **Background**: Create atmosphere and depth; resist the default solid color — layer CSS gradients, geometric patterns, or thematic contextual effects

Avoid AI default aesthetics:
- Overused typefaces (Inter / Roboto / Arial / system fonts)
- Clichéd palettes (especially purple gradients on white)
- Predictable layouts and component patterns
- Generic, context-free designs that look like they could belong anywhere

The trick: actively vary between light and dark themes, different typefaces, different aesthetics — do not converge back to the "safe choice" (like Space Grotesk). Break out of the pattern.

---

## What this means in an sdd context

### 1. Classify the UI — anti-slop does not apply everywhere

| UI type | Anti-slop intensity |
|---|---|
| Marketing / Landing page / Portfolio | 🔴 Full force — distinctive typefaces, dark theme, geometric backgrounds, animation |
| Consumer-facing product (App / Consumer Web) | 🟡 Moderate — color palette should have personality but readability comes first |
| **Internal enterprise tools / Admin dashboards / Config panels** | 🟢 **Anti-slop stands down** — readability, consistency, and predictability win |
| Debug panels / Throwaway tools | 🟢 Not needed at all — functional is enough |

**Decision rule**: is the user coming for aesthetic experience or to get work done? Aesthetic-driven → anti-slop. Work-driven → leave it alone.

### 2. Priority relative to project brand guidelines

If the project has `brand-guidelines` / a design system / a UI spec → **brand guidelines take precedence**.

Anti-slop is the "quality floor in the absence of a spec," not an aesthetic requirement that overrides the spec.

### 3. Relationship to other references (e.g., vue-style.md in the same directory)

Code-style references (variable naming, component structure, CSS naming) are **hard constraints**; anti-slop is about **visual aesthetics** — they do not conflict:
- The code references govern what the code looks like
- Anti-slop governs what the rendered result looks like

### 4. Three self-check questions before shipping

Before finishing a component or page, ask yourself:

1. **Is the font Inter / Roboto / system-ui?** If yes → consider switching (unless it is a tooling UI)
2. **Is the background a flat solid color?** If yes → consider adding a gradient / geometric pattern / subtle texture (where appropriate)
3. **Is the color palette "purple gradient on white" or a similar AI-default palette?** If yes → reselect

If any answer is "yes" and the task is **not a tooling UI** → change it.

---

## Relationship to agent-principles.md

`agent-principles.md` governs **functional correctness** (no laziness, no hallucination, no bypasses).
This file governs **visual non-mediocrity**.

They operate at different levels, and **both MUST be followed**:
- No matter how visually distinctive, a broken feature is a failure
- No matter how functionally correct, AI-slop visuals are a failure (in applicable scenarios)
