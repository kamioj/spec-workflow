---
name: Vue 3 Modern Patterns & Project Conventions (original)
companion: vue-style.md (Vue official style guide — read that first)
note: The official style guide focuses on syntax. This file fills in the gaps around how to structure a modern Vue project, apply design patterns, and avoid anti-patterns.
---

# Vue 3 Modern Practices & Design Patterns

`vue-style.md` covers the official rules; this file covers practical choices and pattern application in real projects.

---

## 1. Default Tech Stack (2025–2026 Mainstream)

| Dimension | Recommended | Alternatives / Not Recommended |
|---|---|---|
| API Style | **Composition API + `<script setup>`** | Options API (acceptable only for small components or legacy compatibility) |
| Types | **TypeScript** | Plain JS (only for small/personal projects) |
| State Management | **Pinia** | Vuex (read-only for v2 legacy) / purely local ref |
| Routing | **Vue Router 4** | (no alternative) |
| Build Tool | **Vite** | Webpack (only for maintaining existing projects) |
| UI Library | Element Plus / Naive UI / Ant Design Vue | Project-dependent, no strict requirement |
| HTTP | axios / fetch + custom wrapper | (no strict requirement) |
| Testing | Vitest + Vue Test Utils | Jest (legacy) |

**NEVER use in new projects**: Options API, Vuex, Webpack (unless the project already uses them).

---

## 2. Standard Directory Structure

```
src/
├── api/                  ← API wrappers (split by business domain)
│   ├── user.ts
│   ├── order.ts
│   └── _client.ts        (axios instance + interceptors)
├── assets/               ← Static assets (images, fonts)
│   ├── images/
│   └── icons/
├── components/           ← Reusable components (shared across pages)
│   ├── base/             (BaseButton, BaseInput — lowest-level primitives)
│   ├── business/         (UserCard, OrderItem — domain-specific components)
│   └── layout/           (Header, Sidebar, Footer)
├── composables/          ← Composition API reusable logic ⭐
│   ├── useUser.ts
│   ├── usePagination.ts
│   └── useRequest.ts
├── layouts/              ← Page layout templates
│   ├── DefaultLayout.vue
│   └── AdminLayout.vue
├── router/               ← Route configuration
│   ├── index.ts
│   ├── routes.ts
│   └── guards.ts         (route guards: auth, login)
├── stores/               ← Pinia stores
│   ├── user.ts
│   ├── app.ts
│   └── index.ts
├── views/                ← Route-level pages (one view = one route)
│   ├── user/
│   │   ├── UserList.vue
│   │   ├── UserDetail.vue
│   │   └── components/   (sub-components exclusive to this view, not shared)
│   └── order/
├── types/                ← TypeScript type definitions
│   ├── user.ts
│   ├── api.ts
│   └── common.ts
├── utils/                ← Utility functions (pure functions, no side effects)
│   ├── date.ts
│   ├── format.ts
│   └── validator.ts
├── styles/               ← Global styles
│   ├── variables.scss
│   ├── reset.scss
│   └── theme.scss
├── App.vue
└── main.ts
```

### Key Conventions

- **`views/` vs `components/`**: Route-level components go in `views/`; anything reusable across pages goes in `components/`. Sub-components used only within a single view live in that view's own `components/` subdirectory.
- **`composables/` is the heart of Vue 3**: All reactive logic shared across components belongs here. Mixins are no longer used.
- **`api/` contains no business logic**: Only request wrappers and type definitions. Business logic lives in composables or stores.
- **`stores/` holds only globally shared state**: Component-local state stays as `ref` inside the component — do not put it in a store.
- **`utils/` contains pure functions**: No Vue reactivity. If a function depends on reactive state, it belongs in `composables/` instead.

---

## 3. The Composables Pattern (The Most Important Vue 3 Pattern)

Composables replace Vue 2 mixins as the standard approach for logic reuse.

### Naming Convention

- MUST use the `use` prefix: `useUser`, `usePagination`, `useFetch`
- File name matches the exported function name: `composables/usePagination.ts` exports `usePagination`

### Standard Structure

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

### Usage

```vue
<script setup>
import { usePagination } from '@/composables/usePagination'
const { currentPage, total, next, reset } = usePagination()
</script>
```

### When to Write a Composable

| Scenario | Write a Composable? |
|---|---|
| Multiple components need the same reactive logic | ✅ Always |
| A single component's `setup` exceeds 50 lines | ✅ Extract it |
| Reusing logic that involves lifecycle hooks (e.g., `onMounted`) | ✅ Composable is the only right approach |
| Pure computation with no reactive state | ❌ Put it in `utils/` |
| One-off logic that won't be reused | ❌ Write it directly in the component |

