---
name: TypeScript 工程化决策（国内实战版）
companion: google-ts-style.md（fork 阿里巴巴风格的 Google TS 规范作为编码层）
note: 本文件聚焦"国内项目实际怎么做"，国外/官方推荐作为对照参考列在每节末尾
audience: Vue 3 + Java 全栈、国内中后台 / SaaS / 业务项目
---

# TypeScript 工程化决策（国内实战版）

`google-ts-style.md` 是语法/编码规范层；本文件是工程化决策（tsconfig 严格度、类型架构、运行时校验、Vue 3 实战、渐进迁移）。

**本文件立场**：以"国内 Vue 3 + 中后台项目里大多数团队实际怎么做"为推荐项，把官方/国外社区的理想做法作为参考列出。**不替你做道德判断**——`any` 在国内业务里就是用得多，文档要承认现实并给出可执行的收敛路径。

---

## 0. 国内 TS 工程现状速写（先认现状再谈规范）

| 维度 | 国内中后台典型 | 国外（Vercel / Stripe / Linear 风） |
|---|---|---|
| `strict` 全开 | 50% 项目开，但常关 `strictFunctionTypes` | 默认全开 |
| `noUncheckedIndexedAccess` | <10% 开启 | 推荐开启 |
| `any` 使用 | 频繁，业务赶期默认逃生口 | 视为代码异味，PR review 卡 |
| 类型来源 | 后端 Swagger/接口文档手抄 / 工具生成 | tRPC / GraphQL Codegen / OpenAPI typegen |
| 运行时校验 | 基本没有，靠后端兜底；表单用 `async-validator`（Element/AntDV 内置） | Zod / Valibot 普及 |
| 模块系统 | CJS 老项目仍占大头，新项目 ESM | ESM 已收敛 |
| 类型检查 | Vite dev 跳过，CI 用 `vue-tsc --noEmit` 兜底 | 同 |
| 主力模板 | Vben Admin / Soybean Admin / 有来 / RuoYi-Vue3 | T3 stack / Next.js + Drizzle |

**核心矛盾**：国内业务团队水平参差 + 项目交付压力大 + 后端类型不可靠（接口口径常变），导致"严格 TS"在国内常被妥协。本规范的目标是**让团队在能接受的代价内逐步收敛**，而非一刀切要求工程纯净。

---

## 1. tsconfig 三档严格度（按团队成熟度选）

国内项目状态分布很广，不要拿一套配置硬套。先自评团队，再选档：

### 档 A：宽松（存量项目 / JS 迁移中 / 初级团队为主）

适用：从 Vue 2 升 Vue 3、从 JS 改 TS、外包二开、5 人以下小团队。**目标是能跑起来**。

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": false,
    "noImplicitAny": false,        // ★ 关键妥协：允许隐式 any
    "allowJs": true,                // 允许 .js 混入
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

注意：这不是"好"配置，而是"现实"配置。**至少开 `isolatedModules` 和 `skipLibCheck`**，前者保 Vite/esbuild 不爆，后者保第三方 d.ts 烂也能编译。

### 档 B：中等（国内中后台主流 / Vben / Soybean 风格）

适用：8-30 人团队、有专职前端、新项目、TS 已使用 1 年以上。**最常见的国内配置**。

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",       // ★ Vite 项目用 Bundler 而非 NodeNext
    "strict": true,                       // ★ 开 strict
    "strictFunctionTypes": false,         // ★ 国内常关：Vue 组件 props 二变兼容旧组件
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,       // ★ 兼容老装饰器（class-validator 等）
    "jsx": "preserve",
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] },
    "types": ["vite/client", "node"],
    "lib": ["ES2022", "DOM", "DOM.Iterable"]
  }
}
```

这套对齐 **Vben Admin / Soybean Admin** 实际配置：strict 开但 strictFunctionTypes 关、不开 `noUncheckedIndexedAccess`、不开 `exactOptionalPropertyTypes`。原因是开了后老代码爆 200+ 个错改不动。

### 档 C：严格（追求工程化的国内团队 / 国外标准）

适用：30+ 人前端团队、纯新项目、有专职架构师、愿意为类型安全付前期成本。

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,        // 数组/索引访问自动加 undefined
    "exactOptionalPropertyTypes": true,      // 区分 { a?: T } 和 { a: T | undefined }
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noPropertyAccessFromIndexSignature": true,
    "verbatimModuleSyntax": true,            // 强制 import type
    // ...其余同档 B
  }
}
```

