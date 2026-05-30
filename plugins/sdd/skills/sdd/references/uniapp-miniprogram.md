---
name: uni-app & 微信小程序 Conventions (自写)
note: 官方编码规范缺失（uniapp）/ 偏设计层（小程序），本文件覆盖跨端陷阱、性能、目录结构、反模式。
---

# uni-app 与微信小程序规范

uni-app 项目编译到多端（H5/小程序/App），核心约束是**跨端兼容**与**性能优化**。

---

## 1. 项目结构

```
src/                       (uni-app 标准结构)
├── pages/                 ← 页面（pages.json 注册）
│   ├── index/
│   │   ├── index.vue
│   │   └── index.scss
│   └── user/
├── components/            ← 自定义组件（easycom 自动注册）
│   └── uni-xxx/
├── static/                ← 静态资源（不参与编译，路径 /static/）
│   ├── images/
│   └── icons/
├── api/                   ← 接口封装
├── store/                 ← Pinia store
├── utils/                 ← 工具函数
├── composables/           ← 组合式逻辑（Vue 3）
├── styles/                ← 全局样式
├── App.vue                ← 应用入口
├── main.ts                ← Vue 入口
├── manifest.json          ← uni-app 配置（appid、各端配置）
├── pages.json             ← 路由 + 全局窗口
└── uni.scss               ← 全局 SCSS 变量
```

### 关键路径约定

- **`static/`** 是 uni-app 特殊目录，资源不编译直接复制；路径必须 `/static/img.png`（相对路径有跨端坑）
- **`components/uni-xxx/uni-xxx.vue`** 的命名让 easycom 自动注册无需 import
- **页面必须在 `pages.json` 注册**，否则编译报错

---

## 2. 条件编译（核心陷阱区）

uni-app 通过 `#ifdef` / `#ifndef` / `#endif` 处理跨端差异：

```js
// JS
// #ifdef MP-WEIXIN
console.log('仅微信小程序执行')
// #endif

// #ifndef H5
// 非 H5 端执行（包括小程序、App）
// #endif
```