---

## 4. Other Vue Design Patterns

### 4.1 Provide / Inject (Cross-Level Data Passing)

**Use case**: Pass data from an ancestor component to deeply nested descendants without threading props through every intermediate layer.

```vue
<!-- Ancestor -->
<script setup>
import { provide, ref } from 'vue'
const theme = ref('dark')
provide('theme', theme)  // provide under a key
</script>

<!-- Any descendant, regardless of nesting depth -->
<script setup>
import { inject } from 'vue'
const theme = inject('theme')
</script>
```

**Best practice**: Use a `Symbol` as the key to avoid naming collisions, and use TypeScript's `InjectionKey<T>` for type safety.

### 4.2 Renderless Components

**Use case**: Encapsulate complex stateful logic in a component while giving the caller full control over rendering via scoped slots (`v-slot`).

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

<!-- Usage -->
<FetchData url="/api/users" v-slot="{ data, loading }">
  <div v-if="loading">Loading…</div>
  <UserList v-else :users="data" />
</FetchData>
```

**Note**: In the Vue 3 era, composables typically replace renderless components. Prefer composables unless the logic truly needs to be passed around as a component.

### 4.3 Pinia Store Design

```ts
// stores/user.ts — recommended Setup Store style (mirrors Composables syntax)
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // state
  const user = ref(null)
  const token = ref(localStorage.getItem('token'))
  
  // getters
  const isLoggedIn = computed(() => !!token.value)
  const userName = computed(() => user.value?.name ?? 'Guest')
  
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

**When to create a store**: Only for state that is genuinely shared across multiple components or pages. Component-local state belongs in `ref` inside the component — **do not put it in a store**.

### 4.4 Observer / Event Bus (Avoid)

Vue 3 removed the global `$on`/`$emit` EventBus. **Use Pinia instead** for global event-like communication — trigger an action in the store and have other components watch the resulting state.

If you truly need a pub/sub mechanism, [mitt](https://github.com/developit/mitt) is a minimal option, but in most cases the need indicates a design problem. Consider whether a store would be a cleaner solution first.

---

## 5. SOLID Principles in Vue

| Principle | How It Manifests in Vue |
|---|---|
| **S** Single Responsibility | One component, one job. Anything over 200 lines should be split. |
| **O** Open/Closed | Slots and props let components be extended without modification. |
| **L** Liskov Substitution | A derived base component (e.g., `PrimaryButton`) should be usable wherever `BaseButton` is expected. |
| **I** Interface Segregation | Define precise prop types; avoid passing generic `Object`. |
| **D** Dependency Inversion | Components should depend on props/inject, not import specific stores directly (unless unavoidable). |

---

## 6. Performance Patterns

| Scenario | What to Use |
|---|---|
| Large lists (>100 items) | `v-memo` or a virtual list library (e.g., `vue-virtual-scroller`) |
| Expensive computation | `computed` (cached); avoid complex expressions directly in templates |
| Preventing unnecessary child re-renders | Precise prop types via `defineProps` + `v-once` for truly static content |
| Route-level lazy loading | `() => import('./Page.vue')` |
| On-demand component imports | `unplugin-vue-components` for auto-import |
| Image lazy loading | `<img loading="lazy">` or a dedicated library |

---

## 7. Anti-Pattern Checklist

| Anti-Pattern | Why It's a Problem |
|---|---|
| Writing new code with Options API | Mixing it with Composition API creates confusion across the team |
| Putting all state in Pinia | Bloats the store; local state should stay in the component |
| Composables without the `use` prefix | Breaks convention and hurts readability |
| Placing reactive logic in `utils/` | utils should be pure functions; reactive logic belongs in composables |
| Putting cross-page sub-components in `views/x/components/` | Anything shared across pages belongs in `src/components/` |
| Using `<script>` without the `setup` syntax sugar in new code | There is no good reason to skip `setup` in new code |
| Global EventBus abuse (overusing mitt) | State becomes impossible to trace; use Pinia instead |
| Components with 500+ lines in a single file | Must be split — extract sub-components and composables |
| Using `Object` as a prop type | Loses all type-checking benefits; define an explicit interface |
| `v-for` without `:key` or using index as key | Priority A rule; causes unnecessary full re-renders when order changes |
| Mutating props directly | Violates one-way data flow |
| Complex expressions in templates | Extract them as `computed` properties |
