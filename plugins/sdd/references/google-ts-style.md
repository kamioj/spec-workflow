---
name: Google TypeScript Style Guide（fork）
source: https://google.github.io/styleguide/tsguide.html
note: 完整 fork 自官方，companion: ts-conventions.md（2026 工程化决策与反模式）
---

# Google TypeScript Style Guide

> 完整抓取自 <https://google.github.io/styleguide/tsguide.html>，保留所有章节、代码块与 DO/DON'T 条目。

---

## Introduction

### Terminology notes

本指南使用 RFC 2119 术语。_must_、_must not_、_should_、_should not_、_may_ 有明确含义。_prefer_ 映射 _should_，_avoid_ 映射 _should not_。

### Guide notes

所有示例均为非规范性说明。示例中的可选格式选择不得作为强制规则。

---

## Source file basics

### File encoding: UTF-8

源文件使用 UTF-8 编码。

#### Whitespace characters

行终止符以外，只允许 ASCII 水平空格字符（0x20）作为空白。字符串字面量中所有其他空白必须转义。

#### Special escape sequences

使用特殊转义序列（`\'`、`\"`、`\\`、`\b`、`\f`、`\n`、`\r`、`\t`、`\v`），不使用数字等价形式。不使用遗留的八进制转义。

#### Non-ASCII characters

- **DO:** 使用实际 Unicode 字符（如 `∞`）；不可打印字符使用 hex 或 Unicode 转义并附说明注释

```typescript
// Good
const units = 'μs';
const output = '﻿' + content;  // byte order mark

// Bad
const units = 'μs'; // Greek letter mu, 's'
```

---

## Source file structure

文件按以下顺序组成（各节之间恰好一个空行）：

1. 版权信息（如有）
2. `@fileoverview` JSDoc（如有）
3. Imports（如有）
4. 文件实现

### `@fileoverview` JSDoc

```typescript
/**
 * @fileoverview Description of file. Lorem ipsum dolor sit amet, consectetur
 * adipiscing elit, sed do eiusmod tempor incididunt.
 */
```

### Imports

ES6 和 TypeScript 支持四种 import 变体：

| Import 类型 | 示例 | 用途 |
|---|---|---|
| module | `import * as foo from '...';` | TypeScript imports |
| named | `import {SomeThing} from '...';` | TypeScript imports |
| default | `import SomeThing from '...';` | 需要它的外部代码 |
| side-effect | `import '...';` | 有副作用的库 |

```typescript
// Good
import * as ng from '@angular/core';
import {Foo} from './foo';
import Button from 'Button';
import 'jasmine';
```

#### Import paths

- **DO:** 使用相对路径（`./foo`）引用同项目文件，不使用绝对路径（`path/to/foo`）
- **AVOID:** 过多父目录步骤（`../../../`），会遮蔽模块结构

#### Namespace versus named imports

- **PREFER named imports** 用于频繁使用的符号或名称清晰的符号
- **PREFER namespace imports** 用于从大型 API 使用许多不同符号

```typescript
// Bad: 过长的 import，不必要的命名空间化
import {Item as TableviewItem, Header as TableviewHeader, Row as TableviewRow,
  Model as TableviewModel, Renderer as TableviewRenderer} from './tableview';

// Better: 使用模块命名空间
import * as tableview from './tableview';
let item: tableview.Item|undefined;

// Better: 用本地名称引入常用函数
import {describe, it, expect} from './testing';
describe('foo', () => {
  it('bar', () => { ... });
});
```

### Exports

- **DO:** 所有代码使用具名导出（named exports）
- **DON'T:** 不使用默认导出（default exports）

```typescript
// Good
export class Foo { ... }

// Bad
export default class Foo { ... }
```

**Why no default exports?**

- 没有规范名称，增加维护难度
- 可读性差：`import Foo from './bar'` 和 `import Bar from './bar'` 均合法
- 从不存在的 named export 导入会报错；从 default 导入不存在成员则不报错

#### Mutable exports

- **DON'T:** 不允许 `export let`（可变导出）

```typescript
// Good: 用显式 getter 暴露可变绑定
let foo = 3;
window.setTimeout(() => { foo = 4; }, 1000);
export function getFoo() { return foo; };
```

