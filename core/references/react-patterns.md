---
name: React Engineering & Design Patterns (China Mainstream Edition)
companion: bulletproof-react.md (international community fork, used as a modernization upgrade reference) + js-style.md / ts-conventions.md
note: This document focuses on how React projects are organized in the Chinese ecosystem. For general syntax / naming / TypeScript rules, see google-ts-style.md.
---

# React Engineering & Design Patterns (China Production-Oriented)

The React ecosystem in China differs dramatically from the international community. Bulletproof-React / Zustand / TanStack are the internationally recommended defaults, but 80%+ of React projects in China — especially admin dashboards and internal tools — run on the Alibaba de-facto standard: **Umi + Ant Design + dva/RTK**. This document treats the Chinese mainstream as the **default recommendation**, with the international stack covered as an optional upgrade path.

`bulletproof-react.md` is the international reference; this document covers China-specific decision-making, design patterns, and anti-patterns.

---

## 1. React Project Type Distribution in China (Prerequisite Context)

Ordered by frequency:

| Type | Estimated Share | Typical Use Cases | Primary Stack |
|---|---|---|---|
| **Enterprise admin dashboards** (admin / management systems / SaaS) | ~60% | OA, CRM, data platforms, internal tools | **Umi + Ant Design Pro + dva** |
| **Mobile H5** (campaign pages, marketing, official sites) | ~20% | e-commerce campaigns, landing pages, lightweight apps | Vite + React + lightweight UI |
| **Mini programs / cross-platform** (WeChat / Douyin / JD, etc.) | ~15% | storefronts, utility mini programs | **Taro** |
| **SSR / full-stack** (Next.js / Umi SSR) | ~5% | content sites, SEO requirements | Umi SSR > Next.js (Next.js has limited GFW impact but weaker domestic ecosystem) |

**Key facts**:

- React projects in China ≈ admin dashboard projects. "React engineering" in the Chinese context defaults to **admin dashboard engineering**
- High-performance consumer-facing products still lean heavily toward Vue (Evan You's influence in China + some ByteDance teams' preference)
- React 19 adoption is low domestically; a large installed base of React 17 / 18 projects exists; Class Component legacy projects still represent a significant portion

---

## 2. Default Stack Choices (China Mainstream, 2026)

### 2.1 Admin Dashboards (Primary Use Case)

| Dimension | China Mainstream | International Reference (Upgrade Path) |
|---|---|---|
| Framework | **UmiJS 4** (by Alibaba / Ant Design Pro default) | Vite + React Router |
| Scaffold | **Ant Design Pro** | create-vite + manual setup |
| Routing | Umi convention-based routing (auto-mapped from `src/pages/`) | TanStack Router |
| UI library | **Ant Design 5** + **Pro Components** | shadcn/ui / Radix |
| Data layer | **dva** (built into Umi) / **@umijs/max** model | Zustand / Jotai |
| Data fetching | **umi-request** / **axios** + Pro Service conventions | TanStack Query |
| Forms | **Ant Design Form** + `ProForm` | react-hook-form + zod |
| Tables | **ProTable** (killer feature) | TanStack Table |
| Charts | **AntV G2 / G6 / X6** | Recharts / D3 |
| Styling | Less / CSS Modules (Umi default) | Tailwind CSS |
| Build | Umi built-in (Vite / Webpack switchable) | Vite |
| Types | TypeScript (Ant Design Pro 5+ default) | same |
| Testing | Jest + RTL (Umi built-in) | Vitest + RTL |

### 2.2 Mobile H5

| Dimension | China Mainstream | Notes |
|---|---|---|
| Build | **Vite** | new projects |
| UI | **Vant** (Youzan) / **NutUI** (JD.com) / **Antd Mobile** | the three major mobile UI libraries |
| Routing | React Router v6 | simple and sufficient |
| State | useState + Context / Zustand | no need for dva |
| Data fetching | axios + custom hooks | TanStack Query optional |
| Compatibility | Focus on iOS Safari / WeChat in-app browser | mandatory for China |

### 2.3 Mini Programs / Cross-Platform

