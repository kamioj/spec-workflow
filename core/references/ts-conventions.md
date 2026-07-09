---
name: TypeScript Engineering Decisions (Practical Edition)
companion: google-ts-style.md (a fork of Google TS style adapted for the Alibaba ecosystem, serving as the coding layer)
note: This file focuses on "how projects are actually run in practice." Internationally recommended best practices are listed at the end of each section for reference.
audience: Vue 3 + Java full-stack, domestic mid/back-office SaaS and business projects
---

# TypeScript Engineering Decisions (Practical Edition)

`google-ts-style.md` covers syntax and coding conventions; this file covers engineering decisions — tsconfig strictness levels, type architecture, runtime validation, Vue 3 in practice, and incremental migration.

**Stance**: recommendations here reflect what most teams actually do in real Vue 3 mid/back-office projects. Ideal practices from the official docs and international community are listed as reference points. **No moral judgments are made** — `any` is heavily used in domestic business codebases, and this document acknowledges that reality while providing an actionable path toward convergence.

---

## 0. State of the Industry (Understand the Reality Before Setting Standards)

| Dimension | Typical domestic mid/back-office | International (Vercel / Stripe / Linear style) |
|---|---|---|
| `strict` fully enabled | ~50% of projects, but `strictFunctionTypes` is often disabled | Enabled by default |
| `noUncheckedIndexedAccess` | <10% enabled | Recommended to enable |
| `any` usage | Frequent — the default escape hatch under deadline pressure | Treated as a code smell; blocked in PR review |
| Type sources | Hand-copied from Swagger/API docs, or tool-generated | tRPC / GraphQL Codegen / OpenAPI typegen |
| Runtime validation | Virtually absent; the backend is expected to catch issues; forms use `async-validator` (bundled with Element/AntDV) | Zod / Valibot widely adopted |
| Module system | CJS still dominates legacy projects; new projects use ESM | ESM has converged |
| Type checking | Vite dev skips it; CI uses `vue-tsc --noEmit` as a safety net | Same |
| Primary templates | Vben Admin / Soybean Admin / Youlaи / RuoYi-Vue3 | T3 stack / Next.js + Drizzle |

**Core tension**: Uneven team skill levels, high delivery pressure, and unreliable backend types (API contracts change frequently) all push teams to compromise on strict TypeScript. The goal of this guide is to **help teams converge incrementally at an acceptable cost** — not to mandate engineering purity in one sweep.

---

## 1. tsconfig Strictness: Three Tiers (Choose Based on Team Maturity)

Domestic projects span a wide range of states. Do not force a single config across the board. Assess your team first, then pick a tier.

### Tier A: Lenient (Legacy projects / JS-to-TS migration in progress / junior-majority teams)

Use when: migrating from Vue 2 to Vue 3, converting from JS to TS, working on outsourced or forked projects, or teams of 5 or fewer. **The goal is just to get it running.**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": false,
    "noImplicitAny": false,        // ★ Key compromise: allow implicit any
    "allowJs": true,                // Allow .js files to coexist
    "checkJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "lib": ["ES2020", "DOM", "DOM.Iterable"]
  }
}
```

Note: this is not a "good" config — it is a "realistic" one. **At minimum, enable `isolatedModules` and `skipLibCheck`**: the former prevents Vite/esbuild from exploding, the latter lets compilation succeed even when third-party `.d.ts` files are broken.

### Tier B: Moderate (Mainstream domestic mid/back-office — Vben / Soybean style)

Use when: teams of 8–30 with dedicated frontend developers, new projects, and at least one year of TypeScript experience. **This is the most common configuration in domestic projects.**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",       // ★ Use Bundler for Vite projects, not NodeNext
    "strict": true,                       // ★ Enable strict
    "strictFunctionTypes": false,         // ★ Often disabled domestically: Vue component props need bivariant compatibility with legacy components
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,       // ★ Compatibility with legacy decorators (class-validator, etc.)
    "jsx": "preserve",
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] },
    "types": ["vite/client", "node"],
    "lib": ["ES2022", "DOM", "DOM.Iterable"]
  }
}
```

