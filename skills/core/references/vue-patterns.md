---
name: Vue 3 Modern Patterns & Project Conventions (自写)
companion: vue-style.md (Vue 官方风格指南，先读那个)
note: 官方风格指南偏语法层面，本文件补足"现代 Vue 项目怎么组织 + 怎么用设计模式 + 反模式"。
---

# Vue 3 现代实践与设计模式

`vue-style.md` 是官方规则；本文件是落地选型和模式应用。

---

## 1. 默认技术栈选型（2025-2026 主流）

| 维度 | 选 | 备选 / 不推荐 |
|---|---|---|
| API 风格 | **Composition API + `<script setup>`** | Options API（仅小组件 / 兼容老项目可用）|
| 类型 | **TypeScript** | 纯 JS（仅小项目 / 个人项目）|
| 状态管理 | **Pinia** | Vuex（v2 遗留只读）/ 完全本地 ref |
| 路由 | **Vue Router 4** | (无替代) |
| 构建 | **Vite** | Webpack（仅老项目维护）|
| UI 库 | Element Plus / Naive UI / Ant Design Vue | 看项目品味，不强制 |
| HTTP | axios / fetch + 自封装 | (无强制) |
| 测试 | Vitest + Vue Test Utils | Jest（旧）|

**不要在新项目用**：Options API、Vuex、Webpack（除非现有项目已用）。

---

## 2. 标准目录结构

```
src/
├── api/                  ← 接口封装（按业务模块拆）
│   ├── user.ts
│   ├── order.ts
│   └── _client.ts        (axios 实例 + 拦截器)
├── assets/               ← 静态资源（图片、字体）
│   ├── images/
│   └── icons/
├── components/           ← 可复用组件（跨页面共用）
│   ├── base/             (BaseButton, BaseInput - 最底层)
│   ├── business/         (UserCard, OrderItem - 业务组件)
│   └── layout/           (Header, Sidebar, Footer)
├── composables/          ← Composition API 复用逻辑 ⭐
│   ├── useUser.ts
│   ├── usePagination.ts
│   └── useRequest.ts
├── layouts/              ← 页面布局模板
│   ├── DefaultLayout.vue
│   └── AdminLayout.vue
├── router/               ← 路由配置
│   ├── index.ts
│   ├── routes.ts
│   └── guards.ts         (路由守卫：权限、登录)
├── stores/               ← Pinia stores
│   ├── user.ts
│   ├── app.ts
│   └── index.ts
├── views/                ← 路由级页面（一个 view = 一个路由）
│   ├── user/
│   │   ├── UserList.vue
│   │   ├── UserDetail.vue
│   │   └── components/   (本页专属子组件，不跨页用)
│   └── order/
├── types/                ← TypeScript 类型定义
│   ├── user.ts
│   ├── api.ts
│   └── common.ts
├── utils/                ← 工具函数（纯函数、无副作用）
│   ├── date.ts
│   ├── format.ts
│   └── validator.ts
├── styles/               ← 全局样式
│   ├── variables.scss
│   ├── reset.scss
│   └── theme.scss
├── App.vue
└── main.ts
```

### 关键约定

- **`views/` vs `components/`**：路由级别用 `views/`，可复用的用 `components/`；本页专属子组件放该 view 的 `components/` 子目录
- **`composables/` 是 Vue 3 灵魂**：所有跨组件复用的响应式逻辑放这里，不再用 mixin
- **`api/` 不放业务逻辑**：只封装请求 + 类型，业务逻辑在 composables/store
- **`stores/` 只放全局共享状态**：组件本地 state 用 `ref` 不要进 store
- **`utils/` 纯函数**：不依赖 Vue 响应式（如果依赖 → 放 composables）

---

## 3. Composables 模式（Vue 3 最核心模式）

Composables 替代了 Vue 2 的 mixin，是逻辑复用的标准方式。

### 命名约定

- 必须 `use` 前缀：`useUser`, `usePagination`, `useFetch`
- 文件名同函数名：`composables/usePagination.ts` exports `usePagination`

### 标准结构

```ts
// composables/usePagination.ts
import { ref, computed } from 'vue'

export function usePagination(initialPage = 1, pageSize = 10) {
  const currentPage = ref(initialPage)
  const total = ref(0)
  
  const totalPages = computed(() => Math.ceil(total.value / pageSize))
  const hasNext = computed(() => currentPage.value < totalPages.value)
  
  function next() { if (hasNext.value) currentPage.value++ }
  function reset() { currentPage.value = initialPage }
  
  return {
    currentPage,
    total,
    totalPages,
    hasNext,
    next,
    reset,
  }
}
```

### 使用

```vue
<script setup>
import { usePagination } from '@/composables/usePagination'
const { currentPage, total, next, reset } = usePagination()
</script>
```

### 何时该写 Composable

| 场景 | 是否写 Composable |
|---|---|
| 多个组件需要相同响应式逻辑 | ✅ 必须 |
| 单组件内 setup 超过 50 行 | ✅ 拆出来 |
| 涉及 lifecycle hooks（onMounted 等）的复用 | ✅ Composable 是唯一方式 |
| 纯计算函数无响应式 | ❌ 放 `utils/` |
| 一次性逻辑、不复用 | ❌ 直接写在组件 |