- **Taro** (JD.com open source) — the de-facto domestic standard; one React codebase compiles to WeChat / Alipay / Douyin / JD / Baidu / QQ / HarmonyOS / H5 / RN
- **Remax** (Ant Group) — largely inactive now; exists mainly in legacy projects
- **uni-app (Vue ecosystem)** — strongest cross-platform coverage but Vue-based; React teams generally avoid it

### 2.4 Avoid in New Projects

- `create-react-app` (deprecated)
- Webpack 4 / Babel 6 legacy configs
- Class Components (legacy projects only)
- Standalone dva package (use `@umijs/max` built-in model instead — equivalent but requires less configuration)
- Arco Design (**ByteDance has effectively halted official maintenance**; since 2025 the community has reported accumulating issues and departing core contributors — not recommended for new projects)
- Next.js (unless explicitly targeting Vercel / international deployment; Umi SSR has better domestic ecosystem integration)
- styled-components (virtually unused in China; Less / CSS Modules dominate by a wide margin)

---

## 3. Standard Directory Structure for Chinese Admin Dashboards (Umi + Ant Design Pro Conventions)

```
src/
├── pages/                    ← ★ Convention-based routing (Umi core)
│   ├── index.tsx             →  /
│   ├── user/
│   │   ├── list.tsx          →  /user/list
│   │   ├── detail.[id].tsx   →  /user/detail/:id
│   │   └── components/       page-specific components
│   └── 404.tsx
├── components/               ← Cross-page reusable components (flat by layer)
│   ├── RightContent/
│   ├── HeaderDropdown/
│   └── Footer/
├── services/                 ← ★ API layer (organized by business domain)
│   ├── user.ts               all user-related API calls
│   ├── order.ts
│   └── typings.d.ts          API type definitions
├── models/                   ← ★ dva / @umijs/max models
│   ├── user.ts               global user state
│   └── global.ts             global configuration state
├── layouts/                  ← layout components
│   └── BasicLayout.tsx
├── utils/                    ← pure utility functions
├── hooks/                    ← cross-page hooks
├── constants/                ← enums / constants
├── locales/                  ← i18n (zh-CN / en-US)
├── assets/                   ← images / fonts
├── access.ts                 ← Umi access control config
├── app.tsx                   ← Umi runtime config (request interceptors, layout, initial data)
├── global.less
└── typings.d.ts

config/
├── config.ts                 ← Umi main config
├── routes.ts                 ← route config (or use convention-based routing)
├── proxy.ts                  ← local dev proxy
└── defaultSettings.ts        ← Pro Layout config
```

**The defining characteristic of Chinese directory structures**: **flat-by-layer** (pages / services / models / components) rather than Bulletproof's **feature-based splitting**. Reasons:

1. **Umi convention-based routing hard-codes `src/pages/`** — the framework dictates the entry point
2. **Ant Design Pro scaffolds use this exact structure** — low onboarding cost for new team members
3. **Business boundaries in Chinese admin systems are blurry** — feature-based splitting often makes maintenance harder, since features call into each other frequently
4. **All major vendor internal templates use the layered approach** — Alibaba / Ant Group internal templates follow these conventions

> The Bulletproof `features/` structure is more "architecturally correct" but is broadly **rejected by Chinese teams** — unfamiliar to new hires, mismatched with scaffolding, and out of step with Alibaba's official documentation. Only consider migrating to feature-based structure for large-scale SaaS / long-lived projects with experienced React engineers at the helm.

---

## 4. Chinese Mobile H5 Project Structure

H5 projects should stay lean — do not use Umi:

```
src/
├── pages/                    ← flat by page
│   ├── Home/
│   │   ├── index.tsx
│   │   ├── index.module.less
│   │   └── components/
│   └── Order/
├── components/               ← shared components
├── api/                      ← API wrappers (calling it "services" is fine too)
├── hooks/
├── utils/
├── store/                    ← Zustand / simple Context
├── styles/
│   ├── reset.less
│   └── variables.less
├── App.tsx
└── main.tsx                  ← Vite entry point
```

**H5 priorities**:

- Initial bundle size (route lazy loading + Vant tree-shaking)
- Viewport scaling (rem / vw) — `postcss-pxtorem`
- WeChat in-app browser compatibility (many iOS WKWebView pitfalls)
- NEVER use Umi for H5 (overkill; slower builds)

---

## 5. Taro Cross-Platform Project Structure

```
src/
├── pages/
│   ├── index/
│   │   ├── index.tsx
│   │   ├── index.config.ts   ← mini program page config (nav bar, tabBar)
│   │   └── index.less
├── components/
├── services/
├── store/
├── utils/
├── app.tsx                   ← app entry point
├── app.config.ts             ← global config (pages list, tabBar)
└── app.less
config/
├── index.ts
├── dev.ts
└── prod.ts
```

**Key Taro conventions**:

- Every page MUST have a `.config.ts` (native mini program requirement)
- Use `Taro.request` or a wrapper — do not use `fetch` directly
- DOM APIs are unavailable (mini programs have no `window` / `document`)
- Use `rpx` units or configure `pxTransform`
- React syntax is mostly identical, but **always check Taro docs for event names** (`onClick` is automatically mapped to `bindtap` in mini programs)

Cross-platform compatibility requires **conditional compilation**:

```typescript
if (process.env.TARO_ENV === 'weapp') {
  // WeChat-specific logic
} else if (process.env.TARO_ENV === 'h5') {
  // H5-specific logic
}
```

---

## 6. dva / @umijs/max Model (Core Data Layer for Chinese Admin Dashboards)

Umi 4 + `@umijs/max` ships a built-in model solution — a streamlined version of dva. This is **the absolute default for state management in Chinese admin dashboards**.

```typescript
// src/models/user.ts
import { useState, useCallback } from 'react'

export default function useUserModel() {
  const [currentUser, setCurrentUser] = useState<API.User | null>(null)
  const [loading, setLoading] = useState(false)

  const fetchUser = useCallback(async () => {
    setLoading(true)
    try {
      const user = await services.getCurrentUser()
      setCurrentUser(user)
    } finally {
      setLoading(false)
    }
  }, [])

  return { currentUser, loading, fetchUser }
}
```

```typescript
// consuming the model in any component
import { useModel } from '@umijs/max'

function Header() {
  const { currentUser, loading } = useModel('user')
  return <div>{currentUser?.name}</div>
}
```

**Differences from traditional dva**:

- No more `namespace / state / effects / reducers` boilerplate
- A model is just a hook — pure React mental model
- Legacy dva projects can keep using the `dva` package; new projects should use `@umijs/max` model directly

**When traditional dva still makes sense**: the codebase already has substantial dva code, the team is familiar with redux-saga, or strict action audit logging is required.

---

## 7. Ant Design in Practice

### 7.1 Forms (99% of Chinese projects use AntD Form; react-hook-form adoption is < 5%)

```typescript
// ✅ Recommended: ProForm (the killer feature for admin dashboards)
import { ProForm, ProFormText, ProFormSelect } from '@ant-design/pro-components'

<ProForm
  onFinish={async (values) => {
    await services.createUser(values)
    message.success('Submitted')
    return true
  }}
>
  <ProFormText name="name" label="Name" rules={[{ required: true }]} />
  <ProFormSelect
    name="role"
    label="Role"
    request={async () => services.getRoleOptions()}  // remote data loading
  />
</ProForm>
```

```typescript
// ✅ Plain Form (consumer-facing / complex custom layouts)
const [form] = Form.useForm()

<Form form={form} layout="vertical" onFinish={onSubmit}>
  <Form.Item name="name" label="Name" rules={[{ required: true, message: 'Please enter' }]}>
    <Input />
  </Form.Item>
</Form>
```

### 7.2 ProTable (Standard for Admin Dashboards — Eliminates ~80% of Table Boilerplate)

```typescript
<ProTable<API.User>
  columns={columns}
  request={async (params) => {
    // params includes current / pageSize / search fields
    const { data, total } = await services.queryUsers(params)
    return { data, total, success: true }
  }}
  rowKey="id"
  search={{ labelWidth: 'auto' }}
  toolBarRender={() => [<Button type="primary">New</Button>]}
/>
```