This aligns with the actual configs used by **Vben Admin / Soybean Admin**: `strict` on, `strictFunctionTypes` off, `noUncheckedIndexedAccess` off, `exactOptionalPropertyTypes` off. The reason: enabling those flags would produce 200+ errors in existing code that the team cannot immediately fix.

### Tier C: Strict (Engineering-focused domestic teams / international standard)

Use when: frontend teams of 30+, greenfield projects, a dedicated architect on the team, and willingness to pay the upfront cost of type safety.

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,        // Array/index access automatically includes undefined
    "exactOptionalPropertyTypes": true,      // Distinguishes { a?: T } from { a: T | undefined }
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "verbatimModuleSyntax": true,            // Enforces import type
    // ...rest same as Tier B
  }
}
```

**International recommendation (for reference)**: Matt Pocock / Total TypeScript recommends Tier C fully enabled, inheriting from `@tsconfig/strictest`. Few domestic projects can actually land on Tier C, because:
- `noUncheckedIndexedAccess` causes every `list[0].name` in existing code to error — you must add `?.` or assertions throughout
- `exactOptionalPropertyTypes` conflicts with the common pattern of passing `undefined` as a default prop value
- Steep learning curve for junior team members

### Migration Path (Incremental Strategy from A → C)

1. **Key switch for A → B**: Enable `strict` first. Expect 50–200 new errors. Allow temporary `// @ts-expect-error fix-later` annotations and track them on a migration board, resolving them gradually.
2. **Key switch for B → C**: Enable `noUncheckedIndexedAccess` first — it has the highest return on investment (prevents roughly 40% of out-of-bounds bugs). Save `exactOptionalPropertyTypes` for last.

---

## 2. `type` vs `interface`: Division of Responsibility

The **most common reality** in domestic projects: `interface` and `type` are used interchangeably throughout the same codebase, because different people wrote different modules, and templates like Vben/Soybean themselves mix the two. This creates inconsistency. Establish the following rule at project kickoff.

**Recommended division**:

| Use `interface` | Use `type` |
|---|---|
| Object shapes (entities, component Props, config) | Union types `A \| B` |
| Class contracts (`implements`) | Intersection types `A & B` |
| Anything that needs inheritance or declaration merging | Function signatures |
| Public API boundaries (error messages are more readable) | Utility type compositions: `Pick<>` / `Partial<>` |

```typescript
// ✅ Object shapes / class contracts → interface
interface User { id: string; name: string }
interface AdminUser extends User { perms: string[] }

// ✅ Unions / utility types → type
type Status = 'idle' | 'loading' | 'success' | 'error'
type UserResponse = Pick<User, 'id' | 'name'>
type EventHandler<T> = (e: T) => void
```

**Common anti-patterns in domestic projects** (by frequency):

1. **All backend fields defined as `interface` with every field marked `?:`** — to hedge against the uncertainty of "the backend might not return that field." The consequence is that every field access anywhere in the frontend requires `?.`. **Correct approach**: clearly distinguish "fields guaranteed by the API contract" from "nullable fields"; contain the uncertainty at the boundary (runtime validation) rather than spreading it through the entire type system.
2. **The same concept defined as both `interface UserVO` and `type UserDto`**: pick one and stay consistent.
3. **Using `type` for everything because "it looks shorter"**: `interface` produces more readable error messages; use it consistently for object shapes.

---

## 3. `any` / `unknown` / Type Assertions (The Biggest Problem Area)

**Acknowledge the reality**: `any` is heavily used in domestic business code. Reasons:
- Backend API response shapes are unstable; writing an `interface` against them risks constant breakage
- Legacy JS libraries without `@types` packages
- Deadline pressure — `as any` takes 5 seconds; writing correct types takes 5 minutes
- Junior team members don't know how to write complex types

**Convergence strategy (ordered by increasing effort)**:

```typescript
// Level 1 (worst): unchecked any
function handle(data: any) { return data.user.name }  // ❌ Type system is meaningless

// Level 2 (acceptable): unknown + type guard
function handle(data: unknown) {
  if (isUser(data)) return data.name  // ✅ At least forces a runtime check
}

// Level 3 (recommended): explicit interface + boundary validation
interface ApiResp { user: { name: string } }
function handle(data: ApiResp) { return data.user.name }
// Validate once at the call site (Zod / hand-written guard); use safely inside

// Level 4 (strict): Zod end-to-end inference
const RespSchema = z.object({ user: z.object({ name: z.string() }) })
type ApiResp = z.infer<typeof RespSchema>
```

**Practical recommendations for projects**:
- Ban `as any`; use `as unknown as T` instead (it's uglier on purpose — the extra step signals that this is an intentional escape).
- Use `// @ts-expect-error <reason>` instead of `// @ts-ignore`: when the TypeScript version is upgraded, stale suppressions will be flagged, preventing them from accumulating silently.
- ESLint rule: set `@typescript-eslint/no-explicit-any` to `warn`, not `error`. Setting it to `error` causes developers to disable the entire line, making violations invisible. Run periodic counts and chip away at them.
- Use `unknown` at API boundaries to force callers to validate before accessing fields.

**International recommendation (for reference)**: the `@typescript-eslint/strict-type-checked` config bans `any` outright, including `as any`. Few domestic projects can adopt this because the existing `any` backlog is so large that CI turns entirely red.

---

## 4. Runtime Validation: Current State and Rolling Out Zod

**Current state (honest assessment)**:
- 90% of form validation uses **`async-validator`** (bundled with Element Plus / Ant Design Vue) — but it **only validates form input, not types**.
- API responses are almost never validated at runtime; the frontend "trusts the Swagger docs" — and gets burned frequently.
- Zod penetration in domestic projects grew quickly from 2024–2026, but remains concentrated mainly in larger companies, overseas-facing products, and greenfield projects.
- Most teams **have never heard of Valibot / ArkType**.

**Recommended selection by use case**:

| Scenario | Domestic recommendation | International recommendation |
|---|---|---|
| Form validation (user input) | `async-validator` (built into UI library `rules`) | Zod + vee-validate |
| API response validation (new projects) | **Zod** (at boundaries; roll out incrementally) | Zod |
| API response validation (existing projects) | Don't force it; add it to critical endpoints first | Full coverage |
| Environment variables / config | Zod (trivially low cost — strongly recommended to add immediately) | Zod |
| Edge / browser bundle-size sensitive | Zod is fine | Valibot |

**How to adopt Zod in a Vue project**:

```typescript
// ✅ Validate once at the API boundary; use the inferred type everywhere inside
import { z } from 'zod'

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  age: z.number().int().nonnegative().optional(),
})
type User = z.infer<typeof UserSchema>  // ★ Do NOT hand-write interface User

export async function fetchUser(id: string): Promise<User> {
  const raw = await api.get(`/user/${id}`)
  return UserSchema.parse(raw)            // Hard validation at the boundary; throws on failure
  // Or use .safeParse() to get { success, data, error } when you don't want exceptions
}
```

```typescript
// ✅ Environment variable validation (lowest cost, highest payoff — add it now)
const Env = z.object({
  VITE_API_BASE: z.string().url(),
  VITE_APP_TITLE: z.string().min(1),
})
export const env = Env.parse(import.meta.env)
```

**A domestic-specific anti-pattern**: hand-writing `interface User`, then separately writing `userFormRules` (async-validator rules), and then having Swagger generate yet another `.d.ts` — three definitions of the same concept, where changing one and forgetting the others is almost guaranteed to cause bugs. **Zod inference is the single source of truth** and solves this problem.

---

## 5. Vue 3 + TypeScript in Practice (The Domestic Primary Battleground)

### 5.1 `<script setup lang="ts">` as Standard

```vue
<script setup lang="ts">
// ✅ Vue 3.3+ generic-style defineProps (recommended)
interface Props {
  user: User
  loading?: boolean
}
const props = defineProps<Props>()

// ✅ Vue 3.5+ destructured default values (replaces withDefaults)
const { user, loading = false } = defineProps<Props>()

// ✅ defineEmits with tuple syntax
const emit = defineEmits<{
  update: [value: User]
  cancel: []
}>()

// ✅ defineExpose + InstanceType to get the child component type
defineExpose({ refresh: () => {} })
</script>
```

**Common pitfalls in domestic projects**:
- **Vue 2 → Vue 3 migration projects**: still using `defineComponent({ props: {...} })` Options API, which has much weaker type inference than `setup`. Migration advice: write all new components with `setup`; convert old ones when they're touched for other reasons.
- **`ref` and generics**: write `const list = ref<User[]>([])` rather than `ref([])`, otherwise TypeScript infers `Ref<never[]>`.
- **`computed` return types**: annotate explicitly with `computed<T>(() => ...)` in complex cases.
- **`provide/inject` across components**: use `InjectionKey<T>` for strong typing; without it, `inject` returns `unknown`.

```typescript
import type { InjectionKey } from 'vue'
export const UserKey: InjectionKey<User> = Symbol('user')

// Usage
provide(UserKey, currentUser)
const user = inject(UserKey)  // Type is User | undefined
const user2 = inject(UserKey, defaultUser)  // Type is User
```

### 5.2 Volar / vue-tsc Toolchain

**Standard domestic setup**:
- IDE: VS Code + **Vue - Official extension** (formerly Volar, renamed after 2024). **Disable** the old TypeScript Vue Plugin.
- Enable **Takeover Mode**: disable VS Code's built-in TypeScript plugin (within the `.vue` project only), letting Volar take over all TypeScript files. Type-checking performance improves 2–3×.
- CLI checking: add `vue-tsc --noEmit` to CI. Local `pnpm dev` skips type checking (Vite omits it for speed); CI / `pnpm build` serves as the safety net.

```json
// package.json — typical domestic scripts
{
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit && vite build",
    "type-check": "vue-tsc --noEmit",
    "lint": "eslint . --fix"
  }
}
```

**Performance pitfall**: `vue-tsc` is slow on large projects, often because `include` in `tsconfig.json` is too broad (accidentally including `dist`, `node_modules`, or generated code). Diagnose with `vue-tsc --listFiles | wc -l` — a healthy project should have fewer than 2,000 files.

### 5.3 API Types and Backend Synchronization

Three mainstream approaches in domestic projects (by team size):

1. **Hand-write interfaces to match Swagger** (most common, teams of 5–15)
   - Cost: any backend field change causes drift; catching it relies on code review
   - Convergence: use Zod to gate the API layer, with types inferred from the schema

2. **Generate types from Swagger / OpenAPI tooling** (teams of 10+)
   - Tools: `openapi-typescript`, `swagger-typescript-api`, Bytedance's internal `Yapi → ts`
   - Cost: output quality depends on backend doc quality; patching is often necessary
   - Suitable for: mid/back-office projects with well-maintained backend docs and stable APIs

3. **GraphQL Codegen / tRPC** (a minority — mostly overseas-facing full-TS teams)
   - Domestic BFF projects using NestJS + GraphQL are rare, but growing in overseas products
   - Highest benefit, highest migration cost

---

## 6. Node.js / BFF Scenarios (Domestic Reality)

**Domestic Node BFF framework distribution** (rough estimate):
- **NestJS**: the first choice for new projects; best-in-class TypeScript support; DI experience similar to Spring. **Fastest growing in 2024–2026**.
- **Egg.js / Midway**: mainstream within Alibaba's internal ecosystem; limited community adoption elsewhere.
- **Express + hand-written TS**: prevalent in legacy projects; low migration cost but weak engineering discipline.
- **Koa + hand-written TS**: mid-generation legacy projects; commonly paired with `koa-router` + `class-validator`.
- **Fastify**: chosen by performance-oriented teams; small domestic market share.
- **Hono**: for edge computing / Cloudflare Workers use cases; niche but growing.

### 6.1 ESM vs CJS (Domestic Reality)

**Harsh reality**: more than 80% of domestic Node BFF codebases **are still CJS**, for these reasons:
- NestJS before v12 defaulted to CJS
- Legacy projects depend on `__dirname` / `require` patterns
- ESM had many rough edges before Node 20 (top-level `await`, JSON imports, etc.)

**2026 inflection point**:
- Node 22+ has stable support for `require(esm)`, allowing CJS to directly require ESM packages
- NestJS v12 fully switches to ESM
- There is no good reason for new projects to use CJS

**Recommendations**:
- New Node projects: **ESM** (`"type": "module"`), but note that `import './x.js'` MUST include the file extension.
- Existing CJS projects: don't force a migration; wait until an ESM-only dependency forces your hand.
- `tsconfig` `module` / `moduleResolution`: use `Bundler` for Vite projects; use `NodeNext` for pure Node projects.

### 6.2 Common TypeScript Practices for NestJS / Express

```typescript
// ✅ Environment variable validation (Zod — every Node project should have this)
const Env = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string(),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
})
export const env = Env.parse(process.env)

// ✅ Custom Error class — never throw a raw string
export class BizError extends Error {
  constructor(public code: number, message: string) { super(message) }
}

// ✅ Use unknown for external input; force validation
export async function handleWebhook(body: unknown) {
  const data = WebhookSchema.parse(body)  // Zod validates at the gate
  // Use data.xxx safely inside
}
```

**NestJS in domestic projects**: commonly paired with `class-validator` + `class-transformer` (the decorator style is familiar to backend developers coming from Java Bean Validation). **Decorators and Zod are not mutually exclusive**: use class-validator for DTOs at the controller layer, and Zod for data-flow validation in internal business logic.

---

## 7. Incremental JS → TS Migration (The Primary Battleground for Domestic Legacy Projects)

Domestic projects with large Vue 2 + JS codebases that need to upgrade to Vue 3 + TS should **never attempt a full switch at once**.

### Phase 1: Allow JS and TS to Coexist (1–2 weeks)

```json
{
  "compilerOptions": {
    "allowJs": true,
    "checkJs": false,      // Don't check JS files yet
    "strict": false,
    "noImplicitAny": false
  },
  "include": ["src/**/*.ts", "src/**/*.tsx", "src/**/*.vue", "src/**/*.js"]
}
```

- Leave legacy `.js` files untouched
- Enforce `.ts` for all new files
- Change `<script>` to `<script lang="ts">` in `.vue` files, but allow `any` inside

### Phase 2: Migrate Core Modules to TS (1–2 months)

- Prioritize: API call layer, Store / Pinia, utility functions, shared components
- Business pages come later
- Migrate one file completely at a time — **never leave a file half `.js` and half `.ts`**

### Phase 3: Enable `strict` (At the Team's Own Pace)

- Enable `strict` first, before enabling `noImplicitAny`
- Use `// @ts-expect-error fix-later #issueXXX` to annotate legacy violations
- Build a dashboard tracking `any` count and `@ts-expect-error` count; drive them down week by week

### Phase 4: Zod at the Boundaries (Ongoing)

- New API endpoints: use Zod directly
- Existing endpoints: convert them opportunistically during refactors
- Do not require full coverage in one pass

**A common mistake in domestic projects**: leadership announces "everyone switches to strict TypeScript next month," and the result is that everyone frantically sprinkles `any` everywhere to keep CI green. The type system becomes decoration, and the team develops a negative impression of TypeScript. **Incremental tier upgrades beat big-bang mandates.**

---

## 8. Anti-Pattern Catalog (Ordered by Domestic Frequency)

| # | Anti-pattern | Frequency | Why it's a problem |
|---|---|---|---|
| 1 | `as any` / `data as any` | Very high | The single biggest type system escape hatch; should be caught in PR review |
| 2 | Every field in an `interface` marked `?:` | Very high | Spreads uncertainty throughout the codebase; validate at the boundary instead |
| 3 | Function parameters without types (implicit any) | High | Turning off `noImplicitAny` effectively disables the type system |
| 4 | `ref([])` without a type parameter | High | Inferred as `Ref<never[]>`; subsequent `push` calls can only be fixed with `any` |
| 5 | Same concept defined as both `interface XxxVO` and `type XxxDto` | High | Dual sources of truth; guaranteed to drift |
| 6 | `// @ts-ignore` without a reason | High | Use `// @ts-expect-error <reason>` instead; TypeScript upgrades will surface stale suppressions |
| 7 | Overusing `enum` | Medium | Use `as const` objects + string literal unions instead; tree-shake friendly |
| 8 | Hand-copying backend fields into interfaces without staying in sync | Medium | Use `openapi-typescript` to generate types automatically |
| 9 | Writing component props as `Object as PropType<User>` | Medium | Use Vue 3.3+ generic `defineProps<Props>()` instead |
| 10 | Using `Object` / `{}` as a type | Medium | Use `Record<string, unknown>` or a concrete `interface` |
| 11 | Unconstrained bare generics `<T>` | Medium | Use at least `<T extends ...>` |
| 12 | Copying `React.FC` patterns into Vue projects | Low | Vue doesn't have this; in `setup`, a function is just a function |
| 13 | Not enabling `noUncheckedIndexedAccess` (strict tier) | High | Most domestic projects skip it; revisit when moving to Tier C |
| 14 | Hand-writing a type and a schema separately without linking them | High | Use `z.infer` to derive types — single source of truth |

---

## 9. ESLint / Prettier Stack (Dominant Domestic Tooling)

Domestic mid/back-office templates (Vben / Soybean / Youlai) have converged on:

- **`@antfu/eslint-config`** (most popular in the domestic Vue ecosystem; minimal configuration)
- **`eslint-plugin-vue`** + **`@typescript-eslint/eslint-plugin`**
- **Prettier** is gradually being replaced by the built-in stylistic rules in `@antfu/eslint-config`
- **`simple-git-hooks`** + **`lint-staged`**: auto-run lint on commit

Minimal ESLint config example (Flat Config, dominant in 2026):

```javascript
// eslint.config.js
import antfu from '@antfu/eslint-config'

export default antfu({
  vue: true,
  typescript: true,
  stylistic: true,
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn',  // ★ warn, not error
    '@typescript-eslint/no-unused-vars': 'warn',
    'vue/multi-word-component-names': 'off',
  },
})
```

**International recommendation (for reference)**: the `typescript-eslint` official `strict-type-checked` + `stylistic-type-checked` configs are the strictest available baseline, but they require `parserOptions.project`, which makes linting 3–5× slower on large projects. Most domestic projects skip this in favor of performance.

---

## 10. Authoritative References

- [TypeScript Official Do's and Don'ts](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html) — `google-ts-style.md` in this directory is a fork of this
- [Vue 3 Official TypeScript Guide](https://cn.vuejs.org/guide/typescript/overview) — all Vue 3.3+ typed APIs documented here
- [@vue/tsconfig](https://github.com/vuejs/tsconfig) — official tsconfig preset; included by default in create-vue
- [Vben Admin](https://github.com/vbenjs/vue-vben-admin) / [Soybean Admin](https://github.com/soybeanjs/soybean-admin) — benchmark domestic mid/back-office templates; practical tsconfig reference
- [Alibaba f2e-spec](https://github.com/alibaba/f2e-spec) — Alibaba frontend coding standards (TS / Vue / React)
- [typescript-eslint configs](https://typescript-eslint.io/users/configs/)
- [Zod Documentation](https://zod.dev/)
- [openapi-typescript](https://openapi-ts.dev/) — Swagger to TypeScript types; the go-to tool for domestic mid/back-office projects
- [Matt Pocock - Total TypeScript](https://www.totaltypescript.com/) — the benchmark for strict TypeScript in the international community; recommended for advanced reference
