---
name: "JavaScript / ES6+ 编码要点（自有提炼）"
source: https://github.com/airbnb/javascript
note: 关键要点自有提炼，覆盖现代 ES6+ 日常开发中最高频的风格决策；完整规范及历史背景见官方
audience: dev agent，聚焦 JS/ES6+，TypeScript 专项见 ts-conventions.md / google-ts-style.md
---

# JavaScript / ES6+ 编码要点（自有提炼）

---

## 1. 变量与引用

- 声明不会被重新赋值的变量一律用 `const`；需要重新赋值才用 `let`；**禁用 `var`**
  - `var` 有函数作用域提升，在块内声明的变量会泄漏到块外，是长期来源的 bug 根源
  - `const` 不代表不可变（对象属性仍可修改），仅保证绑定不变
- 每个声明独占一行，不用逗号批量声明（阅读和 diff 都更清晰）

```js
// ✅
const a = 1
const b = 2

// ❌
var a = 1, b = 2
```

---

## 2. 对象

- 用字面量 `{}` 创建对象，不用 `new Object()`
- 属性名与变量同名时用**简写属性**；函数属性用**方法简写**
- 动态属性名用**计算属性**，在字面量内直接写，不要先创建再赋值

```js
const name = 'Jay'
const key = 'role'

// ✅
const user = {
  name,                    // 简写属性
  greet() { return 'hi' }, // 方法简写
  [key]: 'admin',          // 计算属性
}

// ❌
const user = { name: name }
user[key] = 'admin'
```

- 合并/扩展对象优先用展开运算符 `...`，不要用 `Object.assign` 直接改第一个入参（会产生副作用）

```js
// ✅
const merged = { ...defaults, ...overrides }

// ❌（修改了 defaults）
const merged = Object.assign(defaults, overrides)
```

---

## 3. 数组

- 用字面量 `[]` 创建数组，不用 `new Array()`
- 追加元素用 `push`，不要直接写 `arr[arr.length] = x`
- 复制数组用展开 `[...arr]`，不用 `.slice()`
- 类数组转真数组用 `Array.from()` 或 `[...iterable]`

---

## 4. 解构

解构能减少中间变量，提高可读性，优先使用。

- 访问对象多个属性时，用**对象解构**而非反复点属性

```js
// ✅
const { name, age } = user

// ❌
const name = user.name
const age = user.age
```

- 函数参数是对象时，直接在参数位置解构并写默认值

```js
// ✅
function render({ title = 'Untitled', visible = true } = {}) { ... }
```

- 访问数组固定位置元素时，用**数组解构**

```js
const [first, , third] = items
```

- 函数需要返回多个值时，优先返回对象解构（而非数组），好处是调用方按名取值、顺序无关

---

## 5. 字符串

- 字符串字面量用单引号 `'...'`（保持一致，HTML 属性值一般用双引号，JS 里用单引号易区分）
- **禁止字符串拼接** `+`，超过变量插值场景用**模板字符串** `` ` ``

```js
// ✅
const msg = `Hello, ${name}! You have ${count} messages.`

// ❌
const msg = 'Hello, ' + name + '! You have ' + count + ' messages.'
```

- 超长字符串不要用 `\` 续行（不同平台行尾符行为不一致），用模板字符串多行即可

---

## 6. 函数

- **普通具名函数**优先用函数声明（有提升，调试栈可见名字），而非赋给变量的匿名函数表达式
- **回调、高阶函数参数**优先用**箭头函数**：语法简洁、不绑定自己的 `this`，避免老式 `var self = this` 技巧

```js
// ✅ 回调用箭头函数
const doubled = nums.map(n => n * 2)

