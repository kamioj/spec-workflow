---
name: uni-app & WeChat Mini Program Conventions (original)
note: The official uni-app coding guidelines are sparse, and the WeChat mini-program documentation skews toward design. This file covers cross-platform pitfalls, performance, directory structure, and anti-patterns.
---

# uni-app & WeChat Mini-Program Conventions

uni-app projects compile to multiple targets (H5, mini-programs, and App). The two core constraints are **cross-platform compatibility** and **performance**.

---

## 1. Project Structure

```
src/                       (standard uni-app layout)
├── pages/                 ← Pages (registered in pages.json)
│   ├── index/
│   │   ├── index.vue
│   │   └── index.scss
│   └── user/
├── components/            ← Custom components (auto-registered via easycom)
│   └── uni-xxx/
├── static/                ← Static assets (not processed by the compiler; served at /static/)
│   ├── images/
│   └── icons/
├── api/                   ← API wrappers
├── store/                 ← Pinia store
├── utils/                 ← Utility functions
├── composables/           ← Composable logic (Vue 3)
├── styles/                ← Global styles
├── App.vue                ← Application entry point
├── main.ts                ← Vue entry point
├── manifest.json          ← uni-app config (appid, per-platform settings)
├── pages.json             ← Routes + global window config
└── uni.scss               ← Global SCSS variables
```

### Key Path Conventions

- **`static/`** is a special uni-app directory: assets are copied as-is without any compilation. Paths MUST use the absolute form `/static/img.png` — relative paths have cross-platform issues.
- **`components/uni-xxx/uni-xxx.vue`** naming convention enables easycom auto-registration without explicit imports.
- **Every page MUST be registered in `pages.json`**, or the build will fail.

---

## 2. Conditional Compilation (The Primary Pitfall Zone)

uni-app handles cross-platform differences via `#ifdef` / `#ifndef` / `#endif` directives:

```js
// JS
// #ifdef MP-WEIXIN
console.log('runs on WeChat mini-program only')
// #endif

// #ifndef H5
// runs on all platforms except H5 (includes mini-programs and App)
// #endif
```

```vue
<template>
  <!-- template -->
  <!-- #ifdef MP-WEIXIN -->
  <view>WeChat mini-program exclusive content</view>
  <!-- #endif -->
</template>

<style>
/* CSS */
/* #ifdef MP-WEIXIN */
.specific { color: red; }
/* #endif */
</style>
```

```json
// pages.json
{
  "pages": [
    {"path": "pages/index/index"}
    // #ifdef MP-WEIXIN
    , {"path": "pages/wx-only/wx-only"}
    // #endif
  ]
}
```

### Platform Identifiers

| Identifier | Platform |
|---|---|
| `H5` | H5 (web) |
| `MP-WEIXIN` | WeChat mini-program |
| `MP-ALIPAY` | Alipay mini-program |
| `MP-BAIDU` | Baidu mini-program |
| `MP-TOUTIAO` | ByteDance mini-program |
| `MP-QQ` | QQ mini-program |
| `MP` | All mini-programs |
| `APP-PLUS` | App (plus environment) |
| `APP-NVUE` | App nvue pages |

### Conditional Compilation Pitfalls

1. **The file MUST remain syntactically valid on both sides of a conditional block**:
   ```json
   {
     "pages": [
       {"path": "a"},
       // #ifdef MP-WEIXIN
       {"path": "b"},        // ⚠️ trailing comma before #endif with nothing after it → JSON parse error
       // #endif
     ]
   }
   ```
   The correct approach: wrap the entire object in the conditional block so **the comma is also inside the block**.

2. **Variables defined inside a conditional block MUST NOT be used outside it**:
   ```js
   // #ifdef H5
   const x = 1
   // #endif
   console.log(x)   // ❌ x is undefined on mini-programs
   ```

3. **Malformed `pages.json` causes a blank screen**: If conditional compilation breaks the JSON structure, the build either errors out or produces a white screen at runtime. After any edit to `pages.json`, verify the app on every target platform.

4. **`<style scoped>` has inconsistent behavior across mini-programs**: Some mini-program runtimes handle scoped CSS compilation differently. Avoid relying on it for cross-platform components.

---

## 3. WeChat Mini-Program Performance (The Official Three Pillars)

### 3.1 setData Optimization

`setData` is the single biggest performance bottleneck in mini-programs:

| Do / Avoid | Details |
|---|---|
| ✅ Reduce call frequency | Batch multiple updates into one call; never call setData inside a loop |
| ✅ Minimize payload per call | Only set changed fields; use path syntax (`'list[0].name'`) instead of resetting the entire list |
| ✅ Keep data lean | Do not store computed values or view-irrelevant data in `data` |
| ❌ High-frequency setData | Calling setData in scroll or input events causes jank — MUST debounce/throttle (100ms minimum) |