**国外推荐（参考）**：Matt Pocock / Total TypeScript 推荐档 C 全开 + 把 `tsconfig` 继承自 `@tsconfig/strictest`。国内项目能落地档 C 的不多，因为：
- `noUncheckedIndexedAccess` 一开，老代码 `list[0].name` 全报错，要加 `?.` 或断言
- `exactOptionalPropertyTypes` 与组件 props 默认值传 undefined 的习惯冲突
- 团队新人学习曲线陡

### 升档路径（从 A → C 的渐进策略）

1. **A → B 的关键开关**：先开 `strict`，预期增加 50-200 个错。允许临时 `// @ts-expect-error 待修` 标注，建迁移看板逐步消化
2. **B → C 的关键开关**：先开 `noUncheckedIndexedAccess`，这是收益最大的（防 40% 越界 bug）；`exactOptionalPropertyTypes` 留最后

---

## 2. type vs interface 分工

国内项目**最常见的现实**：同一份代码里 `interface` 和 `type` 混着用，因为不同人写不同模块、Vben/Soybean 自身也是混的。这造成约定混乱，需要在项目立项时定一次规则。

**推荐分工**：

| 用 `interface` | 用 `type` |
|---|---|
| 对象形状（实体、组件 Props、配置）| 联合类型 `A \| B` |
| 类的合约（implements）| 交叉类型 `A & B` |
| 需要继承 / 合并（declaration merging）| 函数签名 |
| 公共 API 边界（错误信息更清晰）| 工具类型 `Pick<>` / `Partial<>` 组合 |

```typescript
// ✅ 对象/类合约 → interface
interface User { id: string; name: string }
interface AdminUser extends User { perms: string[] }

// ✅ 联合 / 工具类型 → type
type Status = 'idle' | 'loading' | 'success' | 'error'
type UserResponse = Pick<User, 'id' | 'name'>
type EventHandler<T> = (e: T) => void
```

**国内常见反模式**（按出现频率）：

1. **后端字段全推导成 interface 但用 `?:` 标记所有字段为可选**——为了避后端"可能不返回某字段"的不确定性。后果是前端任何字段访问都要加 `?.`。**正确做法**：明确区分"接口契约字段必返"和"可空字段"，把不确定性挡在边界处（运行时校验）而非污染整个类型系统
2. **同一概念既有 `interface UserVO` 又有 `type UserDto`**：选一个，统一
3. **用 `type` 写所有东西因为"看起来更短"**：interface 在错误信息里更可读，对象形状坚持 interface

---

## 3. any / unknown / 断言（国内最大重灾区）

**承认现实**：`any` 在国内业务代码里就是用得多，原因：
- 后端接口返回字段不稳定，写 interface 等于绑死
- 引入老 JS 库无 `@types`
- 业务赶期，写 `as any` 5 秒搞定，写正确类型要 5 分钟
- 团队新人不会写复杂类型

**收敛策略（按代价递增）**：

```typescript
// 级别 1（最差）：放任 any
function handle(data: any) { return data.user.name }  // ❌ 类型系统形同虚设

// 级别 2（凑合）：unknown + 类型守卫
function handle(data: unknown) {
  if (isUser(data)) return data.name  // ✅ 至少强制了运行时判断
}

// 级别 3（推荐）：明确 interface + 边界校验
interface ApiResp { user: { name: string } }
function handle(data: ApiResp) { return data.user.name }
// 在调用处做一次性校验（Zod / 手写 guard），内部就放心用

// 级别 4（严苛）：Zod 全链路推导
const RespSchema = z.object({ user: z.object({ name: z.string() }) })
type ApiResp = z.infer<typeof RespSchema>
```

**项目落地建议**：
- 禁用 `as any`，改用 `as unknown as T`（写起来更丑，提醒你这是故意逃逸）
- 用 `// @ts-expect-error <原因>` 替代 `// @ts-ignore`：TS 升级后无效注释会报错，避免遗留
- ESLint 规则：`@typescript-eslint/no-explicit-any` 设为 `warn` 不要 `error`（error 会被开发同学 disable 整行，反而看不见），定期跑统计去消化
- 接口边界用 `unknown`，强迫调用方校验

**国外推荐（参考）**：`@typescript-eslint/strict-type-checked` 配置直接禁 `any`，包括 `as any`。国内项目能跑这套的少，因为存量 any 太多，开了 CI 红一片。

---

## 4. 运行时校验：国内现状与 Zod 推广

**国内现状（诚实）**：
- 表单校验 90% 用 **`async-validator`**（Element Plus / Ant Design Vue 内置）—— 但它**只校验表单输入，不校验类型**
- 接口返回基本不做运行时校验，前端"相信后端 Swagger 文档"——经常翻车
- Zod 在国内 2024-2026 渗透较快，但仍主要集中在中大厂 / 出海项目 / 新项目
- 多数团队**没听过 Valibot / ArkType**