#### Container classes

- **DON'T:** 不创建仅含静态方法/属性的容器类用于命名空间

```typescript
// Bad
export class Container {
  static FOO = 1;
  static bar() { return 1; }
}

// Good
export const FOO = 1;
export function bar() { return 1; }
```

### Import and export type

#### Import type

- **DO:** 只用作类型时使用 `import type {...}`；值时使用普通 import

```typescript
import type {Foo} from './foo';
import {Bar} from './foo';
import {type Foo, Bar} from './foo';
```

#### Export type

- **DO:** 重新导出类型时使用 `export type`

```typescript
export type {AnInterface} from './foo';
```

#### Use modules not namespaces

- **DON'T:** 不使用 `namespace Foo { ... }`
- **DON'T:** 不使用 `/// <reference path="..."/>`
- **DON'T:** 不使用 `require()`

---

## Language features

### Local variable declarations

#### Use const and let

- **DO:** 始终使用 `const` 或 `let`，默认用 `const`，需要重新赋值时才用 `let`
- **DON'T:** 永远不用 `var`

```typescript
const foo = otherValue;  // 如果 "foo" 不变
let bar = someValue;     // 如果 "bar" 需要重新赋值
var foo = someValue;     // Don't use
```

#### One variable per declaration

- **DON'T:** 不允许 `let a = 1, b = 2;` 这类多变量声明

---

### Array literals

#### Do not use the `Array` constructor

```typescript
// Bad
const a = new Array(2); // [undefined, undefined]
const b = new Array(2, 3); // [2, 3]

// Good
const a = [2];
const b = [2, 3];
const c = [];
c.length = 2;
Array.from<number>({length: 5}).fill(0);
```

#### Do not define properties on arrays

- **DON'T:** 不在数组上定义非数字属性（除 `length`）

#### Array destructuring

```typescript
const [a, b, c, ...rest] = generateResults();
let [, b,, d] = someArray;

// Good: 可选参数带默认值
function destructured([a = 4, b = 2] = []) { … }

// Bad
function badDestructuring([a, b] = [4, 2]) { … }
```

- **TIP:** 解包多返回值时，优先对象解构而非数组解构（可命名元素）

---

### Object literals

#### Do not use the `Object` constructor

- **DON'T:** 不使用 `Object` 构造函数；使用对象字面量 `{}`

#### Iterating objects

```typescript
// Bad
for (const x in someObj) {
  // x 可能来自原型链！
}

// Good
for (const x in someObj) {
  if (!someObj.hasOwnProperty(x)) continue;
}
for (const x of Object.keys(someObj)) { ... }
for (const [key, value] of Object.entries(someObj)) { ... }
```

#### Object destructuring

```typescript
// Good
interface Options {
  num?: number;
  str?: string;
}
function destructured({num, str = 'default'}: Options = {}) {}

// Disallowed: 嵌套过深，或非平凡默认值
function nestedTooDeeply({x: {num, str}}: {x: Options}) {}
function nontrivialDefault({num, str}: Options = {num: 42, str: 'default'}) {}
```

---

### Classes

#### Constructors

- **DO:** 构造函数调用必须使用括号，即使无参数

```typescript
const x = new Foo();  // Good
const x = new Foo;    // Bad
```

#### Class members

##### No #private fields

- **DON'T:** 不使用私有字段（`#ident`）；使用 TypeScript 可见性注解

```typescript
// Bad
class Clazz {
  #ident = 1;
}

// Good
class Clazz {
  private ident = 1;
}
```

##### Use readonly

- **DO:** 对在构造函数外不重新赋值的属性使用 `readonly`

##### Parameter properties

```typescript
// Bad: 样板代码
class Foo {
  private readonly barService: BarService;
  constructor(barService: BarService) {
    this.barService = barService;
  }
}

// Good
class Foo {
  constructor(private readonly barService: BarService) {}
}
```

##### Getters and setters

- **DO:** getter 必须是纯函数（一致结果，无副作用）

```typescript
// Bad: getter 改变可观测状态
class Foo {
  nextId = 0;
  get next() { return this.nextId++; }
}

// Bad: 无逻辑的透传 accessor
class Bar {
  private barInternal = '';
  get bar() { return this.barInternal; }
  set bar(value: string) { this.barInternal = value; }
}
```