uni-app performs automatic diffing, which is more forgiving than raw setData — but high-frequency calls are still a problem.

### 3.2 Sub-Packages

```json
// pages.json
{
  "pages": [
    {"path": "pages/index/index"}     // main package
  ],
  "subPackages": [
    {
      "root": "subpkg-user",
      "pages": [
        {"path": "profile/profile"}    // full path: /subpkg-user/profile/profile
      ]
    }
  ],
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["subpkg-user"]      // preload sub-package once main package is ready
    }
  }
}
```

| Limit | Value |
|---|---|
| Main package | ≤ 2MB |
| Single sub-package | ≤ 4MB |
| Total | ≤ 20MB |
| Independent sub-package | Can launch directly without the main package (faster cold start) |

**Strategy**: Put the home page and shared components in the main package. Organize business modules as separate sub-packages. Rarely used features (e.g., settings) should be independent sub-packages.

### 3.3 Skeleton Screens & First-Screen Performance

- Replace blank white screens with skeleton screens while data is loading (WeChat DevTools can auto-generate these).
- Fire async requests in `onLoad` — do not block rendering.
- Serve images via CDN, use WebP format, and enable lazy loading.
- Pre-fetch first-screen data in `onAppLaunch`.

### 3.4 Render Layer Limits

| Constraint | Limit |
|---|---|
| WXML node count | < 1000 |
| Node nesting depth | < 30 |
| Single setData payload | < 100KB |

Exceeding these limits causes stuttering and potential crashes. Use virtual lists or pagination for long lists.

---

## 4. Cross-Platform API Compatibility

Not all `uni.*` APIs are supported on every platform. **Always check the compatibility table in the documentation** before using an API.

### Commonly Problematic APIs

| API | Compatibility Issue |
|---|---|
| `uni.request` | Works everywhere, but H5 requires the backend to configure CORS |
| `uni.uploadFile` | App and mini-programs handle multipart differently |
| `uni.getStorage` | Async; `uni.getStorageSync` is sync. Storage limits vary by platform (mini-programs: 10MB) |
| `uni.navigateTo` | Cannot navigate to a tabBar page — use `switchTab` instead |
| `uni.showModal` | `cancelText` is limited to 4 characters on mini-programs |
| `uni.canvasToTempFilePath` | Varies significantly by platform; off-screen canvas is not supported everywhere |
| `uni.getLocation` | Mini-programs require `requiredPrivateInfos` declared in `app.json` |

### Recommended Approach

- Wrap platform differences behind a `utils/platform.ts` abstraction layer.
- For critical APIs, implement a fallback chain: try A first, fall back to B on failure.
- Use `uni.canIUse('xxx')` to check support before calling unfamiliar APIs.

---

## 5. Styling Notes

### rpx Units (Responsive Pixels)

```css
/* uni-app recommends rpx, which scales automatically with screen width */
.title {
  font-size: 28rpx;   /* 750rpx = full screen width */
  padding: 20rpx 30rpx;
}
```

**Conversion**: On a 750px-wide iPhone 6 design mockup, 1px = 1rpx. Other devices scale proportionally.

### Cross-Platform CSS Differences

| Platform | Notes |
|---|---|
| H5 | Standard CSS, no special restrictions |
| WeChat mini-program | Some CSS3 features unsupported (e.g., `:has()`); use `<view>` instead of `<div>` |
| App-vue | Close to H5 |
| App-nvue | Flex layout only — **grid is not supported** |

When writing cross-platform components, NEVER use Grid, Container Queries, or other modern CSS features unless you have confirmed the component will only run on H5.

---

## 6. Anti-Pattern Checklist

| Anti-Pattern | Consequence |
|---|---|
| Referencing static assets with relative paths (`../static/x.png`) | Paths break after sub-package splitting |
| Using `uni.*` APIs without checking the compatibility table | Runtime errors on certain platforms |
| Stuffing business modules into the main package | Slow first screen; the 2MB limit causes app store submission failures |
| Frequent setData in scroll event handlers | Jank and dropped frames |
| Setting a 100KB data field all at once | Render layer crash |
| Using grid layout in cross-platform components | Not supported in nvue |
| Trailing comma/semicolon inside conditional compilation blocks | JSON parse error, white screen |
| Using variables outside the conditional block where they were defined | `undefined` on some platforms |
| Using `px` instead of `rpx` | Does not adapt to different screen sizes |
| Excessive `console.log` in mini-programs (especially in loops) | Degrades performance |
| Running critical business logic synchronously in `onLoad` | Blocks first-screen rendering, delays skeleton screen |
| `cancelText` longer than 4 characters | Truncated silently by mini-program runtime |
