---
name: CSS / CSS3 Conventions (自写)
note: Vue 项目优先 scoped CSS，全局样式按 BEM 命名；现代布局 Flex + Grid + Container Queries。
---

# CSS 规范

---

## 1. Vue 项目样式策略

| 范围 | 用什么 | 备注 |
|---|---|---|
| 组件内样式 | **`<style scoped>`** | Vue SFC 默认，避免全局污染 |
| 跨组件共享变量（颜色、间距、字号）| **CSS Variables**（`:root` 里定义）| 优先于 SCSS 变量，运行时可改 |
| 全局重置 / 工具类 | `src/styles/reset.scss` + `utils.scss` | 在 `main.ts` 一次性 import |
| 主题切换（暗色模式）| CSS Variables + class 切换 | `[data-theme="dark"]` 覆写变量 |
| 动态计算样式 | `:style` 绑定 + ref | 不要在 CSS 里 hack |

### scoped CSS 注意

```vue
<style scoped>
/* 默认只影响当前组件 */
.title { color: blue; }

/* 影响子组件根元素或 slot 内容：用 :deep() */
:deep(.child-component) { color: red; }

/* 影响 slot 传入内容 */
:slotted(.slotted-child) { color: green; }

/* 全局穿透（慎用，破坏 scoped）*/
:global(.app-wide) { ... }
</style>
```

---

## 2. 命名约定

### 组件内（scoped）

无需命名约定——scoped 自动加 hash 避免冲突，直接用语义化类名：

```vue
<style scoped>
.title { ... }
.subtitle { ... }
.btn-primary { ... }
</style>
```

### 全局样式（BEM 推荐）

跨组件、全局工具类用 **BEM**：`block__element--modifier`

```scss
/* Block：独立组件 */
.card { ... }

/* Element：组件内的部分（双下划线）*/
.card__title { ... }
.card__body { ... }
.card__footer { ... }

/* Modifier：变体（双连字符）*/
.card--featured { ... }
.card__title--large { ... }
```

**判断**：scoped 内**不要**用 BEM（多余）；全局样式必须 BEM 防冲突。

---

## 3. 现代布局选型

| 场景 | 用什么 | 理由 |
|---|---|---|
| 1D 排布（一行或一列） | **Flexbox** | API 简单，对齐控制强 |
| 2D 网格（页面/卡片排列）| **Grid** | 二维原生支持 |
| 组件自适应（不依赖视口） | **Container Queries** | 2023+ 浏览器普及 |
| 视口级响应式 | **Media Queries** | 经典方案 |
| 老项目兼容 | float + clearfix（避免新写）| 仅维护用 |

### Flex vs Grid 快速判断

```scss
/* Flex：一行导航、按钮组、垂直居中 */
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

/* Grid：卡片列表、复杂页面布局 */
.card-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 16px;
}
```

### Container Queries（现代）

```scss
.card {
  container-type: inline-size;
}

@container (min-width: 400px) {
  .card__title { font-size: 1.5rem; }
}
```

组件根据**自己的宽度**响应，不依赖视口——比 media query 更适合可复用组件。

---

## 4. CSS Variables（设计令牌）

```scss
/* src/styles/variables.scss 或 :root */
:root {
  /* 颜色 */
  --color-primary: #1890ff;
  --color-success: #52c41a;
  --color-warning: #faad14;
  --color-danger: #ff4d4f;
  --color-text: #333;
  --color-text-secondary: #666;
  --color-border: #e8e8e8;
  --color-bg: #fff;
  
  /* 间距（4px 基准）*/
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;
  
  /* 字号 */
  --font-size-sm: 12px;
  --font-size-base: 14px;
  --font-size-lg: 16px;
  --font-size-xl: 20px;
  
  /* 圆角 */
  --radius-sm: 2px;
  --radius-md: 4px;
  --radius-lg: 8px;
  
  /* 阴影 */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.1);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);
  
  /* z-index 层级 */
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

**好处**：运行时可改（暗色模式只切 class，无需重新构建）；JS 可读可写（`getComputedStyle().getPropertyValue('--color-primary')`）。

---

## 5. 间距与字号系统

**4px / 8px 基准**：所有 padding、margin、gap 应是 4 的倍数。

```scss
/* 推荐 */
padding: 16px 24px;
margin-bottom: 8px;
gap: 12px;

/* 不推荐 */
padding: 13px 19px;  /* 神奇数字，破坏一致性 */
margin-top: 7px;
```

**字号阶梯**：用 12/14/16/20/24/32... 这种倍数关系，不要 13、15、17 这种。

---

## 6. z-index 管理

**禁止裸写 `z-index: 999`**。必须用 CSS Variables 或固定阶梯：

| 层级 | z-index | 用途 |
|---|---|---|
| 基础 | 0 | 普通元素 |
| 浮动 | 10 | 卡片 hover、tooltip |
| 下拉 | 1000 | dropdown、popover |
| 固定栏 | 1500 | sticky header、固定底栏 |
| 遮罩 | 2000 | modal mask |
| 弹窗 | 2001 | modal content |
| 通知 | 3000 | toast、message |

---

## 7. 性能与可访问性

- **避免深层嵌套**：SCSS 嵌套 ≤3 层
- **不写 `!important`**（除非覆盖第三方库无法绕过）
- **transition 写 `transform` 和 `opacity`**，避免触发 reflow（width/height/top/left 慢）
- **`will-change` 谨慎用**，只在动画前临时加，结束删掉
- **图片用 `loading="lazy"`** + 合适的 `width`/`height` 防止 CLS
- **联系颜色对比度 ≥4.5:1**（WCAG AA）
- **`outline: none` 必须配合自定义 focus 样式**，否则键盘用户失能

---

## 8. 反模式清单

| 反模式 | 为什么不行 |
|---|---|
| 内联 style="" 写大段样式 | 不可复用、不可主题化 |
| `!important` 解决冲突 | 治标不治本，加 CSS 优先级或重构选择器 |
| 深层选择器（`.a .b .c .d`）| 性能差、难维护 |
| `id` 选择器（`#header`） | 不可复用，CSS 优先级混乱 |
| 同一颜色硬编码多处 | 用 CSS Variable |
| 13px / 17px 这种非阶梯字号 | 视觉破碎 |
| 老式 float 布局新写 | 用 Flex/Grid |
| `* { box-sizing: border-box }` 散在多处 | 全局 reset 一次定义 |
| Vue 中 `<style>` 不加 scoped | 必然全局污染 |
| 用 `>>>` 或 `/deep/`（已废弃）| 用 `:deep()` |