---

## 4. 其他 Vue 设计模式

### 4.1 Provide / Inject（跨层级传递）

**场景**：祖先组件向深层后代传数据，避免一级级 props 透传

```vue
<!-- 祖先 -->
<script setup>
import { provide, ref } from 'vue'
const theme = ref('dark')
provide('theme', theme)  // 用 key 提供
</script>

<!-- 任意层后代 -->
<script setup>
import { inject } from 'vue'
const theme = inject('theme')
</script>
```

**最佳实践**：用 `Symbol` 作 key 避免冲突，用 TypeScript `InjectionKey<T>` 加类型。

### 4.2 Render-less Component（无渲染逻辑组件）

**场景**：把复杂状态逻辑封装成组件，调用者控制渲染（v-slot scoped slots）

```vue
<!-- FetchData.vue -->
<script setup>
import { ref } from 'vue'
const props = defineProps(['url'])
const data = ref(null)
const loading = ref(true)
fetch(props.url).then(r => r.json()).then(d => { data.value = d; loading.value = false })
</script>
<template>
  <slot :data="data" :loading="loading" />
</template>

<!-- 使用 -->
<FetchData url="/api/users" v-slot="{ data, loading }">
  <div v-if="loading">加载中</div>
  <UserList v-else :users="data" />
</FetchData>
```

**注**：Vue 3 时代 Composables 通常替代了 render-less，仅在需要"作为组件传递"时用。

### 4.3 Pinia Store 设计

```ts
// stores/user.ts - 推荐 Setup Store 风格（同 Composables）
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // state
  const user = ref(null)
  const token = ref(localStorage.getItem('token'))
  
  // getters
  const isLoggedIn = computed(() => !!token.value)
  const userName = computed(() => user.value?.name ?? '游客')
  
  // actions
  async function login(credentials) {
    const res = await api.login(credentials)
    token.value = res.token
    user.value = res.user
    localStorage.setItem('token', res.token)
  }
  
  function logout() {
    user.value = null
    token.value = null
    localStorage.removeItem('token')
  }
  
  return { user, token, isLoggedIn, userName, login, logout }
})
```

**何时建 Store**：跨多个组件/页面共享的状态。仅本组件内的状态用 `ref`，**不要进 store**。

### 4.4 Observer / 事件总线（不推荐用）

Vue 3 移除了 `$on`/`$emit` 全局 EventBus。**推荐用 Pinia 替代**全局事件——store 的 action 触发，多个组件 watch state 响应。

如果真的需要事件，用 [mitt](https://github.com/developit/mitt)，但**多数情况是设计问题**，先想能不能用 store。

---

## 5. SOLID 在 Vue 中

| 原则 | Vue 中表现 |
|---|---|
| **S** 单一职责 | 一个组件一个职责；超 200 行就要拆 |
| **O** 开闭原则 | Slot + Props 让组件可扩展不修改 |
| **L** 里氏替换 | 基础组件（BaseButton）的衍生（PrimaryButton）应能替代 |
| **I** 接口隔离 | Props 定义精确类型，不要传 `Object` |
| **D** 依赖反转 | 组件依赖 props/inject，不直接 import 具体 store（除非必要）|

---

## 6. 性能模式

| 场景 | 用什么 |
|---|---|
| 大列表（>100 项） | `v-memo` 或虚拟列表（vue-virtual-scroller）|
| 计算昂贵 | `computed`（缓存），避免在 template 写复杂表达式 |
| 防止子组件重渲染 | `defineProps` 精确类型 + `v-once`（静态内容）|
| 路由级懒加载 | `() => import('./Page.vue')` |
| 组件按需引入 | `unplugin-vue-components` 自动导入 |
| 图片懒加载 | `<img loading="lazy">` 或专门库 |

---

## 7. 反模式清单

| 反模式 | 为什么不行 |
|---|---|
| 用 Options API 写新代码 | 与 Composition API 混杂，团队混乱 |
| 把所有 state 放 Pinia | Store 膨胀，本地 state 应留组件内 |
| Composable 不用 `use` 前缀 | 违反约定，可读性差 |
| 在 `utils/` 放响应式逻辑 | utils 应是纯函数，响应式归 composables |
| 跨页面的子组件放 `views/x/components/` | 跨用的归 `src/components/` |
| `<script>` 不用 `setup` 语法糖 | 新代码无理由不用 setup |
| 全局 EventBus（mitt 滥用）| 状态难追踪，用 Pinia |
| 一个文件 500+ 行组件 | 必拆，按功能拆子组件 + composables |
| Props 用 `Object` 泛类型 | 失去类型检查，写明 interface |
| v-for 不写 `:key` 或用 index 当 key | 官方 Priority A 硬规则 |
| 直接修改 props | 单向数据流违反 |
| 在模板里写复杂表达式 | 拆 computed |
