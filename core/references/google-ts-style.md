---
name: TypeScript Coding Style Essentials (Curated)
source: https://google.github.io/styleguide/tsguide.html
note: Personal interpretation and distillation of the Google TypeScript Style Guide — not a verbatim copy. Focuses on the coding layer (naming, type syntax, imports, language features); engineering decisions are in the companion file.
companion: ts-conventions.md
---

# TypeScript Coding Style Essentials (Curated)

`ts-conventions.md` covers engineering decisions (tsconfig configuration, `any` convergence strategy, Zod adoption, Vue 3 in practice). This file covers **coding-layer rules** — naming conventions, syntax choices, and language feature guidelines to follow line by line while writing code.

---

## 1. Naming Conventions

| Context | Style | Examples |
|---|---|---|
| Classes / interfaces / enums / type aliases | `UpperCamelCase` | `UserService`, `ApiResponse` |
| Functions / methods / variables / parameters | `lowerCamelCase` | `getUserById`, `isLoading` |
| Constants (module-level, readonly primitives) | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Private fields / methods | `lowerCamelCase`; optional underscore prefix | `_cache` (not required) |
| Generic type parameters | Single uppercase letter or meaningful capitalized word | `T`, `K`, `TValue` |
| File names | `kebab-case` or `lowerCamelCase`; be consistent within the project | `user-service.ts` |

**Key points**:
- Boolean variables and function names MUST use an `is` / `has` / `can` prefix for clarity.
- Avoid abbreviations (`usr` → `user`), except for universally recognized domain terms (`url`, `id`).
- Avoid piling up meaningless single-letter generics: `<T, U, V>` is hard to read; prefer `<TKey, TValue>`.

---

## 2. `type` vs `interface`

- **Use `interface` for object shapes**: it supports inheritance (`extends`), class implementation (`implements`), and declaration merging, and produces more readable error messages.
- **Use `type` for unions, intersections, and utility types**: `type Status = 'ok' | 'err'`, `type Opt<T> = T | null`.

```typescript
// Object shapes → interface
interface Pagination { page: number; size: number; total: number }
interface UserQuery extends Pagination { keyword?: string }

// Unions / function signatures → type
type SortOrder = 'asc' | 'desc'
type Fetcher<T> = (id: string) => Promise<T>
```

---

## 3. Imports and Exports

- **Prefer named exports**; avoid exporting a single large default object from a module (hard to trace during refactors).
- **Annotate type imports explicitly**: `import type { User } from './types'`, keeping them separate from value imports (aids tree-shaking and tooling).
- **Merge imports from the same module**: never split them across two `import` lines.

```typescript
// Recommended
import type { User, Role } from './models'
import { createUser, deleteUser } from './user-service'

// Avoid: mixing types and values, duplicate imports from the same module
import { User, createUser } from './user-service'
import { Role } from './user-service'
```

- Circular dependencies are a design problem — never work around them with `import` tricks; split the module instead.
- Reference same-project files using relative paths or the `@/` alias; NEVER use absolute paths.

---

## 4. Language Features: Do / Don't

### Variable Declarations

- **Default to `const`**; only use `let` when reassignment is required. NEVER use `var`.
- Initialize variables at the point of declaration; avoid the "undefined drift" pattern of declaring first and assigning later.

```typescript
// Recommended
const user = await fetchUser(id)

// Avoid
let user: User
user = await fetchUser(id)
```

### Type Inference

- Do not annotate types that TypeScript can infer (`const x = 3` — do not write `const x: number = 3`).
- Function return types: omission is fine for simple private functions; public API functions should **always have an explicit return type** to prevent implementation details from leaking into the signature.

```typescript
// Public API: explicit return type
export function formatDate(ts: number): string { ... }

// Internal utility: omission is fine
const double = (n: number) => n * 2
```

### Avoid `any`

- Use `unknown` to receive external input; this forces the caller to narrow the type before using it.
- For type assertions, prefer `as T`; only fall back to `as unknown as T` when there is genuinely no alternative, and always leave a comment explaining why.
- For a detailed convergence strategy, see `ts-conventions.md §3`.

### Alternatives to `enum`

- Prefer `as const` objects combined with a literal union type over `enum` (enums compile to runtime objects that do not tree-shake cleanly; string enums are less bad, but numeric enums should especially be avoided).

```typescript
// Recommended
const Direction = { Up: 'UP', Down: 'DOWN' } as const
type Direction = typeof Direction[keyof typeof Direction]

// Use with caution
enum Status { Active = 'ACTIVE', Inactive = 'INACTIVE' }
```

### Classes and Functions

- Use **pure functions** for stateless utility logic; do not force them into a class. A class is not a namespace.
- Keep constructor parameters minimal; for dependency injection or configuration, prefer an options object over a long parameter list.
- Avoid empty `constructor` bodies; avoid inheritance chains whose only purpose is to share a few lines of utility code.

### Optional Chaining and Nullish Coalescing

- Prefer `?.` and `??` over hand-written `x && x.y` and `x != null ? x : default`.
- However, avoid chaining `?.` excessively: `a?.b?.c?.d?.e` is a signal that the data structure has a design problem.

---

## 5. Comments and Documentation

- **Public APIs MUST have JSDoc**: `/** description */`, with `@param` for parameters and `@returns` for the return value.
- **Internal implementation comments**: explain *why*, not *what*. Do not comment code that already reads clearly.
- **TODO format**: `// TODO(owner): description` — always include an owner. NEVER write a bare `TODO`.
- NEVER use `@ts-ignore`. When suppression is genuinely necessary, use `@ts-expect-error` and MUST include a reason on the same line or the line immediately above.

```typescript
/** Fetches a user by ID; returns null if not found. */
export async function findUser(id: string): Promise<User | null> { ... }

// @ts-expect-error: third-party library types are incomplete; pending upstream fix issue#1234
legacyLib.doSomething(value)
```

---

## 6. Other Coding Conventions

- **Destructuring**: when a function takes more than two parameters, use an options object with destructuring for better readability.
- **Template literals**: always use template literals for string concatenation; NEVER use `+`.
- **Error handling**: `e` in a `catch (e)` block is typed as `unknown`; always narrow the type before accessing properties. NEVER write `(e as any).message`.
- **`never` exhaustiveness check**: the standard pattern for exhaustive `switch` statements over a union type:

```typescript
function assertNever(x: never): never {
  throw new Error(`Unhandled branch: ${x}`)
}

switch (status) {
  case 'ok': return handleOk()
  case 'err': return handleErr()
  default: return assertNever(status)  // Compile error if a branch is missing
}
```