**推荐选型分层**：

| 场景 | 国内推荐 | 国外推荐 |
|---|---|---|
| 表单校验（用户输入）| `async-validator`（UI 库自带 rules）| Zod + vee-validate |
| 接口响应校验（新项目）| **Zod**（边界处，逐步推广）| Zod |
| 接口响应校验（存量项目）| 暂不强求，只对关键接口加 | 全量加 |
| 环境变量 / 配置 | Zod（成本极低，强烈推荐立刻加）| Zod |
| Edge / 浏览器优化包体 | Zod 已够 | Valibot |

**Zod 在 Vue 项目的落地姿势**：

```typescript
// ✅ 接口边界一次校验，内部用推导出的类型
import { z } from 'zod'

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  age: z.number().int().nonnegative().optional(),
})
type User = z.infer<typeof UserSchema>  // ★ 不要手写 interface User

export async function fetchUser(id: string): Promise<User> {
  const raw = await api.get(`/user/${id}`)
  return UserSchema.parse(raw)            // 边界处强校验，失败抛错
  // 或 .safeParse() 拿到 { success, data, error }，用于不想抛异常的场景
}
```

```typescript
// ✅ 环境变量校验（成本最低，收益最高，立刻能加）
const Env = z.object({
  VITE_API_BASE: z.string().url(),
  VITE_APP_TITLE: z.string().min(1),
})
export const env = Env.parse(import.meta.env)
```

**国内特有反模式**：手写 `interface User` + 另写一份 `userFormRules`（async-validator 规则）+ Swagger 又生成一份 d.ts，三处定义同一概念，改一处忘改另两处必出 bug。**Zod 推导是单一真相源**，能解决这个问题。

---

## 5. Vue 3 + TS 实战要点（国内主战场）

### 5.1 `<script setup lang="ts">` 标配

```vue
<script setup lang="ts">
// ✅ Vue 3.3+ 类型泛型式 defineProps（推荐）
interface Props {
  user: User
  loading?: boolean
}
const props = defineProps<Props>()

// ✅ Vue 3.5+ 解构默认值（取代 withDefaults）
const { user, loading = false } = defineProps<Props>()

// ✅ defineEmits 用元组语法
const emit = defineEmits<{
  update: [value: User]
  cancel: []
}>()

// ✅ defineExpose 配合 InstanceType 拿到子组件类型
defineExpose({ refresh: () => {} })
</script>
```

**国内常见坑**：
- **Vue 2 → Vue 3 迁移项目**：还在用 `defineComponent({ props: {...} })` Options API，类型推导比 setup 弱很多。迁移建议：新组件全 setup，老组件维护时再改
- **`ref` 与泛型**：`const list = ref<User[]>([])` 而非 `ref([])`，否则推导出 `Ref<never[]>`
- **`computed` 返回类型**：复杂场景显式标注 `computed<T>(() => ...)`
- **`provide/inject` 跨组件类型**：用 `InjectionKey<T>` 强类型，否则 inject 出来全是 `unknown`

```typescript
import type { InjectionKey } from 'vue'
export const UserKey: InjectionKey<User> = Symbol('user')

// 使用
provide(UserKey, currentUser)
const user = inject(UserKey)  // 类型为 User | undefined
const user2 = inject(UserKey, defaultUser)  // 类型为 User
```

### 5.2 Volar / vue-tsc 工具链

**国内标配**：
- IDE：VS Code + **Vue - Official 扩展**（原 Volar，2024 后改名）。**关闭** TypeScript Vue Plugin 老插件
- 启用 **Takeover Mode**：禁用 VS Code 内置 TS 插件（仅 .vue 项目内），让 Volar 接管所有 TS 文件，类型检查性能提升 2-3x
- CLI 检查：`vue-tsc --noEmit` 加入 CI；本地 `pnpm dev` 不做类型检查（Vite 跳过以保速），靠 CI / `pnpm build` 兜底

```json
// package.json 国内典型脚本
{
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit && vite build",
    "type-check": "vue-tsc --noEmit",
    "lint": "eslint . --fix"
  }
}
```

**性能坑**：大项目 `vue-tsc` 慢，往往因为 `tsconfig.json` 的 `include` 太宽（把 `dist`、`node_modules`、生成代码也算进来）。检查方法：`vue-tsc --listFiles | wc -l`，正常项目应在 2000 文件内。

### 5.3 接口类型与后端联动

