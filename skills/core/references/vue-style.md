---
name: Vue 3 风格要点（自有提炼）
source: https://vuejs.org/style-guide/
note: 基于 Vue 官方 Style Guide 理解自行提炼，聚焦命名/模板/props/scoped 等编码规范层；架构模式/Composables/Pinia/SOLID 见 companion
companion: vue-patterns.md
---

# Vue 3 风格要点（自有提炼）

`vue-patterns.md` 覆盖架构模式和项目组织；本文件聚焦**编码规范层**——命名、组件结构、模板写法、props 定义，对应官方 Priority A（必须）和 Priority B（强烈推荐）的精华。

---

## 1. 组件命名

### 多词原则（Priority A）

组件名必须由**两个以上单词**组成，防止与 HTML 原生元素冲突。

```
✅ UserCard.vue / OrderList.vue / AppHeader.vue
❌ Card.vue / List.vue / Header.vue
```

### 大小写约定

- **文件名**：`PascalCase`（`UserCard.vue`）
- **模板中引用**：新代码统一 `<UserCard />`，避免 kebab-case 混用导致团队规范割裂
- **Base 组件**（通用基础组件）统一加前缀：`BaseButton`、`BaseInput`、`BaseModal`
- **单例组件**（全局只出现一次）加 `The` 前缀：`TheNavbar`、`TheSidebar`
- **父子强关联组件**用父名作前缀：`UserList` → `UserListItem`、`UserListHeader`

### 命名语义

- 组件名用**名词**（描述是什么）：`OrderTable`、`UserAvatar`
- 布尔 props 用形容词/动词过去式：`disabled`、`loading`、`isVisible`
- 事件名用 kebab-case 动词短语：`update:modelValue`、`item-click`、`form-submit`

---

## 2. 单文件组件结构顺序（Priority B）

SFC 内部顺序建议：`<script setup>` → `<template>` → `<style scoped>`。

```vue
<script setup lang="ts">
// 1. 外部导入
// 2. props / emits 定义
// 3. store / 注入
// 4. 响应式状态
// 5. computed
// 6. 函数
// 7. lifecycle hooks
</script>

<template>
  <!-- 模板 -->
</template>

<style scoped>
/* 样式 */
</style>
```

`<script setup>` 内部亦按以上顺序书写，让 reviewer 能快速定位。

---

## 3. Props 定义规范（Priority A）

### 必须带类型，生产代码必须带校验

```ts
// ✅ 推荐：TypeScript 泛型写法（Vue 3.3+）
interface Props {
  userId: string
  userName: string
  age?: number
  role: 'admin' | 'user' | 'guest'
}
const props = defineProps<Props>()

// ✅ 如需运行时校验 / 默认值（Options 风格）
defineProps({
  userId: { type: String, required: true },
  age:    { type: Number, default: 0 },
})

// ❌ 纯数组声明，无类型信息
defineProps(['userId', 'userName'])
```

### camelCase 定义，模板里 kebab-case 传入

```ts
// 定义
defineProps<{ greetingText: string }>()
```

```html
<!-- 父组件传入 -->
<WelcomeBanner greeting-text="Hello" />
```

---

## 4. 模板写法要点

### v-for 必须绑定 `:key`（Priority A）

key 应为**稳定唯一标识**（业务 ID），不要用循环 index（顺序变化会触发全量重渲染）。

```html
✅ <li v-for="item in list" :key="item.id">
❌ <li v-for="(item, i) in list" :key="i">
```

### 不在同一元素上同时使用 `v-if` 和 `v-for`（Priority A）

`v-if` 优先级高于 `v-for`，同元素并存会导致 `v-if` 访问不到循环变量，且每次渲染都重新过滤。

```html
<!-- ❌ 错误写法 -->
<li v-for="user in users" v-if="user.active" :key="user.id">

<!-- ✅ 先用 computed 过滤 -->
<li v-for="user in activeUsers" :key="user.id">
```

```ts
const activeUsers = computed(() => users.value.filter(u => u.active))
```

### `v-if` / `v-else-if` / `v-else` 链

确保相邻分支都有唯一 `key`，否则 Vue 会复用 DOM 节点导致状态残留：

```html
<input v-if="loginType === 'username'" key="username-input" placeholder="用户名" />
<input v-else key="email-input" placeholder="邮箱" />
```

### 属性顺序建议（Priority B）

模板属性推荐按以下顺序排列，方便扫描：

1. `v-if` / `v-show`（渲染条件）
2. `v-for` + `:key`
3. `id` / `ref` / `name`
4. `v-bind` / `:prop`（数据绑定）
5. `v-model`
6. `v-on` / `@event`（事件）
7. `v-slot`

---

## 5. 组件通信规范

### 单向数据流（Priority A）

- 父 → 子：props
- 子 → 父：`emit`
- **禁止直接修改 props**，应 emit 事件由父处理，或用 `computed setter`

```ts
// ❌ 直接修改
props.count++

// ✅ emit 通知父组件
emit('update:count', props.count + 1)
```

### `v-model` 命名（Vue 3）

多个 v-model 时显式命名，不要堆一个组件多个匿名双绑：

```html
<UserForm v-model:name="userName" v-model:email="userEmail" />
```

### Emit 定义要完整（Priority A）

```ts
// ✅ 显式声明，IDE 可跳转，类型安全
const emit = defineEmits<{
  'update:modelValue': [value: string]
  'submit': [form: FormData]
  'cancel': []
}>()
```

---

## 6. Scoped 样式（Priority B）

- 组件样式**默认加 `scoped`**，防止全局污染
- 需要穿透子组件时用 `:deep()`，不要去掉 scoped
- 全局样式（主题变量、reset）放 `src/styles/`，不要写在 scoped 块里

```vue
<style scoped>
/* 本组件样式 */
.card { border: 1px solid #eee; }

/* 穿透子组件（如 Element Plus 内部节点）*/
:deep(.el-input__inner) { border-radius: 4px; }
</style>
```

- CSS 类名用 kebab-case：`.user-card`、`.form-label`

---

## 7. 其他高频规则（Priority A/B 精华）

| 规则 | 说明 |
|---|---|
| 自闭合无内容组件 | `<UserCard />` 而非 `<UserCard></UserCard>` |
| 模板内不写复杂表达式 | 超过一个三目/方法调用就拆 computed |
| 组件文件一个组件 | 不在同一 `.vue` 文件定义多个组件（调试难）|
| `defineExpose` 最小化 | 只暴露外部真正需要调用的方法，不全量 expose |
| 避免 `$parent` / `$root` | 耦合强，改用 provide/inject 或 emit |
| 引入路径用别名 | `@/components/...` 而非 `../../components/...` |

---

## 8. 与 vue-patterns.md 分工

| 话题 | 看哪个文件 |
|---|---|
| 组件命名、props 写法、模板规则 | **本文件** |
| Composables 设计与复用 | vue-patterns.md |
| Pinia Store 结构 | vue-patterns.md |
| 目录结构约定 | vue-patterns.md |
| SOLID / 性能模式 | vue-patterns.md |
| provide/inject 深层传递 | vue-patterns.md |