ProTable ships with built-in search forms, pagination, column visibility toggles, density controls, and export — **not using ProTable in a Chinese admin dashboard is working against yourself**.

### 7.3 Global Configuration

```typescript
// app.tsx
import zhCN from 'antd/locale/zh_CN'
import { ConfigProvider } from 'antd'

export function rootContainer(container) {
  return <ConfigProvider locale={zhCN} theme={{ token: { colorPrimary: '#1677ff' } }}>{container}</ConfigProvider>
}
```

---

## 8. Custom Hooks (Still a Core Pattern — Chinese Use Cases)

Common hooks in domestic projects:

```typescript
// 1. usePermission — RBAC access checks (extremely common in admin dashboards)
export function usePermission() {
  const { initialState } = useModel('@@initialState')
  const access = initialState?.currentUser?.access ?? []

  return {
    can: (code: string) => access.includes(code),
    canAny: (codes: string[]) => codes.some(c => access.includes(c)),
  }
}

// 2. useUrlState — sync table filter state to the URL (prevents state loss on page refresh)
import { useUrlState } from 'ahooks'

const [filter, setFilter] = useUrlState({ status: 'all', page: 1 })

// 3. useRequest (by ahooks — the de-facto standard for data fetching in Chinese admin dashboards)
import { useRequest } from 'ahooks'

const { data, loading, run, refresh } = useRequest(
  (id) => services.getUserDetail(id),
  { manual: true, debounceWait: 300 }
)
```

**ahooks** (by Alibaba) has extremely high adoption in China. It includes `useRequest`, `useDebounce`, `useUrlState`, `useAntdTable`, and 60+ other hooks. It is **the Swiss Army knife of Chinese React projects** — occupying a role similar to lodash.

### When to Extract a Hook

| Scenario | Extract? |
|---|---|
| Same reactive logic needed across multiple components | ✅ MUST |
| Single component exceeds 300 lines | ✅ extract |
| Logic involves coordinating multiple lifecycle effects | ✅ hooks are the only clean way |
| Pure computation (no state / effects) | ❌ put it in `utils/` |
| One-off logic with no reuse | ❌ keep it inline in the component |

---

## 9. State Management Decision Matrix (China Production Edition)

```
State category:
├── Server data (API responses)
│   ├── Admin dashboards → ahooks useRequest / ProTable.request
│   └── International upgrade path → TanStack Query / SWR
├── Global client state (user, theme, menu, permissions)
│   ├── Admin dashboards → @umijs/max model / dva
│   ├── H5 / Taro → Zustand (lightweight enough)
│   └── Large legacy codebases → Redux Toolkit
├── Local component state / forms → useState / AntD Form
└── URL state → useUrlState / route params
```

**Common anti-patterns in China**:

- Not using `ProTable.request` in admin dashboards, and instead manually managing list data with `useEffect + setState`
- Stuffing all state into dva models, including ephemeral state that only one page uses
- Models importing from each other, creating circular dependencies
- Using Redux without RTK, resulting in forests of `actionType` string constants

---

## 10. Design Patterns (Adapted for Chinese Use Cases)

| Pattern | Status | Typical Chinese Usage |
|---|---|---|
| **Custom Hooks** | ✅ Core | 90% of reuse scenarios; ahooks serves as the canonical reference |
| **Compound Components** | ✅ Still valuable | Used extensively inside Ant Design (Tabs / Form.Item / Select.Option) |
| **HOC** | ⚠️ Declining but still present | `withAuth` / dva's `connect()` |
| **Provider** | ✅ Use with care | `ConfigProvider` / theming; avoid for high-frequency values |
| **Render Props** | ❌ Obsolete | Replaced by hooks |
| **Container/Presenter** | ⚠️ Weakened | Hooks naturally provide the same layering |

### Compound Components — Chinese Example: ProTable Columns