国内三种主流做法（按团队规模）：

1. **手写 interface 对齐 Swagger**（最常见，5-15 人团队）
   - 代价：后端改字段必脱钩，靠 code review 兜底
   - 收敛：用 Zod 收口在接口层，类型推导自 schema

2. **用工具从 Swagger / OpenAPI 生成**（10+ 人团队）
   - 工具：`openapi-typescript`、`swagger-typescript-api`、字节内部 `Yapi → ts`
   - 代价：生成结果质量看后端文档质量，常需 patch
   - 适合：后端文档规范、接口稳定的中后台

3. **GraphQL Codegen / tRPC**（少数前后端 TS 团队，主要出海项目）
   - 国内 BFF 用 NestJS + GraphQL 的少，但出海产品越来越多
   - 收益最大、改造成本也最大

---

## 6. Node.js / BFF 场景（国内现实）

**国内 Node BFF 框架分布**（粗估）：
- **NestJS**：新项目首选，TS 支持最完整，DI 体验接近 Spring。**国内 2024-2026 增长最快**
- **Egg.js / Midway**：阿里系内部主流，社区项目少
- **Express + 手写 TS**：老项目居多，迁移成本低但工程化弱
- **Koa + 手写 TS**：中等老项目，常配 `koa-router` + `class-validator`
- **Fastify**：性能党选用，国内占比小
- **Hono**：边缘计算 / Cloudflare Workers 党，小众但增长

### 6.1 ESM vs CJS（国内现状）

**残酷现实**：国内 Node BFF **存量 80%+ 仍是 CJS**，原因：
- NestJS 12 之前默认 CJS
- 老项目依赖 `__dirname` / `require` 模式
- ESM 在 Node 20 之前坑多（顶层 await、json import 等）

**2026 转折点**：
- Node 22+ 已稳定支持 `require(esm)`，CJS 可直接 require ESM 包
- NestJS v12 全量切 ESM
- 新项目无理由不用 ESM

**推荐**：
- 新 Node 项目：**ESM**（`"type": "module"`），但要注意 `import './x.js'` 必须带扩展名
- 存量 CJS 项目：不必强迁，等遇到必须升级的 ESM-only 依赖时再处理
- tsconfig `module` / `moduleResolution`：Vite 项目用 `Bundler`，纯 Node 项目用 `NodeNext`

### 6.2 NestJS / Express 常见 TS 实践

```typescript
// ✅ 环境变量校验（Zod，国内任何 Node 项目都该加）
const Env = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string(),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
})
export const env = Env.parse(process.env)

// ✅ 自定义 Error 类，避免 throw 'string'
export class BizError extends Error {
  constructor(public code: number, message: string) { super(message) }
}

// ✅ 外部输入用 unknown，强制校验
export async function handleWebhook(body: unknown) {
  const data = WebhookSchema.parse(body)  // Zod 把关
  // 内部安心用 data.xxx
}
```

**NestJS 国内特色**：常和 `class-validator` + `class-transformer` 搭配（装饰器风格类似 Java Bean Validation，国内后端转前端友好）。**装饰器与 Zod 不冲突**：DTO 用 class-validator（控制器层）+ 内部业务用 Zod（数据流校验）。

---

## 7. 渐进式 JS → TS 迁移（国内存量项目主战场）

国内大量 Vue 2 + JS 项目要升 Vue 3 + TS，**不要一次性全改**。

### 阶段 1：允许 JS 共存（1-2 周）

```json
{
  "compilerOptions": {
    "allowJs": true,
    "checkJs": false,      // 暂不检查 JS
    "strict": false,
    "noImplicitAny": false
  },
  "include": ["src/**/*.ts", "src/**/*.tsx", "src/**/*.vue", "src/**/*.js"]
}
```

- 老 `.js` 文件原样保留
- 新文件强制 `.ts`
- `vue` 文件 `<script>` 改 `<script lang="ts">`，但内部允许 `any`

### 阶段 2：核心模块迁 TS（1-2 月）

- 优先迁：API 调用层、Store / Pinia、工具函数、公共组件
- 业务页面后迁
- 一个文件一次迁完，**不要 .js 和 .ts 各保留一半**

### 阶段 3：开 strict（看团队节奏）

- 先开 `strict` 不开 `noImplicitAny`
- 用 `// @ts-expect-error 待修 #issueXXX` 标注遗留
- 建 dashboard 跟踪 `any` 数量 / `@ts-expect-error` 数量，逐周下降

### 阶段 4：边界 Zod 化（持续）

- 新接口直接 Zod
- 老接口在重构时机顺手改
- 不强求一次性全覆盖

