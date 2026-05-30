---
name: Vue 3 Official Style Guide
source: https://vuejs.org/style-guide/
fork-date: 2026-05-14
note: 官方四个优先级规则合并，原样保留英文。Composition API / Pinia / 目录结构补充见末尾。
---

# Vue 3 Style Guide (Fork)

本文件 fork 自 Vue 官方 [LLM-friendly style guide](https://vuejs.org/style-guide.md)。

**四个优先级**：
- A. Essential：硬规则，违反必然出错
- B. Strongly Recommended：高度推荐
- C. Recommended：可读性建议
- D. Use with Caution：危险模式

---

## A. Essential (Error Prevention)


::: warning Note
This Vue.js Style Guide is outdated and needs to be reviewed. If you have any questions or suggestions, please [open an issue](https://github.com/vuejs/docs/issues/new).
:::

These rules help prevent errors, so learn and abide by them at all costs. Exceptions may exist, but should be very rare and only be made by those with expert knowledge of both JavaScript and Vue.

## Use multi-word component names {#use-multi-word-component-names}

User component names should always be multi-word, except for root `App` components. This [prevents conflicts](https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name) with existing and future HTML elements, since all HTML elements are a single word.

```vue-html
<!-- in pre-compiled templates -->
<Item />

<!-- in in-DOM templates -->
<item></item>
```

```vue-html
<!-- in pre-compiled templates -->
<TodoItem />

<!-- in in-DOM templates -->
<todo-item></todo-item>
```

## Use detailed prop definitions {#use-detailed-prop-definitions}

In committed code, prop definitions should always be as detailed as possible, specifying at least type(s).

::: details Detailed Explanation
Detailed [prop definitions](/guide/components/props#prop-validation) have two advantages:

* They document the API of the component, so that it's easy to see how the component is meant to be used.
* In development, Vue will warn you if a component is ever provided incorrectly formatted props, helping you catch potential sources of error.
  :::

```js
// This is only OK when prototyping
props: ['status']
```

```js
props: {
  status: String
}
```

```js
// Even better!
props: {
  status: {
    type: String,
    required: true,

    validator: value => {
      return [
        'syncing',
        'synced',
        'version-conflict',
        'error'
      ].includes(value)
    }
  }
}
```

```js
// This is only OK when prototyping
const props = defineProps(['status'])
```

```js
const props = defineProps({
  status: String
})
```

```js
// Even better!

const props = defineProps({
  status: {
    type: String,
    required: true,

    validator: (value) => {
      return ['syncing', 'synced', 'version-conflict', 'error'].includes(
        value
      )
    }
  }
})
```

## Use keyed `v-for` {#use-keyed-v-for}

`key` with `v-for` is *always* required on components, in order to maintain internal component state down the subtree. Even for elements though, it's a good practice to maintain predictable behavior, such as [object constancy](https://bost.ocks.org/mike/constancy/) in animations.

::: details Detailed Explanation
Let's say you have a list of todos:

```js
data() {
  return {
    todos: [
      {
        id: 1,
        text: 'Learn to use v-for'
      },
      {
        id: 2,
        text: 'Learn to use key'
      }
    ]
  }
}
```

```js
const todos = ref([
  {
    id: 1,
    text: 'Learn to use v-for'
  },
  {
    id: 2,
    text: 'Learn to use key'
  }
])
```

Then you sort them alphabetically. When updating the DOM, Vue will optimize rendering to perform the cheapest DOM mutations possible. That might mean deleting the first todo element, then adding it again at the end of the list.

The problem is, there are cases where it's important not to delete elements that will remain in the DOM. For example, you may want to use `<transition-group>` to animate list sorting, or maintain focus if the rendered element is an `<input>`. In these cases, adding a unique key for each item (e.g. `:key="todo.id"`) will tell Vue how to behave more predictably.

In our experience, it's better to *always* add a unique key, so that you and your team simply never have to worry about these edge cases. Then in the rare, performance-critical scenarios where object constancy isn't necessary, you can make a conscious exception.
:::

```vue-html
<ul>
  <li v-for="todo in todos">
    {{ todo.text }}
  </li>
</ul>
```

```vue-html
<ul>
  <li
    v-for="todo in todos"
    :key="todo.id"
  >
    {{ todo.text }}
  </li>
</ul>
```

## Avoid `v-if` with `v-for` {#avoid-v-if-with-v-for}

**Never use `v-if` on the same element as `v-for`.**

There are two common cases where this can be tempting:

* To filter items in a list (e.g. `v-for="user in users" v-if="user.isActive"`). In these cases, replace `users` with a new computed property that returns your filtered list (e.g. `activeUsers`).

* To avoid rendering a list if it should be hidden (e.g. `v-for="user in users" v-if="shouldShowUsers"`). In these cases, move the `v-if` to a container element (e.g. `ul`, `ol`).

::: details Detailed Explanation
When Vue processes directives, `v-if` has a higher priority than `v-for`, so that this template:

```vue-html
<ul>
  <li
    v-for="user in users"
    v-if="user.isActive"
    :key="user.id"
  >
    {{ user.name }}
  </li>
</ul>
```

Will throw an error, because the `v-if` directive will be evaluated first and the iteration variable `user` does not exist at this moment.

This could be fixed by iterating over a computed property instead, like this:

```js
computed: {
  activeUsers() {
    return this.users.filter(user => user.isActive)
  }
}
```

```js
const activeUsers = computed(() => {
  return users.filter((user) => user.isActive)
})
```

```vue-html
<ul>
  <li
    v-for="user in activeUsers"
    :key="user.id"
  >
    {{ user.name }}
  </li>
</ul>
```

Alternatively, we can use a `<template>` tag with `v-for` to wrap the `<li>` element:

```vue-html
<ul>
  <template v-for="user in users" :key="user.id">
    <li v-if="user.isActive">
      {{ user.name }}
    </li>
  </template>
</ul>
```

:::

```vue-html
<ul>
  <li
    v-for="user in users"
    v-if="user.isActive"
    :key="user.id"
  >
    {{ user.name }}
  </li>
</ul>
```

```vue-html
<ul>
  <li
    v-for="user in activeUsers"
    :key="user.id"
  >
    {{ user.name }}
  </li>
</ul>
```

```vue-html
<ul>
  <template v-for="user in users" :key="user.id">
    <li v-if="user.isActive">
      {{ user.name }}
    </li>
  </template>
</ul>
```

## Use component-scoped styling {#use-component-scoped-styling}

For applications, styles in a top-level `App` component and in layout components may be global, but all other components should always be scoped.

This is only relevant for [Single-File Components](/guide/scaling-up/sfc). It does *not* require that the [`scoped` attribute](https://vue-loader.vuejs.org/guide/scoped-css.html) be used. Scoping could be through [CSS modules](https://vue-loader.vuejs.org/guide/css-modules.html), a class-based strategy such as [BEM](http://getbem.com/), or another library/convention.

**Component libraries, however, should prefer a class-based strategy instead of using the `scoped` attribute.**

This makes overriding internal styles easier, with human-readable class names that don't have too high specificity, but are still very unlikely to result in a conflict.

::: details Detailed Explanation
If you are developing a large project, working with other developers, or sometimes include 3rd-party HTML/CSS (e.g. from Auth0), consistent scoping will ensure that your styles only apply to the components they are meant for.

Beyond the `scoped` attribute, using unique class names can help ensure that 3rd-party CSS does not apply to your own HTML. For example, many projects use the `button`, `btn`, or `icon` class names, so even if not using a strategy such as BEM, adding an app-specific and/or component-specific prefix (e.g. `ButtonClose-icon`) can provide some protection.
:::

```vue-html
<template>
  <button class="btn btn-close">×</button>
</template>

<style>
.btn-close {
  background-color: red;
}
</style>
```

```vue-html
<template>
  <button class="button button-close">×</button>
</template>

<!-- Using the `scoped` attribute -->
<style scoped>
.button {
  border: none;
  border-radius: 2px;
}

.button-close {
  background-color: red;
}
</style>
```

```vue-html
<template>
  <button :class="[$style.button, $style.buttonClose]">×</button>
</template>

<!-- Using CSS modules -->
<style module>
.button {
  border: none;
  border-radius: 2px;
}

.buttonClose {
  background-color: red;
}
</style>
```

```vue-html
<template>
  <button class="c-Button c-Button--close">×</button>
</template>

<!-- Using the BEM convention -->
<style>
.c-Button {
  border: none;
  border-radius: 2px;
}

.c-Button--close {
  background-color: red;
}
</style>
```

---

## B. Strongly Recommended


::: warning Note
This Vue.js Style Guide is outdated and needs to be reviewed. If you have any questions or suggestions, please [open an issue](https://github.com/vuejs/docs/issues/new).
:::

These rules have been found to improve readability and/or developer experience in most projects. Your code will still run if you violate them, but violations should be rare and well-justified.

## Component files {#component-files}

**Whenever a build system is available to concatenate files, each component should be in its own file.**

This helps you to more quickly find a component when you need to edit it or review how to use it.

```js
app.component('TodoList', {
  // ...
})

app.component('TodoItem', {
  // ...
})
```

```
components/
|- TodoList.js
|- TodoItem.js
```

```
components/
|- TodoList.vue
|- TodoItem.vue
```

## Single-file component filename casing {#single-file-component-filename-casing}

**Filenames of [Single-File Components](/guide/scaling-up/sfc) should either be always PascalCase or always kebab-case.**

PascalCase works best with autocompletion in code editors, as it's consistent with how we reference components in JS(X) and templates, wherever possible. However, mixed case filenames can sometimes create issues on case-insensitive file systems, which is why kebab-case is also perfectly acceptable.

```
components/
|- mycomponent.vue
```

```
components/
|- myComponent.vue
```

```
components/
|- MyComponent.vue
```

```
components/
|- my-component.vue
```

## Base component names {#base-component-names}

**Base components (a.k.a. presentational, dumb, or pure components) that apply app-specific styling and conventions should all begin with a specific prefix, such as `Base`, `App`, or `V`.**

::: details Detailed Explanation
These components lay the foundation for consistent styling and behavior in your application. They may **only** contain:

* HTML elements,
* other base components, and
* 3rd-party UI components.

But they'll **never** contain global state (e.g. from a [Pinia](https://pinia.vuejs.org/) store).

Their names often include the name of an element they wrap (e.g. `BaseButton`, `BaseTable`), unless no element exists for their specific purpose (e.g. `BaseIcon`). If you build similar components for a more specific context, they will almost always consume these components (e.g. `BaseButton` may be used in `ButtonSubmit`).

Some advantages of this convention:

* When organized alphabetically in editors, your app's base components are all listed together, making them easier to identify.

* Since component names should always be multi-word, this convention prevents you from having to choose an arbitrary prefix for simple component wrappers (e.g. `MyButton`, `VueButton`).

* Since these components are so frequently used, you may want to simply make them global instead of importing them everywhere. A prefix makes this possible with Webpack:

  ```js
  const requireComponent = require.context(
    './src',
    true,
    /Base[A-Z]\w+\.(vue|js)$/
  )
  requireComponent.keys().forEach(function (fileName) {
    let baseComponentConfig = requireComponent(fileName)
    baseComponentConfig =
      baseComponentConfig.default || baseComponentConfig
    const baseComponentName =
      baseComponentConfig.name ||
      fileName.replace(/^.+\//, '').replace(/\.\w+$/, '')
    app.component(baseComponentName, baseComponentConfig)
  })
  ```

  :::

```
components/
|- MyButton.vue
|- VueTable.vue
|- Icon.vue
```

```
components/
|- BaseButton.vue
|- BaseTable.vue
|- BaseIcon.vue
```

```
components/
|- AppButton.vue
|- AppTable.vue
|- AppIcon.vue
```

```
components/
|- VButton.vue
|- VTable.vue
|- VIcon.vue
```

## Tightly coupled component names {#tightly-coupled-component-names}

**Child components that are tightly coupled with their parent should include the parent component name as a prefix.**

If a component only makes sense in the context of a single parent component, that relationship should be evident in its name. Since editors typically organize files alphabetically, this also keeps these related files next to each other.

::: details Detailed Explanation
You might be tempted to solve this problem by nesting child components in directories named after their parent. For example:

```
components/
|- TodoList/
   |- Item/
      |- index.vue
      |- Button.vue
   |- index.vue
```

or:

```
components/
|- TodoList/
   |- Item/
      |- Button.vue
   |- Item.vue
|- TodoList.vue
```

This isn't recommended, as it results in:

* Many files with similar names, making rapid file switching in code editors more difficult.
* Many nested sub-directories, which increases the time it takes to browse components in an editor's sidebar.
  :::

```
components/
|- TodoList.vue
|- TodoItem.vue
|- TodoButton.vue
```

```
components/
|- SearchSidebar.vue
|- NavigationForSearchSidebar.vue
```

```
components/
|- TodoList.vue
|- TodoListItem.vue
|- TodoListItemButton.vue
```

```
components/
|- SearchSidebar.vue
|- SearchSidebarNavigation.vue
```

## Order of words in component names {#order-of-words-in-component-names}

**Component names should start with the highest-level (often most general) words and end with descriptive modifying words.**

::: details Detailed Explanation
You may be wondering:

> "Why would we force component names to use less natural language?"

In natural English, adjectives and other descriptors do typically appear before the nouns, while exceptions require connector words. For example:

* Coffee *with* milk
* Soup *of the* day
* Visitor *to the* museum

You can definitely include these connector words in component names if you'd like, but the order is still important.

Also note that **what's considered "highest-level" will be contextual to your app**. For example, imagine an app with a search form. It may include components like this one:

```
components/
|- ClearSearchButton.vue
|- ExcludeFromSearchInput.vue
|- LaunchOnStartupCheckbox.vue
|- RunSearchButton.vue
|- SearchInput.vue
|- TermsCheckbox.vue
```

As you might notice, it's quite difficult to see which components are specific to the search. Now let's rename the components according to the rule:

```
components/
|- SearchButtonClear.vue
|- SearchButtonRun.vue
|- SearchInputExcludeGlob.vue
|- SearchInputQuery.vue
|- SettingsCheckboxLaunchOnStartup.vue
|- SettingsCheckboxTerms.vue
```

Since editors typically organize files alphabetically, all the important relationships between components are now evident at a glance.

You might be tempted to solve this problem differently, nesting all the search components under a "search" directory, then all the settings components under a "settings" directory. We only recommend considering this approach in very large apps (e.g. 100+ components), for these reasons:

* It generally takes more time to navigate through nested sub-directories, than scrolling through a single `components` directory.
* Name conflicts (e.g. multiple `ButtonDelete.vue` components) make it more difficult to quickly navigate to a specific component in a code editor.
* Refactoring becomes more difficult, because find-and-replace often isn't sufficient to update relative references to a moved component.
  :::

```
components/
|- ClearSearchButton.vue
|- ExcludeFromSearchInput.vue
|- LaunchOnStartupCheckbox.vue
|- RunSearchButton.vue
|- SearchInput.vue
|- TermsCheckbox.vue
```

```
components/
|- SearchButtonClear.vue
|- SearchButtonRun.vue
|- SearchInputQuery.vue
|- SearchInputExcludeGlob.vue
|- SettingsCheckboxTerms.vue
|- SettingsCheckboxLaunchOnStartup.vue
```

## Self-closing components {#self-closing-components}

**Components with no content should be self-closing in [Single-File Components](/guide/scaling-up/sfc), string templates, and [JSX](/guide/extras/render-function#jsx-tsx) - but never in in-DOM templates.**

Components that self-close communicate that they not only have no content, but are **meant** to have no content. It's the difference between a blank page in a book and one labeled "This page intentionally left blank." Your code is also cleaner without the unnecessary closing tag.

Unfortunately, HTML doesn't allow custom elements to be self-closing - only [official "void" elements](https://www.w3.org/TR/html/syntax.html#void-elements). That's why the strategy is only possible when Vue's template compiler can reach the template before the DOM, then serve the DOM spec-compliant HTML.

```vue-html
<!-- In Single-File Components, string templates, and JSX -->
<MyComponent></MyComponent>
```

```vue-html
<!-- In in-DOM templates -->
<my-component/>
```

```vue-html
<!-- In Single-File Components, string templates, and JSX -->
<MyComponent/>
```

```vue-html
<!-- In in-DOM templates -->
<my-component></my-component>
```

## Component name casing in templates {#component-name-casing-in-templates}

**In most projects, component names should always be PascalCase in [Single-File Components](/guide/scaling-up/sfc) and string templates - but kebab-case in in-DOM templates.**

PascalCase has a few advantages over kebab-case:

* Editors can autocomplete component names in templates, because PascalCase is also used in JavaScript.
* `<MyComponent>` is more visually distinct from a single-word HTML element than `<my-component>`, because there are two character differences (the two capitals), rather than just one (a hyphen).
* If you use any non-Vue custom elements in your templates, such as a web component, PascalCase ensures that your Vue components remain distinctly visible.

Unfortunately, due to HTML's case insensitivity, in-DOM templates must still use kebab-case.

Also note that if you've already invested heavily in kebab-case, consistency with HTML conventions and being able to use the same casing across all your projects may be more important than the advantages listed above. In those cases, **using kebab-case everywhere is also acceptable.**

```vue-html
<!-- In Single-File Components and string templates -->
<mycomponent/>
```

```vue-html
<!-- In Single-File Components and string templates -->
<myComponent/>
```

```vue-html
<!-- In in-DOM templates -->
<MyComponent></MyComponent>
```

```vue-html
<!-- In Single-File Components and string templates -->
<MyComponent/>
```

```vue-html
<!-- In in-DOM templates -->
<my-component></my-component>
```

OR

```vue-html
<!-- Everywhere -->
<my-component></my-component>
```

## Component name casing in JS/JSX {#component-name-casing-in-js-jsx}

**Component names in JS/[JSX](/guide/extras/render-function#jsx-tsx) should always be PascalCase, though they may be kebab-case inside strings for simpler applications that only use global component registration through `app.component`.**

::: details Detailed Explanation
In JavaScript, PascalCase is the convention for classes and prototype constructors - essentially, anything that can have distinct instances. Vue components also have instances, so it makes sense to also use PascalCase. As an added benefit, using PascalCase within JSX (and templates) allows readers of the code to more easily distinguish between components and HTML elements.

However, for applications that use **only** global component definitions via `app.component`, we recommend kebab-case instead. The reasons are:

* It's rare that global components are ever referenced in JavaScript, so following a convention for JavaScript makes less sense.
* These applications always include many in-DOM templates, where [kebab-case **must** be used](#component-name-casing-in-templates).
  :::

```js
app.component('myComponent', {
  // ...
})
```

```js
import myComponent from './MyComponent.vue'
```

```js
export default {
  name: 'myComponent'
  // ...
}
```

```js
export default {
  name: 'my-component'
  // ...
}
```

```js
app.component('MyComponent', {
  // ...
})
```

```js
app.component('my-component', {
  // ...
})
```

```js
import MyComponent from './MyComponent.vue'
```

```js
export default {
  name: 'MyComponent'
  // ...
}
```

## Full-word component names {#full-word-component-names}

**Component names should prefer full words over abbreviations.**

The autocompletion in editors make the cost of writing longer names very low, while the clarity they provide is invaluable. Uncommon abbreviations, in particular, should always be avoided.

```
components/
|- SdSettings.vue
|- UProfOpts.vue
```

```
components/
|- StudentDashboardSettings.vue
|- UserProfileOptions.vue
```

## Prop name casing {#prop-name-casing}

**Prop names should always use camelCase during declaration. When used inside in-DOM templates, props should be kebab-cased. Single-File Components templates and [JSX](/guide/extras/render-function#jsx-tsx) can use either kebab-case or camelCase props. Casing should be consistent - if you choose to use camelCased props, make sure you don't use kebab-cased ones in your application**

```js
props: {
  'greeting-text': String
}
```

```js
const props = defineProps({
  'greeting-text': String
})
```

```vue-html
// for in-DOM templates
<welcome-message greetingText="hi"></welcome-message>
```

```js
props: {
  greetingText: String
}
```

```js
const props = defineProps({
  greetingText: String
})
```

```vue-html
// for SFC - please make sure your casing is consistent throughout the project
// you can use either convention but we don't recommend mixing two different casing styles
<WelcomeMessage greeting-text="hi"/>
// or
<WelcomeMessage greetingText="hi"/>
```

```vue-html
// for in-DOM templates
<welcome-message greeting-text="hi"></welcome-message>
```

## Multi-attribute elements {#multi-attribute-elements}

**Elements with multiple attributes should span multiple lines, with one attribute per line.**

In JavaScript, splitting objects with multiple properties over multiple lines is widely considered a good convention, because it's much easier to read. Our templates and [JSX](/guide/extras/render-function#jsx-tsx) deserve the same consideration.

```vue-html
<img src="https://vuejs.org/images/logo.png" alt="Vue Logo">
```

```vue-html
<MyComponent foo="a" bar="b" baz="c"/>
```

```vue-html
<img
  src="https://vuejs.org/images/logo.png"
  alt="Vue Logo"
>
```

```vue-html
<MyComponent
  foo="a"
  bar="b"
  baz="c"
/>
```

## Simple expressions in templates {#simple-expressions-in-templates}

**Component templates should only include simple expressions, with more complex expressions refactored into computed properties or methods.**

Complex expressions in your templates make them less declarative. We should strive to describe *what* should appear, not *how* we're computing that value. Computed properties and methods also allow the code to be reused.

```vue-html
{{
  fullName.split(' ').map((word) => {
    return word[0].toUpperCase() + word.slice(1)
  }).join(' ')
}}
```

```vue-html
<!-- In a template -->
{{ normalizedFullName }}
```

```js
// The complex expression has been moved to a computed property
computed: {
  normalizedFullName() {
    return this.fullName.split(' ')
      .map(word => word[0].toUpperCase() + word.slice(1))
      .join(' ')
  }
}
```

```js
// The complex expression has been moved to a computed property
const normalizedFullName = computed(() =>
  fullName.value
    .split(' ')
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join(' ')
)
```

## Simple computed properties {#simple-computed-properties}

**Complex computed properties should be split into as many simpler properties as possible.**

::: details Detailed Explanation
Simpler, well-named computed properties are:

* **Easier to test**

  When each computed property contains only a very simple expression, with very few dependencies, it's much easier to write tests confirming that it works correctly.

* **Easier to read**

  Simplifying computed properties forces you to give each value a descriptive name, even if it's not reused. This makes it much easier for other developers (and future you) to focus in on the code they care about and figure out what's going on.

* **More adaptable to changing requirements**

  Any value that can be named might be useful to the view. For example, we might decide to display a message telling the user how much money they saved. We might also decide to calculate sales tax, but perhaps display it separately, rather than as part of the final price.

  Small, focused computed properties make fewer assumptions about how information will be used, so require less refactoring as requirements change.
  :::

```js
computed: {
  price() {
    const basePrice = this.manufactureCost / (1 - this.profitMargin)
    return (
      basePrice -
      basePrice * (this.discountPercent || 0)
    )
  }
}
```

```js
const price = computed(() => {
  const basePrice = manufactureCost.value / (1 - profitMargin.value)
  return basePrice - basePrice * (discountPercent.value || 0)
})
```

```js
computed: {
  basePrice() {
    return this.manufactureCost / (1 - this.profitMargin)
  },

  discount() {
    return this.basePrice * (this.discountPercent || 0)
  },

  finalPrice() {
    return this.basePrice - this.discount
  }
}
```

```js
const basePrice = computed(
  () => manufactureCost.value / (1 - profitMargin.value)
)

const discount = computed(
  () => basePrice.value * (discountPercent.value || 0)
)

const finalPrice = computed(() => basePrice.value - discount.value)
```

## Quoted attribute values {#quoted-attribute-values}

**Non-empty HTML attribute values should always be inside quotes (single or double, whichever is not used in JS).**

While attribute values without any spaces are not required to have quotes in HTML, this practice often leads to *avoiding* spaces, making attribute values less readable.

```vue-html
<input type=text>
```

```vue-html
<AppSidebar :style={width:sidebarWidth+'px'}>
```

```vue-html
<input type="text">
```

```vue-html
<AppSidebar :style="{ width: sidebarWidth + 'px' }">
```

## Directive shorthands {#directive-shorthands}

**Directive shorthands (`:` for `v-bind:`, `@` for `v-on:` and `#` for `v-slot`) should be used always or never.**

```vue-html
<input
  v-bind:value="newTodoText"
  :placeholder="newTodoInstructions"
>
```

```vue-html
<input
  v-on:input="onInput"
  @focus="onFocus"
>
```

```vue-html
<template v-slot:header>
  <h1>Here might be a page title</h1>
</template>

<template #footer>
  <p>Here's some contact info</p>
</template>
```

```vue-html
<input
  :value="newTodoText"
  :placeholder="newTodoInstructions"
>
```

```vue-html
<input
  v-bind:value="newTodoText"
  v-bind:placeholder="newTodoInstructions"
>
```

```vue-html
<input
  @input="onInput"
  @focus="onFocus"
>
```

```vue-html
<input
  v-on:input="onInput"
  v-on:focus="onFocus"
>
```

```vue-html
<template v-slot:header>
  <h1>Here might be a page title</h1>
</template>

<template v-slot:footer>
  <p>Here's some contact info</p>
</template>
```

```vue-html
<template #header>
  <h1>Here might be a page title</h1>
</template>

<template #footer>
  <p>Here's some contact info</p>
</template>
```

---

## C. Recommended


::: warning Note
This Vue.js Style Guide is outdated and needs to be reviewed. If you have any questions or suggestions, please [open an issue](https://github.com/vuejs/docs/issues/new).
:::

Where multiple, equally good options exist, an arbitrary choice can be made to ensure consistency. In these rules, we describe each acceptable option and suggest a default choice. That means you can feel free to make a different choice in your own codebase, as long as you're consistent and have a good reason. Please do have a good reason though! By adapting to the community standard, you will:

1. Train your brain to more easily parse most of the community code you encounter
2. Be able to copy and paste most community code examples without modification
3. Often find new hires are already accustomed to your preferred coding style, at least in regards to Vue

## Component/instance options order {#component-instance-options-order}

**Component/instance options should be ordered consistently.**

This is the default order we recommend for component options. They're split into categories, so you'll know where to add new properties from plugins.

1. **Global Awareness** (requires knowledge beyond the component)

   * `name`

2. **Template Compiler Options** (changes the way templates are compiled)

   * `compilerOptions`

3. **Template Dependencies** (assets used in the template)

   * `components`
   * `directives`

4. **Composition** (merges properties into the options)

   * `extends`
   * `mixins`
   * `provide`/`inject`

5. **Interface** (the interface to the component)

   * `inheritAttrs`
   * `props`
   * `emits`

6. **Composition API** (the entry point for using the Composition API)

   * `setup`

7. **Local State** (local reactive properties)

   * `data`
   * `computed`

8. **Events** (callbacks triggered by reactive events)

   * `watch`
   * Lifecycle Events (in the order they are called)
     * `beforeCreate`
     * `created`
     * `beforeMount`
     * `mounted`
     * `beforeUpdate`
     * `updated`
     * `activated`
     * `deactivated`
     * `beforeUnmount`
     * `unmounted`
     * `errorCaptured`
     * `renderTracked`
     * `renderTriggered`

9. **Non-Reactive Properties** (instance properties independent of the reactivity system)

   * `methods`

10. **Rendering** (the declarative description of the component output)
    * `template`/`render`

## Element attribute order {#element-attribute-order}

**The attributes of elements (including components) should be ordered consistently.**

This is the default order we recommend for component options. They're split into categories, so you'll know where to add custom attributes and directives.

1. **Definition** (provides the component options)

   * `is`

2. **List Rendering** (creates multiple variations of the same element)

   * `v-for`

3. **Conditionals** (whether the element is rendered/shown)

   * `v-if`
   * `v-else-if`
   * `v-else`
   * `v-show`
   * `v-cloak`

4. **Render Modifiers** (changes the way the element renders)

   * `v-pre`
   * `v-once`

5. **Global Awareness** (requires knowledge beyond the component)

   * `id`

6. **Unique Attributes** (attributes that require unique values)

   * `ref`
   * `key`

7. **Two-Way Binding** (combining binding and events)

   * `v-model`

8. **Other Attributes** (all unspecified bound & unbound attributes)

9. **Events** (component event listeners)

   * `v-on`

10. **Content** (overrides the content of the element)
    * `v-html`
    * `v-text`

## Empty lines in component/instance options {#empty-lines-in-component-instance-options}

**You may want to add one empty line between multi-line properties, particularly if the options can no longer fit on your screen without scrolling.**

When components begin to feel cramped or difficult to read, adding spaces between multi-line properties can make them easier to skim again. In some editors, such as Vim, formatting options like this can also make them easier to navigate with the keyboard.

```js
props: {
  value: {
    type: String,
    required: true
  },

  focused: {
    type: Boolean,
    default: false
  },

  label: String,
  icon: String
},

computed: {
  formattedValue() {
    // ...
  },

  inputClasses() {
    // ...
  }
}
```

```js
// No spaces are also fine, as long as the component
// is still easy to read and navigate.
props: {
  value: {
    type: String,
    required: true
  },
  focused: {
    type: Boolean,
    default: false
  },
  label: String,
  icon: String
},
computed: {
  formattedValue() {
    // ...
  },
  inputClasses() {
    // ...
  }
}
```

```js
defineProps({
  value: {
    type: String,
    required: true
  },
  focused: {
    type: Boolean,
    default: false
  },
  label: String,
  icon: String
})
const formattedValue = computed(() => {
  // ...
})
const inputClasses = computed(() => {
  // ...
})
```

```js
defineProps({
  value: {
    type: String,
    required: true
  },

  focused: {
    type: Boolean,
    default: false
  },

  label: String,
  icon: String
})

const formattedValue = computed(() => {
  // ...
})

const inputClasses = computed(() => {
  // ...
})
```

## Single-file component top-level element order {#single-file-component-top-level-element-order}

**[Single-File Components](/guide/scaling-up/sfc) should always order `<script>`, `<template>`, and `<style>` tags consistently, with `<style>` last, because at least one of the other two is always necessary.**

```vue-html [ComponentX.vue]
<style>/* ... */</style>
<script>/* ... */</script>
<template>...</template>
```

```vue-html [ComponentA.vue]
<script>/* ... */</script>
<template>...</template>
<style>/* ... */</style>
```

```vue-html [ComponentB.vue]
<template>...</template>
<script>/* ... */</script>
<style>/* ... */</style>
```

```vue-html [ComponentA.vue]
<script>/* ... */</script>
<template>...</template>
<style>/* ... */</style>
```

```vue-html [ComponentB.vue]
<script>/* ... */</script>
<template>...</template>
<style>/* ... */</style>
```

or

```vue-html [ComponentA.vue]
<template>...</template>
<script>/* ... */</script>
<style>/* ... */</style>
```

```vue-html [ComponentB.vue]
<template>...</template>
<script>/* ... */</script>
<style>/* ... */</style>
```

---

## D. Use with Caution


::: warning Note
This Vue.js Style Guide is outdated and needs to be reviewed. If you have any questions or suggestions, please [open an issue](https://github.com/vuejs/docs/issues/new).
:::

Some features of Vue exist to accommodate rare edge cases or smoother migrations from a legacy code base. When overused however, they can make your code more difficult to maintain or even become a source of bugs. These rules shine a light on potentially risky features, describing when and why they should be avoided.

## Element selectors with `scoped` {#element-selectors-with-scoped}

**Element selectors should be avoided with `scoped`.**

Prefer class selectors over element selectors in `scoped` styles, because large numbers of element selectors are slow.

::: details Detailed Explanation
To scope styles, Vue adds a unique attribute to component elements, such as `data-v-f3f3eg9`. Then selectors are modified so that only matching elements with this attribute are selected (e.g. `button[data-v-f3f3eg9]`).

The problem is that large numbers of element-attribute selectors (e.g. `button[data-v-f3f3eg9]`) will be considerably slower than class-attribute selectors (e.g. `.btn-close[data-v-f3f3eg9]`), so class selectors should be preferred whenever possible.
:::

```vue-html
<template>
  <button>×</button>
</template>

<style scoped>
button {
  background-color: red;
}
</style>
```

```vue-html
<template>
  <button class="btn btn-close">×</button>
</template>

<style scoped>
.btn-close {
  background-color: red;
}
</style>
```

## Implicit parent-child communication {#implicit-parent-child-communication}

**Props and events should be preferred for parent-child component communication, instead of `this.$parent` or mutating props.**

An ideal Vue application is props down, events up. Sticking to this convention makes your components much easier to understand. However, there are edge cases where prop mutation or `this.$parent` can simplify two components that are already deeply coupled.

The problem is, there are also many *simple* cases where these patterns may offer convenience. Beware: do not be seduced into trading simplicity (being able to understand the flow of your state) for short-term convenience (writing less code).

```js
app.component('TodoItem', {
  props: {
    todo: {
      type: Object,
      required: true
    }
  },

  template: '<input v-model="todo.text">'
})
```

```js
app.component('TodoItem', {
  props: {
    todo: {
      type: Object,
      required: true
    }
  },

  methods: {
    removeTodo() {
      this.$parent.todos = this.$parent.todos.filter(
        (todo) => todo.id !== vm.todo.id
      )
    }
  },

  template: `
    <span>
      {{ todo.text }}
      <button @click="removeTodo">
        ×
      </button>
    </span>
  `
})
```

```js
app.component('TodoItem', {
  props: {
    todo: {
      type: Object,
      required: true
    }
  },

  emits: ['input'],

  template: `
    <input
      :value="todo.text"
      @input="$emit('input', $event.target.value)"
    >
  `
})
```

```js
app.component('TodoItem', {
  props: {
    todo: {
      type: Object,
      required: true
    }
  },

  emits: ['delete'],

  template: `
    <span>
      {{ todo.text }}
      <button @click="$emit('delete')">
        ×
      </button>
    </span>
  `
})
```

```vue
<script setup>
defineProps({
  todo: {
    type: Object,
    required: true
  }
})
</script>

<template>
  <input v-model="todo.text" />
</template>
```

```vue
<script setup>
import { getCurrentInstance } from 'vue'

const props = defineProps({
  todo: {
    type: Object,
    required: true
  }
})

const instance = getCurrentInstance()

function removeTodo() {
  const parent = instance.parent
  if (!parent) return

  parent.props.todos = parent.props.todos.filter((todo) => {
    return todo.id !== props.todo.id
  })
}
</script>

<template>
  <span>
    {{ todo.text }}
    <button @click="removeTodo">×</button>
  </span>
</template>
```

```vue
<script setup>
defineProps({
  todo: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['input'])
</script>

<template>
  <input :value="todo.text" @input="emit('input', $event.target.value)" />
</template>
```

```vue
<script setup>
defineProps({
  todo: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['delete'])
</script>

<template>
  <span>
    {{ todo.text }}
    <button @click="emit('delete')">×</button>
  </span>
</template>
```
