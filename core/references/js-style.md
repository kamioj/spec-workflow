---
name: "JavaScript / ES6+ Coding Guidelines (curated)"
source: https://github.com/airbnb/javascript
note: Key points curated in-house, covering the most frequently encountered style decisions in modern ES6+ day-to-day development. For the complete ruleset and historical rationale, see the official guide.
audience: dev agent, focused on JS/ES6+. For TypeScript-specific guidance see ts-conventions.md / google-ts-style.md.
---

# JavaScript / ES6+ Coding Guidelines (curated)

---

## 1. Variables and References

- Use `const` for any binding that will not be reassigned; use `let` only when reassignment is needed; **NEVER use `var`**.
  - `var` is function-scoped and hoisted, so variables declared inside a block leak out — a persistent source of bugs.
  - `const` does not mean immutable (object properties can still be mutated); it only guarantees the binding itself won't change.
- Declare each variable on its own line — avoid comma-separated batch declarations. This makes code easier to read and produces cleaner diffs.

```js
// ✅
const a = 1
const b = 2

// ❌
var a = 1, b = 2
```

---

## 2. Objects

- Use object literals `{}` to create objects — NEVER `new Object()`.
- Use **shorthand properties** when a property name matches the variable name; use **method shorthand** for function properties.
- Use **computed property names** for dynamic keys — write them directly inside the literal instead of assigning after the fact.

```js
const name = 'Jay'
const key = 'role'

// ✅
const user = {
  name,                    // shorthand property
  greet() { return 'hi' }, // method shorthand
  [key]: 'admin',          // computed property
}

// ❌
const user = { name: name }
user[key] = 'admin'
```

- Prefer the spread operator `...` for merging or extending objects. avoid `Object.assign` with the target as the first argument — that mutates the original and produces side effects.

```js
// ✅
const merged = { ...defaults, ...overrides }

// ❌ (mutates defaults)
const merged = Object.assign(defaults, overrides)
```

---

## 3. Arrays

- Use array literals `[]` — NEVER `new Array()`.
- Use `push` to append items — NEVER write `arr[arr.length] = x` directly.
- Copy arrays with spread `[...arr]` rather than `.slice()`.
- Convert array-like objects or iterables to real arrays using `Array.from()` or `[...iterable]`.

---

## 4. Destructuring

Destructuring reduces intermediate variables and improves readability — prefer it consistently.

- When accessing multiple properties on an object, use **object destructuring** rather than chaining dot notation repeatedly.

```js
// ✅
const { name, age } = user

// ❌
const name = user.name
const age = user.age
```

- When a function parameter is an object, destructure it directly in the parameter list and set defaults there.

```js
// ✅
function render({ title = 'Untitled', visible = true } = {}) { ... }
```

- Use **array destructuring** when accessing elements at fixed positions.

```js
const [first, , third] = items
```

- When a function needs to return multiple values, prefer returning an object (destructured by the caller) over an array. The caller can then pull values by name, making order irrelevant.

---

## 5. Strings

- Use single quotes `'...'` for string literals (HTML attribute values typically use double quotes, so single quotes in JS make the two easy to distinguish).
- **NEVER concatenate strings with `+`**. Use **template literals** `` ` `` whenever variable interpolation is involved.

```js
// ✅
const msg = `Hello, ${name}! You have ${count} messages.`

// ❌
const msg = 'Hello, ' + name + '! You have ' + count + ' messages.'
```

- avoid line-continuation with `\` for long strings — line-ending behavior varies across platforms. Use a multi-line template literal instead.

---

## 6. Functions

- For **regular named functions**, prefer function declarations (they are hoisted and show their name in stack traces) over anonymous function expressions assigned to a variable.
- For **callbacks and higher-order function arguments**, prefer **arrow functions**: the syntax is concise and they do not bind their own `this`, eliminating the old `var self = this` workaround.

```js
// ✅ arrow function for callback
const doubled = nums.map(n => n * 2)