**国内常见错误做法**：领导喊"下个月全切 TS 严格模式"，结果：所有人疯狂加 `any` 应付，类型系统变成装饰，团队对 TS 形成负面印象。**渐进升档比一刀切重要**。

---

## 8. 反模式清单（按国内出现频率排序）

| # | 反模式 | 频率 | 为什么 |
|---|---|---|---|
| 1 | `as any` / `data as any` | 极高 | 类型逃逸最大入口，PR 应 review 拦截 |
| 2 | `interface` 所有字段都 `?:` | 极高 | 把不确定性扩散到全代码，应在边界处校验 |
| 3 | 函数参数无类型（隐式 any）| 高 | `noImplicitAny` 关了就废了类型系统 |
| 4 | `ref([])` 不带泛型 | 高 | 推导出 `Ref<never[]>`，后续 push 报错只能 `any` 绕 |
| 5 | 同概念 `interface XxxVO` + `type XxxDto` 各定义 | 高 | 双源，必脱钩 |
| 6 | `// @ts-ignore` 无原因 | 高 | 改用 `// @ts-expect-error <原因>`，TS 升级会提示 |
| 7 | `enum` 滥用 | 中 | 改用 `as const` 对象 + 联合字符串，treeshake 友好 |
| 8 | 后端字段手抄 interface 不同步 | 中 | 用 openapi-typescript 自动生成 |
| 9 | 组件 props 写 `Object as PropType<User>` | 中 | Vue 3.3+ 用 `defineProps<Props>()` 泛型写法 |
| 10 | `Object` / `{}` 作类型 | 中 | 用 `Record<string, unknown>` 或具体 interface |
| 11 | 无 constraint 的裸泛型 `<T>` | 中 | 至少 `<T extends ...>` |
| 12 | `React.FC` 在 Vue 项目里抄过来 | 低 | Vue 没这玩意，setup 直接函数即可 |
| 13 | 不开 `noUncheckedIndexedAccess`（严格档）| 高 | 国内大多不开，进档 C 再考虑 |
| 14 | 手写 type + 手写 schema 不联动 | 高 | 用 `z.infer` 推导，单一真相源 |

---

## 9. ESLint / Prettier 配套（国内主流栈）

国内中后台模板（Vben / Soybean / 有来）的 ESLint 配置都收敛到：

- **`@antfu/eslint-config`**（国内 Vue 圈最流行，配置极简）
- **`eslint-plugin-vue`** + **`@typescript-eslint/eslint-plugin`**
- **Prettier** 慢慢被 `@antfu/eslint-config` 内置的 stylistic 规则取代
- **`simple-git-hooks`** + **`lint-staged`**：commit 前自动跑 lint

最小 ESLint 配置示例（Flat Config，2026 主流）：

```javascript
// eslint.config.js
import antfu from '@antfu/eslint-config'

export default antfu({
  vue: true,
  typescript: true,
  stylistic: true,
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn',  // ★ warn 而非 error
    '@typescript-eslint/no-unused-vars': 'warn',
    'vue/multi-word-component-names': 'off',
  },
})
```

**国外推荐（参考）**：`typescript-eslint` 官方的 `strict-type-checked` + `stylistic-type-checked` 是最严格基线，但需要开 `parserOptions.project`，大项目 lint 慢 3-5x。国内项目大多不开，性能优先。

---

## 10. 权威信息源

- [TypeScript 官方 Do's and Don'ts](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html) — 本目录 `google-ts-style.md` 即是 fork
- [Vue 3 官方 TS 指南](https://cn.vuejs.org/guide/typescript/overview) — Vue 3.3+ 类型化 API 全在这
- [@vue/tsconfig](https://github.com/vuejs/tsconfig) — 官方 tsconfig preset，create-vue 默认引入
- [Vben Admin](https://github.com/vbenjs/vue-vben-admin) / [Soybean Admin](https://github.com/soybeanjs/soybean-admin) — 国内中后台模板标杆，tsconfig 实战参考
- [阿里 f2e-spec](https://github.com/alibaba/f2e-spec) — 阿里前端规约（含 TS / Vue / React）
- [typescript-eslint configs](https://typescript-eslint.io/users/configs/)
- [Zod 中文文档](https://zod.nodejs.cn/) / [Zod 官方](https://zod.dev/)
- [openapi-typescript](https://openapi-ts.dev/) — Swagger 转 TS 类型，国内中后台首选
- [Matt Pocock - Total TypeScript](https://www.totaltypescript.com/) — 国外严格派的标杆，可作进阶参考
