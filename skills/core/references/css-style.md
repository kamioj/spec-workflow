---
name: CSS / CSS3 Conventions (hand-written)
note: Vue projects default to scoped CSS; global styles follow BEM naming. Modern layout stack is Flex + Grid + Container Queries.
---

# CSS Conventions

---

## 1. Styling Strategy for Vue Projects

| Scope | What to use | Notes |
|---|---|---|
| Component-level styles | **`<style scoped>`** | Vue SFC default; prevents global bleed |
| Cross-component shared tokens (colors, spacing, type scale) | **CSS Variables** (defined in `:root`) | Preferred over SCSS variables; can be changed at runtime |
| Global reset / utility classes | `src/styles/reset.scss` + `utils.scss` | Import once in `main.ts` |
| Theme switching (dark mode) | CSS Variables + class toggle | Override variables under `[data-theme="dark"]` |
| Dynamically computed styles | `:style` binding + `ref` | NEVER hack this in CSS |

### Scoped CSS: things to know

```vue
<style scoped>
/* Applies only to the current component by default */
.title { color: blue; }

/* Target a child component's root element or slot content: use :deep() */
:deep(.child-component) { color: red; }

/* Target content passed via slots */
:slotted(.slotted-child) { color: green; }

/* Global pierce (use sparingly — breaks scoping) */
:global(.app-wide) { ... }
</style>
```

---

## 2. Naming Conventions

### Inside components (scoped)

No naming convention is needed — scoped CSS automatically appends a hash to prevent collisions. Use plain semantic class names:

```vue
<style scoped>
.title { ... }
.subtitle { ... }
.btn-primary { ... }
</style>
```

### Global styles (BEM recommended)

For cross-component and global utility classes, use **BEM**: `block__element--modifier`

```scss
/* Block: a standalone component */
.card { ... }

/* Element: a part of the component (double underscore) */
.card__title { ... }
.card__body { ... }
.card__footer { ... }

/* Modifier: a variant (double hyphen) */
.card--featured { ... }
.card__title--large { ... }
```

**Rule of thumb**: MUST NOT use BEM inside scoped styles (it's redundant); global styles MUST use BEM to prevent naming conflicts.

---

## 3. Modern Layout Toolbox

| Scenario | Use | Rationale |
|---|---|---|
| 1D flow (single row or column) | **Flexbox** | Simple API, strong alignment control |
| 2D grid (pages, card layouts) | **Grid** | Native two-dimensional support |
| Component-responsive (independent of viewport) | **Container Queries** | Widely available in 2023+ browsers |
| Viewport-responsive | **Media Queries** | The classic approach |
| Legacy project maintenance | float + clearfix (avoid writing new) | For maintenance only |

### Flex vs Grid: quick guide

```scss
/* Flex: horizontal nav, button groups, vertical centering */
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

/* Grid: card lists, complex page layouts */
.card-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 16px;
}
```

### Container Queries (modern)

```scss
.card {
  container-type: inline-size;
}

@container (min-width: 400px) {
  .card__title { font-size: 1.5rem; }
}
```

The component responds to **its own width** rather than the viewport — a better fit for reusable components than media queries.

---

## 4. CSS Variables (Design Tokens)

```scss
/* src/styles/variables.scss or :root */
:root {
  /* Colors */
  --color-primary: #1890ff;
  --color-success: #52c41a;
  --color-warning: #faad14;
  --color-danger: #ff4d4f;
  --color-text: #333;
  --color-text-secondary: #666;
  --color-border: #e8e8e8;
  --color-bg: #fff;
  
  /* Spacing (4px base) */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;
  
  /* Type scale */
  --font-size-sm: 12px;
  --font-size-base: 14px;
  --font-size-lg: 16px;
  --font-size-xl: 20px;
  
  /* Border radius */
  --radius-sm: 2px;
  --radius-md: 4px;
  --radius-lg: 8px;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.1);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);
  
  /* z-index layers */
  --z-dropdown: 1000;
  --z-modal: 2000;
  --z-toast: 3000;
}

[data-theme="dark"] {
  --color-text: #e8e8e8;
  --color-bg: #1a1a1a;
  --color-border: #333;
}
```

**Benefits**: values can be changed at runtime (dark mode is a class toggle — no rebuild required); JS can read and write them via `getComputedStyle().getPropertyValue('--color-primary')`.

---

## 5. Spacing and Type Scale

**4px / 8px base grid**: all `padding`, `margin`, and `gap` values MUST be multiples of 4.

```scss
/* Preferred */
padding: 16px 24px;
margin-bottom: 8px;
gap: 12px;

/* Avoid */
padding: 13px 19px;  /* magic numbers that break visual consistency */
margin-top: 7px;
```

**Type scale**: stick to the scale — 12 / 14 / 16 / 20 / 24 / 32… NEVER use off-scale values like 13, 15, or 17.

---

## 6. z-index Management

**NEVER hardcode `z-index: 999`**. Always use CSS Variables or a fixed stacking ladder:

| Layer | z-index | Use case |
|---|---|---|
| Base | 0 | Normal elements |
| Floating | 10 | Card hover states, tooltips |
| Dropdown | 1000 | Dropdowns, popovers |
| Fixed bars | 1500 | Sticky headers, fixed footers |
| Overlay | 2000 | Modal backdrop |
| Dialog | 2001 | Modal content |
| Notifications | 3000 | Toasts, messages |

---

## 7. Performance and Accessibility

- **avoid deep nesting**: SCSS nesting MUST NOT exceed 3 levels.
- **NEVER write `!important`** (unless overriding a third-party library with no other escape hatch).
- **Animate `transform` and `opacity`** — avoid animating properties that trigger reflow (`width`, `height`, `top`, `left` are slow).
- **Use `will-change` sparingly** — add it temporarily before an animation starts and remove it when done.
- **Use `loading="lazy"` on images** along with explicit `width` / `height` to prevent Cumulative Layout Shift (CLS).
- **Color contrast MUST be at least 4.5:1** (WCAG AA).
- **NEVER remove `outline` without providing a custom focus style** — doing so disables keyboard navigation for users who rely on it.

---

## 8. Anti-Patterns

| Anti-pattern | Why it's a problem |
|---|---|
| Inline `style=""` with extensive rules | Not reusable, not themeable |
| `!important` to resolve conflicts | Treats the symptom — increase CSS specificity or refactor the selector instead |
| Deep selectors (`.a .b .c .d`) | Poor performance and hard to maintain |
| `id` selectors (`#header`) | Not reusable; wreaks havoc on CSS specificity |
| Same color hardcoded in multiple places | Use a CSS Variable |
| Off-scale font sizes (13px, 17px, etc.) | Produces visual inconsistency |
| New code using the legacy `float` layout | Use Flex or Grid instead |
| `* { box-sizing: border-box }` scattered throughout | Define it once in the global reset |
| `<style>` without `scoped` in Vue components | Will inevitably pollute global styles |
| Using `>>>` or `/deep/` (deprecated) | Use `:deep()` instead |