// ❌ unnecessary named function expression
const doubled = nums.map(function(n) { return n * 2 })
```

- When an arrow function body is a single expression, omit the braces and `return` (implicit return).
- Write parameter defaults in the function signature — NEVER check `if (x === undefined) x = default` at the top of the body.

```js
// ✅
function request(url, timeout = 5000) { ... }
```

- **NEVER use the `arguments` object** — use rest parameters `...args` instead (a real array with all array methods available).
- Mutating function parameters creates hard-to-trace side effects: **NEVER reassign a parameter variable**, and NEVER mutate properties on an object argument directly — copy it first if you need to modify it.

---

## 7. Arrow Functions: specifics

- You may omit parentheses around a single parameter: `n => n * 2`. Zero or multiple parameters always require parentheses.
- When the function body is a single object literal, wrap it in parentheses to prevent the parser from treating the braces as a block: `n => ({ id: n })`.
- Arrow functions are not appropriate as object methods — `this` will refer to the enclosing scope, not the object itself.

---

## 8. Classes

- Use `class` syntax — NEVER write prototype chains manually (`Foo.prototype.method = ...`).
- Use `extends` for inheritance and `super()` to invoke parent methods.
- MUST NOT assign arrow functions to instance properties as methods (unless you explicitly need a bound `this`) — doing so gives every instance its own copy of the function, breaking prototype sharing.

---

## 9. Modules (import / export)

- Use ES Modules (`import` / `export`) — NEVER CommonJS `require` in new projects.
- Use `export default` when a file has a single default export; use named `export` when there are multiple exports.
- **MUST NOT omit file extensions in import paths** (required by pure ESM runtimes outside of bundlers). NEVER mutate the exported objects of an imported module — side effects become untraceable.
- Place all `import` statements at the top of the file. NEVER use `import()` inside conditionals or function bodies unless you genuinely need lazy loading.
- Import from each source only once — NEVER split imports from the same module across multiple lines.

```js
// ✅
import { a, b, c } from './utils'

// ❌
import { a } from './utils'
import { b } from './utils'
```

---

## 10. Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Variables / functions | `camelCase` | `getUserName` |
| Classes / constructors / components | `PascalCase` | `UserProfile` |
| Module-level constants | `UPPER_SNAKE_CASE` | `MAX_RETRY` |
| Private (by convention) | underscore prefix `_` | `_internalCache` |
| Boolean variables | `is` / `has` / `can` prefix | `isLoading` |
| File names | Match the primary export; PascalCase for components, kebab-case for utilities | `UserCard.vue` / `date-utils.js` |

- Names MUST be descriptive. **NEVER use single-letter variable names** (loop counters like `i` are acceptable; everything else should be spelled out).
- Spell out abbreviations in full unless they are universally understood (`url`, `id`, `dom`).

---

## 11. Common Pitfalls

### == vs ===

**Always use `===` and `!==`**. NEVER use `==`.
`==` performs type coercion and produces surprising results: `'' == false` and `0 == null` both evaluate to `true`.
Exception: checking for `null` / `undefined` — `x == null` is the one readable shorthand that catches both simultaneously.

### Truthy / falsy evaluation

The following are all falsy in JS: `false`, `0`, `''`, `null`, `undefined`, `NaN`.
- You don't need `arr.length > 0` to check for a non-empty array — `arr.length` is sufficient.
- **Watch out for `0` and empty strings**: `if (count)` is `false` when `count === 0`, which may be a bug.

### `var` hoisting

`var` declarations are hoisted to the top of their enclosing function; only the declaration is hoisted, not the assignment. Accessing the variable before its declaration doesn't throw — it just returns `undefined`.
Using `const` / `let` eliminates this entirely: accessing them before declaration throws a `ReferenceError` inside the temporal dead zone, surfacing bugs earlier.

### `this` binding

A regular function's `this` depends on how it is called (strict mode, object method, constructor, etc.) and is easy to lose. When a callback is passed to a third-party library, `this` will almost certainly change.
**Solution**: use arrow functions for callbacks (they inherit `this` from the enclosing scope), or explicitly `.bind(this)` where necessary.

---

## 12. Authoritative Sources

- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript) — complete ruleset with discussion and rationale
- [MDN JavaScript Reference](https://developer.mozilla.org/en-US/docs/Web/JavaScript) — authoritative documentation for language features
- [ECMAScript Specification](https://tc39.es/ecma262/) — the language standard; the final word on ambiguous semantics