```typescript
const columns: ProColumns<User>[] = [
  { title: 'Name', dataIndex: 'name', copyable: true },
  { title: 'Status', dataIndex: 'status', valueType: 'select', valueEnum: { 0: 'Disabled', 1: 'Enabled' } },
  {
    title: 'Actions',
    valueType: 'option',
    render: (_, record) => [
      <a key="edit" onClick={() => handleEdit(record)}>Edit</a>,
      <a key="del" onClick={() => handleDel(record)}>Delete</a>,
    ],
  },
]
```

`valueType` + `valueEnum` is the heart of Pro Components' "convention as configuration" model.

---

## 11. Anti-Pattern Catalog (Ordered by Frequency in Chinese Projects)

| Anti-pattern | Frequency | Consequence |
|---|---|---|
| **Bloated dva models** (single model with 1000+ lines / 50+ effects) | ★★★★★ | One change ripples everywhere; hot-reload cannot pinpoint the source |
| **AntD Form with more than 2 levels of Form.List nesting** | ★★★★★ | Performance collapse + impossible-to-write validation logic |
| **Ant Design wrapper components that get out of hand** (a `MyButton` with 50 overridden props) | ★★★★☆ | Every AntD upgrade nukes the whole site |
| **Complex data transforms inside ProTable `request`** | ★★★★☆ | Sorting / pagination parameters get mangled |
| **Splitting `services` files by page** (`pages/user/services.ts`) | ★★★★☆ | API reuse becomes painful; caching / mock configs are scattered |
| **Chained `useEffect` dependencies** (A triggers B, B triggers C, C triggers A) | ★★★★☆ | Infinite loops / impossible to trace |
| **dva `connect` on every component** (pulling global state that doesn't need it) | ★★★★ | Any global state change triggers a massive re-render wave |
| **Manual `setState` validation instead of ProForm / Form's built-in validation** | ★★★★ | Reinventing the wheel inconsistently |
| **Storing server data in dva** (manual cache + invalidation logic) | ★★★ | Reimplementing useRequest by hand |
| **Mixing Class Components with Hooks** | ★★★ | Confused team conventions; rampant in legacy projects |
| **Context managing high-frequency updates** (mouse position, scroll position) | ★★★ | Full tree re-renders on every update |
| **Props drilling more than 3 levels deep** | ★★★ | Refactoring cost escalates sharply |
| **`key={index}` on lists** | ★★★ | The classic reorder bug |
| **`useEffect` without cleanup** | ★★ | Memory leaks |
| **Redux without RTK, using raw `createStore`** | ★★ | Boilerplate hell |
| **Cross-page imports of `pages/xxx/components/Foo`** | ★★ | Breaks routing decoupling; makes refactoring painful |
| **`React.FC` in new code** | ★ | Breaks generics; officially discouraged |

---

## 12. Performance Patterns (Chinese Admin Dashboard Priorities)

| Scenario | Approach |
|---|---|
| Large tables (> 500 rows) | Virtual scrolling (rc-virtual-list / ProTable with `scroll.y`) |
| Long Form.List forms | Split into sub-components + `React.memo` to avoid whole-form re-renders |
| Route-level lazy loading | Umi auto code-splitting + `dynamic()`; for non-Umi projects use `lazy()` |
| AntD tree-shaking | Umi / Ant Design Pro enables babel-plugin-import by default |
| Charts | AntV G2 with tree-shaking; large datasets with G2 + Web Worker |
| Preventing re-renders | `React.memo` + stable references; ahooks `useMemoizedFn` |
| Static assets | Alibaba Cloud OSS / Tencent Cloud COS + CDN; never import large images directly |

**React 19 Compiler adoption in China is negligible** — most projects still require manual `useMemo / useCallback`.

---

## 13. SOLID Principles in React (Condensed)

| Principle | React Expression |
|---|---|
| S — Single Responsibility | One component, one concern; split at 300+ lines |
| O — Open/Closed | Extend via props + slot-style children; ProComponents `fieldProps` pattern |
| L — Liskov Substitution | Derived components should be substitutable for their base component |
| I — Interface Segregation | Precise props; avoid `Record<string, any>` |
| D — Dependency Inversion | Components depend on props / hooks, not direct imports of concrete models |

---

## 14. International Stack Migration Reference

> When should a Chinese project consider switching to the international stack (Bulletproof + Zustand + TanStack)?

**Good reasons to switch**:

- Brand-new long-lived project with experienced React engineers on the team
- International deployment, primarily serving overseas users
- Strong type-safety requirements (TanStack Router's typed routing is a clear win)
- Breaking away from Ant Design's visual language (consumer-facing brand customization)

**Reasons not to switch**:

- Admin dashboard + Ant Design design specs (no real benefit to migrating)
- Team consists mainly of backend developers doing some frontend work, or junior engineers (Umi's Chinese documentation is comprehensive)
- Short project timeline (< 3 months)
- Requires ProTable / ProForm-level business components (building equivalents from scratch is extremely costly)

**Incremental modernization**: gradually introducing TanStack Query inside a Umi project to replace the server-data parts of dva is a common pragmatic upgrade path in China.

---

## 15. How Major Chinese Tech Companies Approach React (Overview)

| Company | Primary Stack | Notes |
|---|---|---|
| Alibaba | **Umi + Ant Design + dva/RTK** | Ant Design originates from Ant Group; the de-facto standard |
| ByteDance | **Modern.js** (in-house full-stack framework) + Semi Design | Arco maintenance has stalled; internal teams are shifting to Semi |
| Tencent | TDesign + open stack | Each BG operates independently; no unified stack |
| JD.com | **Taro** (in-house open source) + NutUI | Mini program business is the primary focus |
| Baidu | In-house frameworks + Ant Design Pro | Admin dashboard mainstream |
| Meituan | Mtfe (internal) + Ant Design | Strict internal framework conventions |

**Practical conclusion**: unless you're joining a specific company and adopting their internal stack, **Umi + Ant Design Pro is still the most universally applicable choice in the general hiring market**.

---

## 16. React 19 in China — Current State

- Adoption is low; as of Q1 2026, fewer than 20% of new domestic projects use React 19
- Primary blockers: Ant Design 5's React 19 strict mode compatibility is still catching up; enterprise projects are conservative about upgrades
- **The most-used new API is `use(promise)`**, followed by `useActionState`
- React Compiler has virtually no adoption (insufficient ecosystem support)
- Legacy codebases run primarily on React 17 / 18, with dva / Umi 3 still under maintenance

```typescript
// React 19 new APIs (optional for domestic projects)
const value = use(promise)                              // ✅ practical
const [error, action, pending] = useActionState(...)   // ⚠️ AntD Form already covers this use case
const [optimistic, addOptimistic] = useOptimistic(...) // ⚠️ niche
```

If your project is still on React 18, there is no need to upgrade just to access the new APIs.

---

## 17. Authoritative Sources

China mainstream:

- [UmiJS Official Docs](https://umijs.org/) — Alibaba's React application framework
- [Ant Design](https://ant.design/) — the de-facto standard UI library for Chinese admin dashboards
- [Ant Design Pro](https://pro.ant.design/) — admin dashboard scaffold
- [Pro Components](https://procomponents.ant.design/) — ProTable / ProForm and more
- [ahooks](https://ahooks.js.org/) — Alibaba's React Hooks library
- [Taro](https://taro.zone/) — JD.com cross-platform framework
- [AntV](https://antv.antgroup.com/) — Ant Group data visualization
- [Semi Design](https://semi.design/) — ByteDance / Douyin frontend component library

International reference (upgrade path):

- [Bulletproof-React](https://github.com/alan2207/bulletproof-react) — the `bulletproof-react.md` in this directory is forked from here
- [React Official Docs](https://react.dev/)
- [TanStack Router / Query](https://tanstack.com/)
- [Zustand](https://github.com/pmndrs/zustand)

---

## 18. One-Line Summary

**React in China = admin dashboard React = Umi + Ant Design Pro + Pro Components + dva/Max model + ahooks**. Without fluency in this stack, you cannot work on most domestic projects. Bulletproof / Zustand / TanStack are all excellent — but get comfortable with the Chinese mainstream first, then talk about upgrading.
