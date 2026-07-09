---
name: Vue 3 Style Essentials (original distillation)
source: https://vuejs.org/style-guide/
note: Distilled from the official Vue Style Guide, focusing on the coding-convention layer — naming, component structure, templates, props, and scoped styles. Architecture patterns, Composables, Pinia, and SOLID are covered in the companion file.
companion: vue-patterns.md
---
<!-- GENERATED from core/references/vue-style.md — edit the core file and run node tools/generate.mjs; hand edits will be overwritten -->

# Vue 3 Style Essentials

`vue-patterns.md` covers architecture patterns and project organization. This file focuses on **coding conventions** — naming, component structure, template rules, and props — drawn from the official Priority A (Essential) and Priority B (Strongly Recommended) guidelines.

---

## 1. Component Naming

### Multi-Word Rule (Priority A)

Component names MUST consist of **two or more words** to avoid conflicts with native HTML elements.

```
✅ UserCard.vue / OrderList.vue / AppHeader.vue
❌ Card.vue / List.vue / Header.vue
```

### Casing Conventions

- **File names**: `PascalCase` (`UserCard.vue`)
- **Usage in templates**: New code should consistently use `<UserCard />`. Avoid mixing in kebab-case, which fragments team conventions.
- **Base components** (generic, lowest-level primitives) MUST share a common prefix: `BaseButton`, `BaseInput`, `BaseModal`
- **Singleton components** (appear only once globally) should be prefixed with `The`: `TheNavbar`, `TheSidebar`
- **Tightly coupled child components** should use the parent's name as a prefix: `UserList` → `UserListItem`, `UserListHeader`

### Naming Semantics

- Component names should be **nouns** that describe what the component *is*: `OrderTable`, `UserAvatar`
- Boolean props should use adjectives or past-participle verbs: `disabled`, `loading`, `isVisible`
- Event names should use kebab-case verb phrases: `update:modelValue`, `item-click`, `form-submit`

---

## 2. Single-File Component Block Order (Priority B)

The recommended block order inside an SFC is: `<script setup>` → `<template>` → `<style scoped>`.

```vue
<script setup lang="ts">
// 1. External imports
// 2. props / emits definitions
// 3. store / injections
// 4. Reactive state
// 5. Computed properties
// 6. Functions
// 7. Lifecycle hooks
</script>

<template>
  <!-- template -->
</template>

<style scoped>
/* styles */
</style>
```

Follow the same ordering inside `<script setup>` as well, so reviewers can navigate the file at a glance.

---

## 3. Props Definition Standards (Priority A)

### Always Include Types; Production Code Must Include Validation

```ts
// ✅ Recommended: TypeScript generic syntax (Vue 3.3+)
interface Props {
  userId: string
  userName: string
  age?: number
  role: 'admin' | 'user' | 'guest'
}
const props = defineProps<Props>()

// ✅ When runtime validation or default values are needed (Options-style)
defineProps({
  userId: { type: String, required: true },
  age:    { type: Number, default: 0 },
})

// ❌ Array syntax — no type information at all
defineProps(['userId', 'userName'])
```

### Define in camelCase, Pass in kebab-case from Templates

```ts
// Definition
defineProps<{ greetingText: string }>()
```

```html
<!-- Parent passing the prop -->
<WelcomeBanner greeting-text="Hello" />
```

---

## 4. Template Writing Rules

### `v-for` Must Have `:key` (Priority A)

The key MUST be a **stable, unique identifier** (a business ID). Never use the loop index — when order changes, index-based keys trigger full re-renders.

```html
✅ <li v-for="item in list" :key="item.id">
❌ <li v-for="(item, i) in list" :key="i">
```

### NEVER Use `v-if` and `v-for` on the Same Element (Priority A)

`v-if` has higher precedence than `v-for`. When both are on the same element, `v-if` cannot access the loop variable, and the list is filtered on every render pass.

```html
<!-- ❌ Wrong -->
<li v-for="user in users" v-if="user.active" :key="user.id">

<!-- ✅ Filter first with a computed property -->
<li v-for="user in activeUsers" :key="user.id">
```

```ts
const activeUsers = computed(() => users.value.filter(u => u.active))
```

### `v-if` / `v-else-if` / `v-else` Chains

Make sure adjacent branches each have a unique `key`; otherwise Vue will reuse DOM nodes across branches and leave stale state behind:

```html
<input v-if="loginType === 'username'" key="username-input" placeholder="Username" />
<input v-else key="email-input" placeholder="Email" />
```

### Attribute Ordering (Priority B)

Arrange template attributes in the following order for easy scanning:

1. `v-if` / `v-show` (render condition)
2. `v-for` + `:key`
3. `id` / `ref` / `name`
4. `v-bind` / `:prop` (data bindings)
5. `v-model`
6. `v-on` / `@event` (event listeners)
7. `v-slot`

---

## 5. Component Communication Standards

### One-Way Data Flow (Priority A)

- Parent → Child: props
- Child → Parent: `emit`
- **NEVER mutate props directly.** Emit an event and let the parent handle the update, or use a `computed` setter.

```ts
// ❌ Direct mutation
props.count++

// ✅ Notify the parent via emit
emit('update:count', props.count + 1)
```

### `v-model` Naming (Vue 3)

When a component has multiple `v-model` bindings, name them explicitly. Do not stack multiple unnamed two-way bindings on a single component.

```html
<UserForm v-model:name="userName" v-model:email="userEmail" />
```

### Emit Definitions Must Be Explicit (Priority A)

```ts
// ✅ Explicit declaration — IDE navigation and type safety both work
const emit = defineEmits<{
  'update:modelValue': [value: string]
  'submit': [form: FormData]
  'cancel': []
}>()
```

---

## 6. Scoped Styles (Priority B)

- Component styles should **use `scoped` by default** to prevent global CSS leakage.
- When you need to target child component internals, use `:deep()` — do not remove `scoped`.
- Global styles (theme variables, resets) belong in `src/styles/` and should never be written inside a `scoped` block.

```vue
<style scoped>
/* Component-local styles */
.card { border: 1px solid #eee; }

/* Penetrate child component internals (e.g., Element Plus nodes) */
:deep(.el-input__inner) { border-radius: 4px; }
</style>
```

- CSS class names should use kebab-case: `.user-card`, `.form-label`

---

## 7. Other High-Frequency Rules (Priority A/B Highlights)

| Rule | Details |
|---|---|
| Self-close empty components | Use `<UserCard />` instead of `<UserCard></UserCard>` |
| No complex expressions in templates | If it involves more than one ternary or method call, extract a `computed` |
| One component per file | Do not define multiple components in a single `.vue` file — it makes debugging painful |
| Minimize `defineExpose` | Only expose methods that external callers genuinely need; do not expose everything |
| Avoid `$parent` / `$root` | Tight coupling; use `provide`/`inject` or `emit` instead |
| Use path aliases for imports | `@/components/...` not `../../components/...` |

---

## 8. Division of Responsibility with vue-patterns.md

| Topic | Where to Look |
|---|---|
| Component naming, props, template rules | **This file** |
| Composables design and reuse | vue-patterns.md |
| Pinia store structure | vue-patterns.md |
| Directory structure conventions | vue-patterns.md |
| SOLID / performance patterns | vue-patterns.md |
| `provide`/`inject` for deep passing | vue-patterns.md |