```vue
<template>
  <!-- 模板 -->
  <!-- #ifdef MP-WEIXIN -->
  <view>微信小程序专属</view>
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

### 平台标识

| 标识 | 含义 |
|---|---|
| `H5` | H5 端 |
| `MP-WEIXIN` | 微信小程序 |
| `MP-ALIPAY` | 支付宝小程序 |
| `MP-BAIDU` | 百度小程序 |
| `MP-TOUTIAO` | 字节小程序 |
| `MP-QQ` | QQ 小程序 |
| `MP` | 所有小程序通用 |
| `APP-PLUS` | App（plus 环境）|
| `APP-NVUE` | App nvue 页面 |

### 条件编译陷阱

1. **条件块前后文件必须语法合法**：
   ```json
   {
     "pages": [
       {"path": "a"},
       // #ifdef MP-WEIXIN
       {"path": "b"},        // ⚠️ 末尾逗号 + #endif 后无内容 → JSON 解析失败
       // #endif
     ]
   }
   ```
   正确写法：把整个对象包在条件内，**逗号也在条件内**

2. **变量必须在条件块内定义**：
   ```js
   // #ifdef H5
   const x = 1
   // #endif
   console.log(x)   // ❌ 在小程序端 x 未定义
   ```

3. **pages.json 写错导致白屏**：条件编译破坏 JSON 结构 → 编译报错或运行白屏。改完必须各端跑一遍

4. **`<style scoped>` 在不同小程序兼容性**：部分小程序对 scoped CSS 编译有差异，避免依赖

---

## 3. 微信小程序性能（官方三件套）

### 3.1 setData 优化

`setData` 是小程序最大性能点：

| 做 / 不做 | 详情 |
|---|---|
| ✅ 减少调用频次 | 多次合并成一次，避免循环里 setData |
| ✅ 减少单次数据量 | 只 setData 变化的字段；用路径 `'list[0].name'` 不要整 list 重设 |
| ✅ 避免大对象 | data 中不放计算属性能算的、不放视图不需要的 |
| ❌ 高频 setData | 滚动/输入事件里 setData → 必须防抖（throttle 100ms 起）|

uniapp 自动做 diff，比手写 setData 友好，但仍要避开高频调用。

### 3.2 分包

```json
// pages.json
{
  "pages": [
    {"path": "pages/index/index"}     // 主包
  ],
  "subPackages": [
    {
      "root": "subpkg-user",
      "pages": [
        {"path": "profile/profile"}    // 路径: /subpkg-user/profile/profile
      ]
    }
  ],
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["subpkg-user"]      // 主包加载完预加载分包
    }
  }
}
```

| 限制 | 值 |
|---|---|
| 主包 | ≤ 2MB |
| 单分包 | ≤ 4MB |
| 整体 | ≤ 20MB |
| 独立分包 | 不依赖主包，可直接打开（启动快）|

**策略**：首页 + 公共组件入主包；业务模块各成分包；不常用功能（如设置）入独立分包。

### 3.3 骨架屏 / 首屏优化

- 数据未就绪用骨架屏替代白屏（微信开发者工具有自动生成功能）
- `onLoad` 异步请求，不阻塞渲染
- 图片用 CDN + WebP + 懒加载
- 首屏数据预取（onAppLaunch 预加载）

### 3.4 渲染层约束

| 约束 | 值 |
|---|---|
| WXML 节点数 | < 1000 |
| 节点嵌套深度 | < 30 |
| 单 setData 数据量 | < 100KB |

超过会卡顿甚至崩。长列表用虚拟列表或分页加载。

---

## 4. 跨端 API 兼容

不是所有 `uni.*` API 都全端支持。开发时**先查文档兼容性表**。

### 高频踩坑 API

| API | 兼容性问题 |
|---|---|
| `uni.request` | 全端 OK，但 H5 跨域要后端配 CORS |
| `uni.uploadFile` | App 和小程序对 multipart 处理不同 |
| `uni.getStorage` | 异步 / `uni.getStorageSync` 同步，存储上限各端不同（小程序 10MB）|
| `uni.navigateTo` | 不能跳 tabBar 页面（必须用 `switchTab`）|
| `uni.showModal` | 小程序内 `cancelText` 长度限制 4 个字 |
| `uni.canvasToTempFilePath` | 各端实现差异大，离屏 canvas 部分端不支持 |
| `uni.getLocation` | 小程序要在 `app.json` 声明 `requiredPrivateInfos` |

### 推荐做法

- 包装一层 `utils/platform.ts` 处理差异
- 关键 API 写 fallback 链：先试 A，失败试 B
- 使用前用 `uni.canIUse('xxx')` 判断

---

## 5. 样式注意

### rpx 单位（响应式像素）

```css
/* uni-app 推荐 rpx，自动按屏幕宽度缩放 */
.title {
  font-size: 28rpx;   /* 750rpx = 屏幕宽度 */
  padding: 20rpx 30rpx;
}
```

**换算**：iPhone6 设计稿 750px 宽 → 1px = 1rpx；其他设备按比例。

### 跨端 CSS 差异

| 端 | 注意 |
|---|---|
| H5 | 标准 CSS，无特殊 |
| 微信小程序 | 不支持部分 CSS3（如 `:has()`）；`<view>` 而非 `<div>` |
| App-vue | 接近 H5 |
| App-nvue | 仅支持 flex 布局，**不能用 grid** |

新写跨端组件**禁用 Grid、Container Queries** 等新特性，除非确认仅跑 H5。

---

## 6. 反模式清单

| 反模式 | 后果 |
|---|---|
| 静态资源用相对路径 `../static/x.png` | 分包后路径失效 |
| 没看兼容性表直接用 uni.* API | 部分端运行时报错 |
| 主包塞业务模块 | 首屏慢，超 2MB 上架失败 |
| 频繁 setData（滚动事件里）| 卡顿、掉帧 |
| 一个 data 字段 100KB 整设 | 渲染层崩溃 |
| 跨端组件用 grid 布局 | nvue 端不支持 |
| 条件编译块尾巴的逗号 / 分号 | JSON 解析报错、白屏 |
| 条件内定义变量条件外用 | 部分端 undefined |
| 直接用 px 不用 rpx | 不同屏幕不适配 |
| 小程序里大量 console.log | 影响性能（特别是循环里）|
| 重要业务逻辑写在 onLoad 同步执行 | 阻塞首屏，骨架屏延迟 |
| `cancelText` 写"取消操作" | 小程序限制 4 字，截断 |