#### Visibility

```typescript
// Bad
class Foo {
  public bar = new Bar();  // BAD: 不需要 public
  constructor(public readonly baz: Baz) {}  // BAD: readonly 已隐含
}

// Good
class Foo {
  bar = new Bar();
  constructor(public baz: Baz) {}
}
```

#### Disallowed class patterns

- **DON'T:** 不直接操作 `prototype`；不使用 mixins；不修改内置对象原型

---

### Functions

#### Prefer function declarations for named functions

```typescript
// Good
function foo() { return 42; }

// Bad
const foo = () => 42;
```

需要显式类型注解时可用箭头函数：

```typescript
const fooSearch: SearchFunction = (source, subString) => { ... };
```

#### Do not use function expressions

```typescript
// Good
bar(() => { this.doSomething(); })

// Bad
bar(function() { ... })
```

#### Rebinding `this`

```typescript
// Bad
function clickHandler() { this.textContent = 'Hello'; }
document.body.onclick = clickHandler;

// Good
document.body.onclick = () => { document.body.textContent = 'hello'; };
```

- **DO:** 优先箭头函数，而非 `f.bind(this)` 或 `const self = this`

#### Arrow functions as properties

```typescript
// Bad
class DelayHandler {
  constructor() { setTimeout(this.patienceTracker, 5000); }
  private patienceTracker = () => { this.waitedPatiently = true; }
}

// Good
class DelayHandler {
  constructor() {
    setTimeout(() => { this.patienceTracker(); }, 5000);
  }
  private patienceTracker() { this.waitedPatiently = true; }
}
```

#### Event handlers

需要注销时，箭头函数属性更合适（提供稳定引用）：

```typescript
// Good
class Component {
  onAttached() {
    window.addEventListener('onbeforeunload', this.listener);
  }
  onDetached() {
    window.removeEventListener('onbeforeunload', this.listener);
  }
  private listener = () => { confirm('Do you want to exit?'); }
}
```

#### Prefer rest and spread

```typescript
function variadic(array: string[], ...numbers: number[]) {}
```

---

### Primitive literals

#### Use single quotes

- **DO:** 普通字符串字面量使用单引号（`'`）而非双引号（`"`）

#### No line continuations

```typescript
// Disallowed
const LONG_STRING = 'This is a very very long string. \
    It inadvertently contains long stretches of spaces.';

// Good
const LONG_STRING = 'This is a very very long string. ' +
    'It does not contain long stretches of spaces.';
```

#### Template literals

```typescript
function arithmetic(a: number, b: number) {
  return `Here is a table of arithmetic operations:
${a} + ${b} = ${a + b}
${a} - ${b} = ${a - b}`;
}
```

#### Type coercion

```typescript
// Good
const bool = Boolean(false);
const str = String(aNumber);
const bool2 = !!str;
const str2 = `result: ${bool2}`;
```

- **DON'T:** 枚举值不得使用 `Boolean()` 或 `!!` 转换布尔；使用显式比较
- **DON'T:** 不使用一元 `+` 做字符串转数字强制
- **DON'T:** 不使用 `parseInt` 或 `parseFloat`（除非非十进制字符串）

---

### Control structures

#### Control flow statements and blocks

- **DO:** 所有控制流语句（`if`/`else`/`for`/`do`/`while`）必须使用大括号块

```typescript
// Good
for (let i = 0; i < x; i++) {
  doSomethingWith(i);
}

// Bad
for (let i = 0; i < x; i++) doSomethingWith(i);

// Exception: 单行 if 可省略 block
if (x) x.doFoo();
```

#### Iterating containers

```typescript
// Good
for (const x of someArr) { ... }
for (let i = 0; i < someArr.length; i++) { ... }
for (const [i, x] of someArr.entries()) { ... }

// Bad: for-in 给的是字符串索引，不是值
for (const x in someArray) { ... }
```

#### Exception handling

##### Instantiate errors using `new`

```typescript
// Good
throw new Error('Foo is not a valid bar.');

// Bad
throw Error('Foo is not a valid bar.');
```

##### Only throw errors