// ❌ 不必要的具名 function 表达式
const doubled = nums.map(function(n) { return n * 2 })
```

- 箭头函数体只有一个表达式时，省略花括号和 `return`（隐式返回）
- 参数默认值写在函数签名里，不要在函数体第一行做 `if (x === undefined) x = default`

```js
// ✅
function request(url, timeout = 5000) { ... }
```

- **禁用 `arguments` 对象**，用剩余参数 `...args` 替代（是真正的数组，有完整数组方法）
- 修改函数入参会产生难以追踪的副作用：**不要重新赋值参数变量**，不要直接修改对象入参的属性（需要修改就先复制）

---

## 7. 箭头函数细则

- 只有一个参数时可省略括号：`n => n * 2`（参数为零个或多个则必须有括号）
- 函数体是单个对象字面量时，用括号包裹以避免被解析成块：`n => ({ id: n })`
- 箭头函数不适合作为对象方法（`this` 会指向外层，而非对象本身）

---

## 8. Class

- 用 `class` 语法，不用手写原型链（`Foo.prototype.method = ...`）
- 继承用 `extends`，调父类方法用 `super()`
- 实例方法不要用箭头函数赋给属性（除非明确需要绑定 `this`），会导致每个实例独立持有函数副本，无法共享原型

---

## 9. 模块（import / export）

- 用 ES Module（`import` / `export`），不用 CommonJS `require`（新项目）
- 每个文件只有一个默认导出时，用 `export default`；有多个具名导出时用具名 `export`
- **import 路径不要省略扩展名**（打包工具外的纯 ESM 运行时需要）；引入的模块不要修改它的导出对象（副作用不可追踪）
- 所有 `import` 放文件顶部，不要在条件分支或函数体里动态用 `import()`（除非确实需要懒加载）
- 每个来源只 `import` 一次，不要多行分散引入同一模块

```js
// ✅
import { a, b, c } from './utils'

// ❌
import { a } from './utils'
import { b } from './utils'
```

---

## 10. 命名约定

| 类型 | 约定 | 示例 |
|---|---|---|
| 变量 / 函数 | `camelCase` | `getUserName` |
| 类 / 构造函数 / 组件 | `PascalCase` | `UserProfile` |
| 常量（模块级不变量）| `UPPER_SNAKE_CASE` | `MAX_RETRY` |
| 私有（约定）| 下划线前缀 `_` | `_internalCache` |
| 布尔变量 | `is` / `has` / `can` 前缀 | `isLoading` |
| 文件名 | 与主导出一致，组件用 PascalCase，工具函数用 kebab-case | `UserCard.vue` / `date-utils.js` |

- 名字要有描述性，**不用单字母变量**（循环计数器 `i` 可以，其他尽量避免）
- 缩写除非极度通用（`url`、`id`、`dom`），否则写全称

---

## 11. 常见陷阱

### == vs ===

**始终用 `===` 和 `!==`**，禁用 `==`。
`==` 会做类型转换，结果常出乎意料：`'' == false`、`0 == null` 均为 `true`（不合直觉）。
例外：检查 `null` / `undefined` 时，`x == null` 是唯一可读的简写（同时判断两者）。

### 真值判断

JS 中以下值均为假值（falsy）：`false`、`0`、`''`、`null`、`undefined`、`NaN`。
- 不要用 `arr.length > 0` 来判断数组非空，用 `arr.length` 即可
- **注意 `0` 和空字符串**：`if (count)` 在 `count = 0` 时为假，可能是 bug

### var 提升

`var` 声明会提升到函数顶部，赋值留在原处；在声明前访问不报错，值为 `undefined`。
用 `const` / `let` 替代可彻底避免此类问题（访问暂时性死区会抛 ReferenceError，更早暴露错误）。

### this 绑定

普通函数的 `this` 取决于调用方式（严格模式 / 非严格模式 / 对象方法 / 构造函数），容易丢失。
回调传入第三方库时，`this` 几乎必然变化。
**解决**：回调用箭头函数（继承外层 `this`），或在必要时 `.bind(this)`。

---

## 12. 权威信息源

- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript) — 完整规范及讨论背景
- [MDN JavaScript 参考](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript) — 语言特性权威文档
- [ECMAScript 规范](https://tc39.es/ecma262/) — 语言标准，疑难语义的最终裁定
