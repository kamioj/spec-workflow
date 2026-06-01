---
name: TypeScript 编码风格要点（自有提炼）
source: https://google.github.io/styleguide/tsguide.html
note: 基于 Google TS Style Guide 的自有理解与提炼，非原文复制。聚焦编码规则层（命名、类型语法、imports、语言特性），工程化决策见 companion。
companion: ts-conventions.md
---

# TypeScript 编码风格要点（自有提炼）

`ts-conventions.md` 负责工程化决策（tsconfig 配置、any 收敛策略、Zod 推广、Vue 3 实战）；本文件负责**编码层规则**：写代码时逐行遵守的命名、语法、语言特性选择。

---

## 1. 命名规范

| 场景 | 风格 | 示例 |
|---|---|---|
| 类 / 接口 / 枚举 / 类型别名 | `UpperCamelCase` | `UserService`、`ApiResponse` |
| 函数 / 方法 / 变量 / 参数 | `lowerCamelCase` | `getUserById`、`isLoading` |
| 常量（模块级、只读原始值）| `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| 私有属性 / 方法 | `lowerCamelCase`，可选下划线前缀 | `_cache`（非强制）|
| 泛型参数 | 单大写字母或有意义大写词 | `T`、`K`、`TValue` |
| 文件名 | `kebab-case` 或 `lowerCamelCase`，保持项目内一致 | `user-service.ts` |

**要点**：
- 布尔变量/函数名用 `is` / `has` / `can` 前缀，语义清晰
- 避免缩写（`usr` → `user`），除非是领域公认缩写（`url`、`id`）
- 泛型避免无意义的单字母堆叠：`<T, U, V>` 难读，改用 `<TKey, TValue>`

---

## 2. type vs interface

- **对象形状用 `interface`**：支持继承（`extends`）、类实现（`implements`）、declaration merging，错误提示更可读
- **联合 / 交叉 / 工具类型用 `type`**：`type Status = 'ok' | 'err'`、`type Opt<T> = T | null`

```typescript
// 对象形状 → interface
interface Pagination { page: number; size: number; total: number }
interface UserQuery extends Pagination { keyword?: string }

// 联合 / 函数签名 → type
type SortOrder = 'asc' | 'desc'
type Fetcher<T> = (id: string) => Promise<T>
```

---

## 3. imports / exports 规范

- **优先具名导出**，避免整个模块默认导出一个大对象（重构时难追踪）
- **类型导入显式标注**：`import type { User } from './types'`，不混入值导入（有助 tree-shake 和工具识别）
- **同模块导入合并**：不要分两行 import 同一模块

```typescript
// 推荐
import type { User, Role } from './models'
import { createUser, deleteUser } from './user-service'

// 避免：类型和值混写、同模块重复 import
import { User, createUser } from './user-service'
import { Role } from './user-service'
```

- 循环依赖是设计问题，不要用 `import` 技巧绕过，应拆模块
- 引用同项目文件用相对路径或 `@/` 别名，不用绝对路径

---

## 4. 语言特性：do / don't

### 变量声明

- **默认用 `const`**，只有需要重新赋值时才用 `let`，禁用 `var`
- 变量声明时即初始化，避免先声明后赋值的"undefined 漂移"

```typescript
// 推荐
const user = await fetchUser(id)

// 避免
let user: User
user = await fetchUser(id)
```

### 类型推断

- 能推断出的类型不必显式标注（`const x = 3` 不要写 `const x: number = 3`）
- 函数返回类型：简单私有函数可省略，公共 API 函数**显式标注**，防止实现细节泄露到签名

```typescript
// 公共 API：显式返回类型
export function formatDate(ts: number): string { ... }

// 内部工具：省略无妨
const double = (n: number) => n * 2
```

### 避免 `any`

- 用 `unknown` 接收外部输入，强迫调用方做类型收窄再使用
- 类型断言优先用 `as T`，确实绕不开才用 `as unknown as T`，每处留注释说明原因
- 详细收敛策略见 `ts-conventions.md §3`

### 枚举替代

- 优先用 `as const` 对象 + 字面量联合类型，而非 `enum`（enum 编译产物有运行时对象，tree-shake 不干净；字符串枚举还好，数字枚举尤其避免）

```typescript
// 推荐
const Direction = { Up: 'UP', Down: 'DOWN' } as const
type Direction = typeof Direction[keyof typeof Direction]

// 谨慎使用
enum Status { Active = 'ACTIVE', Inactive = 'INACTIVE' }
```

### 类与函数

- 无状态工具逻辑用**纯函数**，不要强行包成 class（class 不是命名空间的替代品）
- 构造函数参数尽量少；依赖注入、配置项考虑用选项对象传参而非多参数列表
- 避免空的 `constructor`，不要写继承链只为共用几行工具代码

### 可选链 / 空值合并

- `?.` 和 `??` 优先于手写 `x && x.y`、`x != null ? x : default`
- 但不要滥用链式 `?.`：`a?.b?.c?.d?.e` 说明数据结构设计有问题

---

## 5. 注释与文档

- **公共 API 必须有 JSDoc**：`/** 描述 */`，标注参数说明用 `@param`，返回值用 `@returns`
- **内部实现注释**：说明"为什么"而非"做了什么"；代码能自解释的逻辑不必注释
- **TODO 格式**：`// TODO(owner): 描述`，要有负责人，不要裸 `TODO`
- 禁用 `@ts-ignore`；需要绕开检查用 `@ts-expect-error`，必须在同行或上一行写原因

```typescript
/** 根据用户 ID 获取用户详情，不存在时返回 null */
export async function findUser(id: string): Promise<User | null> { ... }

// @ts-expect-error: 第三方库类型不完整，待上游修复 issue#1234
legacyLib.doSomething(value)
```

---

## 6. 其他编码约定

- **解构赋值**：函数参数超过 2 个时用对象入参，配合解构可读性更好
- **模板字符串**：字符串拼接统一用模板字符串，不用 `+` 连接
- **错误处理**：`catch (e)` 中 `e` 类型是 `unknown`，先做类型判断再访问属性，不要直接 `(e as any).message`
- **`never` 穷举检查**：switch 对联合类型的 exhaustive check 标准写法：

```typescript
function assertNever(x: never): never {
  throw new Error(`未处理的分支: ${x}`)
}

switch (status) {
  case 'ok': return handleOk()
  case 'err': return handleErr()
  default: return assertNever(status)  // 漏分支时编译报错
}
```