```typescript
// Bad: 无堆栈追踪
throw 'oh noes!';
Promise.reject('oh noes!');

// Good
throw new Error('oh noes!');
class MyError extends Error {}
throw new MyError('my oh noes!');
```

##### Catching and rethrowing

```typescript
function assertIsError(e: unknown): asserts e is Error {
  if (!(e instanceof Error)) throw new Error("e is not an Error");
}

try {
  doSomething();
} catch (e: unknown) {
  assertIsError(e);
  displayError(e.message);
}
```

##### Empty catch blocks

```typescript
// Good
try {
  return handleNumericResponse(response);
} catch (e: unknown) {
  // Response is not numeric. Continue to handle as text.
}
```

#### Switch statements

```typescript
// Good
switch (x) {
  case Y:
    doSomethingElse();
    break;
  default:
    // nothing to do.
}
```

#### Equality checks

- **DO:** 始终使用 `===` 和 `!==`
- **Exception:** 与 null 比较可用 `== null` 同时覆盖 `null` 和 `undefined`

#### Type and non-nullability assertions

- **DO:** 尽量用运行时检查代替类型断言和非空断言

```typescript
// Bad
(x as Foo).foo();
y!.bar();

// Good
if (x instanceof Foo) { x.foo(); }
if (y) { y.bar(); }
```

##### Type assertion syntax

```typescript
// Bad
const x = (<Foo>z).length;

// Good
const x = (z as Foo).length;
```

##### Type assertions and object literals

```typescript
// Bad: 重构时字段改名不会报错
const foo = { bar: 123, bam: 'abc' } as Foo;

// Good: 重构时会在声明处报错
const foo: Foo = { bar: 123, bam: 'abc' };
```

---

### Disallowed features

- **DON'T:** 不使用基本类型包装类 `new String()`、`new Boolean()`、`new Number()`
- **DON'T:** 不依赖 ASI（自动分号插入）；所有语句显式以分号结尾
- **DON'T:** 不使用 `const enum`；使用普通 `enum`
- **DON'T:** 生产代码中不出现 `debugger`
- **DON'T:** 不使用 `with`
- **DON'T:** 不使用 `eval` 或 `Function(...string)` 构造函数
- **DON'T:** 不使用非标准 ECMAScript 或 Web Platform 特性
- **DON'T:** 不修改内置类型的构造函数或原型方法

---

## Naming

### Identifiers

标识符只使用 ASCII 字母、数字、下划线（用于常量和结构化测试方法名），以及（极少数情况）`$`。

#### Naming style

- **DON'T:** 不用前导或尾随下划线表示私有
- **DON'T:** 不用 `opt_` 前缀表示可选参数
- **DON'T:** 不特殊标记接口（不用 `IMyInterface`）

#### Descriptive names

```typescript
// Good
errorCount
dnsConnectionIndex
referrerUrl
customerId

// Bad
n               // 无意义
nErr            // 歧义缩写
wgcConnections  // 只有你们组知道
cstmrId         // 删除内部字母
customerID      // ID 的 camelCase 不正确
```

#### Camel case

- **DO:** 将缩写当整个词处理：`loadHttpUrl`，不是 `loadHTTPURL`

### Rules by identifier type

| 风格 | 类型 |
|---|---|
| `UpperCamelCase` | class / interface / type / enum / decorator / type 参数 / TSX 组件 |
| `lowerCamelCase` | 变量 / 参数 / 函数 / 方法 / 属性 / 模块别名 |
| `CONSTANT_CASE` | 全局常量值，包括 enum 值 |
| `#ident` | 私有标识符（永远不用） |

#### Constants

只有模块级符号、模块级类的静态字段和模块级 enum 值才可用 `CONST_CASE`；函数内局部变量使用 `lowerCamelCase`。

---

## Type system

### Type inference

- **DO:** 对简单初始化类型（`string`、`number`、`boolean`、`RegExp`、`new` 表达式）省略类型注解

```typescript
const x = 15;  // 类型推断

// Bad: boolean 不增加可读性
const x: boolean = true;

// Bad: Set 从初始化显而易见
const x: Set<string> = new Set();

// Good: 防止泛型参数推断为 unknown
const x = new Set<string>();
```

---

### Undefined and null

- **DON'T:** 类型别名不得包含 `|null` 或 `|undefined`

```typescript
// Bad
type CoffeeResponse = Latte|Americano|undefined;

// Better
type CoffeeResponse = Latte|Americano;
class CoffeeService {
  getLatte(): CoffeeResponse|undefined { ... };
}
```

#### Prefer optional over `|undefined`

```typescript
// Good
interface CoffeeOrder {
  sugarCubes: number;
  milk?: Whole|LowFat|HalfHalf;
}
function pourCoffee(volume?: Milliliter) { ... }
```

---

### Use structural types

- **DO:** 用接口定义结构类型，不用类

```typescript
// Good
interface Foo {
  a: number;
  b: string;
}

// Bad
class Foo {
  readonly a: number;
  readonly b: number;
}
```

---

### Prefer interfaces over type literal aliases

```typescript
// Good
interface User {
  firstName: string;
  lastName: string;
}

// Bad
type User = {
  firstName: string,
  lastName: string,
}
```

---

### `Array<T>` Type

```typescript
// Good
let a: string[];
let b: readonly string[];
let e: Array<{n: number, s: string}>;
let f: Array<string|number>;

// Bad
let a: Array<string>;       // 语法糖更短
let e: {n: number, s: string}[];  // 大括号更难读
```

---

### Indexable types / index signatures

```typescript
// Good: 有意义的 key 标签
const users: {[userName: string]: number} = ...;

// Bad
const users: {[key: string]: number} = ...;
```

> 优先使用 ES6 `Map` 和 `Set` 类型，而非索引签名。

---

### Mapped and conditional types

简单接口扩展通常比 `Pick<T, Keys>` 等更清晰：

```typescript
// Complex (OK but less clear)
type FoodPreferences = Pick<User, 'favoriteIcecream'|'favoriteChocolate'>;

// Clearer
interface FoodPreferences {
  favoriteIcecream: string;
  favoriteChocolate: string;
}
```

---

### `any` Type

- **AVOID:** `any` 会屏蔽严重错误
- 替代：更具体类型、`unknown`、抑制 lint 并注释原因

```typescript
// Good: 用 unknown
const val: unknown = value;

// Bad
const danger: any = value;
danger.whoops();  // 完全未检查
```

---

### `{}` Type

- **AVOID:** `{}` 表示任何非 null/undefined 值，极少合适
- 优先用 `unknown`、`Record<string, T>`、`object`

---

### Tuple types

```typescript
// Good
function splitInHalf(input: string): [string, string] {
  return [x, y];
}
const [leftHalf, rightHalf] = splitInHalf('my string');

// 需要有意义属性名时用 inline object
function splitHostPort(address: string): {host: string, port: number} { ... }
```

---

### Wrapper types

- **NEVER:** 不使用 `String`、`Boolean`、`Number`（大写）；始终使用小写形式

---

## Toolchain requirements

### @ts-ignore

- **DON'T:** 不使用 `@ts-ignore`、`@ts-expect-error`、`@ts-nocheck`（单元测试中 `@ts-expect-error` 可有限使用）

---

## Comments and documentation

### JSDoc versus comments

- `/** JSDoc */`：给代码用户看的文档
- `// line comments`：给代码实现者看的实现注释

### Multi-line comments

- **DO:** 多行注释使用多个单行 `//`，不使用 `/* */` 块注释

### JSDoc general form

```typescript
/**
 * Multiple lines of JSDoc text are written here,
 * wrapped normally.
 * @param arg A number to do something to.
 */
function doSomething(arg: number) { … }
```

### Markdown

```typescript
// Bad: 工具会把列表渲染成一行
/**
 * Computes weight based on three factors:
 *   items sent
 *   items received
 */

// Good
/**
 * Computes weight based on three factors:
 *
 * - items sent
 * - items received
 */
```

---

## 总评

Google TypeScript Style Guide 是一份以**可维护性、可读性、类型安全**为核心的工程级规范，覆盖从文件结构、导入导出、类/函数写法、命名约定到类型系统使用（禁用 `any`/`{}`/包装类）和工具链要求（禁用 `@ts-ignore`、不用 `const enum`）的全链路约束，每条规则均附正反代码示例和背后的 **Why**。

## 信息源

- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
